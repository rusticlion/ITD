local Symbols = require("core.symbols")

local Crests = {}

Crests.ORDER = {
    "Valor",
    "Shadow"
}

local ALIASES = {
    valor = "Valor",
    valour = "Valor",
    shadow = "Shadow"
}

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

    combatant:remove_crest(canonical, 1)

    local effect = definition.expend and definition.expend(engine, combatant) or { type = canonical:lower() }
    effect.crest = canonical

    return true, canonical, effect
end

return Crests
