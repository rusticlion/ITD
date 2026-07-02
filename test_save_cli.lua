local Save = require("core.save")
local World = require("systems.world")

local function memory_filesystem()
    local files = {}
    local directories = {}

    return {
        files = files,
        directories = directories,
        getInfo = function(path)
            if files[path] then
                return { type = "file" }
            end
            return nil
        end,
        read = function(path)
            return files[path]
        end,
        write = function(path, source)
            files[path] = source
            return true
        end,
        createDirectory = function(path)
            directories[path] = true
            return true
        end
    }
end

local function assert_equal(actual, expected, label)
    if actual ~= expected then
        error((label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local obsolete_version = Save.VERSION - 1
local obsolete_save, obsolete_error = Save.deserialize(
    "return { save_version = " .. tostring(obsolete_version) .. " }"
)
assert_equal(obsolete_save, nil, "obsolete save data")
assert_equal(
    obsolete_error,
    "unsupported save version " .. tostring(obsolete_version) .. "; expected " .. tostring(Save.VERSION),
    "obsolete save error"
)

local fs = memory_filesystem()
local path = "saves/test_slot.lua"

local world = World.new({
    autosave = true,
    save_backend = fs,
    save_path = path
})

world.player.x = 4
world.player.y = 6
world.player.facing = "left"
world.player:addItem("shovel")
world.room_states.basement_1.pipe_shovel = { removed = true }
local claimed_instance_id = world:add_claimed_part({ def_id = "bone_demon_skull", type = "HEAD", status = "healthy" }, "test.encounter")
world:autosave("test")

assert(fs.files[path], "expected save file to be written")
assert(fs.directories.saves, "expected save directory to be created")

local loaded = assert(Save.load(path, fs))
assert_equal(loaded.save_version, Save.VERSION, "save version")
assert_equal(loaded.run.player.x, 4, "player x")
assert_equal(loaded.run.player.y, 6, "player y")
assert_equal(loaded.run.player.facing, "left", "player facing")
assert_equal(loaded.run.player.inventory.shovel, true, "player inventory")
assert_equal(loaded.run.dreamform.head, claimed_instance_id, "claimed part equipped into head slot")
assert_equal(loaded.run.parts[claimed_instance_id].def_id, "bone_demon_skull", "claimed part is current body")
assert_equal(loaded.run.parts.part_inst_dreamer_head, nil, "replaced part should not remain in run parts")
assert_equal(loaded.run.discovered_parts.dreamer_head, true, "discovered starter part")
assert_equal(loaded.run.discovered_parts.bone_demon_skull, true, "discovered claimed part")
assert_equal(loaded.rooms.basement_1.pipe_shovel.removed, true, "actor state")

local restored = World.new({
    save = loaded,
    autosave = false
})

assert_equal(restored.player.x, 4, "restored player x")
assert_equal(restored.player.y, 6, "restored player y")
assert_equal(restored.player.facing, "left", "restored player facing")
assert_equal(restored.player:hasItem("shovel"), true, "restored inventory")
assert_equal(restored.room_states.basement_1.pipe_shovel.removed, true, "restored actor state")
assert_equal(restored.run.dreamform.head, claimed_instance_id, "restored claimed head slot")
assert_equal(restored.run.parts[claimed_instance_id].def_id, "bone_demon_skull", "restored current claimed body part")

local pipe = restored.room.actor_by_id.pipe_shovel
assert(pipe, "expected pipe actor")
assert_equal(pipe.state.removed, true, "bound actor state")

local combat_world = World.new({ autosave = false })
local replaced_arm_id = combat_world.run.dreamform.arm_r
local summary = combat_world:apply_combat_result({
    type = "combat_result",
    outcome = "victory",
    encounter_id = "test.claim",
    player_parts = {},
    enemy_parts = {},
    claimable_parts = {
        { def_id = "bone_demon_right_bare_bones", type = "ARM", status = "wounded" }
    },
    claimed_part = { def_id = "bone_demon_right_bare_bones", id = "bone_demon_right_bare_bones", name = "Bare Bones", type = "ARM", status = "wounded" },
    claimed_slot = "arm_r"
})

local claimed_arm_id = combat_world.run.dreamform.arm_r
assert(claimed_arm_id ~= replaced_arm_id, "claimed arm should replace the old right arm instance")
assert_equal(combat_world.run.parts[replaced_arm_id], nil, "replaced arm should be deleted from current parts")
assert_equal(combat_world.run.parts[claimed_arm_id].def_id, "bone_demon_right_bare_bones", "claimed arm def")
assert_equal(combat_world.run.parts[claimed_arm_id].status, "healthy", "claimed wounded part gets post-combat recovery")
assert_equal(combat_world.run.discovered_parts.bone_demon_right_bare_bones, true, "claimed arm discovered")
assert_equal(summary.claim_summary.slot_id, "arm_r", "claim summary slot")
assert_equal(summary.claim_summary.replaced_part.def_id, "dreamer_back_hand", "claim summary replaced part")

print("save smoke test passed.")
