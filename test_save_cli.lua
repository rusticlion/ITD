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
world:add_claimed_part({ def_id = "bone_demon_skull", status = "healthy" }, "test.encounter")
world:autosave("test")

assert(fs.files[path], "expected save file to be written")
assert(fs.directories.saves, "expected save directory to be created")

local loaded = assert(Save.load(path, fs))
assert_equal(loaded.save_version, Save.VERSION, "save version")
assert_equal(loaded.run.player.x, 4, "player x")
assert_equal(loaded.run.player.y, 6, "player y")
assert_equal(loaded.run.player.facing, "left", "player facing")
assert_equal(loaded.run.player.inventory.shovel, true, "player inventory")
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

local pipe = restored.room.actor_by_id.pipe_shovel
assert(pipe, "expected pipe actor")
assert_equal(pipe.state.removed, true, "bound actor state")

print("save smoke test passed.")
