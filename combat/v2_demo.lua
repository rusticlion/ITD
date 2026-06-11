local Content = require("combat.v2_content")

local Demo = {}

local MODULE_NAME = "data.combat.v2_demo_parts"

local function load_definitions()
    return Content.load_module(MODULE_NAME)
end

function Demo.create_combatants()
    local definitions = load_definitions()
    return
        Content.build_combatant(definitions, "player_demo"),
        Content.build_combatant(definitions, "enemy_demo")
end

function Demo.validate()
    return Content.validate(require(MODULE_NAME))
end

return Demo
