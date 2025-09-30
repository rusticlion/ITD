local Entity = {}
Entity.__index = Entity

local TILE_SIZE = 32

function Entity.new(data)
    local self = setmetatable({}, Entity)
    self.type = data.type
    self.x = data.x
    self.y = data.y

    for k, v in pairs(data) do
        if k ~= "type" and k ~= "x" and k ~= "y" then
            self[k] = v
        end
    end

    return self
end

function Entity:draw()
    if self.type == "crack" then
        love.graphics.setColor(0.1, 0.1, 0.1)
        love.graphics.rectangle(
            "fill",
            (self.x - 1) * TILE_SIZE + 12,
            (self.y - 1) * TILE_SIZE + 4,
            8,
            24
        )
    elseif self.type == "pipe" then
        love.graphics.setColor(0.3, 0.3, 0.4)
        love.graphics.rectangle(
            "fill",
            (self.x - 1) * TILE_SIZE + 4,
            (self.y - 1) * TILE_SIZE + 8,
            24,
            16
        )
        if self.has_shovel then
            love.graphics.setColor(0.6, 0.4, 0.2)
            love.graphics.rectangle(
                "fill",
                (self.x - 1) * TILE_SIZE + 10,
                (self.y - 1) * TILE_SIZE + 24,
                12,
                4
            )
        end
    end

    love.graphics.setColor(1, 1, 1)
end

function Entity:interact(player)
    if self.type == "crack" then
        if player.equipped == "shovel" then
            return "dig"
        else
            return "message", "The crack is too narrow to fit through..."
        end
    elseif self.type == "pipe" then
        if self.has_shovel then
            self.has_shovel = false
            return "item", "shovel"
        else
            return "message", "An empty drainage pipe."
        end
    end
end

return Entity
