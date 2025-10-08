local Events = require("combat.events")

local States = {}

States.WAITING = {
    enter = function(_) end,
    process = function(_) return nil end
}

States.ROUND_START = {
    enter = function(engine)
        engine.current_round = engine.current_round + 1
        engine:emit(Events.ROUND_START, { round = engine.current_round })
    end,
    process = function(_) return "UPKEEP" end
}

States.UPKEEP = {
    enter = function(engine)
        engine:emit(Events.UPKEEP_PHASE, { round = engine.current_round })
    end,
    process = function(_) return "TECH_SELECT" end
}

States.TECH_SELECT = {
    enter = function(engine)
        engine:emit(Events.TECH_SELECT_PHASE, {
            round = engine.current_round,
            combatants = engine.combatants
        })
        engine:begin_tech_selection()
    end,
    process = function(engine)
        if engine:tech_selection_complete() then
            return "ATTACK_ASSIGN"
        end
        return nil
    end
}

States.ATTACK_ASSIGN = {
    enter = function(engine)
        engine:emit(Events.ATTACK_ASSIGN_PHASE, { round = engine.current_round })
        engine:prepare_attack_assignments()
    end,
    process = function(engine)
        if engine:attack_assignment_complete() then
            return "DEFENSE_ASSIGN"
        end
        return nil
    end
}

States.DEFENSE_ASSIGN = {
    enter = function(engine)
        engine:emit(Events.DEFENSE_ASSIGN_PHASE, { round = engine.current_round })
        engine:prepare_defense_assignments()
    end,
    process = function(engine)
        if engine:defense_assignment_complete() then
            return "RESOLUTION"
        end
        return nil
    end
}

States.RESOLUTION = {
    enter = function(engine)
        engine:emit(Events.RESOLUTION_PHASE, { round = engine.current_round })
        engine:resolve_actions()
    end,
    process = function(engine)
        if engine:check_combat_end() then
            return "COMPLETE"
        end
        return "ROUND_END"
    end
}

States.ROUND_END = {
    enter = function(engine)
        engine:emit(Events.ROUND_END, { round = engine.current_round })
    end,
    process = function(_) return "ROUND_START" end
}

States.COMPLETE = {
    enter = function(engine)
        engine:emit(Events.COMBAT_END, { round = engine.current_round })
    end,
    process = function(_) return nil end
}

return States
