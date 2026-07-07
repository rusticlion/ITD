-- Fixed-resolution game surface and final presentation pass.
--
-- Every game state draws into the 960x540 logical canvas. The canvas is then
-- presented to the window in one place, which keeps game coordinates stable
-- and provides the seam for whole-screen color grading and other display
-- shaders. Window scaling is supported here even though the current window is
-- intentionally the same size as the logical canvas.

local Display = {
    WIDTH = 960,
    HEIGHT = 540,
    canvas = nil,
    shader = nil,
    frame_active = false
}

local CLEAR_COLOR = { 34 / 255, 32 / 255, 52 / 255, 1 }

-- Desaturation is the only presentation effect today. Keeping it in this
-- final pass avoids a second temporary canvas in core.screenfx; the eventual
-- handheld treatment can grow from this shader without changing state draws.
local PRESENT_SHADER = [[
extern number desaturation;

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
    vec4 pixel = Texel(tex, texture_coords) * color;
    number gray = dot(pixel.rgb, vec3(0.299, 0.587, 0.114));
    return vec4(mix(pixel.rgb, vec3(gray), desaturation), pixel.a);
}
]]

local function graphics()
    return love and love.graphics
end

local function presentation_rect(lg)
    local window_width, window_height = lg.getDimensions()
    local scale = math.min(
        window_width / Display.WIDTH,
        window_height / Display.HEIGHT)
    local width = Display.WIDTH * scale
    local height = Display.HEIGHT * scale

    return {
        x = math.floor((window_width - width) / 2 + 0.5),
        y = math.floor((window_height - height) / 2 + 0.5),
        width = width,
        height = height,
        scale = scale
    }
end

function Display.load()
    local lg = graphics()
    assert(lg, "Display.load requires love.graphics")

    Display.canvas = lg.newCanvas(Display.WIDTH, Display.HEIGHT, {
        format = "rgba8",
        msaa = 0
    })
    Display.canvas:setFilter("nearest", "nearest")
    Display.shader = lg.newShader(PRESENT_SHADER)
end

function Display.begin_frame()
    local lg = graphics()
    if not lg then
        return
    end
    if not Display.canvas then
        Display.load()
    end
    assert(not Display.frame_active, "Display.begin_frame called before the previous frame ended")

    lg.push("all")
    lg.setCanvas(Display.canvas)
    lg.origin()
    lg.clear(CLEAR_COLOR)
    Display.frame_active = true
end

function Display.end_frame(options)
    local lg = graphics()
    if not lg then
        return
    end
    assert(Display.frame_active, "Display.end_frame called without Display.begin_frame")
    Display.frame_active = false

    lg.setCanvas()
    lg.pop()

    local presentation = presentation_rect(lg)
    local desaturation = math.max(0, math.min(
        tonumber(options and options.desaturation) or 0,
        1))

    lg.push("all")
    lg.origin()
    lg.clear(CLEAR_COLOR)
    lg.setColor(1, 1, 1, 1)
    Display.shader:send("desaturation", desaturation)
    lg.setShader(Display.shader)
    lg.draw(
        Display.canvas,
        presentation.x,
        presentation.y,
        0,
        presentation.scale,
        presentation.scale)
    lg.pop()
end

-- Convert window-space pointer input back into the stable game coordinate
-- system. The third return value is false when the pointer is in letterboxing.
function Display.window_to_logical(x, y)
    local lg = graphics()
    if not lg then
        return x, y, true
    end

    local presentation = presentation_rect(lg)
    local logical_x = (x - presentation.x) / presentation.scale
    local logical_y = (y - presentation.y) / presentation.scale
    local inside = logical_x >= 0 and logical_y >= 0
        and logical_x < Display.WIDTH and logical_y < Display.HEIGHT

    return logical_x, logical_y, inside
end

function Display.pointer_position()
    if not (love and love.mouse and love.mouse.getPosition) then
        return 0, 0, false
    end
    return Display.window_to_logical(love.mouse.getPosition())
end

return Display
