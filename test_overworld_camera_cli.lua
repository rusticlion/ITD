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

print("overworld camera smoke test passed.")
