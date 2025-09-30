local GameState = require("core.gamestate")
local Overworld = require("states.overworld")

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    GameState.switch(Overworld)
end

function love.update(dt)
    GameState.update(dt)
end

function love.draw()
    GameState.draw()
end

function love.keypressed(key)
    GameState.keypressed(key)
end

function love.keyreleased(key)
    GameState.keyreleased(key)
end
