local Events = require("combat.events")
local States = require("combat.states")
local Dice = require("core.dice")
local CrestPassives = require("combat.crests")
local AI = require("combat.ai")

local Engine = {}
Engine.__index = Engine

local MAX_STATE_ADVANCES_PER_UPDATE = 8

local function is_part_targetable(engine, part)
    if not part or part.status == "maimed" then
        return false
    end

    if engine and engine:is_part_untargetable(part) then
        return false
    end

    return true
end

local function collect_targetable_parts_from(engine, combatant)
    local parts = {}

    if not combatant or not combatant.body_parts then
        return parts
    end

    for _, part in ipairs(combatant.body_parts) do
        if is_part_targetable(engine, part) then
            table.insert(parts, part)
        end
    end

    return parts
end

local function merge_keyword_sources(destination, source)
    if not source or not source.keywords then
        return
    end

    for key, value in pairs(source.keywords) do
        if type(value) == "number" then
            destination[key] = (destination[key] or 0) + value
        elseif type(value) == "boolean" then
            destination[key] = value and 1 or 0
        elseif type(value) == "string" then
            local numeric = tonumber(value)
            destination[key] = numeric or value
        else
            destination[key] = value
        end
    end
end

local function collect_keywords(tech, action)
    local combined = {}
    merge_keyword_sources(combined, tech)
    merge_keyword_sources(combined, action)
    return combined
end

local function get_keyword_value(keywords, key)
    if not keywords then
        return nil
    end

    local value = keywords[key]
    if type(value) == "number" then
        return value
    elseif type(value) == "boolean" then
        return value and 1 or 0
    elseif type(value) == "string" then
        return tonumber(value) or value
    end

    return value
end

local function apply_consistent_keyword(result, keywords)
    if not result or not keywords then
        return nil
    end

    local consistent_value = get_keyword_value(keywords, "Consistent")
    if not consistent_value then
        return nil
    end

    consistent_value = tonumber(consistent_value)
    if not consistent_value then
        return nil
    end

    local count = result.count or #result.rolls or 0
    if count <= 0 then
        return nil
    end

    result.rolls = result.rolls or {}
    for index = 1, count do
        result.rolls[index] = consistent_value
    end

    result.total = consistent_value * count
    result.consistent_value = consistent_value

    return consistent_value
end

local AttackPipeline = {}

function AttackPipeline.apply_base_totals(_, context)
    context.attack_total = (context.attack_total or 0)
    context.effective_defense = math.max(0, context.effective_defense or 0)
    context.effective_toughness = (context.base_toughness or 0) + context.effective_defense
    context.defense_total = context.effective_defense
end

function AttackPipeline.apply_piercing(_, context)
    local pierce = get_keyword_value(context.keywords, "Piercing")
    if not pierce then
        return
    end

    pierce = tonumber(pierce) or 0
    if pierce <= 0 then
        return
    end

    local total_reduction = 0
    local defense_before = context.effective_defense or 0
    local defense_reduction = math.min(defense_before, pierce)
    context.effective_defense = defense_before - defense_reduction
    total_reduction = total_reduction + defense_reduction

    local remaining = pierce - defense_reduction
    local toughness_reduction = 0
    if remaining > 0 then
        local base_before = context.base_toughness or 0
        toughness_reduction = math.min(base_before, remaining)
        context.base_toughness = base_before - toughness_reduction
        total_reduction = total_reduction + toughness_reduction
    end

    context.effective_defense = math.max(0, context.effective_defense)
    context.base_toughness = math.max(0, context.base_toughness or 0)
    context.effective_toughness = (context.base_toughness or 0) + context.effective_defense
    context.defense_total = context.effective_defense

    context.notes = context.notes or {}
    context.notes.piercing = total_reduction
    context.notes.piercing_defense = defense_reduction
    context.notes.piercing_toughness = toughness_reduction
end

function AttackPipeline.check_hit(_, context)
    context.hit = (context.attack_total or 0) > (context.effective_toughness or 0)
end

function AttackPipeline.apply_brutal(_, context)
    if not context.hit then
        return
    end

    local brutal = get_keyword_value(context.keywords, "Brutal")
    if not brutal then
        return
    end

    brutal = tonumber(brutal) or 0
    if brutal == 0 then
        return
    end

    context.damage = (context.damage or context.base_damage or 1) + brutal
    context.notes = context.notes or {}
    context.notes.brutal = brutal
