local Actor = {}
Actor.__index = Actor

local DEFAULT_TILE_SIZE = 32

local function copy_table(source)
    local copy = {}
    for key, value in pairs(source or {}) do
        if type(value) == "table" then
            copy[key] = copy_table(value)
        else
            copy[key] = value
        end
    end
    return copy
end

local function normalize_properties(source)
    local properties = {}

    for key, value in pairs(source or {}) do
        if type(key) == "number" and type(value) == "table" and value.name then
            properties[value.name] = value.value
        elseif type(value) == "table" then
            properties[key] = copy_table(value)
        else
            properties[key] = value
        end
    end

    return properties
end

local function bool_value(value, default)
    if value == nil then
        return default
    end
    return value == true or value == "true" or value == 1
end

local function uses_pixel_coordinates(data, properties, room)
    if data.tile_x or data.tile_y or properties.tile_x or properties.tile_y then
        return false
    end

    if data.units == "pixels" or data.pixel_coordinates or properties.pixel_coordinates then
        return true
    end

    if data.gid or data.rotation or data.shape or data.polygon or data.polyline then
        return true
    end

    if type(data.id) == "number" and (data.x ~= nil or data.y ~= nil) then
        return true
    end

    local x = tonumber(data.x)
    local y = tonumber(data.y)
    if room and x and y and (x > (room.width or 0) or y > (room.height or 0)) then
        return true
    end

    return false
end

local function object_tile_position(data, tile_size, room, properties)
    if data.tile_x and data.tile_y then
        return tonumber(data.tile_x) or 1, tonumber(data.tile_y) or 1
    end

    if properties.tile_x and properties.tile_y then
        return tonumber(properties.tile_x) or 1, tonumber(properties.tile_y) or 1
    end

    local size = tile_size or DEFAULT_TILE_SIZE
    if uses_pixel_coordinates(data, properties, room) then
        return math.floor((tonumber(data.x) or 0) / size) + 1,
            math.floor((tonumber(data.y) or 0) / size) + 1
    end

    return tonumber(data.x) or 1, tonumber(data.y) or 1
end

function Actor.new(data, room)
    data = data or {}
    local properties = normalize_properties(data.properties or {})
    local actor_type = properties.actor_type or data.actor_type or data.type or "message"
    local x, y = object_tile_position(data, room and room.tile_size or DEFAULT_TILE_SIZE, room, properties)
    local id = tostring(properties.id or data.name or data.id or (actor_type .. "_" .. tostring(x) .. "_" .. tostring(y)))

    local actor = {
        id = id,
        name = data.name or id,
        type = actor_type,
        x = x,
        y = y,
        width = data.width,
        height = data.height,
        layer = data.layer or properties.layer or "actors",
        visible = bool_value(data.visible, true),
        solid = bool_value(properties.solid or data.solid, false),
        interactable = bool_value(properties.interactable or data.interactable, false),
        properties = properties,
        state = {},
        room = room
    }

    return setmetatable(actor, Actor)
end

function Actor:tile_rect(tile_size)
    local size = tile_size or DEFAULT_TILE_SIZE
    return (self.x - 1) * size, (self.y - 1) * size, size, size
end

function Actor:sort_y(tile_size)
    local size = tile_size or DEFAULT_TILE_SIZE
    return (self.y - 1) * size + size
end

function Actor:update(world, dt)
    if self.update_fn then
        self:update_fn(world, dt)
    end
end

function Actor:update_ambient(world, dt)
    if self.ambient_update_fn then
        self:ambient_update_fn(world, dt)
    end
end

function Actor:draw(world)
    if self.visible == false then
        return
    end

    if self.draw_fn then
        self:draw_fn(world)
    end
end

function Actor:interact(world, player)
    if self.interact_fn then
        return self:interact_fn(world, player)
    end

    local message = self.properties and self.properties.message
    if message then
        return { type = "message", text = message }
    end

    return nil
end

return Actor
