local AI = {}

local BENEFICIAL_CRESTS = {
    Shadow = true,
    Valor = true,
    Knowledge = true,
    Cunning = true
}

local DETRIMENTAL_CRESTS = {
    Madness = true,
    Greed = true,
    Corruption = true
}

local STATUS_PRIORITY = {
    wounded = 3,
    healthy = 2,
    maimed = 0
}

local function average_for_die(dice_type)
    if type(dice_type) ~= "string" then
        return 0
    end

    local sides = dice_type:lower():match("d(%d+)")
    sides = sides and tonumber(sides)

    if not sides or sides <= 0 then
        return 0
    end

    return (sides + 1) / 2
end

local function count_wounded_parts(combatant)
    if not combatant or not combatant.body_parts then
        return 0
    end

    local total = 0
    for _, part in ipairs(combatant.body_parts) do
        if part.status == "wounded" then
            total = total + 1
        end
    end

    return total
end

local function estimate_attack_value(action)
    local dice_count = action.dice_count or 0
    local average = average_for_die(action.dice_type or "d6")
    local bonus = action.flat_bonus or 0

    return dice_count * average + bonus
end

local function estimate_defense_value(action)
    local dice_count = action.dice_count or 0
    local average = average_for_die(action.dice_type or "d6")

    return dice_count * average
end

local function crest_value(crest, amount)
    local multiplier = amount or 1

    if BENEFICIAL_CRESTS[crest] then
        return 2 * multiplier
    end

    if DETRIMENTAL_CRESTS[crest] then
        return -2 * multiplier
    end

    return multiplier
end

local function score_tech(ai_combatant, opponent, tech)
    if not tech then
        return -math.huge
    end

    local offense = 0
    local defense = 0
    local support = 0

    local opponent_wounds = count_wounded_parts(opponent)

    for _, action in ipairs(tech.actions or {}) do
        if action.type == "attack_roll" then
            local value = estimate_attack_value(action)

            if opponent_wounds > 0 then
                value = value * (1 + opponent_wounds * 0.15)
            end

            offense = offense + value
        elseif action.type == "damage_body_part" then
            local steps = action.amount or 1
            offense = offense + (steps * 6)
        elseif action.type == "defense_roll" then
            defense = defense + estimate_defense_value(action)
        elseif action.type == "heal_body_part" then
            support = support + 6
        elseif action.type == "gain_crest" then
            support = support + crest_value(action.crest, action.amount)
        elseif action.type == "consume_crest" then
            support = support - crest_value(action.crest, action.amount)
        end
    end

    local heart_points = ai_combatant and ai_combatant.heart_points or 3
    if heart_points <= 1 then
        defense = defense * 1.75
        support = support + 2
    elseif heart_points == 2 then
        defense = defense * 1.25
    end

    local ai_wounds = count_wounded_parts(ai_combatant)
    if ai_wounds > 0 then
        support = support + ai_wounds * 2.5
    end

    local total_actions = #(tech.actions or {})

    return offense * 1.1 + defense + support + total_actions * 0.1
end

local function get_tech_list(ai_combatant, provided)
    if provided and #provided > 0 then
        return provided
    end

    if ai_combatant and ai_combatant.get_available_techs then
        return ai_combatant:get_available_techs()
    end

    return {}
end

function AI.choose_tech(ai_combatant, opponent, available_techs)
    local techs = get_tech_list(ai_combatant, available_techs)
    local best_tech = nil
    local best_score = -math.huge

    for _, tech in ipairs(techs) do
        local score = score_tech(ai_combatant, opponent, tech)
        if score > best_score then
            best_score = score
            best_tech = tech
        end
    end

    return best_tech
end

local function gather_targetable_parts(opponent, context)
    if not opponent then
        return {}
    end

    local parts = nil

    if context and context.engine and context.engine.get_targetable_parts then
        parts = context.engine:get_targetable_parts(opponent)
    end

    if parts and #parts > 0 then
        return parts
    end

    parts = {}
    for _, part in ipairs(opponent.body_parts or {}) do
        if part.status ~= "maimed" then
            table.insert(parts, part)
        end
    end

    return parts
end

local function sort_target_priority(parts)
    table.sort(parts, function(a, b)
        local a_priority = STATUS_PRIORITY[a.status or "healthy"] or 1
        local b_priority = STATUS_PRIORITY[b.status or "healthy"] or 1

        if a_priority == b_priority then
            local a_toughness = a.toughness or math.huge
            local b_toughness = b.toughness or math.huge

            if a_toughness == b_toughness then
                local a_hp = a.hp_value or 0
                local b_hp = b.hp_value or 0
                if a_hp == b_hp then
                    return (a.id or "") < (b.id or "")
                end
                return a_hp > b_hp
            end

            return a_toughness < b_toughness
        end

        return a_priority > b_priority
    end)
end

function AI.assign_targets(ai_combatant, opponent, tech, context)
    local assignments = {}

    if not tech or not tech.actions or not opponent then
        return assignments
    end

    local engine = context and context.engine or nil
    local targetable_parts = gather_targetable_parts(opponent, context)

    if #targetable_parts == 0 then
        return assignments
    end

    sort_target_priority(targetable_parts)

    local function get_preferred_part(index)
        if #targetable_parts == 0 then
            return nil
        end

        local adjusted = ((index - 1) % #targetable_parts) + 1
        return targetable_parts[adjusted]
    end

    local attack_index = 0

    for index, action in ipairs(tech.actions) do
        if action.type == "attack_roll" then
            attack_index = attack_index + 1

            local target_part = nil

            if action.target_body_part_id and opponent.get_body_part_by_id then
                target_part = opponent:get_body_part_by_id(action.target_body_part_id)
            end

            if not target_part then
                target_part = get_preferred_part(attack_index)
            end

            if target_part then
                if target_part.status == "maimed" then
                    target_part = nil
                end
            end

            if target_part then
                if not engine or not engine.is_part_untargetable or not engine:is_part_untargetable(target_part) then
                    assignments[index] = target_part
                end
            end
        end
    end

    return assignments
end

return AI