end


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
        states = States,
        untargetable_parts = setmetatable({}, { __mode = "k" })
    }

    return setmetatable(instance, Engine)
end

function Engine:get_attack_pipeline()
    return {
        AttackPipeline.apply_base_totals,
        AttackPipeline.apply_piercing,
        AttackPipeline.check_hit,
        AttackPipeline.apply_brutal
    }
end

function Engine:run_attack_pipeline(context)
    if not context then
        return nil
    end

    for _, step in ipairs(self:get_attack_pipeline()) do
        step(self, context)
    end

    return context
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
    self.untargetable_parts = setmetatable({}, { __mode = "k" })
    self:clear_combatant_modifiers()

    self:emit(Events.COMBAT_START, { combatants = self.combatants })
    self:transition_to("ROUND_START")
end

function Engine:clear_combatant_modifiers()
    for _, combatant in ipairs(self.combatants) do
        if combatant.clear_modifiers then
            combatant:clear_modifiers()
        end
    end
end

function Engine:clear_untargetable_parts()
    self.untargetable_parts = setmetatable({}, { __mode = "k" })
end

function Engine:is_part_untargetable(part)
    if not part then
        return false
    end

    return self.untargetable_parts and self.untargetable_parts[part] == true
end

function Engine:mark_part_untargetable(part)
    if not part then
        return
    end

    self.untargetable_parts = self.untargetable_parts or setmetatable({}, { __mode = "k" })
    self.untargetable_parts[part] = true
end

function Engine:get_targetable_parts(combatant)
    return collect_targetable_parts_from(self, combatant)
end

function Engine:apply_crest_passives()
    for _, combatant in ipairs(self.combatants) do
        CrestPassives.apply(self, combatant)
    end
end

function Engine:perform_upkeep()
    self:clear_untargetable_parts()
    self:clear_combatant_modifiers()
    self:apply_crest_passives()
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

    local function advance_queue()
        table.remove(self.selection_queue, 1)
        self:advance_tech_selection()
    end

    local function handle_player_selection()
        if #available_techs > 0 then
            local metadata = {
                type = "tech_select_phase",
                combatant = combatant,
                options = {}
            }

            for index, tech in ipairs(available_techs) do
                local source_part = tech and tech._source_part or nil
                metadata.options[index] = {
                    index = index,
                    tech = tech,
                    tech_id = tech and tech.id,
                    tech_name = tech and tech.name,
                    body_part = source_part,
                    body_part_id = source_part and source_part.id,
                    body_part_name = source_part and source_part.name
                }
            end

            self:emit(Events.TECH_SELECT_PHASE, {
                combatant = combatant,
                available_techs = available_techs,
                options = metadata.options
            })

            local function handle_input(engine, raw_input)
                local choice = tonumber(raw_input)
                local selected_tech = choice and available_techs[choice] or nil
                local selected_option = choice and metadata.options[choice] or nil

                if not selected_tech then
                    engine:request_input("Invalid selection. Choose a tech by number", handle_input, metadata)
                    return
                end

                combatant.selected_tech = selected_tech
                engine:emit(Events.TECH_SELECTED, {
                    combatant = combatant,
                    tech = combatant.selected_tech,
                    body_part = selected_option and selected_option.body_part,
                    option = selected_option
                })

                engine:clear_input()
                advance_queue()
            end

            self:request_input("Select tech for " .. combatant.name, handle_input, metadata)
        else
            combatant.selected_tech = nil
            advance_queue()
        end
    end

    if combatant.is_player then
        if self:prompt_crest_expenditure(combatant, handle_player_selection) then
            return
        end

        handle_player_selection()
        return
    end

    if #available_techs > 0 then
        local opponent = self:get_opponent(combatant)
        combatant.selected_tech = AI.choose_tech(combatant, opponent, available_techs) or available_techs[1]
        self:emit(Events.TECH_SELECTED, {
            combatant = combatant,
            tech = combatant.selected_tech,
            automatic = true
        })
    else
        combatant.selected_tech = nil
    end

    advance_queue()
