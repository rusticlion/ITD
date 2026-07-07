-- Global screen effect layer: flash, desaturation pulse, hit-stop, shake.
-- main.lua owns the two integration points:
--   local game_dt = ScreenFX.update(dt)   -- hit-stop filters the dt states see
--   ScreenFX.begin_frame() / GameState.draw() / ScreenFX.end_frame()
-- Display owns the logical canvas and consumes ScreenFX.desaturation_amount()
-- during its final presentation pass.
-- All effects scale with the global juice setting; at 0 they are no-ops
-- (reduced motion). Headless-safe: without love.graphics only the dt filter runs.

local ScreenFX = {
    juice = 1.0,
    hitstop_remaining = 0,
    shakes = {},
    flashes = {},
    desat = nil,
    shake_x = 0,
    shake_y = 0
}

local SHAKE_MAGNITUDE_CAP = 4 -- pixels; restraint is the point

local function graphics()
    return love and love.graphics
end

local function random_unit()
    if love and love.math and love.math.random then
        return love.math.random() * 2 - 1
    end
    return math.random() * 2 - 1
end

function ScreenFX.set_juice(scale)
    ScreenFX.juice = math.max(0, math.min(tonumber(scale) or 1, 1))
end

function ScreenFX.get_juice()
    return ScreenFX.juice
end

-- Freeze game time briefly. Concurrent requests extend, never stack.
function ScreenFX.hitstop(duration)
    if ScreenFX.juice <= 0 then
        return
    end
    local scaled = (duration or 0) * ScreenFX.juice
    ScreenFX.hitstop_remaining = math.max(ScreenFX.hitstop_remaining, scaled)
end

function ScreenFX.shake(magnitude, duration)
    if ScreenFX.juice <= 0 then
        return
    end
    table.insert(ScreenFX.shakes, {
        magnitude = math.min(magnitude or 2, SHAKE_MAGNITUDE_CAP) * ScreenFX.juice,
        duration = math.max(duration or 0.2, 0.01),
        elapsed = 0
    })
end

-- color: {r, g, b} 0..1; alpha is driven by the effect itself.
function ScreenFX.flash(color, duration, peak_alpha)
    if ScreenFX.juice <= 0 then
        return
    end
    table.insert(ScreenFX.flashes, {
        color = color or { 1, 1, 1 },
        duration = math.max(duration or 0.2, 0.01),
        peak_alpha = (peak_alpha or 0.35) * ScreenFX.juice,
        elapsed = 0
    })
end

function ScreenFX.desaturate(strength, duration)
    if ScreenFX.juice <= 0 then
        return
    end
    ScreenFX.desat = {
        strength = math.max(0, math.min((strength or 0.8) * ScreenFX.juice, 1)),
        duration = math.max(duration or 0.35, 0.01),
        elapsed = 0
    }
end

-- Advance effects on real time; return the dt the game should simulate with.
function ScreenFX.update(dt)
    dt = dt or 0

    for index = #ScreenFX.shakes, 1, -1 do
        local shake = ScreenFX.shakes[index]
        shake.elapsed = shake.elapsed + dt
        if shake.elapsed >= shake.duration then
            table.remove(ScreenFX.shakes, index)
        end
    end

    for index = #ScreenFX.flashes, 1, -1 do
        local flash = ScreenFX.flashes[index]
        flash.elapsed = flash.elapsed + dt
        if flash.elapsed >= flash.duration then
            table.remove(ScreenFX.flashes, index)
        end
    end

    if ScreenFX.desat then
        ScreenFX.desat.elapsed = ScreenFX.desat.elapsed + dt
        if ScreenFX.desat.elapsed >= ScreenFX.desat.duration then
            ScreenFX.desat = nil
        end
    end

    -- Shake offset is sampled once per frame so draw calls inside one frame agree.
    ScreenFX.shake_x, ScreenFX.shake_y = 0, 0
    for _, shake in ipairs(ScreenFX.shakes) do
        local falloff = 1 - (shake.elapsed / shake.duration)
        local amplitude = shake.magnitude * falloff * falloff
        ScreenFX.shake_x = ScreenFX.shake_x + random_unit() * amplitude
        ScreenFX.shake_y = ScreenFX.shake_y + random_unit() * amplitude
    end

    if ScreenFX.hitstop_remaining > 0 then
        ScreenFX.hitstop_remaining = math.max(0, ScreenFX.hitstop_remaining - dt)
        return 0
    end

    return dt
end

function ScreenFX.is_frozen()
    return ScreenFX.hitstop_remaining > 0
end

function ScreenFX.desaturation_amount()
    local desat = ScreenFX.desat
    if not desat then
        return 0
    end
    -- Sharp attack, smooth release.
    local t = desat.elapsed / desat.duration
    return desat.strength * (1 - t) * (1 - t)
end

function ScreenFX.begin_frame()
    local lg = graphics()
    if not lg then
        return
    end

    lg.push()
    -- Integer snap keeps the pixel grid honest at every camera scale.
    lg.translate(math.floor(ScreenFX.shake_x + 0.5), math.floor(ScreenFX.shake_y + 0.5))
end

function ScreenFX.end_frame()
    local lg = graphics()
    if not lg then
        return
    end

    lg.pop()

    for _, flash in ipairs(ScreenFX.flashes) do
        local t = flash.elapsed / flash.duration
        local alpha = flash.peak_alpha * (1 - t)
        lg.setColor(flash.color[1], flash.color[2], flash.color[3], alpha)
        local canvas = lg.getCanvas and lg.getCanvas()
        local width, height
        if canvas then
            width, height = canvas:getDimensions()
        else
            width, height = lg.getDimensions()
        end
        lg.rectangle("fill", 0, 0, width, height)
    end
    lg.setColor(1, 1, 1, 1)
end

-- Test/debug helper: drop all live effects without touching configuration.
function ScreenFX.reset()
    ScreenFX.hitstop_remaining = 0
    ScreenFX.shakes = {}
    ScreenFX.flashes = {}
    ScreenFX.desat = nil
    ScreenFX.shake_x, ScreenFX.shake_y = 0, 0
end

return ScreenFX
