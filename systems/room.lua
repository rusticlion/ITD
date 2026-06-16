local ActorRegistry = require("systems.actor_registry")

local Room = {}
Room.__index = Room

local DEFAULT_TILE_SIZE = 32
local DRAWN_TILE_LAYERS = {
    ground = true,
    ground_detail = true,
    walls = true,
    objects_low = true,
    objects_high = true,
    effects = true
}

local TILE_COLORS = {
    ground = { 0.18, 0.17, 0.18, 1 },
    ground_detail = { 0.24, 0.2, 0.2, 1 },
    walls = { 0.4, 0.3, 0.3, 1 },
    objects_low = { 0.28, 0.24, 0.28, 1 },
    objects_high = { 0.24, 0.21, 0.25, 1 },
    effects = { 0.42, 0.28, 0.46, 0.5 }
}

local function require_if_needed(room_source)
    if type(room_source) == "string" then
        return require(room_source)
    end
    return room_source or {}
end

local function normalize_legacy_room(data)
    if data.layers then
        return data
    end

    return {
        id = data.id or "legacy_room",
        width = data.width,
        height = data.height,
        tilewidth = data.tile_size or DEFAULT_TILE_SIZE,
        tileheight = data.tile_size or DEFAULT_TILE_SIZE,
        layers = {
            {
                name = "ground",
                type = "tilelayer",
                data = data.tiles
            },
            {
                name = "collision",
                type = "tilelayer",
                visible = false,
                data = data.tiles
            },
            {
                name = "actors",
                type = "objectgroup",
                objects = data.entities or {}
            }
        }
    }
end

local function layer_tile(layer, x, y, width)
    if not layer or not layer.data then
        return 0
    end

    local row = layer.data[y]
    if type(row) == "table" then
        return row[x] or 0
    end

    return layer.data[(y - 1) * width + x] or 0
end

local function set_color(color)
    love.graphics.setColor(color)
end

function Room.new(room_source, world)
    local data = normalize_legacy_room(require_if_needed(room_source))
    local room = {
        id = data.id or data.name or "room",
        width = data.width or 0,
        height = data.height or 0,
        tile_size = data.tilewidth or data.tileheight or data.tile_size or DEFAULT_TILE_SIZE,
        properties = data.properties or {},
        layers = data.layers or {},
        actors = {},
        actor_by_id = {},
        world = world,
        state = world and world.room_states and world.room_states[data.id or data.name or "room"] or {}
    }

    setmetatable(room, Room)
    if world and world.room_states then
        world.room_states[room.id] = room.state
    end
    room:load_actors()
    return room
end

function Room:layer(name)
    for _, layer in ipairs(self.layers or {}) do
        if layer.name == name then
            return layer
        end
    end
    return nil
end

function Room:tile_at(layer_name, x, y)
    return layer_tile(self:layer(layer_name), x, y, self.width)
end

function Room:is_tile_solid(x, y)
    if x < 1 or y < 1 or x > self.width or y > self.height then
        return true
    end

    local collision = self:layer("collision")
    if collision then
        return self:tile_at("collision", x, y) ~= 0
    end

    return self:tile_at("walls", x, y) ~= 0
end

function Room:is_blocked(x, y)
    if self:is_tile_solid(x, y) then
        return true
    end

    for _, actor in ipairs(self.actors or {}) do
        if actor.solid and actor.x == x and actor.y == y and actor.visible ~= false then
            return true
        end
    end

    return false
end

function Room:load_actors()
    for _, layer in ipairs(self.layers or {}) do
        if layer.type == "objectgroup" and layer.name == "actors" then
            for _, object in ipairs(layer.objects or {}) do
                local actor = ActorRegistry.create(object, self)
                self:add_actor(actor)
            end
        end
    end
end

function Room:add_actor(actor)
    self.state[actor.id] = self.state[actor.id] or actor.state or {}
    actor.state = self.state[actor.id]
    table.insert(self.actors, actor)
    self.actor_by_id[actor.id] = actor
end

function Room:actor_at(x, y, predicate)
    for index = #(self.actors or {}), 1, -1 do
        local actor = self.actors[index]
        if actor.x == x and actor.y == y and actor.visible ~= false then
            if not predicate or predicate(actor) then
                return actor
            end
        end
    end

    return nil
end

function Room:interactable_at(x, y)
    return self:actor_at(x, y, function(actor)
        return actor.interactable == true
    end)
end

function Room:update(world, dt)
    for _, actor in ipairs(self.actors or {}) do
        actor:update(world, dt)
    end
end

function Room:update_ambient(world, dt)
    for _, actor in ipairs(self.actors or {}) do
        actor:update_ambient(world, dt)
    end
end

function Room:draw_tile_layer(layer)
    if not layer or layer.visible == false or not DRAWN_TILE_LAYERS[layer.name] then
        return
    end

    local color = TILE_COLORS[layer.name] or TILE_COLORS.ground
    set_color(color)

    for y = 1, self.height do
        for x = 1, self.width do
            if layer_tile(layer, x, y, self.width) ~= 0 then
                love.graphics.rectangle(
                    "fill",
                    (x - 1) * self.tile_size,
                    (y - 1) * self.tile_size,
                    self.tile_size,
                    self.tile_size
                )
            end
        end
    end
end

function Room:draw_actor_band(world, include_player)
    local drawables = {}

    for _, actor in ipairs(self.actors or {}) do
        if actor.layer == "actors" and actor.visible ~= false then
            table.insert(drawables, {
                sort_y = actor:sort_y(self.tile_size),
                draw = function()
                    actor:draw(world)
                end
            })
        end
    end

    if include_player and world and world.player then
        table.insert(drawables, {
            sort_y = world.player:sort_y(self.tile_size),
            draw = function()
                world.player:draw(self.tile_size)
            end
        })
    end

    table.sort(drawables, function(a, b)
        return a.sort_y < b.sort_y
    end)

    for _, drawable in ipairs(drawables) do
        drawable.draw()
    end
end

function Room:draw(world)
    self:draw_tile_layer(self:layer("ground"))
    self:draw_tile_layer(self:layer("ground_detail"))
    self:draw_tile_layer(self:layer("walls"))
    self:draw_tile_layer(self:layer("objects_low"))
    self:draw_actor_band(world, true)
    self:draw_tile_layer(self:layer("objects_high"))
    self:draw_tile_layer(self:layer("effects"))
    love.graphics.setColor(1, 1, 1, 1)
end

return Room