end

function Engine:tech_selection_complete()
    return self.selection_queue == nil and not self:needs_input()
end

function Engine:get_expendable_crests(combatant)
    local options = {}

    if not combatant or not combatant.crest_pool then
        return options
    end

    for crest, count in pairs(combatant.crest_pool) do
        if (count or 0) > 0 and CrestPassives.can_expend(crest) then
            table.insert(options, {
                name = crest,
                count = count
            })
        end
    end

    table.sort(options, function(a, b)
        if a.name == b.name then
            return false
        end
        return a.name < b.name
    end)

    for index, entry in ipairs(options) do
        entry.index = index
    end

    return options
end

function Engine:prompt_select_crest(combatant, options, continue_callback)
    local crest_options = options or self:get_expendable_crests(combatant)
    if not crest_options or #crest_options == 0 then
        if continue_callback then
            continue_callback()
        end
        return
    end

    local metadata = {
        type = "crest_select",
        combatant = combatant,
        options = crest_options
    }

    local function handle_selection(engine, raw_input)
        local choice = tonumber(raw_input)
        local selection = choice and crest_options[choice] or nil

        if not selection then
            engine:request_input("Select crest to expend (enter number)", handle_selection, metadata)
            return
        end

        engine:clear_input()
        engine:expend_crest(combatant, selection.name, function()
            if continue_callback then
                continue_callback()
            end
        end)
    end

    self:request_input("Select crest to expend (enter number)", handle_selection, metadata)
end

function Engine:prompt_crest_expenditure(combatant, on_complete)
    if not combatant then
        return false
    end

    combatant._crest_prompted_round = combatant._crest_prompted_round or 0
    if combatant._crest_prompt_in_progress then
        return true
    end

    if combatant._crest_prompted_round == self.current_round then
        return false
    end

    local function finish()
        combatant._crest_prompt_in_progress = false
        combatant._crest_prompted_round = self.current_round
        if on_complete then
            on_complete()
        end
    end

    local function ask_again()
        local crest_options = self:get_expendable_crests(combatant)
        if #crest_options == 0 then
            finish()
            return
        end

        local metadata = {
            type = "crest_prompt",
            combatant = combatant,
            options = crest_options
        }

        local function handle_yes_no(engine, raw_input)
            local response = tostring(raw_input or ""):lower()
            if response == "y" or response == "yes" then
                engine:clear_input()
                engine:prompt_select_crest(combatant, crest_options, ask_again)
            elseif response == "n" or response == "no" then
                engine:clear_input()
                finish()
            else
                engine:request_input("Expend a crest? (y/n)", handle_yes_no, metadata)
            end
        end

        self:request_input("Expend a crest? (y/n)", handle_yes_no, metadata)
    end

    combatant._crest_prompt_in_progress = true
    ask_again()

    return true
end

function Engine:grant_crest(combatant, crest, amount, extra)
    if not combatant or not combatant.add_crest or not crest then
        return 0
    end

    local delta = amount or 1
    local total = combatant:add_crest(crest, delta)
    local data = {
        combatant = combatant,
        crest = crest,
        amount = delta,
        total = total
    }

    if extra then
        for key, value in pairs(extra) do
            if data[key] == nil then
                data[key] = value
            end
        end
    end

    self:emit(Events.CREST_GAINED, data)
    return total
end

function Engine:expend_crest(combatant, crest, on_complete)
    if not combatant or not crest then
        if on_complete then
            on_complete(nil)
        end
        return
    end

    local current = combatant.get_crest_count and combatant:get_crest_count(crest) or 0
    if current <= 0 then
        if on_complete then
            on_complete(nil)
        end
        return
    end

    local remaining = combatant.remove_crest and combatant:remove_crest(crest, 1) or (current - 1)
    if remaining < 0 then
        remaining = 0
    end

    local handler = CrestPassives.get_expend_handler(crest)

    local function finalize(effect_data)
        self:emit(Events.CREST_EXPENDED, {
            combatant = combatant,
            crest = crest,
            remaining = remaining,
            effect = effect_data
        })

        if on_complete then
            on_complete(effect_data)
        end
    end

    if handler then
        handler(self, combatant, finalize)
    else
        finalize(nil)
    end
