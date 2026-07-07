local previous_love = love

love = {
    graphics = {
        getDimensions = function()
            return 1920, 1200
        end
    },
    mouse = {
        getPosition = function()
            return 960, 600
        end
    }
}

local Display = require("core.display")

local x, y, inside = Display.window_to_logical(960, 600)
assert(x == 480 and y == 270 and inside, "window center maps to logical center")

x, y, inside = Display.window_to_logical(0, 0)
assert(not inside, "letterbox input is outside the logical canvas")

x, y, inside = Display.pointer_position()
assert(x == 480 and y == 270 and inside, "pointer helper uses the display transform")

love = previous_love
print("display smoke test passed.")
