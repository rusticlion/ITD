local Assets = require("core.assets")
local GameState = require("core.gamestate")
local Overworld = require("states.overworld")

local function has_launch_arg(name)
    for _, value in ipairs(arg or {}) do
        if value == name then
            return true
        end
    end
    return false
end

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    Assets:load()
    if has_launch_arg("--v2-combat") then
        GameState.switch(require("states.v2_combat"))
    else
        GameState.switch(Overworld)
    end
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

function love.mousepressed(x, y, button, istouch, presses)
    GameState.mousepressed(x, y, button, istouch, presses)
end

function love.mousereleased(x, y, button, istouch, presses)
    GameState.mousereleased(x, y, button, istouch, presses)
end
