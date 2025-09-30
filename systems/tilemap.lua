local TileMap = {}
TileMap.__index = TileMap

local TILE_SIZE = 32

local Entity = require("systems.entity")

local function create_entities(room_data)
    local entities = {}
    for _, entity in ipairs(room_data.entities or {}) do
        entities[#entities + 1] = Entity.new(entity)
    end
    return entities
end

function TileMap.new(room_module)
    local room_data = require(room_module)

    local map = {
        width = room_data.width or 0,
        height = room_data.height or 0,
        tiles = room_data.tiles or {},
        entities = create_entities(room_data),
        tile_size = TILE_SIZE
    }

    return setmetatable(map, TileMap)
end

function TileMap:isSolid(x, y)
    if x < 1 or y < 1 or x > self.width or y > self.height then
        return true
    end

    local row = self.tiles[y]
    if not row then
        return true
    end

    return row[x] ~= 0
end

function TileMap:getEntityAt(x, y)
    for _, entity in ipairs(self.entities) do
        if entity.x == x and entity.y == y then
            return entity
        end
    end
    return nil
end

function TileMap:draw()
    for y = 1, self.height do
        local row = self.tiles[y]
        for x = 1, self.width do
            local tile = row and row[x] or 1
            if tile == 1 then
                love.graphics.setColor(0.4, 0.3, 0.3)
            else
                love.graphics.setColor(0.2, 0.2, 0.2)
            end

            love.graphics.rectangle(
                "fill",
                (x - 1) * self.tile_size,
                (y - 1) * self.tile_size,
                self.tile_size,
                self.tile_size
            )
        end
    end

    for _, entity in ipairs(self.entities) do
        entity:draw()
    end

    love.graphics.setColor(1, 1, 1)
end

return TileMap
