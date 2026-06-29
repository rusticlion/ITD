local Events = require("combat.events")
local Crests = require("combat.crests")
local Effects = require("combat.v2_effects")
local Keywords = require("combat.keywords")
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

local function copy_result_fields(target, source)
    for key, value in pairs(source or {}) do
        if key ~= "actions" and target[key] == nil then
            target[key] = value
        end
    end
end

local function copy_fields(source)
    local copy = {}
    for key, value in pairs(source or {}) do
        copy[key] = value
    end
    return copy
end

local function amount_or_default(value, default)
    local numeric = tonumber(value)
    if not numeric or numeric < 1 then
        return default or 1
    end
    return math.floor(numeric)
end

local function repeated_symbol(symbol, amount)
    local symbols = {}
    local normalized = Symbols.normalize(symbol)
    for _ = 1, amount_or_default(amount, 1) do
        if normalized and normalized ~= Symbols.BLANK then
            table.insert(symbols, normalized)
        end
    end
    return symbols
end

local function normalize_destination(destination)
    local value = destination and tostring(destination):lower()
    if value == "sockets" then
        return "socket"
    elseif value == "rims" then
        return "rim"
    elseif value == "slots" then
        return "slot"
    end
    return value
end

local function modifier_applies_to_destination(modifier, destination)
    local wanted = normalize_destination(modifier and (modifier.destination or modifier.destination_kind))
    if not wanted then
        return true
    end

    local actual = normalize_destination(destination)
    return actual == nil or actual == wanted
end

local function modifier_matches_symbols(modifier, symbols)
    local match = modifier and (modifier.match or modifier.match_symbol or modifier.source_symbol)
    if not match or match == "any" then
        return true
    end

    if type(match) == "table" then
        for _, symbol in ipairs(match) do
            if Symbols.has(symbols, symbol) then
                return true
            end
        end
        return false
    end

    return Symbols.has(symbols, match)
end

local function modifier_matches_target(modifier, target_part)
    local wanted = modifier and (modifier.target_status or modifier.part_status)
    if not wanted then
        return true
    end

    return target_part ~= nil and tostring(target_part.status or ""):lower() == tostring(wanted):lower()
end

local function default_spellmark_target(destination)
    return normalize_destination(destination) == "rim" and "opponent" or "self"
end

local function spellmark_accepts_symbol(spellmark, symbols)
    local accepted = spellmark and (spellmark.symbol or spellmark.accept_symbol or Symbols.ESSENCE)
    return accepted and Symbols.has(symbols, accepted)
end

local function spellmark_part_matches(spellmark, part)
    if not spellmark or not part then
        return false
    end

    if spellmark.target_part_id and spellmark.target_part_id ~= part.id then
        return false
    end

    local wanted_type = spellmark.target_type or spellmark.part_type
    if wanted_type and tostring(wanted_type):upper() ~= tostring(part.type or ""):upper() then
        return false
    end

    return true
end

local function classify_symbols_for_relevance(symbols, relevant_symbols)
    local used = {}
    local burned = {}

    for _, symbol in ipairs(symbols or {}) do
        if relevant_symbols[symbol] then
            table.insert(used, symbol)
        elseif symbol ~= Symbols.BLANK then
            table.insert(burned, symbol)
        end
    end

    return used, burned
end

local function slot_cost(slot)
    local cost = slot and slot.cost or {}
    local normalized = {}

    for _, symbol in ipairs(cost) do
        table.insert(normalized, Symbols.normalize(symbol))
    end

    return normalized
end

local function rim_accepts_symbols(part, symbols)
    if Keywords.has(part, "Armored") and Symbols.count(symbols, Symbols.STRIKE) < 2 then
        return false, "armored_requires_two_strikes"
    end

    return true
end

local function count_contest_symbol(assignment, symbol)
    -- Resolution counts the full effective face. used/burned symbols describe
    -- destination relevance for presentation and spellmarks, not a second tally.
    return assignment and Symbols.count(assignment.symbols or {}, symbol) or 0
end

local function match_slot_feed(part, slot, symbols)
    local cost = slot_cost(slot)
    local to_light = {}
    local burned = {}
    local hungry = Keywords.slot_is_hungry(part, slot)

    for _, symbol in ipairs(symbols or {}) do
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

    return cost, to_light, burned
end

local function lit_count(to_light)
    local total = 0
    for _ in pairs(to_light or {}) do
        total = total + 1
    end
    return total
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

