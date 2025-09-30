local Overworld = {}
Overworld.__index = Overworld

local Player = require("systems.player")
local TileMap = require("systems.tilemap")

function Overworld:enter()
    self.player = Player.new(5, 5)
    self.map = TileMap.new("data.rooms.basement_1")
end

function Overworld:update(dt)
    self.player:update(dt, self.map)
end

function Overworld:draw()
    self.map:draw()
    self.player:draw()

    if self.player.equipped then
        love.graphics.print("[" .. self.player.equipped .. "]", 10, 10)
    end
end

function Overworld:keypressed(key)
    if key == "space" then
        local entity = self.map:getEntityAt(self.player.x, self.player.y)
        if entity then
            local action, param = entity:interact(self.player)

            if action == "message" then
                print(param)
            elseif action == "item" then
                self.player:addItem(param)
                print("Found: " .. param .. "!")
            elseif action == "dig" then
                print("You dig through the wall...")
            end
        end
    else
        self.player:keypressed(key, self.map)
    end
end

function Overworld:keyreleased(key)
    self.player:keyreleased(key)
end

return Overworld
