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
end

function Overworld:keypressed(key)
    self.player:keypressed(key, self.map)
end

function Overworld:keyreleased(key)
    self.player:keyreleased(key)
end

return Overworld
