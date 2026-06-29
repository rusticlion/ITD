local Content = require("combat.v2_content")
local Encounters = require("combat.v2_encounters")

local Demo = {}

local MODULE_NAME = "data.combat.v2_demo_parts"

function Demo.create_combatants(context)
    return Encounters.create_combatants(context)
end

function Demo.validate()
    local errors = Content.validate(require(MODULE_NAME))
    for _, message in ipairs(Encounters.validate()) do
        table.insert(errors, message)
    end
    return errors
end

return Demo
