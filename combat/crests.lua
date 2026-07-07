local Symbols = require("core.symbols")

local Crests = {}

Crests.ORDER = {
    "Valor",
    "Shadow",
    "Madness"
}

-- Holding this many Madness surrenders one die to the whispers each round.
Crests.MADNESS_SEIZE_THRESHOLD = 3

local ALIASES = {
    valor = "Valor",
    valour = "Valor",
    shadow = "Shadow",
    madness = "Madness"
}

local function random_healthy_part(engine, combatant)
    local healthy = {}
    for _, part in ipairs(combatant and combatant.body_parts or {}) do
        if part.status == "healthy" then
            table.insert(healthy, part)
        end
    end

    if #healthy == 0 then
        return nil
    end

    local roll = (engine and engine.rng) or math.random
    return healthy[roll(1, #healthy)]
end

Crests.DEFINITIONS = {
    Valor = {
        id = "Valor",
        name = "Valor",
        description = "Spend to add ATK to the next die you assign.",
        expend = function(_, combatant)
            if combatant and combatant.add_next_symbol then
                combatant:add_next_symbol(Symbols.STRIKE)
            end

            return {
                type = "valor",
                symbol = Symbols.STRIKE
            }
        end
    },

    Shadow = {
        id = "Shadow",
        name = "Shadow",
        description = "Spend to make slots you open this round shroud their source Body Part.",
        expend = function(_, combatant)
            if combatant then
                combatant.shadow_slot_shroud = true
            end

            return {
                type = "shadow"
            }
        end
    },

    -- The first detrimental crest: expending is a cost paid to purge.
    Madness = {
        id = "Madness",
        name = "Madness",
        detrimental = true,
        description = "At 3+, the whispers move your hand: one die each round is placed for you. "
            .. "Spend: pinch yourself — wound a random Healthy Body Part to purge this.",
        can_expend = function(engine, combatant)
            if not random_healthy_part(engine, combatant) then
                -- You cannot pinch yourself awake when nothing is whole.
                return false, "no_healthy_part"
            end
            return true
        end,
        expend = function(engine, combatant)
            local part = random_healthy_part(engine, combatant)
            if part and engine and engine.apply_damage then
                engine:apply_damage(nil, combatant, part, {
                    source = "crest",
                    crest = "Madness",
                    pinch = true
                })
            end

            return {
                type = "madness",
                part = part
            }
        end
    }
}

function Crests.normalize(crest)
    if crest == nil then
        return nil
    end

    local text = tostring(crest)
    return ALIASES[text:lower()] or text
end

function Crests.definition(crest)
    return Crests.DEFINITIONS[Crests.normalize(crest)]
end

function Crests.is_known(crest)
    return Crests.definition(crest) ~= nil
end

function Crests.describe(crest)
    local definition = Crests.definition(crest)
    if not definition then
        return "Unknown crest: " .. tostring(crest)
    end

    return definition.description
end

function Crests.is_detrimental(crest)
    local definition = Crests.definition(crest)
    return definition ~= nil and definition.detrimental == true
end

-- True when a combatant holds enough Madness for the whispers to take a die.
function Crests.is_seized(combatant)
    if not (combatant and combatant.get_crest_count) then
        return false
    end

    return combatant:get_crest_count("Madness") >= Crests.MADNESS_SEIZE_THRESHOLD
end

function Crests.validate_name(errors, path, crest)
    if not Crests.is_known(crest) then
        table.insert(errors, tostring(path) .. " references unknown crest " .. tostring(crest))
    end
end

function Crests.expend(engine, combatant, crest)
    local canonical = Crests.normalize(crest)
    local definition = Crests.DEFINITIONS[canonical]

    if not combatant or not canonical then
        return false, "invalid_crest"
    end

    if not definition then
        return false, "crest_not_implemented"
    end

    if not combatant.get_crest_count or combatant:get_crest_count(canonical) <= 0 then
        return false, "crest_empty"
    end

    if definition.can_expend then
        local allowed, reason = definition.can_expend(engine, combatant)
        if not allowed then
            return false, reason or "cannot_expend"
        end
    end

    combatant:remove_crest(canonical, 1)

    local effect = definition.expend and definition.expend(engine, combatant) or { type = canonical:lower() }
    effect.crest = canonical

    return true, canonical, effect
end

return Crests
