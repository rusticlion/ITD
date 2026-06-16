local Input = {}

local KEY_BINDINGS = {
    move_up = { "up", "w" },
    move_down = { "down", "s" },
    move_left = { "left", "a" },
    move_right = { "right", "d" },
    confirm = { "space", "return" },
    cancel = { "escape" },
    menu = { "tab" },
    debug_combat = { "c" }
}

local GAMEPAD_BINDINGS = {
    move_up = { "dpup" },
    move_down = { "dpdown" },
    move_left = { "dpleft" },
    move_right = { "dpright" },
    confirm = { "a" },
    cancel = { "b" },
    menu = { "start" }
}

local key_lookup = {}
local button_lookup = {}
local down_actions = {}
local pressed_actions = {}

local function add_binding(lookup, input_id, action)
    lookup[input_id] = lookup[input_id] or {}
    table.insert(lookup[input_id], action)
end

local function build_lookup(bindings, lookup)
    for action, inputs in pairs(bindings) do
        for _, input_id in ipairs(inputs) do
            add_binding(lookup, input_id, action)
        end
    end
end

local function copy_actions(actions)
    local copy = {}
    for _, action in ipairs(actions or {}) do
        table.insert(copy, action)
    end
    return copy
end

local function press_actions(actions)
    for _, action in ipairs(actions or {}) do
        down_actions[action] = true
        pressed_actions[action] = true
    end
    return copy_actions(actions)
end

local function release_actions(actions)
    for _, action in ipairs(actions or {}) do
        down_actions[action] = false
    end
    return copy_actions(actions)
end

build_lookup(KEY_BINDINGS, key_lookup)
build_lookup(GAMEPAD_BINDINGS, button_lookup)

function Input.actions_for_key(key)
    return copy_actions(key_lookup[key])
end

function Input.actions_for_button(button)
    return copy_actions(button_lookup[button])
end

function Input.action_for_key(key)
    local actions = key_lookup[key]
    return actions and actions[1] or nil
end

function Input.is_action(key, action)
    for _, existing in ipairs(key_lookup[key] or {}) do
        if existing == action then
            return true
        end
    end
    return false
end

function Input.keypressed(key)
    return press_actions(key_lookup[key])
end

function Input.keyreleased(key)
    return release_actions(key_lookup[key])
end

function Input.gamepadpressed(button)
    return press_actions(button_lookup[button])
end

function Input.gamepadreleased(button)
    return release_actions(button_lookup[button])
end

function Input.is_down(action)
    return down_actions[action] == true
end

function Input.was_pressed(action)
    return pressed_actions[action] == true
end

function Input.update()
    pressed_actions = {}
end

return Input
