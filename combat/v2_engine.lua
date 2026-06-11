local Events = require("combat.events")
local Symbols = require("core.symbols")
local SymbolDie = require("core.symbol_die")

local Engine = {}
Engine.__index = Engine

local TIMING_SPEND = "spend"
local TIMING_ON_HIT = "on_hit"
local TIMING_ON_WOUND_MAIM = "on_wound_maim"
local TIMING_UPKEEP = "upkeep"

local function copy_list(source)
    local copy = {}
    for index, value in ipairs(source or {}) do
        copy[index] = value
    end
    return copy
end

local function append_list(destination, source)
    for _, value in ipairs(source or {}) do
        table.insert(destination, value)
    end
end

local function slot_cost(slot)
    local cost = slot and slot.cost or {}
    local normalized = {}

    for _, symbol in ipairs(cost) do
        table.insert(normalized, Symbols.normalize(symbol))
    end

    return normalized
end

local function is_part_targetable(engine, part)
    if not part or part.status == "maimed" then
        return false
    end

    if engine and engine:is_part_untargetable(part) then
        return false
    end

    return true
end

local function part_belongs_to(combatant, part)
    if not combatant or not part then
        return false
    end

    for _, existing in ipairs(combatant.body_parts or {}) do
        if existing == part then
            return true
        end
    end

    return false
end

local function find_part(combatant, part_or_id)
    if type(part_or_id) == "table" then
        return part_or_id
    end

    if combatant and combatant.get_body_part_by_id then
        return combatant:get_body_part_by_id(part_or_id)
    end

    return nil
end

local function is_slot_filled(part, slot)
    local cost = slot_cost(slot)
    if #cost == 0 then
        return false
    end

    for index = 1, #cost do
        if not (part.slot_charge and part.slot_charge[index]) then
            return false
        end
    end

    return true
end

function Engine:new()
    local instance = {
        state = "WAITING",
        combatants = {},
        current_round = 0,
        event_queue = {},
        listeners = {},
        winner = nil,
        initiative = "player",
        dice_pools = {},
        assignments = {
            sockets = {},
            rims = {}
        },
        slot_queue = {},
        token_counter = 0,
        queue_counter = 0,
        untargetable_parts = setmetatable({}, { __mode = "k" })
    }

    return setmetatable(instance, Engine)
end

function Engine:emit(event_type, data)
    table.insert(self.event_queue, {
        type = event_type,
        data = data,
        timestamp = os.clock(),
        round = self.current_round
    })

    local listeners = self.listeners[event_type]
    if listeners then
        for _, callback in ipairs(listeners) do
            callback(data)
        end
    end
end

function Engine:on(event_type, callback)
    self.listeners[event_type] = self.listeners[event_type] or {}
    table.insert(self.listeners[event_type], callback)
end

function Engine:add_combatant(combatant)
    table.insert(self.combatants, combatant)
end

function Engine:get_opponent(combatant)
    for _, candidate in ipairs(self.combatants or {}) do
        if candidate ~= combatant then
            return candidate
        end
    end

    return nil
end

function Engine:set_initiative(initiative)
    self.initiative = initiative or "player"
end

function Engine:is_part_untargetable(part)
    return self.untargetable_parts and self.untargetable_parts[part] == true
end

function Engine:mark_part_untargetable(part, source)
    if not part then
        return
    end

    self.untargetable_parts[part] = true
    self:eject_latch(part, source)
end

function Engine:clear_round_state()
    self.dice_pools = {}
    self.assignments = {
        sockets = {},
        rims = {}
    }
    self.untargetable_parts = setmetatable({}, { __mode = "k" })

    for _, combatant in ipairs(self.combatants or {}) do
        if combatant.clear_v2_round_effects then
            combatant:clear_v2_round_effects()
        end
    end
end

function Engine:start_combat()
    self.current_round = 0
    self.event_queue = {}
    self.winner = nil
    self.slot_queue = {}
    self.state = "WAITING"
    self:emit(Events.COMBAT_START, { combatants = self.combatants })
    self:start_round()
end

function Engine:start_round()
    self.current_round = self.current_round + 1
    self.state = "ROUND_START"
    self:emit(Events.ROUND_START, { round = self.current_round })
    self:perform_upkeep()
    self:roll_all_dice()
    self.state = "ALLOCATION"
    self:emit(Events.ALLOCATION_PHASE, {
        round = self.current_round,
        initiative = self.initiative,
        dice_pools = self.dice_pools
    })
end

function Engine:perform_upkeep()
    self:clear_round_state()
    self:emit(Events.UPKEEP_PHASE, { round = self.current_round })
    self:resolve_slot_window(TIMING_UPKEEP)
