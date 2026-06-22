local Content = require("combat.v2_content")
local Combatant = require("combat.combatant")

local Demo = {}

local MODULE_NAME = "data.combat.v2_demo_parts"
local DREAMFORM_SLOT_ORDER = {
    "head",
    "body",
    "arm_l",
    "arm_r",
    "leg_l",
    "leg_r"
}

local ENCOUNTER_LOADOUTS = {
    bone_demon = "enemy_demo",
    zombie = "enemy_demo",
    ["debug.demo"] = "enemy_demo"
}

local function load_definitions()
    return Content.load_module(MODULE_NAME)
end

local function build_player_from_run(definitions, run)
    if not (run and run.dreamform and run.parts) then
        return Content.build_combatant(definitions, "player_demo")
    end

    local combatant = Combatant:new({
        id = "player",
        name = "Dreamer",
        is_player = true,
        heart_points = run.heart_points or 3
    })

    for _, slot in ipairs(DREAMFORM_SLOT_ORDER) do
        local instance_id = run.dreamform[slot]
        local instance = instance_id and run.parts[instance_id]
        if instance and instance.def_id then
            local part = Content.build_part(definitions, instance.def_id)
            part.instance_id = instance_id
            part.dreamform_slot = slot
            part.status = instance.status or "healthy"
            combatant:add_body_part(part)
        end
    end

    if #combatant.body_parts == 0 then
        return Content.build_combatant(definitions, "player_demo")
    end

    return combatant
end

local function enemy_loadout_for(context)
    local encounter_id = context and context.encounter_id
    return ENCOUNTER_LOADOUTS[encounter_id] or "enemy_demo"
end

function Demo.create_combatants(context)
    local definitions = load_definitions()
    return
        build_player_from_run(definitions, context and context.run),
        Content.build_combatant(definitions, enemy_loadout_for(context))
end

function Demo.validate()
    return Content.validate(require(MODULE_NAME))
end

return Demo
