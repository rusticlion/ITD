local Events = require("combat.events")
local States = require("combat.states")

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
    self.attack_assignment_ready = true
end

function Engine:attack_assignment_complete()
    return self.attack_assignment_ready
end

function Engine:prepare_defense_assignments()
    self.defense_assignment_ready = true
end

function Engine:defense_assignment_complete()
    return self.defense_assignment_ready
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

function Engine:resolve_action(attacker, action)
    if not action or action.type == nil then
        return
    end

    if action.type == "direct_damage" then
        local opponent, body_part = self:select_target_body_part(attacker, action)
        if opponent and body_part then
            local amount = action.amount or 1
            self:apply_damage(attacker, opponent, body_part, amount)
        end
    end
end

function Engine:resolve_actions()
    for _, combatant in ipairs(self.combatants) do
        local tech = combatant.selected_tech
        if tech and tech.actions then
            for _, action in ipairs(tech.actions) do
                self:resolve_action(combatant, action)
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
