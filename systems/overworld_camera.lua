local Camera = {}
Camera.__index = Camera

Camera.DEFAULT_MODE = "standard"
Camera.MODE_ORDER = { "wide", "standard", "close" }
Camera.MODES = {
    wide = {
        scale = 0.5,
        tile_pixels = 16,
        color = { 0.35, 0.63, 1, 0.9 }
    },
    standard = {
        scale = 1,
        tile_pixels = 32,
        color = { 0.25, 0.88, 0.68, 0.9 }
    },
    close = {
        scale = 1.5,
        tile_pixels = 48,
        color = { 0.98, 0.39, 0.32, 0.9 }
    }
}

local function clamp(value, min_value, max_value)
    return math.max(min_value, math.min(max_value, value))
end

local function valid_mode(mode)
    return Camera.MODES[mode] ~= nil
end

local function snapped(value, scale)
    return math.floor(value * scale + 0.5) / scale
end

local function centered_axis(target, view_size, bounds_start, bounds_size)
    if bounds_size <= view_size then
        return bounds_start + (bounds_size - view_size) / 2
    end

    return clamp(
        target - view_size / 2,
        bounds_start,
        bounds_start + bounds_size - view_size)
end

function Camera.new(options)
    options = options or {}
    local mode = options.mode or Camera.DEFAULT_MODE
    assert(valid_mode(mode), "Unknown overworld camera mode: " .. tostring(mode))

    return setmetatable({
        x = 0,
        y = 0,
        mode = mode,
        room_mode = mode,
        debug_override_index = 1,
        show_guides = false,
        active_zone = nil,
        viewport_width = 960,
        viewport_height = 540
    }, Camera)
end

function Camera.is_valid_mode(mode)
    return valid_mode(mode)
end

function Camera:scale(mode)
    local definition = Camera.MODES[mode or self.mode] or Camera.MODES[Camera.DEFAULT_MODE]
    return definition.scale
end

function Camera:tile_pixels(mode)
    local definition = Camera.MODES[mode or self.mode] or Camera.MODES[Camera.DEFAULT_MODE]
    return definition.tile_pixels
end

function Camera:viewport_world_size(mode, width, height)
    local scale = self:scale(mode)
    return (width or self.viewport_width) / scale,
        (height or self.viewport_height) / scale
end

function Camera:mode_for_room(room, target_x, target_y)
    local room_mode = room and room.property and room:property("camera_zoom")
        or room and room.property and room:property("camera_mode")
        or Camera.DEFAULT_MODE
    if not valid_mode(room_mode) then
        room_mode = Camera.DEFAULT_MODE
    end

    self.room_mode = room_mode
    self.active_zone = room and room.camera_zone_at and room:camera_zone_at(target_x, target_y) or nil

    local zone_mode = self.active_zone and (
        self.active_zone:property("camera_zoom")
        or self.active_zone:property("camera_mode")
        or self.active_zone:property("zoom"))
    if valid_mode(zone_mode) then
        return zone_mode
    end

    return room_mode
end

function Camera:debug_override()
    return self.debug_override_index > 1
        and Camera.MODE_ORDER[self.debug_override_index - 1]
        or nil
end

function Camera:cycle_debug_override()
    self.debug_override_index = (self.debug_override_index % (#Camera.MODE_ORDER + 1)) + 1
    return self:debug_override()
end

function Camera:toggle_guides()
    self.show_guides = not self.show_guides
    return self.show_guides
end

function Camera:bounds_for_room(room)
    local map_width = (room and room.width or 0) * (room and room.tile_size or 32)
    local map_height = (room and room.height or 0) * (room and room.tile_size or 32)
    local zone = self.active_zone

    if zone and zone:property("camera_bounds") == true then
        return zone.x, zone.y, zone.width, zone.height
    end

    return 0, 0, map_width, map_height
end

function Camera:frame_for_mode(room, target_x, target_y, mode)
    local view_width, view_height = self:viewport_world_size(mode)
    local bounds_x, bounds_y, bounds_width, bounds_height = self:bounds_for_room(room)
    local scale = self:scale(mode)
    local x = snapped(centered_axis(target_x, view_width, bounds_x, bounds_width), scale)
    local y = snapped(centered_axis(target_y, view_height, bounds_y, bounds_height), scale)
    return x, y, view_width, view_height
end

function Camera:update(room, target_x, target_y, viewport_width, viewport_height)
    self.viewport_width = viewport_width or self.viewport_width
    self.viewport_height = viewport_height or self.viewport_height

    local authored_mode = self:mode_for_room(room, target_x, target_y)
    self.mode = self:debug_override() or authored_mode

    self.x, self.y = self:frame_for_mode(room, target_x, target_y, self.mode)
end

function Camera:snap_world(value)
    return snapped(value, self:scale())
end

function Camera:world_to_screen(x, y)
    local scale = self:scale()
    return (x - self.x) * scale, (y - self.y) * scale
end

function Camera:screen_to_world(x, y)
    local scale = self:scale()
    return x / scale + self.x, y / scale + self.y
end

function Camera:attach()
    love.graphics.push()
    love.graphics.scale(self:scale(), self:scale())
    love.graphics.translate(-self.x, -self.y)
end

function Camera:detach()
    love.graphics.pop()
end

function Camera:draw_world_guides(room, target_x, target_y)
    if not self.show_guides then
        return
    end

    local current_scale = self:scale()
    love.graphics.setLineWidth(1 / current_scale)

    for _, mode in ipairs(Camera.MODE_ORDER) do
        local x, y, width, height = self:frame_for_mode(room, target_x, target_y, mode)
        local color = Camera.MODES[mode].color
        love.graphics.setColor(color)
        love.graphics.rectangle("line", x, y, width, height)
    end

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function Camera:debug_label()
    local override = self:debug_override()
    if override then
        return string.format(
            "CAMERA %s (%dpx) [override]",
            override:upper(),
            self:tile_pixels(override))
    end

    return string.format(
        "CAMERA %s (%dpx)",
        tostring(self.mode):upper(),
        self:tile_pixels())
end

return Camera
