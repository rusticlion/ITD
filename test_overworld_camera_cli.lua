local Camera = require("systems.overworld_camera")

local function close_enough(left, right)
    return math.abs(left - right) < 0.0001
end

local function region(properties, x, y, width, height)
    return {
        x = x,
        y = y,
        width = width,
        height = height,
        property = function(_, key, default)
            local value = properties[key]
            return value == nil and default or value
        end
    }
end

local room = {
    width = 100,
    height = 60,
    tile_size = 32,
    property = function(_, key)
        if key == "camera_zoom" then
            return "standard"
        end
    end,
    camera_zone_at = function()
        return nil
    end
}

local camera = Camera.new()
local wide_w, wide_h = camera:viewport_world_size("wide", 960, 540)
local standard_w, standard_h = camera:viewport_world_size("standard", 960, 540)
local close_w, close_h = camera:viewport_world_size("close", 960, 540)

assert(wide_w == 1920 and wide_h == 1080, "expected wide viewport footprint")
assert(standard_w == 960 and standard_h == 540, "expected standard viewport footprint")
assert(close_w == 640 and close_h == 360, "expected close viewport footprint")

camera:update(room, 1600, 960, 960, 540)
assert(camera.mode == "standard", "expected room camera mode")
assert(camera.x == 1120 and camera.y == 690, "expected centered standard camera")

camera:update(room, 16, 16, 960, 540)
assert(camera.x == 0 and camera.y == 0, "expected camera clamp at room origin")

local small_room = {
    width = 10,
    height = 8,
    tile_size = 32,
    property = function(_, key)
        if key == "camera_zoom" then
            return "close"
        end
    end,
    camera_zone_at = function()
        return nil
    end
}

camera:update(small_room, 160, 128, 960, 540)
assert(camera.mode == "close", "expected close room mode")
assert(close_enough(camera.x, -160), "expected narrow room to center horizontally")
assert(close_enough(camera.y, -52), "expected short room to center vertically")
assert(close_enough(camera.x * camera:scale(), math.floor(camera.x * camera:scale() + 0.5)),
    "expected camera translation to land on screen pixels")

local tile_room = {
    width = 30,
    height = 17,
    tile_size = 32,
    property = function(_, key)
        if key == "camera_zoom" then
            return "close"
        end
    end,
    camera_zone_at = function()
        return nil
    end
}
local tile_camera = Camera.new({ mode = "close" })
tile_camera:update(tile_room, 656, 336, 960, 540)
assert(tile_camera.x == 320, "expected initial camera clamp at the right map edge")
tile_camera:update(tile_room, 624, 336, 960, 540)
assert(tile_camera.x == 288, "expected first inward step to pan one full tile")
tile_camera:update(tile_room, 592, 336, 960, 540)
assert(tile_camera.x == 256, "expected subsequent tracking to remain tile-quantized")

local close_zone = region({
    camera_zoom = "close",
    camera_bounds = true
}, 640, 320, 640, 360)

room.camera_zone_at = function(_, x, y)
    if x >= 640 and x < 1280 and y >= 320 and y < 680 then
        return close_zone
    end
end

camera:update(room, 800, 500, 960, 540)
assert(camera.mode == "close", "expected camera zone mode")
assert(camera.x == 640 and camera.y == 320, "expected zone to provide camera bounds")

local screen_x, screen_y = camera:world_to_screen(800, 500)
local world_x, world_y = camera:screen_to_world(screen_x, screen_y)
assert(close_enough(world_x, 800) and close_enough(world_y, 500),
    "expected screen/world coordinate round trip")

assert(camera:debug_override() == nil, "expected no initial debug override")
assert(camera:cycle_debug_override() == "wide", "expected first override to be wide")
assert(camera:cycle_debug_override() == "standard", "expected second override to be standard")
assert(camera:cycle_debug_override() == "close", "expected third override to be close")
assert(camera:cycle_debug_override() == nil, "expected override cycle to return to authored mode")

local World = require("systems.world")
local world = World.new({ spawn = "start", autosave = false })
love = {
    graphics = {
        getWidth = function()
            return 960
        end,
        getHeight = function()
            return 540
        end
    }
}
world:update_camera()
assert(world.camera_tracking_locked == true, "expected Basement camera to begin locked")
assert(world.camera.x == 32 and world.camera.y == 184,
    "expected Basement camera anchor to frame the bottom center")
local locked_x = world.camera.x
world.player.render_x = world.player.render_x - 1
world.player.x = world.player.x - 1
world:update_camera()
assert(world.camera.x == locked_x, "expected locked camera to ignore player movement")

-- Stale-save regression: a saved position outside the anchor-locked frame
-- must release the lock and follow the player instead of framing an empty room.
local stale_world = World.new({
    autosave = false,
    save = {
        run = {
            current_room = "data.rooms.basement_1",
            player = { x = 22, y = 9 }
        }
    }
})
assert(stale_world.camera_lock_released == true,
    "expected out-of-frame saved position to release the camera lock")
assert(stale_world.player.x == 22 and stale_world.player.y == 9,
    "expected valid saved position to be preserved")
stale_world:update_camera()
local frame_left = stale_world.camera.x
local frame_right = frame_left + 640 -- close mode: 640 world px wide
local player_px = (stale_world.player.x - 1) * 32
assert(player_px >= frame_left and player_px + 32 <= frame_right,
    "expected released camera to frame the player")

-- A saved position that no longer exists in the reauthored room heals to the
-- start spawn instead of booting the player out of bounds or inside a wall.
local out_of_bounds_world = World.new({
    autosave = false,
    save = {
        run = {
            current_room = "data.rooms.basement_1",
            player = { x = 99, y = 99 }
        }
    }
})
local spawn_x, spawn_y = out_of_bounds_world.room:spawn_tile("start")
assert(out_of_bounds_world.player.x == spawn_x and out_of_bounds_world.player.y == spawn_y,
    "expected out-of-bounds saved position to relocate to the start spawn")

local blocked_world = World.new({
    autosave = false,
    save = {
        run = {
            current_room = "data.rooms.basement_1",
            player = { x = 21, y = 9 }
        }
    }
})
assert(blocked_world.player.x == spawn_x and blocked_world.player.y == spawn_y,
    "expected blocked saved position to relocate to the start spawn")

world:set_flag("basement.passage_open", true)
world:update_camera()
assert(world.camera_tracking_locked == false, "expected hidden passage flag to free camera")
assert(world.camera.x == locked_x, "expected camera unlock not to jump immediately")
world.player.render_x = world.player.render_x - 1
world.player.x = world.player.x - 1
world:update_camera()
assert(world.camera.x == locked_x - 32, "expected freed camera to follow by one full tile")

print("overworld camera smoke test passed.")
