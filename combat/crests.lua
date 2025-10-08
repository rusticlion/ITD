local CrestEffects = {}

local PASSIVE_REGISTRY = {
    Valor = function(engine, combatant, count)
        if count >= 2 and combatant and combatant.add_modifier then
            combatant:add_modifier("attack_bonus", 1)
        end
    end
}

local ALL_CRESTS = {
    "Shadow",
    "Valor",
    "Knowledge",
    "Cunning",
    "Madness",
    "Greed",
    "Corruption"
}

local EXPEND_REGISTRY = {}

local function random_crest_name()
    if #ALL_CRESTS == 0 then
        return nil
    end

    local index = math.random(1, #ALL_CRESTS)
    return ALL_CRESTS[index]
end

function CrestEffects.apply(engine, combatant)
    if not combatant then
        return
    end

    for crest, handler in pairs(PASSIVE_REGISTRY) do
        if handler then
            local count = combatant.get_crest_count and combatant:get_crest_count(crest) or 0
            handler(engine, combatant, count)
        end
    end
end

function CrestEffects.can_expend(crest)
    return crest ~= nil and EXPEND_REGISTRY[crest] ~= nil
end

function CrestEffects.get_expend_handler(crest)
    return crest and EXPEND_REGISTRY[crest] or nil
end

function CrestEffects.random_crest()
    return random_crest_name()
end

EXPEND_REGISTRY.Shadow = function(engine, combatant, on_complete)
    if not engine or not combatant then
        if on_complete then
            on_complete({ type = "shadow", skipped = true })
        end
        return
    end

    local opponent = engine:get_opponent(combatant)
    if not opponent then
        if on_complete then
            on_complete({ type = "shadow", skipped = true })
        end
        return
    end

    local options = engine:get_targetable_parts(opponent)
    if not options or #options == 0 then
        if on_complete then
            on_complete({ type = "shadow", skipped = true })
        end
        return
    end

    local metadata = {
        type = "crest_target_select",
        crest = "Shadow",
        combatant = combatant,
        opponent = opponent,
        options = {}
    }

    for index, part in ipairs(options) do
        metadata.options[index] = {
            index = index,
            part = part,
            id = part.id,
            name = part.name,
            status = part.status,
            toughness = part.toughness or 0
        }
    end

    local function handle_input(engine_instance, raw_input)
        local choice = tonumber(raw_input)
        local selection = choice and metadata.options[choice] or nil

        if not selection then
            engine_instance:request_input("Select a body part to shroud (enter number)", handle_input, metadata)
            return
        end

        engine_instance:clear_input()
        engine_instance:mark_part_untargetable(selection.part)

        if on_complete then
            on_complete({
                type = "shadow",
                target = selection.part
            })
        end
    end

    engine:request_input("Select a body part to shroud (enter number)", handle_input, metadata)
end

EXPEND_REGISTRY.Valor = function(_, combatant, on_complete)
    if combatant and combatant.attack_bonus_tokens then
        table.insert(combatant.attack_bonus_tokens, 2)
    end

    if on_complete then
        on_complete({
            type = "valor",
            bonus = 2
        })
    end
end

EXPEND_REGISTRY.Madness = function(engine, combatant, on_complete)
    if combatant then
        combatant.pending_forced_rerolls = (combatant.pending_forced_rerolls or 0) + 1
    end

    local gained_crest = CrestEffects.random_crest()
    if engine and engine.grant_crest and gained_crest and combatant then
        engine:grant_crest(combatant, gained_crest, 1, { source = "madness_expend" })
    end

    if on_complete then
        on_complete({
            type = "madness",
            gained_crest = gained_crest
        })
    end
end

return CrestEffects