end

function Engine:next_token_id()
    self.token_counter = self.token_counter + 1
    return "die_" .. tostring(self.token_counter)
end

function Engine:roll_all_dice()
    self.state = "ROLL"
    self:emit(Events.ROLL_PHASE, { round = self.current_round })

    for _, combatant in ipairs(self.combatants or {}) do
        self.dice_pools[combatant] = {}

        for _, part in ipairs(combatant.body_parts or {}) do
            local result = SymbolDie.roll(part)
            local token = {
                id = self:next_token_id(),
                owner = combatant,
                source_part = part,
                face_index = result.face_index,
                symbols = result.symbols,
                assigned = false
            }

            table.insert(self.dice_pools[combatant], token)
            self:emit(Events.DICE_ROLLED, {
                combatant = combatant,
                die = token,
                source_part = part,
                face_index = token.face_index,
                symbols = token.symbols,
                formatted = Symbols.format_face(token.symbols)
            })
        end
    end
end

function Engine:get_pool(combatant)
    self.dice_pools[combatant] = self.dice_pools[combatant] or {}
    return self.dice_pools[combatant]
end

function Engine:find_die(combatant, die_or_id)
    if type(die_or_id) == "table" then
        return die_or_id
    end

    for _, die in ipairs(self:get_pool(combatant)) do
        if die.id == die_or_id then
            return die
        end
    end

    return nil
end

function Engine:remove_die_from_pool(combatant, die)
    local pool = self:get_pool(combatant)
    for index = #pool, 1, -1 do
        if pool[index] == die then
            table.remove(pool, index)
            return true
        end
    end

    return false
end

function Engine:get_effective_symbols(combatant, die)
    local base = die and die.symbols or {}
    local pending = combatant and combatant.get_pending_next_symbols and combatant:get_pending_next_symbols() or {}
    return Symbols.with_added_symbols(base, pending), copy_list(pending)
end

function Engine:consume_pending_symbols(combatant)
    if combatant and combatant.consume_pending_next_symbols then
        return combatant:consume_pending_next_symbols()
    end

    return {}
end

function Engine:commit_die(combatant, die, effective_symbols, added_symbols)
    self:remove_die_from_pool(combatant, die)
    self:consume_pending_symbols(combatant)
    die.assigned = true
    die.effective_symbols = effective_symbols
    die.added_symbols = added_symbols
end

function Engine:classify_assignment_symbols(symbols, relevant_symbol)
    local used = {}
    local burned = {}
    local relevant = Symbols.normalize(relevant_symbol)

    for _, symbol in ipairs(symbols or {}) do
        if symbol == relevant then
            table.insert(used, symbol)
        elseif symbol ~= Symbols.BLANK then
            table.insert(burned, symbol)
        end
    end

    return used, burned
end

function Engine:assign_die_to_socket(combatant, die_or_id, part_or_id)
    local die = self:find_die(combatant, die_or_id)
    local part = find_part(combatant, part_or_id)

    if not die or not part or die.owner ~= combatant or not part_belongs_to(combatant, part) then
        return false, "invalid_die_or_part"
    end

    if part.status == "maimed" then
        return false, "part_maimed"
    end

    if self.assignments.sockets[part] then
        return false, "socket_full"
    end

    local effective, added = self:get_effective_symbols(combatant, die)
    if not Symbols.has(effective, Symbols.WARD) then
        return false, "no_ward"
    end

    local used, burned = self:classify_assignment_symbols(effective, Symbols.WARD)
    self:commit_die(combatant, die, effective, added)
    self.assignments.sockets[part] = {
        die = die,
        combatant = combatant,
        part = part,
        symbols = effective,
        used_symbols = used,
        burned_symbols = burned
    }

    self:emit(Events.DIE_ASSIGNED, {
        combatant = combatant,
        die = die,
        destination = "socket",
        part = part,
        used_symbols = used,
        burned_symbols = burned,
        added_symbols = added
    })

    return true
end

