local V2Encounters = require("combat.v2_encounters")
local Actor = require("systems.actor")
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
        spawn = scenario.spawn,
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
    local spawn_x, spawn_y = world.room:spawn_tile(scenario.spawn)
    assert_true(world.player.x == spawn_x and world.player.y == spawn_y,
        scenario.id .. " should apply its named spawn")

    local before_x = world.player.x
    local before_y = world.player.y
    local before_equipped = world.player.equipped
    world:reload_room()
    assert_true(world.player.x == before_x and world.player.y == before_y,
        scenario.id .. " should preserve position across room reload")
    assert_true(world.player.equipped == before_equipped,
        scenario.id .. " should preserve the held tool across room reload")
end

local basement = World.new({
    room = "data.rooms.basement_1",
    spawn = "start",
    autosave = false
})
assert_true(basement.room.id == "basement_1", "Tiled room should expose its stable room id")
assert_true(#basement.room.validation.errors == 0, "Tiled Basement should have no validation errors")
assert_true(#basement.room.validation.warnings == 0, "Tiled Basement should have no validation warnings")

local bone_crack = basement.room.actor_by_id.crack_bone_demon
assert_true(bone_crack and not basement.room:is_tile_solid(bone_crack.x, bone_crack.y),
    "Tiled cracks should occupy deliberate openings in tile collision")
assert_true(basement.room:is_blocked(bone_crack.x, bone_crack.y),
    "unresolved cracks should block their passage tile")

basement.player:addItem("shovel")
local crack_result = bone_crack:interact(basement, basement.player)
assert_true(crack_result.type == "encounter" and crack_result.encounter_id == "basement.bone_demon",
    "Tiled crack properties should produce the authored encounter")
assert_true(not basement.room:is_blocked(bone_crack.x, bone_crack.y),
    "resolved cracks should open their passage tile")

local passage_crack = basement.room.actor_by_id.crack_passage
local passage_result = passage_crack:interact(basement, basement.player)
assert_true(passage_result.type == "passage" and passage_result.flag == "basement.passage_open",
    "hidden passage should return its camera-unlock flag")
basement:handle_result(passage_result)
assert_true(basement:get_flag("basement.passage_open"),
    "resolving the hidden passage should release its world flag")

local shovel_pipe = basement.room.actor_by_id.pipe_shovel
assert_true(shovel_pipe and shovel_pipe.properties.item == "shovel",
    "Tiled pipe properties should preserve its item behavior")
assert_true(basement.room:is_blocked(shovel_pipe.x, shovel_pipe.y),
    "pipes should always block movement")
shovel_pipe.state.removed = true
assert_true(basement.room:is_blocked(shovel_pipe.x, shovel_pipe.y),
    "an emptied pipe should remain solid")

local invisible_trigger = Actor.new({
    name = "pentagram_trigger",
    type = "message",
    collision = "never"
})
assert_true(not invisible_trigger:blocks_movement(basement),
    "never-colliding actors should not block movement")

local scripted_actor = Actor.new({
    name = "scripted_door",
    type = "message",
    collision = "scripted"
})
assert_true(not scripted_actor:blocks_movement(basement),
    "scripted collision should default to open")
scripted_actor:set_collision_enabled(true)
assert_true(scripted_actor:blocks_movement(basement),
    "scripts should be able to enable collision persistently")
scripted_actor:set_collision_enabled(false)
assert_true(not scripted_actor:blocks_movement(basement),
    "scripts should be able to disable collision persistently")

print("designer scenario smoke test passed.")