end

function Engine:consume_attack_bonus_token(combatant)
    if not combatant or not combatant.attack_bonus_tokens then
        return 0
    end

    if #combatant.attack_bonus_tokens == 0 then
        return 0
    end

    return table.remove(combatant.attack_bonus_tokens, 1)
end

function Engine:apply_forced_reroll(combatant, result, context)
    if not combatant or not result then
        return result
    end

    local pending = combatant.pending_forced_rerolls or 0
    if pending <= 0 then
        return result
    end

    local rolls = result.rolls or {}
    if #rolls == 0 then
        combatant.pending_forced_rerolls = math.max(0, pending - 1)
        return result
    end

    combatant.pending_forced_rerolls = pending - 1

    local highest_index = 1
    local highest_value = rolls[1]

    for index, value in ipairs(rolls) do
        if value > highest_value then
            highest_value = value
            highest_index = index
        end
    end

    local sides = result.sides or (result.type and tonumber(result.type:match("d(%d+)"))) or 6
    local new_roll = math.random(1, sides)

    result.total = (result.total or 0) - highest_value + new_roll
    rolls[highest_index] = new_roll

    self:emit(Events.DIE_REROLLED, {
        combatant = combatant,
        crest = "Madness",
        previous_value = highest_value,
        new_value = new_roll,
        context = context
    })

    return result
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
                local opponent = self:get_opponent(combatant)
                local assigned_targets = AI.assign_targets(combatant, opponent, tech, {
                    engine = self,
                    actions = actions
                })

                for _, data in ipairs(actions) do
                    local target_part = assigned_targets and assigned_targets[data.action_index] or nil

                    if target_part and not is_part_targetable(self, target_part) then
                        target_part = nil
                    end

                    if not target_part then
                        local _, fallback_part = self:select_target_body_part(combatant, data.action)
                        target_part = fallback_part
                    end

                    if opponent and target_part then
                        table.insert(self.attack_assignments[combatant], {
                            tech = tech,
                            action = data.action,
                            action_index = data.action_index,
                            target_combatant = opponent,
                            target_part = target_part
                        })

                        self:emit(Events.ATTACK_ASSIGNED, {
                            combatant = combatant,
                            action = data.action,
                            action_index = data.action_index,
                            target = target_part,
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
            local targetable_parts = self:get_targetable_parts(opponent)

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
                    local available_parts = self:get_targetable_parts(entry.combatant)

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

function Engine:select_target_body_part(attacker, action)
    local opponent = self:get_opponent(attacker)
    if not opponent then
        return nil
    end

    if action and action.target_body_part_id then
        local explicit = opponent:get_body_part_by_id(action.target_body_part_id)
        if is_part_targetable(self, explicit) then
            return opponent, explicit
        end
    end

    local targetable = self:get_targetable_parts(opponent)
    if #targetable > 0 then
        return opponent, targetable[1]
    end

    local fallback = opponent:get_first_healthy_part()
    return opponent, fallback
end

function Engine:select_friendly_body_part(combatant, action)
    if not combatant then
        return nil
    end

    if action and action.target_body_part_id then
        local explicit = combatant:get_body_part_by_id(action.target_body_part_id)
        if explicit then
            return combatant, explicit
        end
    end

    for _, part in ipairs(combatant.body_parts or {}) do
        if part.status == "maimed" or part.status == "wounded" then
            return combatant, part
        end
    end

    return combatant, combatant:get_first_healthy_part()
end

function Engine:apply_damage(attacker, target, body_part, amount, context)
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
            status_after = new_status,
            context = context
        })

        if new_status ~= status_before then
            self:emit(Events.BP_STATUS_CHANGED, {
                combatant = target,
                body_part = body_part,
                previous_status = status_before,
                new_status = new_status,
                context = context
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
                heart_point_loss = lost_hp,
                context = context
            })
        end

        status_before = body_part.status

        if body_part.status == "maimed" then
            break
        end
    end
end

