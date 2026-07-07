local Assets = require("core.assets")
local Display = require("core.display")
local GameState = require("core.gamestate")
local Input = require("core.input")
local ScreenFX = require("core.screenfx")
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

local function launch_arg_value(prefix)
    local marker = prefix .. "="
    for _, value in ipairs(arg or {}) do
        if value:sub(1, #marker) == marker then
            return value:sub(#marker + 1)
        end
    end
    return nil
end

local function find_designer_scenario(scenario_id)
    if not scenario_id then
        return nil
    end

    local catalog = require("data.designer_scenarios")
    for _, group in ipairs({ "combat", "overworld" }) do
        for _, scenario in ipairs(catalog[group] or {}) do
            if scenario.id == scenario_id then
                return scenario, group
            end
        end
    end
    return nil
end

local function room_module_name(value)
    if not value or value:find(".", 1, true) then
        return value
    end
    return "data.rooms." .. value
end

local function spawn_player(value)
    local x, y = tostring(value or ""):match("^(%-?%d+),(%-?%d+)$")
    if x and y then
        return {
            x = tonumber(x),
            y = tonumber(y),
            facing = "down"
        }
    end
    return nil
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
    Display.load()
    Text.install(love.graphics)
    Assets:load()
    local encounter_id = launch_arg_value("--encounter")
    local seed = tonumber(launch_arg_value("--seed"))
    local scenario_id = launch_arg_value("--scenario") or launch_arg_value("--checkpoint")
    local scenario, scenario_group = find_designer_scenario(scenario_id)
    local room = launch_arg_value("--room")
    if scenario_id and not scenario then
        error("Unknown designer scenario: " .. tostring(scenario_id))
    elseif scenario and scenario_group == "combat" then
        GameState.switch(require("states.v2_combat"), {
            encounter_id = scenario.encounter_id,
            seed = seed or scenario.seed,
            combat_setup = scenario.combat_setup,
            designer_mode = true,
            designer_scenario_id = scenario.id,
            designer_scenario_name = scenario.name
        })
    elseif scenario and scenario_group == "overworld" then
        GameState.switch(require("states.designer_overworld"), {
            scenario = scenario
        })
    elseif room then
        GameState.switch(require("states.designer_overworld"), {
            scenario = {
                id = "room.direct",
                name = "Direct Room",
                room = room_module_name(room),
                player = spawn_player(launch_arg_value("--spawn")) or {
                    x = 5,
                    y = 5,
                    facing = "down"
                }
            }
        })
    elseif has_launch_arg("--designer-lab") then
        GameState.switch(require("states.designer_lab"))
    elseif has_launch_arg("--bp-editor") then
        GameState.switch(require("states.bp_editor"))
    elseif encounter_id or has_launch_arg("--v2-combat") then
        GameState.switch(require("states.v2_combat"), {
            encounter_id = encounter_id or "debug.demo",
            seed = seed
        })
    else
        GameState.switch(Overworld)
    end
end

function love.update(dt)
    -- ScreenFX advances on real time and returns the (possibly hit-stopped)
    -- dt the game simulates with.
    GameState.update(ScreenFX.update(dt))
    Input.update()
end

function love.draw()
    Display.begin_frame()
    ScreenFX.begin_frame()
    GameState.draw()
    ScreenFX.end_frame()
    Display.end_frame({
        desaturation = ScreenFX.desaturation_amount()
    })
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
    local logical_x, logical_y, inside = Display.window_to_logical(x, y)
    if inside then
        GameState.mousepressed(logical_x, logical_y, button, istouch, presses)
    end
end

function love.mousereleased(x, y, button, istouch, presses)
    -- Releases outside the presented canvas still need to cancel an active
    -- drag, so forward the transformed coordinates even when letterboxed.
    local logical_x, logical_y = Display.window_to_logical(x, y)
    GameState.mousereleased(logical_x, logical_y, button, istouch, presses)
end