function Engine:assign_die_to_rim(attacker, die_or_id, target_part_or_id)
    local die = self:find_die(attacker, die_or_id)
    local defender = self:get_opponent(attacker)
    local target_part = find_part(defender, target_part_or_id)

    if not die or not defender or not target_part or die.owner ~= attacker then
        return false, "invalid_die_or_target"
    end

    if not is_part_targetable(self, target_part) then
        return false, "target_not_targetable"
    end

    if self.assignments.rims[target_part] then
        return false, "rim_full"
    end

    local effective, added = self:get_effective_symbols(attacker, die)
    if not Symbols.has(effective, Symbols.STRIKE) then
        return false, "no_strike"
    end

    local used, burned = self:classify_assignment_symbols(effective, Symbols.STRIKE)
    self:commit_die(attacker, die, effective, added)
    self.assignments.rims[target_part] = {
        die = die,
        attacker = attacker,
        defender = defender,
        part = target_part,
        symbols = effective,
        used_symbols = used,
        burned_symbols = burned
    }

    self:emit(Events.DIE_ASSIGNED, {
        combatant = attacker,
        die = die,
        destination = "rim",
        target_combatant = defender,
        part = target_part,
        used_symbols = used,
        burned_symbols = burned,
        added_symbols = added
    })

    return true
end

function Engine:feed_die_to_slot(combatant, die_or_id, part_or_id)
    local die = self:find_die(combatant, die_or_id)
    local part = find_part(combatant, part_or_id)

    if not die or not part or die.owner ~= combatant or not part_belongs_to(combatant, part) then
        return false, "invalid_die_or_part"
    end

    if not part:is_slot_online() then
        return false, "slot_offline"
    end

    local slot = part.slot
    local cost = slot_cost(slot)
    if #cost == 0 then
        return false, "slot_has_no_cost"
    end

    local effective, added = self:get_effective_symbols(combatant, die)
    local to_light = {}
    local burned = {}
    local hungry = part:has_keyword("Hungry") or (slot and slot.hungry)

    for _, symbol in ipairs(effective or {}) do
        local matched_index = nil

        if symbol ~= Symbols.BLANK then
            for index, required in ipairs(cost) do
                if not (part.slot_charge and part.slot_charge[index]) and not to_light[index] then
                    if hungry or required == symbol then
                        matched_index = index
                        break
                    end
                end
            end
        end

        if matched_index then
            to_light[matched_index] = symbol
        elseif symbol ~= Symbols.BLANK then
            table.insert(burned, symbol)
        end
    end

    local lit_count = 0
    for _ in pairs(to_light) do
        lit_count = lit_count + 1
    end

    if lit_count == 0 then
        return false, "no_matching_pips"
    end

    self:commit_die(combatant, die, effective, added)
    part.slot_charge = part.slot_charge or {}

    local lit = {}
    for index, symbol in pairs(to_light) do
        part.slot_charge[index] = true
        table.insert(lit, {
            index = index,
            symbol = symbol,
            required = cost[index]
        })
    end

    table.sort(lit, function(a, b) return a.index < b.index end)

    self:emit(Events.SLOT_FED, {
        combatant = combatant,
        die = die,
        part = part,
        slot = slot,
        lit = lit,
        burned_symbols = burned,
        added_symbols = added,
        filled = is_slot_filled(part, slot)
    })

    if is_slot_filled(part, slot) then
        self:trigger_slot(combatant, part, slot)
    end

    return true
end

function Engine:trigger_slot(combatant, part, slot)
    part:reset_slot_charge()

    self.queue_counter = self.queue_counter + 1
    local entry = {
        id = "slot_event_" .. tostring(self.queue_counter),
        order = self.queue_counter,
        combatant = combatant,
        part = part,
        slot = slot,
        timing = (slot.timing or TIMING_SPEND):lower(),
        effect = slot.effect or {}
    }

    table.insert(self.slot_queue, entry)

    if combatant.shadow_slot_shroud then
        self:mark_part_untargetable(part, { type = "shadow", slot = slot })
    end

    self:emit(Events.SLOT_TRIGGERED, entry)

    if entry.timing == TIMING_SPEND then
        self:resolve_slot_entry(entry)
    end
end

function Engine:remove_slot_entry(entry)
    for index = #self.slot_queue, 1, -1 do
        if self.slot_queue[index] == entry then
            table.remove(self.slot_queue, index)
            return
        end
    end
end

function Engine:resolve_slot_window(timing)
    local normalized = timing and timing:lower()
    local pending = {}

    for _, entry in ipairs(self.slot_queue or {}) do
        if entry.timing == normalized then
            table.insert(pending, entry)
        end
    end

    table.sort(pending, function(a, b) return (a.order or 0) < (b.order or 0) end)

    for _, entry in ipairs(pending) do
        self:resolve_slot_entry(entry)
    end
end

