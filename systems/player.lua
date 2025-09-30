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