local function find_first_part_by_type(combatant, part_type)
    local wanted = part_type and tostring(part_type):upper()
    if not wanted then
        return nil
    end

    for _, part in ipairs(combatant and combatant.body_parts or {}) do
        if part.type and tostring(part.type):upper() == wanted and part.status ~= "maimed" then
            return part
        end
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

function Engine:new(options)
    options = options or {}
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
        spellmark_counter = 0,
        untargetable_parts = setmetatable({}, { __mode = "k" }),
        rng = options.rng
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
    self:refresh_dynamic_slot_costs()
    self:resolve_slot_window(TIMING_UPKEEP)
end

function Engine:count_damaged_parts(combatant)
    local count = 0
    for _, part in ipairs(combatant and combatant.body_parts or {}) do
        if part.status == "wounded" or part.status == "maimed" then
            count = count + 1
        end
    end
    return count
end

function Engine:refresh_dynamic_slot_costs()
    for _, combatant in ipairs(self.combatants or {}) do
        local opponent = self:get_opponent(combatant)
        for _, part in ipairs(combatant.body_parts or {}) do
            local slot = part.slot
            local rule = slot and slot.dynamic_cost
            if rule and rule.type == "opponent_damaged_parts" then
                local base_cost = slot.base_cost or slot.cost or {}
                slot.base_cost = slot.base_cost or copy_list(base_cost)

                local minimum = math.max(1, math.floor(tonumber(rule.minimum) or 1))
                local per_part = math.max(1, math.floor(tonumber(rule.per_part) or 1))
                local damaged = self:count_damaged_parts(opponent)
                local next_length = math.max(minimum, #slot.base_cost - damaged * per_part)
                local previous_length = #(slot.cost or {})
                local next_cost = {}
                for index = 1, next_length do
                    next_cost[index] = slot.base_cost[index]
                end
                slot.cost = next_cost

                if previous_length ~= next_length then
                    self:emit(Events.SLOT_COST_CHANGED, {
                        combatant = combatant,
                        part = part,
                        slot = slot,
                        previous_length = previous_length,
                        current_length = next_length,
                        damaged_parts = damaged
                    })
                end

                if part:is_slot_online() and is_slot_filled(part, slot) then
                    self:trigger_slot(combatant, part, slot)
                end
            end
        end
    end
end

function Engine:next_token_id()
    self.token_counter = self.token_counter + 1
    return "die_" .. tostring(self.token_counter)
end

function Engine:next_spellmark_id()
    self.spellmark_counter = (self.spellmark_counter or 0) + 1
    return "spellmark_" .. tostring(self.spellmark_counter)
end

function Engine:roll_all_dice()
    self.state = "ROLL"
    self:emit(Events.ROLL_PHASE, { round = self.current_round })

    for _, combatant in ipairs(self.combatants or {}) do
        self.dice_pools[combatant] = {}

        for _, part in ipairs(combatant.body_parts or {}) do
            local result = SymbolDie.roll(part, self.rng)
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

function Engine:get_effective_symbols(combatant, die, destination, target_part)
    local base = die and die.symbols or {}
    local pending = combatant and combatant.get_pending_next_symbols and combatant:get_pending_next_symbols() or {}
    local added = copy_list(pending)
    local modifiers = combatant and combatant.get_allocation_symbol_modifiers and combatant:get_allocation_symbol_modifiers() or {}

    for _, modifier in ipairs(modifiers) do
        if modifier_applies_to_destination(modifier, destination)
            and modifier_matches_symbols(modifier, base)
            and modifier_matches_target(modifier, target_part) then
            local symbol = modifier.symbol or modifier.add_symbol
            local amount = amount_or_default(modifier.amount, 1)
            for _, added_symbol in ipairs(repeated_symbol(symbol, amount)) do
                table.insert(added, added_symbol)
            end
        end
    end

    return Symbols.with_added_symbols(base, added), copy_list(added)
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

function Engine:get_assignment_spellmark(combatant, destination, part, symbols)
    local normalized_destination = normalize_destination(destination)
    local spellmarks = combatant and combatant.get_spellmarks and combatant:get_spellmarks() or {}

    for _, spellmark in ipairs(spellmarks) do
        local mark_destination = normalize_destination(spellmark.destination) or "rim"
        local target_side = spellmark.target or spellmark.target_side or default_spellmark_target(mark_destination)

        if mark_destination == normalized_destination
            and target_side == default_spellmark_target(normalized_destination)
            and spellmark_part_matches(spellmark, part)
            and spellmark_accepts_symbol(spellmark, symbols) then
            return spellmark
        end
    end

    return nil
end

function Engine:classify_destination_symbols(combatant, destination, part, symbols)
    local normalized_destination = normalize_destination(destination)
    local primary_symbol = normalized_destination == "rim" and Symbols.STRIKE or Symbols.WARD
    local relevant = {
        [primary_symbol] = true
    }
    local spellmark = self:get_assignment_spellmark(combatant, normalized_destination, part, symbols)

    if spellmark then
        relevant[Symbols.normalize(spellmark.symbol or spellmark.accept_symbol or Symbols.ESSENCE)] = true
    end

    local used, burned = classify_symbols_for_relevance(symbols, relevant)
    return used, burned, spellmark
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

    local effective, added = self:get_effective_symbols(combatant, die, "socket", part)
    local used, burned, spellmark = self:classify_destination_symbols(combatant, "socket", part, effective)
    if not Symbols.has(effective, Symbols.WARD) and not spellmark then
        return false, "no_ward"
    end

    self:commit_die(combatant, die, effective, added)
    local assignment = {
        die = die,
        combatant = combatant,
        part = part,
        symbols = effective,
        used_symbols = used,
        burned_symbols = burned,
        added_symbols = added,
        spellmark = spellmark
    }
    self.assignments.sockets[part] = assignment

    self:emit(Events.DIE_ASSIGNED, {
        combatant = combatant,
        die = die,
        destination = "socket",
        part = part,
        used_symbols = used,
        burned_symbols = burned,
        added_symbols = added,
        spellmark = spellmark
    })

    if spellmark then
        self:resolve_spellmark_assignment(combatant, spellmark, assignment)
    end

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

    local effective, added = self:get_effective_symbols(attacker, die, "rim", target_part)
    local used, burned, spellmark = self:classify_destination_symbols(attacker, "rim", target_part, effective)
    if not Symbols.has(effective, Symbols.STRIKE) and not spellmark then
        return false, "no_strike"
    end

    local accepted, reason = rim_accepts_symbols(target_part, effective)
    if not accepted then
        return false, reason
    end

    self:commit_die(attacker, die, effective, added)
    local assignment = {
        die = die,
        attacker = attacker,
        defender = defender,
        part = target_part,
        symbols = effective,
        used_symbols = used,
        burned_symbols = burned,
        added_symbols = added,
        spellmark = spellmark
    }
    self.assignments.rims[target_part] = assignment

    self:emit(Events.DIE_ASSIGNED, {
        combatant = attacker,
        die = die,
        destination = "rim",
        target_combatant = defender,
        part = target_part,
        used_symbols = used,
        burned_symbols = burned,
        added_symbols = added,
        spellmark = spellmark
    })

    if spellmark then
        self:resolve_spellmark_assignment(attacker, spellmark, assignment)
    end

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

    local effective, added = self:get_effective_symbols(combatant, die, "slot")
    local _, to_light, burned = match_slot_feed(part, slot, effective)

    if lit_count(to_light) == 0 then
        return false, "no_matching_pips"
    end

    self:commit_die(combatant, die, effective, added)
    return self:light_slot_from_symbols(combatant, die, part, slot, effective, added, to_light, burned)
end

function Engine:light_slot_from_symbols(combatant, die, part, slot, symbols, added, to_light, burned, extra)
    if not part or not slot or lit_count(to_light) == 0 then
        return false, "no_matching_pips"
    end

    local cost = slot_cost(slot)
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

    local event = {
        combatant = combatant,
        die = die,
        part = part,
        slot = slot,
        lit = lit,
        burned_symbols = burned or {},
        added_symbols = added or {},
        filled = is_slot_filled(part, slot)
    }

    for key, value in pairs(extra or {}) do
        if event[key] == nil then
            event[key] = value
        end
    end

    self:emit(Events.SLOT_FED, event)

    if is_slot_filled(part, slot) then
        self:trigger_slot(combatant, part, slot)
    end

    return true
end

function Engine:resolve_absorbent_socket(combatant, part, defense, context)
    if not (combatant and part and defense and Keywords.has(part, "Absorbent")) then
        return false
    end

    if not part:is_slot_online() then
        return false
    end

    local slot = part.slot
    if #slot_cost(slot) == 0 then
        return false
    end

    local _, to_light, burned = match_slot_feed(part, slot, defense.symbols or {})
    if lit_count(to_light) == 0 then
        return false
    end

    self.assignments.sockets[part] = nil
    self:emit(Events.KEYWORD_TRIGGERED, {
        combatant = combatant,
        part = part,
        keyword = "Absorbent",
        assignment = defense,
        context = context
    })

    return self:light_slot_from_symbols(combatant, defense.die, part, slot,
        defense.symbols or {}, defense.added_symbols or {}, to_light, burned, {
            source = "keyword",
            keyword = "Absorbent",
            assignment = defense,
            context = context
        })
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

function Engine:resolve_slot_window(timing, trigger_context)
    local normalized = timing and timing:lower()
    local pending = {}
    local trigger_part = trigger_context and trigger_context.part

    for _, entry in ipairs(self.slot_queue or {}) do
        if entry.timing == normalized and (not trigger_part or entry.part == trigger_part) then
            table.insert(pending, entry)
        end
    end

    table.sort(pending, function(a, b) return (a.order or 0) < (b.order or 0) end)

    for _, entry in ipairs(pending) do
        entry.trigger_context = trigger_context
        self:resolve_slot_entry(entry)
    end
end

function Engine:create_virtual_assignment_die(owner, source_part, symbols, source)
    local effective = Symbols.with_added_symbols(symbols or {}, {})
    return {
        id = self:next_token_id(),
        owner = owner,
        source_part = source_part,
        symbols = copy_list(effective),
        effective_symbols = copy_list(effective),
        added_symbols = {},
        assigned = true,
        virtual = true,
        source = source
    }
end

function Engine:auto_assign_symbols(entry, effect)
    local destination = normalize_destination(effect.destination) or "socket"
    local actor = entry.combatant
    local target_side = effect.target or effect.target_side
    if not target_side then
        target_side = destination == "rim" and "opponent" or "self"
    end

    local target = target_side == "opponent" and self:get_opponent(actor) or actor
    local relevant = destination == "rim" and Symbols.STRIKE or Symbols.WARD
    local symbols = repeated_symbol(effect.symbol or relevant, effect.amount or 1)
    local assigned = {}
    local wanted_type = effect.part_type and tostring(effect.part_type):upper()

    if not actor or not target or #symbols == 0 or not Symbols.has(symbols, relevant) then
        return {
            type = effect.type,
            destination = destination,
            assigned = assigned
        }
    end

    for _, part in ipairs(target.body_parts or {}) do
        local type_ok = not wanted_type or (part.type and tostring(part.type):upper() == wanted_type)
        local destination_free = destination == "rim" and not self.assignments.rims[part]
            or destination == "socket" and not self.assignments.sockets[part]
        local targetable = destination ~= "rim" or is_part_targetable(self, part)
        local rim_accepted = destination ~= "rim" or rim_accepts_symbols(part, symbols)

        if type_ok and destination_free and targetable and rim_accepted and part.status ~= "maimed" then
            local token_owner = destination == "rim" and actor or target
            local token = self:create_virtual_assignment_die(token_owner, entry.part, symbols, {
                type = "slot",
                slot = entry.slot,
                effect = effect
            })
            local used, burned = self:classify_assignment_symbols(token.effective_symbols, relevant)

            if destination == "rim" then
                self.assignments.rims[part] = {
                    die = token,
                    attacker = actor,
                    defender = target,
                    part = part,
                    symbols = token.effective_symbols,
                    used_symbols = used,
                    burned_symbols = burned,
                    added_symbols = {},
                    virtual = true,
                    source_slot = entry.slot
                }
            else
                self.assignments.sockets[part] = {
                    die = token,
                    combatant = target,
                    part = part,
                    symbols = token.effective_symbols,
                    used_symbols = used,
                    burned_symbols = burned,
                    added_symbols = {},
                    virtual = true,
                    source_slot = entry.slot
                }
            end

            table.insert(assigned, {
                part = part,
                die = token,
                symbols = token.effective_symbols
            })

            self:emit(Events.DIE_ASSIGNED, {
                combatant = actor,
                die = token,
                destination = destination,
                target_combatant = destination == "rim" and target or nil,
                part = part,
                used_symbols = used,
                burned_symbols = burned,
                added_symbols = {},
                virtual = true,
                source = token.source
            })
        end
    end

    return {
        type = effect.type,
        destination = destination,
        symbol = effect.symbol or relevant,
        amount = amount_or_default(effect.amount, 1),
        target = target,
        assigned = assigned
    }
end

function Engine:open_spellmark(entry, effect)
    local destination = normalize_destination(effect.destination) or "rim"
    local spellmark = {
        id = self:next_spellmark_id(),
        name = effect.name or effect.mark_name or (entry.slot and entry.slot.name) or "Spellmark",
        destination = destination,
        target = effect.target or effect.target_side or default_spellmark_target(destination),
        symbol = Symbols.normalize(effect.symbol or effect.accept_symbol or Symbols.ESSENCE),
        target_type = effect.target_type or effect.part_type,
        target_part_id = effect.target_part_id,
        single_use = effect.single_use ~= false,
        payload = effect.on_mark or effect.payload or effect.effect or { type = "none" },
        source = {
            type = "slot",
            slot = entry.slot,
            part = entry.part
        }
    }

    if entry.combatant and entry.combatant.add_spellmark then
        entry.combatant:add_spellmark(spellmark)
    end

    self:emit(Events.SPELLMARK_OPENED, {
        combatant = entry.combatant,
        part = entry.part,
        slot = entry.slot,
        spellmark = spellmark
    })

    return {
        type = effect.type,
        spellmark = spellmark,
        destination = destination,
        symbol = spellmark.symbol,
        target = spellmark.target
    }
end

function Engine:resolve_spellmark_assignment(combatant, spellmark, assignment)
    if not (combatant and spellmark and assignment) then
        return nil
    end

    if spellmark.single_use ~= false and combatant.remove_spellmark then
        combatant:remove_spellmark(spellmark)
    end

    local payload = spellmark.payload or { type = "none" }
    local payload_type = payload.type or "none"
    local result = {
        type = "spellmark",
        payload_type = payload_type,
        spellmark = spellmark,
        assignment = assignment,
        target_part = assignment.part
    }

    if payload_type == "damage_marked_part" or payload_type == "damage_target_part" or payload_type == "damage_assigned_part" then
        local amount = amount_or_default(payload.amount, 1)
        local target = assignment.defender or assignment.combatant or self:get_opponent(combatant)
        result.amount = amount
        result.damaged = false

        for _ = 1, amount do
            if target and assignment.part and assignment.part.status ~= "maimed" then
                result.damaged = self:apply_damage(combatant, target, assignment.part, {
                    source = "spellmark",
                    spellmark = spellmark,
                    payload = payload,
                    assignment = assignment
                }) or result.damaged
            end
        end
    elseif payload_type ~= "none" then
        result.payload = self:resolve_effect_action({
            combatant = combatant,
            part = spellmark.source and spellmark.source.part,
            slot = spellmark.source and spellmark.source.slot
        }, payload)
    end

    self:emit(Events.SPELLMARK_RESOLVED, {
        combatant = combatant,
        spellmark = spellmark,
        assignment = assignment,
        part = assignment.part,
        effect = result
    })

    if self.state ~= "COMPLETE" and self:check_combat_end() then
        self.state = "COMPLETE"
        self:emit(Events.COMBAT_END, { round = self.current_round, winner = self.winner })
    end

    return result
end

function Engine:resolve_effect_action(entry, effect)
    return Effects.execute(self, entry, effect or { type = "none" })
end

function Engine:resolve_slot_entry(entry)
    if not entry then
        return
    end

    self:remove_slot_entry(entry)

    local effect = entry.effect or {}
    local result = {
        type = type(effect) == "table" and (effect.type or "none") or "custom"
    }

    if type(effect) == "function" then
        result = effect(self, entry) or result
    else
        local actions = Effects.actions(effect)
        result = {
            type = #actions > 1 and "sequence" or ((actions[1] and actions[1].type) or "none"),
            actions = {}
        }

        for _, action in ipairs(actions) do
            local action_result = self:resolve_effect_action(entry, action)
            table.insert(result.actions, action_result)
            if #actions == 1 then
                copy_result_fields(result, action_result)
            end
        end
    end

    self:emit(Events.SLOT_RESOLVED, {
        entry = entry,
        combatant = entry.combatant,
        part = entry.part,
        slot = entry.slot,
        effect = result,
        trigger_context = entry.trigger_context
    })

    if self.state ~= "COMPLETE" and self:check_combat_end() then
        self.state = "COMPLETE"
        self:emit(Events.COMBAT_END, { round = self.current_round, winner = self.winner })
    end
end

function Engine:grant_crest(combatant, crest, amount, extra)
    if not combatant or not crest then
        return 0
    end

    crest = Crests.normalize(crest)
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
    local ok, canonical, effect = Crests.expend(self, combatant, crest)
    if not ok then
        return false, canonical
    end

    self:emit(Events.CREST_EXPENDED, {
        combatant = combatant,
        crest = canonical,
        remaining = combatant:get_crest_count(canonical),
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

function Engine:find_part_by_type(combatant, part_type)
    return find_first_part_by_type(combatant, part_type)
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
    local brittle = Keywords.has(part, "Brittle")
    local after = nil
    local heart_loss = 0

    if brittle then
        part:set_status("maimed")
        after = part.status
        self:emit(Events.KEYWORD_TRIGGERED, {
            combatant = target,
            part = part,
            keyword = "Brittle",
            context = context
        })
    else
        after = part:advance_damage_state()
    end

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

    local trigger_context = copy_fields(context)
    trigger_context.attacker = attacker
    trigger_context.target = target
    trigger_context.part = part
    trigger_context.status_before = before
    trigger_context.status_after = after
    trigger_context.heart_point_loss = heart_loss

    if trigger_context.hit then
        self:resolve_slot_window(TIMING_ON_HIT, trigger_context)
    end
    self:resolve_slot_window(TIMING_ON_WOUND_MAIM, trigger_context)
    return true
end

function Engine:resolve_round()
    self.state = "RESOLUTION"
    self:emit(Events.RESOLUTION_PHASE, { round = self.current_round })

    for _, defender in ipairs(self.combatants or {}) do
        for _, part in ipairs(defender.body_parts or {}) do
            local attack = self.assignments.rims[part]
            local defense = self.assignments.sockets[part]
            local strike_count = count_contest_symbol(attack, Symbols.STRIKE)
            local ward_count = count_contest_symbol(defense, Symbols.WARD)

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
                self:apply_damage(attack.attacker, defender, part, {
                    hit = true,
                    attack = attack,
                    defense = defense,
                    strike_count = strike_count,
                    ward_count = ward_count
                })
            elseif attack and defense and strike_count <= ward_count then
                self:resolve_absorbent_socket(defender, part, defense, {
                    attack = attack,
                    defense = defense,
                    strike_count = strike_count,
                    ward_count = ward_count
                })
            end
        end
    end

    if self:check_combat_end() then
        local was_complete = self.state == "COMPLETE"
        self.state = "COMPLETE"
        if not was_complete then
            self:emit(Events.COMBAT_END, { round = self.current_round, winner = self.winner })
        end
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

    local slot_symbols = self:get_effective_symbols(combatant, die, "slot")
    local opponent = self:get_opponent(combatant)

    for _, part in ipairs(combatant.body_parts or {}) do
        local socket_symbols = self:get_effective_symbols(combatant, die, "socket", part)
        if part.status ~= "maimed" and not self.assignments.sockets[part] then
            local spellmark = self:get_assignment_spellmark(combatant, "socket", part, socket_symbols)
            if Symbols.has(socket_symbols, Symbols.WARD) or spellmark then
                table.insert(destinations.sockets, part)
            end
        end
    end

    if opponent then
        for _, part in ipairs(opponent.body_parts or {}) do
            local rim_symbols = self:get_effective_symbols(combatant, die, "rim", part)
            local spellmark = self:get_assignment_spellmark(combatant, "rim", part, rim_symbols)
            if is_part_targetable(self, part)
                and not self.assignments.rims[part]
                and (Symbols.has(rim_symbols, Symbols.STRIKE) or spellmark)
                and rim_accepts_symbols(part, rim_symbols) then
                table.insert(destinations.rims, part)
            end
        end
    end

    for _, part in ipairs(combatant.body_parts or {}) do
        if part:is_slot_online() then
            local matched = false
            local cost = slot_cost(part.slot)
            for _, symbol in ipairs(slot_symbols) do
                for index, required in ipairs(cost) do
                    if not (part.slot_charge and part.slot_charge[index]) and (Keywords.slot_is_hungry(part, part.slot) or required == symbol) then
                        table.insert(destinations.slots, part)
                        matched = true
                        break
                    end
                end
                if matched then
                    break
                end
            end
        end
    end

    return destinations
end

function Engine:commit_allocation_move(combatant, move)
    if not move or not move.kind or not move.die or not move.part then
        return false, "invalid_move"
    end

    if move.kind == "rim" then
        return self:assign_die_to_rim(combatant, move.die.id, move.part)
    elseif move.kind == "socket" then
        return self:assign_die_to_socket(combatant, move.die.id, move.part)
    elseif move.kind == "slot" then
        return self:feed_die_to_slot(combatant, move.die.id, move.part)
    end

    return false, "unknown_destination"
end

return Engine