function Engine:resolve_slot_entry(entry)
    if not entry then
        return
    end

    self:remove_slot_entry(entry)

    local effect = entry.effect or {}
    local result = {
        type = effect.type or "none"
    }

    if type(effect) == "function" then
        result = effect(self, entry) or result
    elseif effect.type == "gain_crest" then
        local amount = effect.amount or 1
        self:grant_crest(entry.combatant, effect.crest, amount, { source = "slot", slot = entry.slot })
        result.crest = effect.crest
        result.amount = amount
    elseif effect.type == "heal_self" then
        local target_part = self:find_most_damaged_part(entry.combatant)
        result.target_part = target_part
        result.healed = self:apply_healing(entry.combatant, entry.combatant, target_part, effect.amount or 1, { source = "slot", slot = entry.slot })
    elseif effect.type == "add_next_symbol" then
        if entry.combatant and entry.combatant.add_next_symbol then
            entry.combatant:add_next_symbol(effect.symbol or Symbols.STRIKE)
        end
        result.symbol = effect.symbol or Symbols.STRIKE
    end

    self:emit(Events.SLOT_RESOLVED, {
        entry = entry,
        combatant = entry.combatant,
        part = entry.part,
        slot = entry.slot,
        effect = result
    })
end

function Engine:grant_crest(combatant, crest, amount, extra)
    if not combatant or not crest then
        return 0
    end

    local total = combatant:add_crest(crest, amount or 1)
    local data = {
        combatant = combatant,
        crest = crest,
        amount = amount or 1,
        total = total
    }

    for key, value in pairs(extra or {}) do
        if data[key] == nil then
            data[key] = value
        end
    end

    self:emit(Events.CREST_GAINED, data)
    return total
end

function Engine:expend_crest(combatant, crest)
    if not combatant or not crest then
        return false, "invalid_crest"
    end

    if combatant:get_crest_count(crest) <= 0 then
        return false, "crest_empty"
    end

    local effect = {
        type = crest:lower()
    }

    if crest == "Valor" then
        effect.symbol = Symbols.STRIKE
    elseif crest == "Shadow" then
        -- handled after the implementation check below
    else
        return false, "crest_not_implemented"
    end

    combatant:remove_crest(crest, 1)

    if crest == "Valor" then
        combatant:add_next_symbol(Symbols.STRIKE)
    elseif crest == "Shadow" then
        combatant.shadow_slot_shroud = true
    end

    self:emit(Events.CREST_EXPENDED, {
        combatant = combatant,
        crest = crest,
        remaining = combatant:get_crest_count(crest),
        effect = effect
    })

    return true
end

function Engine:eject_latch(part, source)
    local assignment = self.assignments.rims[part]
    if not assignment then
        return nil
    end

    self.assignments.rims[part] = nil
    self:emit(Events.LATCH_EJECTED, {
        part = part,
        assignment = assignment,
        die = assignment.die,
        source = source
    })

    return assignment
end

function Engine:find_most_damaged_part(combatant)
    local maimed = nil
    local wounded = nil

    for _, part in ipairs(combatant and combatant.body_parts or {}) do
        if part.status == "maimed" then
            maimed = maimed or part
        elseif part.status == "wounded" then
            wounded = wounded or part
        end
    end

    return wounded or maimed
end

function Engine:apply_healing(healer, target, part, amount, context)
    if not target or not part or not part.regress_damage_state then
        return false
    end

    local steps = amount or 1
    local before = part.status

    for _ = 1, steps do
        part:regress_damage_state()
    end

    local after = part.status
    local healed = before ~= after

    self:emit(Events.HEAL_APPLIED, {
        healer = healer,
        target = target,
        body_part = part,
        amount = steps,
        status_before = before,
        status_after = after,
        no_effect = not healed,
        context = context
    })

    return healed
end

function Engine:apply_damage(attacker, target, part, context)
    if not target or not part or part.status == "maimed" then
        return false
    end

    local before = part.status
    local after = part:advance_damage_state()
    local heart_loss = 0

    if after == "wounded" then
        if part:vent_slot_charge() then
            self:emit(Events.SLOT_CHARGE_VENTED, {
                combatant = target,
                part = part,
                reason = "wounded"
            })
        end
    elseif after == "maimed" then
        part:vent_slot_charge()
        heart_loss = part.hp_value or 1
        target.heart_points = math.max(0, (target.heart_points or 0) - heart_loss)
    end

    self:emit(Events.BP_STATUS_CHANGED, {
        combatant = target,
        body_part = part,
        status_before = before,
        status_after = after,
        heart_points = target.heart_points
    })

    self:emit(Events.DAMAGE_DEALT, {
        attacker = attacker,
        target = target,
        body_part = part,
        status_before = before,
        status_after = after,
        heart_point_loss = heart_loss,
        context = context
    })

    self:resolve_slot_window(TIMING_ON_WOUND_MAIM)
    return true
end

