local Assets = require("core.assets")
local GameState = require("core.gamestate")
local Input = require("core.input")
local Overworld = require("states.overworld")
local Text = require("ui.text")

local function has_launch_arg(name)
    for _, value in ipairs(arg or {}) do
        if value == name then
            return true
        end
    end
    return false
end

local function dispatch_actionpressed(actions, source)
    local handled = false
    for _, action in ipairs(actions or {}) do
        handled = GameState.actionpressed(action, source) or handled
    end
    return handled
end

local function dispatch_actionreleased(actions, source)
    local handled = false
    for _, action in ipairs(actions or {}) do
        handled = GameState.actionreleased(action, source) or handled
    end
    return handled
end

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    Text.install(love.graphics)
    Assets:load()
    if has_launch_arg("--bp-editor") then
        GameState.switch(require("states.bp_editor"))
    elseif has_launch_arg("--v2-combat") then
        GameState.switch(require("states.v2_combat"))
    else
        GameState.switch(Overworld)
    end
end

function love.update(dt)
    GameState.update(dt)
    Input.update()
end

function love.draw()
    GameState.draw()
end

function love.keypressed(key)
    local handled = dispatch_actionpressed(Input.keypressed(key), { type = "key", key = key })
    if not handled then
        GameState.keypressed(key)
    end
end

function love.keyreleased(key)
    local handled = dispatch_actionreleased(Input.keyreleased(key), { type = "key", key = key })
    if not handled then
        GameState.keyreleased(key)
    end
end

function love.gamepadpressed(_, button)
    dispatch_actionpressed(Input.gamepadpressed(button), { type = "gamepad", button = button })
end

function love.gamepadreleased(_, button)
    dispatch_actionreleased(Input.gamepadreleased(button), { type = "gamepad", button = button })
end

function love.textinput(text)
    GameState.textinput(text)
end

function love.mousepressed(x, y, button, istouch, presses)
    GameState.mousepressed(x, y, button, istouch, presses)
end

function love.mousereleased(x, y, button, istouch, presses)
    GameState.mousereleased(x, y, button, istouch, presses)
end