function Engine:apply_healing(actor, target, body_part, amount, context)
    if not target or not body_part then
        return
    end

    local steps = amount or 1
    for _ = 1, steps do
        local status_before = body_part.status
        local new_status = body_part:regress_damage_state()

        self:emit(Events.HEAL_APPLIED, {
            healer = actor,
            target = target,
            body_part = body_part,
            status_before = status_before,
            status_after = new_status,
            context = context,
            no_effect = status_before == new_status
        })

        if new_status ~= status_before then
            self:emit(Events.BP_STATUS_CHANGED, {
                combatant = target,
                body_part = body_part,
                previous_status = status_before,
                new_status = new_status,
                healed = true,
                context = context
            })
        else
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
                result = self:apply_forced_reroll(combatant, result, {
                    type = "defense",
                    action = action,
                    body_part = target_part
                })

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
            local context = {
                attacker = attacker,
                defender = opponent,
                target_part = body_part,
                action = action,
                action_index = action_index,
                base_damage = amount,
                damage = amount,
                keywords = collect_keywords(attacker and attacker.selected_tech, action)
            }
            self:apply_damage(attacker, opponent, body_part, amount, context)
        end
    elseif action.type == "attack_roll" then
        local result = Dice.roll(action.dice_count or 1, action.dice_type or "d6")
        result = self:apply_forced_reroll(attacker, result, {
            type = "attack",
            action = action,
            action_index = action_index
        })

        local tech = attacker and attacker.selected_tech
        local keywords = collect_keywords(tech, action)
        local consistent_value = apply_consistent_keyword(result, keywords)

        local passive_bonus = attacker and attacker.get_modifier and attacker:get_modifier("attack_bonus") or 0
        local token_bonus = self:consume_attack_bonus_token(attacker)
        local attack_bonus = passive_bonus + token_bonus

        local assignment = self:get_attack_assignment(attacker, action_index)
        local opponent = assignment and assignment.target_combatant
        local body_part = assignment and assignment.target_part

        if not opponent or not body_part then
            opponent, body_part = self:select_target_body_part(attacker, action)
        end

        local defense_total = 0
        if defense_totals and opponent and body_part and body_part.id then
            local opponent_totals = defense_totals[opponent]
            defense_total = opponent_totals and opponent_totals[body_part.id] or 0
        end

        local context = {
            attacker = attacker,
            defender = opponent,
            target_part = body_part,
            action = action,
            action_index = action_index,
            keywords = keywords,
            dice_result = result,
            consistent_value = consistent_value,
            passive_attack_bonus = passive_bonus,
            temporary_attack_bonus = token_bonus,
            attack_bonus = attack_bonus,
            base_roll_total = result.total or 0,
            attack_total = (result.total or 0) + attack_bonus,
            defense_total = defense_total,
            effective_defense = defense_total,
            base_toughness = body_part and body_part.toughness or 0,
            original_base_toughness = body_part and body_part.toughness or 0,
            effective_toughness = (body_part and body_part.toughness or 0) + defense_total,
            base_damage = action.damage or 1,
            damage = action.damage or 1,
            notes = {}
        }

        self:run_attack_pipeline(context)

        self:emit(Events.DICE_ROLLED, {
            attacker = attacker,
            action = action,
            result = result,
            modified_total = context.attack_total,
            attack_bonus = attack_bonus,
            passive_attack_bonus = passive_bonus,
            temporary_attack_bonus = token_bonus,
            context = context
        })

        if context.hit and opponent and body_part then
            self:apply_damage(attacker, opponent, body_part, context.damage, context)
        end
    elseif action.type == "defense_roll" then
        return
    elseif action.type == "gain_crest" then
        local crest = action.crest
        if crest and attacker then
            local amount = action.amount or 1
            self:grant_crest(attacker, crest, amount, { source = "action" })
        end
    elseif action.type == "heal_body_part" then
        local recipient = attacker
        if action.target == "opponent" then
            recipient = self:get_opponent(attacker)
        elseif type(action.target) == "table" and action.target.combatant then
            recipient = action.target.combatant
        end

        local target_combatant, body_part = self:select_friendly_body_part(recipient, action)
        if target_combatant and body_part then
            local amount = action.amount or 1
            local context = {
                healer = attacker,
                target = target_combatant,
                target_part = body_part,
                action = action,
                action_index = action_index
            }
            self:apply_healing(attacker, target_combatant, body_part, amount, context)
        end
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
