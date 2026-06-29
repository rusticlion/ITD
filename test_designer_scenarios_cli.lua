local V2Encounters = require("combat.v2_encounters")
local World = require("systems.world")

local scenarios = require("data.designer_scenarios")

local function assert_true(condition, message)
    if not condition then
        error(message or "assertion failed", 2)
    end
end

for _, scenario in ipairs(scenarios.combat or {}) do
    local player, enemy = V2Encounters.create_combatants({
        encounter_id = scenario.encounter_id
    })
    assert_true(player and #player.body_parts > 0, scenario.id .. " should build a player")
    assert_true(enemy and #enemy.body_parts > 0, scenario.id .. " should build an enemy")
    assert_true(type(scenario.seed) == "number", scenario.id .. " should declare a repeatable seed")
end

for _, scenario in ipairs(scenarios.overworld or {}) do
    local world = World.new({
        room = scenario.room,
        player = scenario.player,
        run = {
            current_room = scenario.room,
            player = scenario.player,
            flags = scenario.flags,
            encounters = scenario.encounters
        },
        flags = scenario.flags,
        room_states = scenario.room_states,
        autosave = false
    })

    assert_true(world.autosave_enabled == false, scenario.id .. " must not autosave")
    assert_true(world.room_module == scenario.room, scenario.id .. " should load its room")
    assert_true(world.player.x == scenario.player.x and world.player.y == scenario.player.y,
        scenario.id .. " should apply its player checkpoint")

    local before_x = world.player.x
    local before_y = world.player.y
    local before_equipped = world.player.equipped
    world:reload_room()
    assert_true(world.player.x == before_x and world.player.y == before_y,
        scenario.id .. " should preserve position across room reload")
    assert_true(world.player.equipped == before_equipped,
        scenario.id .. " should preserve the held tool across room reload")
end

print("designer scenario smoke test passed.")
