local CrestPassives = {}

CrestPassives.registry = {
    Valor = function(engine, combatant, count)
        if count >= 2 then
            if combatant.add_modifier then
                combatant:add_modifier("attack_bonus", 1)
            end
        end
    end
}

function CrestPassives.apply(engine, combatant)
    if not combatant then
        return
    end

    for crest, handler in pairs(CrestPassives.registry) do
        if handler then
            local count = combatant.get_crest_count and combatant:get_crest_count(crest) or 0
            handler(engine, combatant, count)
        end
    end
end

return CrestPassives