function Engine:resolve_round()
    self.state = "RESOLUTION"
    self:emit(Events.RESOLUTION_PHASE, { round = self.current_round })

    for _, defender in ipairs(self.combatants or {}) do
        for _, part in ipairs(defender.body_parts or {}) do
            local attack = self.assignments.rims[part]
            local defense = self.assignments.sockets[part]
            local strike_count = attack and Symbols.count(attack.symbols, Symbols.STRIKE) or 0
            local ward_count = defense and Symbols.count(defense.symbols, Symbols.WARD) or 0

            if part.has_keyword and part:has_keyword("Armored") and strike_count > 0 then
                strike_count = strike_count - 1
            end

            if attack or defense then
                self:emit(Events.PART_RESOLVED, {
                    defender = defender,
                    part = part,
                    attack = attack,
                    defense = defense,
                    strike_count = strike_count,
                    ward_count = ward_count,
                    hit = strike_count > ward_count
                })
            end

            if attack and strike_count > ward_count then
                self:resolve_slot_window(TIMING_ON_HIT)
                self:apply_damage(attack.attacker, defender, part, {
                    attack = attack,
                    defense = defense,
                    strike_count = strike_count,
                    ward_count = ward_count
                })
            end
        end
    end

    if self:check_combat_end() then
        self.state = "COMPLETE"
        self:emit(Events.COMBAT_END, { round = self.current_round, winner = self.winner })
    else
        self.state = "ROUND_END"
        self:emit(Events.ROUND_END, { round = self.current_round })
    end
end

function Engine:check_combat_end()
    local living = {}

    for _, combatant in ipairs(self.combatants or {}) do
        if combatant.is_defeated and not combatant:is_defeated() then
            table.insert(living, combatant)
        end
    end

    if #living == 1 then
        self.winner = living[1]
        return true
    elseif #living == 0 and #self.combatants > 0 then
        self.winner = nil
        return true
    end

    return false
end

function Engine:get_valid_destinations(combatant, die_or_id)
    local die = self:find_die(combatant, die_or_id)
    local destinations = {
        sockets = {},
        rims = {},
        slots = {}
    }

    if not die then
        return destinations
    end

    local effective = self:get_effective_symbols(combatant, die)
    local opponent = self:get_opponent(combatant)

    if Symbols.has(effective, Symbols.WARD) then
        for _, part in ipairs(combatant.body_parts or {}) do
            if part.status ~= "maimed" and not self.assignments.sockets[part] then
                table.insert(destinations.sockets, part)
            end
        end
    end

    if opponent and Symbols.has(effective, Symbols.STRIKE) then
        for _, part in ipairs(opponent.body_parts or {}) do
            if is_part_targetable(self, part) and not self.assignments.rims[part] then
                table.insert(destinations.rims, part)
            end
        end
    end

    for _, part in ipairs(combatant.body_parts or {}) do
        if part:is_slot_online() then
            local cost = slot_cost(part.slot)
            for _, symbol in ipairs(effective) do
                for index, required in ipairs(cost) do
                    if not (part.slot_charge and part.slot_charge[index]) and (part:has_keyword("Hungry") or part.slot.hungry or required == symbol) then
                        table.insert(destinations.slots, part)
                        goto next_part
                    end
                end
            end
        end
        ::next_part::
    end

    return destinations
end

function Engine:auto_allocate(combatant)
    local opponent = self:get_opponent(combatant)
    local pool_snapshot = copy_list(self:get_pool(combatant))

    local function first_available_part(parts, predicate)
        for _, part in ipairs(parts or {}) do
            if predicate(part) then
                return part
            end
        end
        return nil
    end

    for _, die in ipairs(pool_snapshot) do
        if self:find_die(combatant, die.id) then
            local effective = self:get_effective_symbols(combatant, die)

            if Symbols.has(effective, Symbols.STRIKE) and opponent then
                local target = first_available_part(opponent.body_parts, function(part)
                    return is_part_targetable(self, part) and not self.assignments.rims[part]
                end)
                if target and self:assign_die_to_rim(combatant, die.id, target) then
                    goto continue
                end
            end

            if Symbols.has(effective, Symbols.WARD) then
                local target = first_available_part(combatant.body_parts, function(part)
                    return part.status ~= "maimed" and not self.assignments.sockets[part]
                end)
                if target and self:assign_die_to_socket(combatant, die.id, target) then
                    goto continue
                end
            end

            for _, part in ipairs(combatant.body_parts or {}) do
                if self:feed_die_to_slot(combatant, die.id, part) then
                    goto continue
                end
            end
        end

        ::continue::
    end
end

return Engine
