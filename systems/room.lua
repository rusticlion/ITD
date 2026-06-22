local ActorRegistry = require("systems.actor_registry")
local Assets = require("core.assets")

local Room = {}
Room.__index = Room

local DEFAULT_TILE_SIZE = 32
local GID_FLIPPED_HORIZONTALLY = 2147483648
local GID_FLIPPED_VERTICALLY = 1073741824
local GID_FLIPPED_DIAGONALLY = 536870912
local DRAWN_TILE_LAYERS = {
    ground = true,
    ground_detail = true,
    walls = true,
    objects_low = true,
    objects_high = true,
    effects = true
}
local KNOWN_LAYERS = {
    ground = true,
    ground_detail = true,
    walls = true,
    objects_low = true,
    actors = true,
    objects_high = true,
    effects = true,
    regions = true,
    collision = true
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

local function property_value(properties, key)
    if type(properties) ~= "table" then
        return nil
    end

    if properties[key] ~= nil then
        return properties[key]
    end

    for _, property in ipairs(properties) do
        if type(property) == "table" and property.name == key then
            return property.value
        end
    end

    return nil
end

local function basename_without_extension(path)
    if type(path) ~= "string" then
        return nil
    end

    local normalized = path:gsub("\\", "/")
    local basename = normalized:match("([^/]+)$") or normalized
    return basename:gsub("%.[^%.]+$", "")
end

local function tileset_asset_id(tileset)
    return tileset.asset_id
        or property_value(tileset.properties, "asset_id")
        or property_value(tileset.properties, "image_id")
        or basename_without_extension(tileset.image)
        or tileset.name
end

local function decoded_gid(raw_gid)
    local gid = tonumber(raw_gid) or 0
    local flags = {
        horizontal = false,
        vertical = false,
        diagonal = false
    }

    if gid >= GID_FLIPPED_HORIZONTALLY then
        flags.horizontal = true
        gid = gid - GID_FLIPPED_HORIZONTALLY
    end
    if gid >= GID_FLIPPED_VERTICALLY then
        flags.vertical = true
        gid = gid - GID_FLIPPED_VERTICALLY
    end
    if gid >= GID_FLIPPED_DIAGONALLY then
        flags.diagonal = true
        gid = gid - GID_FLIPPED_DIAGONALLY
    end

    return gid, flags
end

local function has_flip(flags)
    return flags.horizontal or flags.vertical or flags.diagonal
end

local function add_message(collection, message)
    collection[#collection + 1] = message
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

local function build_tileset(tileset)
    return {
        firstgid = tonumber(tileset.firstgid) or 1,
        name = tileset.name,
        image = tileset.image,
        image_id = tileset_asset_id(tileset),
        tilewidth = tonumber(tileset.tilewidth) or DEFAULT_TILE_SIZE,
        tileheight = tonumber(tileset.tileheight) or DEFAULT_TILE_SIZE,
        imagewidth = tonumber(tileset.imagewidth),
        imageheight = tonumber(tileset.imageheight),
        columns = tonumber(tileset.columns),
        tilecount = tonumber(tileset.tilecount),
        margin = tonumber(tileset.margin) or 0,
        spacing = tonumber(tileset.spacing) or 0,
        properties = tileset.properties or {},
        source = tileset,
        quads = {}
    }
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
        tilesets = {},
        actors = {},
        actor_by_id = {},
        world = world,
        state = world and world.room_states and world.room_states[data.id or data.name or "room"] or {}
    }

    setmetatable(room, Room)
    if world and world.room_states then
        world.room_states[room.id] = room.state
    end
    room:load_tilesets(data.tilesets or {})
    room:load_actors()
    room.validation = room:validate()
    room:print_validation()
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

function Room:load_tilesets(tilesets)
    self.tilesets = {}

    for _, tileset in ipairs(tilesets or {}) do
        table.insert(self.tilesets, build_tileset(tileset))
    end

    table.sort(self.tilesets, function(a, b)
        return a.firstgid < b.firstgid
    end)
end

function Room:tileset_for_gid(gid)
    gid = tonumber(gid) or 0
    local match

    for _, tileset in ipairs(self.tilesets or {}) do
        if gid >= tileset.firstgid then
            match = tileset
        else
            break
        end
    end

    if not match then
        return nil
    end

    if match.tilecount and gid >= match.firstgid + match.tilecount then
        return nil
    end

    return match
end

function Room:tileset_image(tileset)
    if not tileset then
        return nil
    end

    return tileset.image_id and Assets.images[tileset.image_id] or nil
end

function Room:quad_for_gid(tileset, gid)
    if not (tileset and love and love.graphics and love.graphics.newQuad) then
        return nil
    end

    local image = self:tileset_image(tileset)
    if not image then
        return nil
    end

    local local_id = (tonumber(gid) or 0) - tileset.firstgid
    if local_id < 0 then
        return nil
    end

    if tileset.quads[local_id] then
        return tileset.quads[local_id], image
    end

    local image_width = tileset.imagewidth or image:getWidth()
    local image_height = tileset.imageheight or image:getHeight()
    local tile_width = tileset.tilewidth
    local tile_height = tileset.tileheight
    local stride_x = tile_width + tileset.spacing
    local stride_y = tile_height + tileset.spacing
    local columns = tileset.columns
        or math.max(1, math.floor((image_width - tileset.margin * 2 + tileset.spacing) / stride_x))
    local tile_x = tileset.margin + (local_id % columns) * stride_x
    local tile_y = tileset.margin + math.floor(local_id / columns) * stride_y

    if tile_x + tile_width > image_width or tile_y + tile_height > image_height then
        return nil
    end

    local quad = love.graphics.newQuad(tile_x, tile_y, tile_width, tile_height, image_width, image_height)
    tileset.quads[local_id] = quad
    return quad, image
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

function Room:validate_tilesets(result)
    for _, tileset in ipairs(self.tilesets or {}) do
        if not tileset.image_id then
            add_message(result.warnings, string.format(
                "Tileset '%s' has no image or asset_id; its tiles will use fallback rectangles.",
                tileset.name or tostring(tileset.firstgid)))
        elseif not Assets.images[tileset.image_id] then
            add_message(result.warnings, string.format(
                "Tileset '%s' expects overworld asset '%s', but it is not loaded.",
                tileset.name or tostring(tileset.firstgid),
                tileset.image_id))
        end
    end
end

function Room:validate_layers(result)
    local seen = {}
    local warned_gid = {}
    local warned_diagonal = false
    local has_tilesets = #(self.tilesets or {}) > 0

    for _, layer in ipairs(self.layers or {}) do
        local name = layer.name or "(unnamed)"
        if seen[name] then
            add_message(result.errors, string.format("Layer '%s' is duplicated.", name))
        end
        seen[name] = true

        if not KNOWN_LAYERS[name] then
            add_message(result.warnings, string.format(
                "Layer '%s' is not in the documented overworld layer vocabulary.",
                name))
        end

        if layer.type == "tilelayer" then
            if not layer.data then
                add_message(result.warnings, string.format(
                    "Tile layer '%s' has no Lua tile data. Infinite/chunked maps are not supported yet.",
                    name))
            end

            if layer.width and tonumber(layer.width) ~= self.width then
                add_message(result.warnings, string.format(
                    "Tile layer '%s' width differs from room width.",
                    name))
            end
            if layer.height and tonumber(layer.height) ~= self.height then
                add_message(result.warnings, string.format(
                    "Tile layer '%s' height differs from room height.",
                    name))
            end

            if has_tilesets and layer.data then
                for y = 1, self.height do
                    for x = 1, self.width do
                        local raw_gid = layer_tile(layer, x, y, self.width)
                        local gid, flags = decoded_gid(raw_gid)
                        if gid ~= 0 then
                            if has_flip(flags) and flags.diagonal and not warned_diagonal then
                                add_message(result.warnings,
                                    "Diagonal tile flips are present; avoid them until diagonal rendering is implemented.")
                                warned_diagonal = true
                            end

                            if not self:tileset_for_gid(gid) and not warned_gid[gid] then
                                add_message(result.warnings, string.format(
                                    "Tile layer '%s' uses GID %s, but no loaded tileset owns it.",
                                    name,
                                    tostring(gid)))
                                warned_gid[gid] = true
                            end
                        end
                    end
                end
            end
        end
    end

    if not seen.ground then
        add_message(result.warnings, "Room has no 'ground' tile layer.")
    end
    if not seen.actors then
        add_message(result.warnings, "Room has no 'actors' object layer.")
    end
end

function Room:validate_actors(result)
    local seen = {}

    for _, actor in ipairs(self.actors or {}) do
        if seen[actor.id] then
            add_message(result.errors, string.format("Actor id '%s' is duplicated.", actor.id))
        end
        seen[actor.id] = true

        if actor.name == tostring(actor.id) and tonumber(actor.id) then
            add_message(result.warnings, string.format(
                "Actor '%s' is using Tiled's numeric object id. Give persistent actors stable names.",
                tostring(actor.id)))
        end

        if not ActorRegistry.has(actor.type) then
            add_message(result.warnings, string.format(
                "Actor '%s' has unknown type '%s'. It will have only base Actor behavior.",
                actor.id,
                tostring(actor.type)))
        end

        local explicit_sprite = actor.properties
            and (actor.properties.asset_id or actor.properties.sprite_id or actor.properties.sprite)
        if explicit_sprite and not Assets.images[explicit_sprite] then
            add_message(result.warnings, string.format(
                "Actor '%s' references missing sprite asset '%s'.",
                actor.id,
                tostring(explicit_sprite)))
        end
    end
end

function Room:validate()
    local result = {
        errors = {},
        warnings = {}
    }

    if self.width <= 0 or self.height <= 0 then
        add_message(result.errors, "Room width and height must both be greater than zero.")
    end

    if self.tile_size ~= DEFAULT_TILE_SIZE then
        add_message(result.warnings, string.format(
            "Room tile size is %s; current overworld runtime expects %s.",
            tostring(self.tile_size),
            tostring(DEFAULT_TILE_SIZE)))
    end

    self:validate_tilesets(result)
    self:validate_layers(result)
    self:validate_actors(result)

    return result
end

function Room:print_validation()
    if not self.validation then
        return
    end

    for _, message in ipairs(self.validation.errors or {}) do
        print(string.format("[Room:%s] ERROR: %s", self.id, message))
    end
    for _, message in ipairs(self.validation.warnings or {}) do
        print(string.format("[Room:%s] warning: %s", self.id, message))
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

function Room:draw_tile(layer, raw_gid, x, y)
    local gid, flags = decoded_gid(raw_gid)
    if gid == 0 then
        return true
    end

    local tileset = self:tileset_for_gid(gid)
    local quad, image = self:quad_for_gid(tileset, gid)
    if not (quad and image) then
        return false
    end

    local offset_x = tonumber(layer.offsetx) or 0
    local offset_y = tonumber(layer.offsety) or 0
    local draw_x = (x - 1) * self.tile_size + offset_x
    local draw_y = (y - 1) * self.tile_size + offset_y
    local scale_x = self.tile_size / tileset.tilewidth
    local scale_y = self.tile_size / tileset.tileheight

    if flags.horizontal then
        draw_x = draw_x + self.tile_size
        scale_x = -scale_x
    end
    if flags.vertical then
        draw_y = draw_y + self.tile_size
        scale_y = -scale_y
    end

    love.graphics.setColor(1, 1, 1, tonumber(layer.opacity) or 1)
    love.graphics.draw(image, quad, draw_x, draw_y, 0, scale_x, scale_y)
    return true
end

function Room:draw_fallback_tile(layer, x, y)
    local color = TILE_COLORS[layer.name] or TILE_COLORS.ground
    local opacity = tonumber(layer.opacity) or 1
    set_color({
        color[1],
        color[2],
        color[3],
        (color[4] or 1) * opacity
    })

    love.graphics.rectangle(
        "fill",
        (x - 1) * self.tile_size + (tonumber(layer.offsetx) or 0),
        (y - 1) * self.tile_size + (tonumber(layer.offsety) or 0),
        self.tile_size,
        self.tile_size
    )
end

function Room:draw_tile_layer(layer)
    if not layer or layer.visible == false or not DRAWN_TILE_LAYERS[layer.name] then
        return
    end

    for y = 1, self.height do
        for x = 1, self.width do
            local raw_gid = layer_tile(layer, x, y, self.width)
            if raw_gid ~= 0 and not self:draw_tile(layer, raw_gid, x, y) then
                self:draw_fallback_tile(layer, x, y)
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
