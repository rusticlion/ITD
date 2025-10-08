local Events = require("combat.events")
local States = require("combat.states")
local Dice = require("core.dice")

local Engine = {}
Engine.__index = Engine

local MAX_STATE_ADVANCES_PER_UPDATE = 8

function Engine:new()
    local instance = {
        state = "WAITING",
        combatants = {},
        current_round = 0,
        event_queue = {},
        listeners = {},
        pending_input = nil,
        selection_queue = nil,
        attack_assignments = {},
        defense_assignments = {},
        attack_assignment_queue = nil,
        defense_assignment_queue = nil,
        attack_assignment_ready = false,
        defense_assignment_ready = false,
        winner = nil,
        states = States
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

function Engine:start_combat()
    self.current_round = 0
    self.event_queue = {}
    self.pending_input = nil
    self.selection_queue = nil
    self.attack_assignments = {}
    self.defense_assignments = {}
    self.attack_assignment_queue = nil
    self.defense_assignment_queue = nil
    self.attack_assignment_ready = false
    self.defense_assignment_ready = false
    self.winner = nil

    self:emit(Events.COMBAT_START, { combatants = self.combatants })
    self:transition_to("ROUND_START")
end

function Engine:transition_to(state_name)
    if self.state == state_name then
        return
    end

    self.state = state_name
    local state_data = self.states[state_name]
    if state_data and state_data.enter then
        state_data.enter(self)
    end
end

function Engine:process_state()
    local iterations = 0

    while iterations < MAX_STATE_ADVANCES_PER_UPDATE do
        if self:needs_input() then
            break
        end

        local state_data = self.states[self.state]
        if not state_data or not state_data.process then
            break
        end

        local next_state = state_data.process(self)
        if not next_state or next_state == self.state then
            break
        end

        self:transition_to(next_state)
        iterations = iterations + 1
    end
end

function Engine:needs_input()
    return self.pending_input ~= nil
end

function Engine:get_input_prompt()
    return self.pending_input and self.pending_input.prompt or ""
end

function Engine:get_pending_input_metadata()
    return self.pending_input and self.pending_input.metadata
end

function Engine:provide_input(input)
    if not self.pending_input then
        return
    end

    local handler = self.pending_input.handler
    self.pending_input = nil

    if handler then
        handler(self, input)
    end
end

function Engine:request_input(prompt, handler, metadata)
    self.pending_input = {
        prompt = prompt,
        handler = handler,
        metadata = metadata
    }

    self:emit(Events.AWAIT_PLAYER_INPUT, {
        prompt = prompt,
        state = self.state,
        metadata = metadata
    })
end

function Engine:clear_input()
    self.pending_input = nil
end

function Engine:begin_tech_selection()
    self.attack_assignment_ready = false
    self.defense_assignment_ready = false
    self.selection_queue = {}
    for index, combatant in ipairs(self.combatants) do
        self.selection_queue[index] = combatant
        combatant.selected_tech = nil
    end

    self:advance_tech_selection()
end

local function select_first_tech(techs)
    return techs[1]
end

function Engine:advance_tech_selection()
    if not self.selection_queue then
        return
    end

    if #self.selection_queue == 0 then
        self.selection_queue = nil
        return
    end

    local combatant = self.selection_queue[1]
    local available_techs = combatant:get_available_techs()

    if combatant.is_player and #available_techs > 0 then
        self:emit(Events.TECH_SELECT_PHASE, {
            combatant = combatant,
            available_techs = available_techs
        })

        local function handle_input(engine, raw_input)
            local choice = tonumber(raw_input)
            if not choice or not available_techs[choice] then
                engine:request_input("Invalid selection. Choose a tech by number", handle_input)
                return
            end

            combatant.selected_tech = available_techs[choice]
            engine:emit(Events.TECH_SELECTED, {
                combatant = combatant,
                tech = combatant.selected_tech
            })

            table.remove(engine.selection_queue, 1)
            engine:clear_input()
            engine:advance_tech_selection()
        end

        self:request_input("Select tech for " .. combatant.name, handle_input)
        return
    end

    if #available_techs > 0 then
        combatant.selected_tech = select_first_tech(available_techs)
        self:emit(Events.TECH_SELECTED, {
            combatant = combatant,
            tech = combatant.selected_tech,
            automatic = true
        })
    else
        combatant.selected_tech = nil
    end

    table.remove(self.selection_queue, 1)
    self:advance_tech_selection()
end

function Engine:tech_selection_complete()
    return self.selection_queue == nil and not self:needs_input()
end

function Engine:prepare_attack_assignments()
    self.attack_assignment_ready = false
    self.attack_assignments = {}
    self.attack_assignment_queue = {}

    for _, combatant in ipairs(self.combatants) do
        self.attack_assignments[combatant] = {}

        local tech = combatant.selected_tech
        local actions = {}

        if tech and tech.actions then
            for index, action in ipairs(tech.actions) do
                if action.type == "attack_roll" then
                    table.insert(actions, {
                        action = action,
                        action_index = index
                    })
                end
            end
        end

        if #actions > 0 then
            if combatant.is_player then
                table.insert(self.attack_assignment_queue, {
                    combatant = combatant,
                    actions = actions,
                    next_index = 1
                })
            else
                for _, data in ipairs(actions) do
                    local opponent, body_part = self:select_target_body_part(combatant, data.action)
                    if opponent and body_part then
                        table.insert(self.attack_assignments[combatant], {
                            tech = tech,
                            action = data.action,
                            action_index = data.action_index,
                            target_combatant = opponent,
                            target_part = body_part
                        })

                        self:emit(Events.ATTACK_ASSIGNED, {
                            combatant = combatant,
                            action = data.action,
                            action_index = data.action_index,
                            target = body_part,
                            automatic = true
                        })
                    end
                end
            end
        end
    end

    if self.attack_assignment_queue and #self.attack_assignment_queue == 0 then
        self.attack_assignment_queue = nil
        self.attack_assignment_ready = true
        return
    end

    self:advance_attack_assignment()
end

function Engine:attack_assignment_complete()
    return self.attack_assignment_ready and not self:needs_input()
end

function Engine:add_attack_assignment(combatant, assignment_data, opponent, body_part)
    if not combatant or not assignment_data or not opponent or not body_part then
        return
    end

    local assignments = self.attack_assignments[combatant]
    if not assignments then
        assignments = {}
        self.attack_assignments[combatant] = assignments
    end

    for index = #assignments, 1, -1 do
        local existing = assignments[index]
        if existing.action_index == assignment_data.action_index then
            table.remove(assignments, index)
        end
    end

    table.insert(assignments, {
        tech = combatant.selected_tech,
        action = assignment_data.action,
        action_index = assignment_data.action_index,
        target_combatant = opponent,
        target_part = body_part
    })

    self:emit(Events.ATTACK_ASSIGNED, {
        combatant = combatant,
        action = assignment_data.action,
        action_index = assignment_data.action_index,
        target = body_part,
        automatic = not combatant.is_player
    })
end

function Engine:advance_attack_assignment()
    if not self.attack_assignment_queue then
        return
    end

    while true do
        if #self.attack_assignment_queue == 0 then
            self.attack_assignment_queue = nil
            self.attack_assignment_ready = true
            return
        end

        local entry = self.attack_assignment_queue[1]
        entry.next_index = entry.next_index or 1

        if entry.next_index > #entry.actions then
            table.remove(self.attack_assignment_queue, 1)
        else
            local action_data = entry.actions[entry.next_index]
            local opponent = self:get_opponent(entry.combatant)
            local targetable_parts = collect_targetable_parts_from(opponent)

            if not opponent or #targetable_parts == 0 then
                entry.next_index = entry.next_index + 1
            else
                local action_label = action_data.action.name or action_data.action.id or action_data.action.type or "attack"
                local base_prompt = string.format("Assign attack %d for %s", entry.next_index, entry.combatant.name)

                local options = {}
                for index, part in ipairs(targetable_parts) do
                    options[index] = {
                        index = index,
                        part = part,
                        id = part.id,
                        name = part.name,
                        status = part.status,
                        toughness = part.toughness or 0
                    }
                end

                local metadata = {
                    type = "attack_assignment",
                    combatant = entry.combatant,
                    opponent = opponent,
                    action = action_data.action,
                    action_index = action_data.action_index,
                    action_label = action_label,
                    options = options
                }

                local function handle_input(engine, raw_input)
                    local choice = tonumber(raw_input)
                    local selection = choice and metadata.options[choice] or nil

                    if not selection then
                        engine:request_input(base_prompt .. " - enter a valid option number", handle_input, metadata)
                        return
                    end

                    engine:add_attack_assignment(entry.combatant, action_data, opponent, selection.part)
                    entry.next_index = entry.next_index + 1

                    if entry.next_index > #entry.actions then
                        table.remove(engine.attack_assignment_queue, 1)
                    end

                    engine:clear_input()
                    engine:advance_attack_assignment()
                end

                self:request_input(base_prompt .. " (enter option number)", handle_input, metadata)
                return
            end
        end
    end
end

function Engine:prepare_defense_assignments()
    self.defense_assignment_ready = false
    self.defense_assignments = {}
    self.defense_assignment_queue = {}

    local function select_best_defense_part(combatant)
        local best_part = nil
        for _, part in ipairs(combatant.body_parts) do
            if part.status ~= "maimed" then
                if not best_part or (part.toughness or 0) > (best_part.toughness or 0) then
                    best_part = part
                end
            end
        end
        return best_part
    end

    for _, combatant in ipairs(self.combatants) do
        self.defense_assignments[combatant] = {}

        local tech = combatant.selected_tech
        local actions = {}

        if tech and tech.actions then
            for index, action in ipairs(tech.actions) do
                if action.type == "defense_roll" then
                    table.insert(actions, {
                        action = action,
                        action_index = index
                    })
                end
            end
        end

        if #actions > 0 then
            if combatant.is_player then
                table.insert(self.defense_assignment_queue, {
                    combatant = combatant,
                    actions = actions,
                    next_index = 1
                })
            else
                local preferred_part = select_best_defense_part(combatant)
                for _, data in ipairs(actions) do
                    if preferred_part then
                        table.insert(self.defense_assignments[combatant], {
                            tech = tech,
                            action = data.action,
                            action_index = data.action_index,
                            target_part = preferred_part
                        })

                        self:emit(Events.DEFENSE_ASSIGNED, {
                            combatant = combatant,
                            action = data.action,
                            action_index = data.action_index,
                            target = preferred_part,
                            automatic = true
                        })
                    end
                end
            end
        end
    end

    if self.defense_assignment_queue and #self.defense_assignment_queue == 0 then
        self.defense_assignment_queue = nil
        self.defense_assignment_ready = true
        return
    end

    self:advance_defense_assignment()
end

function Engine:defense_assignment_complete()
    return self.defense_assignment_ready and not self:needs_input()
end

function Engine:add_defense_assignment(combatant, assignment_data, body_part)
    if not combatant or not assignment_data or not body_part then
        return
    end

    local assignments = self.defense_assignments[combatant]
    if not assignments then
        assignments = {}
        self.defense_assignments[combatant] = assignments
    end

    for index = #assignments, 1, -1 do
        local existing = assignments[index]
        if existing.action_index == assignment_data.action_index then
            table.remove(assignments, index)
        end
    end

    table.insert(assignments, {
        tech = combatant.selected_tech,
        action = assignment_data.action,
        action_index = assignment_data.action_index,
        target_part = body_part
    })

    self:emit(Events.DEFENSE_ASSIGNED, {
        combatant = combatant,
        action = assignment_data.action,
        action_index = assignment_data.action_index,
        target = body_part,
        automatic = not combatant.is_player
    })
end

function Engine:advance_defense_assignment()
    if not self.defense_assignment_queue then
        return
    end

    while true do
        if #self.defense_assignment_queue == 0 then
            self.defense_assignment_queue = nil
            self.defense_assignment_ready = true
            return
        end

        local entry = self.defense_assignment_queue[1]
        entry.next_index = entry.next_index or 1

        if entry.next_index > #entry.actions then
            table.remove(self.defense_assignment_queue, 1)
        else
            local action_data = entry.actions[entry.next_index]
            local available_parts = collect_targetable_parts_from(entry.combatant)

            if #available_parts == 0 then
                entry.next_index = entry.next_index + 1
            else
                local action_label = action_data.action.name or action_data.action.id or action_data.action.type or "defense"
                local base_prompt = string.format("Assign defense %d for %s", entry.next_index, entry.combatant.name)

                local options = {}
                for index, part in ipairs(available_parts) do
                    options[index] = {
                        index = index,
                        part = part,
                        id = part.id,
                        name = part.name,
                        status = part.status,
                        toughness = part.toughness or 0
                    }
                end

                local metadata = {
                    type = "defense_assignment",
                    combatant = entry.combatant,
                    action = action_data.action,
                    action_index = action_data.action_index,
                    action_label = action_label,
                    options = options
                }

                local function handle_input(engine, raw_input)
                    local choice = tonumber(raw_input)
                    local selection = choice and metadata.options[choice] or nil

                    if not selection then
                        engine:request_input(base_prompt .. " - enter a valid option number", handle_input, metadata)
                        return
                    end

                    engine:add_defense_assignment(entry.combatant, action_data, selection.part)
                    entry.next_index = entry.next_index + 1

                    if entry.next_index > #entry.actions then
                        table.remove(engine.defense_assignment_queue, 1)
                    end

                    engine:clear_input()
                    engine:advance_defense_assignment()
                end

                self:request_input(base_prompt .. " (enter option number)", handle_input, metadata)
                return
            end
        end
    end
end

function Engine:get_opponent(combatant)
    for _, other in ipairs(self.combatants) do
        if other ~= combatant then
            return other
        end
    end

    return nil
end

local function is_part_targetable(part)
    return part and part.status ~= "maimed"
end

local function collect_targetable_parts_from(combatant)
    local parts = {}

    if not combatant or not combatant.body_parts then
        return parts
    end

    for _, part in ipairs(combatant.body_parts) do
        if is_part_targetable(part) then
            table.insert(parts, part)
        end
    end

    return parts
end

function Engine:select_target_body_part(attacker, action)
    local opponent = self:get_opponent(attacker)
    if not opponent then
        return nil
    end

    if action and action.target_body_part_id then
        local explicit = opponent:get_body_part_by_id(action.target_body_part_id)
        if is_part_targetable(explicit) then
            return opponent, explicit
        end
    end

    local part = opponent:get_first_healthy_part()
    if is_part_targetable(part) then
        return opponent, part
    end

    return opponent, part
end

function Engine:apply_damage(attacker, target, body_part, amount)
    if not target or not body_part or body_part.status == "maimed" then
        return
    end

    local status_before = body_part.status
    local steps = amount or 1

    for _ = 1, steps do
        local new_status = body_part:advance_damage_state()
        self:emit(Events.DAMAGE_DEALT, {
            attacker = attacker,
            target = target,
            body_part = body_part,
            status_before = status_before,
            status_after = new_status
        })

        if new_status ~= status_before then
            self:emit(Events.BP_STATUS_CHANGED, {
                combatant = target,
                body_part = body_part,
                previous_status = status_before,
                new_status = new_status
            })
        end

        if new_status == "maimed" and status_before ~= "maimed" then
            local lost_hp = body_part.hp_value or 1
            target.heart_points = math.max(0, target.heart_points - lost_hp)
            self:emit(Events.DAMAGE_DEALT, {
                attacker = attacker,
                target = target,
                body_part = body_part,
                status_before = "maimed",
                status_after = "maimed",
                heart_point_loss = lost_hp
            })
        end

        status_before = body_part.status

        if body_part.status == "maimed" then
            break
        end
    end
end

function Engine:get_attack_assignment(attacker, action_index)
    local assignments = self.attack_assignments[attacker]
    if not assignments then
        return nil
    end

    for _, assignment in ipairs(assignments) do
        if assignment.action_index == action_index then
            return assignment
        end
    end

    return nil
end

function Engine:roll_defense_assignments()
    local totals = {}

    for _, combatant in ipairs(self.combatants) do
        totals[combatant] = {}
    end

    for combatant, assignments in pairs(self.defense_assignments or {}) do
        for _, assignment in ipairs(assignments) do
            local action = assignment.action
            local target_part = assignment.target_part

            if action and target_part then
                local result = Dice.roll(action.dice_count or 1, action.dice_type or "d6")
                self:emit(Events.DICE_ROLLED, {
                    attacker = combatant,
                    action = action,
                    result = result,
                    defense = true,
                    body_part = target_part
                })

                local part_id = target_part.id
                if part_id then
                    local combatant_totals = totals[combatant]
                    combatant_totals[part_id] = (combatant_totals[part_id] or 0) + (result.total or 0)
                end
            end
        end
    end

    return totals
end

function Engine:resolve_action(attacker, action, action_index, defense_totals)
    if not action or action.type == nil then
        return
    end

    if action.type == "direct_damage" then
        local opponent, body_part = self:select_target_body_part(attacker, action)
        if opponent and body_part then
            local amount = action.amount or 1
            self:apply_damage(attacker, opponent, body_part, amount)
        end
    elseif action.type == "attack_roll" then
        local result = Dice.roll(action.dice_count or 1, action.dice_type or "d6")
        self:emit(Events.DICE_ROLLED, {
            attacker = attacker,
            action = action,
            result = result
        })

        local assignment = self:get_attack_assignment(attacker, action_index)
        local opponent = assignment and assignment.target_combatant
        local body_part = assignment and assignment.target_part

        if not opponent or not body_part then
            opponent, body_part = self:select_target_body_part(attacker, action)
        end

        if opponent and body_part then
            local defense_total = 0
            if defense_totals then
                local opponent_totals = defense_totals[opponent]
                if opponent_totals and body_part.id then
                    defense_total = opponent_totals[body_part.id] or 0
                end
            end

            local toughness = (body_part.toughness or 0) + defense_total
            if result.total > toughness then
                self:apply_damage(attacker, opponent, body_part, 1)
            end
        end
    elseif action.type == "defense_roll" then
        return
    end
end

function Engine:resolve_actions()
    local defense_totals = self:roll_defense_assignments()

    for _, combatant in ipairs(self.combatants) do
        local tech = combatant.selected_tech
        if tech and tech.actions then
            for index, action in ipairs(tech.actions) do
                self:resolve_action(combatant, action, index, defense_totals)
            end
        end
    end
end

function Engine:check_combat_end()
    local surviving = {}
    local defeated = {}

    for _, combatant in ipairs(self.combatants) do
        if combatant:is_defeated() then
            table.insert(defeated, combatant)
        else
            table.insert(surviving, combatant)
        end
    end

    if #defeated > 0 then
        if #surviving == 1 then
            self.winner = surviving[1]
        end
        return true
    end

    return false
end

return Engine
