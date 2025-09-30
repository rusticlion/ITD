local GameState = {
    current = nil
}

local function call(state, method, ...)
    if state and state[method] then
        state[method](state, ...)
    end
end

function GameState.switch(state, ...)
    if state == GameState.current then
        return
    end

    call(GameState.current, "exit")
    GameState.current = state
    call(GameState.current, "enter", ...)
end

function GameState.update(dt)
    call(GameState.current, "update", dt)
end

function GameState.draw()
    call(GameState.current, "draw")
end

function GameState.keypressed(key)
    call(GameState.current, "keypressed", key)
end

function GameState.keyreleased(key)
    call(GameState.current, "keyreleased", key)
end

return GameState
