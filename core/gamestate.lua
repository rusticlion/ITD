local GameState = {
    current = nil,
    stack = {}
}

local function call(state, method, ...)
    if state and state[method] then
        return state[method](state, ...)
    end
end

local function refresh_current()
    GameState.current = GameState.stack[#GameState.stack]
    return GameState.current
end

local function exit_stack()
    for index = #GameState.stack, 1, -1 do
        call(GameState.stack[index], "exit")
        GameState.stack[index] = nil
    end
    refresh_current()
end

function GameState.switch(state, ...)
    if state == GameState.current and #GameState.stack == 1 then
        return
    end

    exit_stack()

    if state then
        table.insert(GameState.stack, state)
        refresh_current()
        call(GameState.current, "enter", ...)
    end
end

function GameState.push(state, ...)
    if not state then
        return
    end

    local previous = GameState.current
    call(previous, "pause", state)
    table.insert(GameState.stack, state)
    refresh_current()
    call(state, "enter", ...)
end

function GameState.pop(...)
    local previous = GameState.current
    if not previous then
        return nil
    end

    call(previous, "exit", ...)
    table.remove(GameState.stack)
    local current = refresh_current()
    call(current, "resume", previous, ...)
    return previous
end

function GameState.replace(state, ...)
    local previous = GameState.current
    if previous then
        call(previous, "exit")
        table.remove(GameState.stack)
    end

    if state then
        table.insert(GameState.stack, state)
    end

    refresh_current()
    call(GameState.current, "enter", ...)
end

function GameState.peek(depth)
    local offset = depth or 0
    return GameState.stack[#GameState.stack - offset]
end

function GameState.size()
    return #GameState.stack
end

function GameState.clear()
    exit_stack()
end

function GameState.update(dt)
    call(GameState.current, "update", dt)
end

function GameState.draw()
    local start_index = 1
    for index = #GameState.stack, 1, -1 do
        if GameState.stack[index] and GameState.stack[index].opaque then
            start_index = index
            break
        end
    end

    for index = start_index, #GameState.stack do
        call(GameState.stack[index], "draw")
    end
end

function GameState.keypressed(key)
    call(GameState.current, "keypressed", key)
end

function GameState.keyreleased(key)
    call(GameState.current, "keyreleased", key)
end

function GameState.actionpressed(action, source)
    return call(GameState.current, "actionpressed", action, source)
end

function GameState.actionreleased(action, source)
    return call(GameState.current, "actionreleased", action, source)
end

function GameState.textinput(text)
    call(GameState.current, "textinput", text)
end

function GameState.mousepressed(x, y, button, istouch, presses)
    call(GameState.current, "mousepressed", x, y, button, istouch, presses)
end

function GameState.mousereleased(x, y, button, istouch, presses)
    call(GameState.current, "mousereleased", x, y, button, istouch, presses)
end

return GameState
