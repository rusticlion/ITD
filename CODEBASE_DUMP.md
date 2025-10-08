# Codebase Dump: ITD

_Generated on 2025-09-30 21:45 UTC_

## AGENTS.md

```markdown
Start by reviewing the documentation in /docs for context on your task - you will be directed to the most relevant documentation. You may be directed to find details for your task in /docs/tickets, otherwise proceed based on the contents of the request.

Review any relevant code before implementation, then proceed to implement the requested features in Lua/LOVE2D.
```

## conf.lua

```lua
function love.conf(t)
    t.window.title = "Into the Dreamlands"
    t.window.width = 800
    t.window.height = 608
    t.console = true
end

```

## core/gamestate.lua

```lua
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

```

## data/rooms/basement_1.lua

```lua
return {
    width = 10,
    height = 8,
    tiles = {
        {1,1,1,1,1,1,1,1,1,1},
        {1,0,0,0,0,0,0,0,0,1},
        {1,0,0,0,0,0,0,0,0,1},
        {1,0,0,0,0,0,0,0,0,1},
        {1,0,0,0,0,0,0,0,0,1},
        {1,0,0,0,0,0,0,0,0,1},
        {1,0,0,0,0,0,0,0,0,1},
        {1,1,1,1,1,1,1,1,1,1}
    },
    entities = {
        {type = "crack", x = 2, y = 2},
        {type = "crack", x = 9, y = 4},
        {type = "crack", x = 5, y = 7},
        {type = "pipe", x = 3, y = 2, has_shovel = true}
    }
}

```

## main.lua

```lua
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

```

## states/overworld.lua

```lua
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

```

## systems/entity.lua

```lua
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

```

## systems/player.lua

```lua
local Player = {}
Player.__index = Player

function Player.new(x, y)
    local self = setmetatable({}, Player)
    self.x = x or 1
    self.y = y or 1
    self.move_timer = 0
    self.move_delay = 0.15
    self.inventory = {}
    self.equipped = nil
    return self
end

function Player:update(dt)
    self.move_timer = math.max(0, self.move_timer - dt)
end

local function attempt_move(self, dx, dy, map)
    local new_x = self.x + dx
    local new_y = self.y + dy

    if not map:isSolid(new_x, new_y) then
        self.x = new_x
        self.y = new_y
        self.move_timer = self.move_delay
    end
end

function Player:keypressed(key, map)
    if self.move_timer > 0 then
        return
    end

    if key == "up" then
        attempt_move(self, 0, -1, map)
    elseif key == "down" then
        attempt_move(self, 0, 1, map)
    elseif key == "left" then
        attempt_move(self, -1, 0, map)
    elseif key == "right" then
        attempt_move(self, 1, 0, map)
    end
end

function Player:keyreleased(_)
end

function Player:addItem(item)
    self.inventory[item] = true
    if not self.equipped then
        self.equipped = item
    end
end

function Player:hasItem(item)
    return self.inventory[item] == true
end

function Player:draw()
    love.graphics.setColor(0.7, 0.7, 1)
    love.graphics.rectangle(
        "fill",
        (self.x - 1) * 32 + 8,
        (self.y - 1) * 32 + 8,
        16,
        16
    )
    love.graphics.setColor(1, 1, 1)
end

return Player

```

## systems/tilemap.lua

```lua
local TileMap = {}
TileMap.__index = TileMap

local TILE_SIZE = 32

local Entity = require("systems.entity")

local function create_entities(room_data)
    local entities = {}
    for _, entity in ipairs(room_data.entities or {}) do
        entities[#entities + 1] = Entity.new(entity)
    end
    return entities
end

function TileMap.new(room_module)
    local room_data = require(room_module)

    local map = {
        width = room_data.width or 0,
        height = room_data.height or 0,
        tiles = room_data.tiles or {},
        entities = create_entities(room_data),
        tile_size = TILE_SIZE
    }

    return setmetatable(map, TileMap)
end

function TileMap:isSolid(x, y)
    if x < 1 or y < 1 or x > self.width or y > self.height then
        return true
    end

    local row = self.tiles[y]
    if not row then
        return true
    end

    return row[x] ~= 0
end

function TileMap:getEntityAt(x, y)
    for _, entity in ipairs(self.entities) do
        if entity.x == x and entity.y == y then
            return entity
        end
    end
    return nil
end

function TileMap:draw()
    for y = 1, self.height do
        local row = self.tiles[y]
        for x = 1, self.width do
            local tile = row and row[x] or 1
            if tile == 1 then
                love.graphics.setColor(0.4, 0.3, 0.3)
            else
                love.graphics.setColor(0.2, 0.2, 0.2)
            end

            love.graphics.rectangle(
                "fill",
                (x - 1) * self.tile_size,
                (y - 1) * self.tile_size,
                self.tile_size,
                self.tile_size
            )
        end
    end

    for _, entity in ipairs(self.entities) do
        entity:draw()
    end

    love.graphics.setColor(1, 1, 1)
end

return TileMap

```

