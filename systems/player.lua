local Assets = require("core.assets")

local Player = {}
Player.__index = Player

function Player.new(x, y)
    local self = setmetatable({}, Player)
    self.x = x or 1
    self.y = y or 1
    self.render_x = self.x
    self.render_y = self.y
    self.facing = "down"
    self.move_duration = 0.14
    self.move_elapsed = 0
    self.move_from_x = self.x
    self.move_from_y = self.y
    self.move_to_x = self.x
    self.move_to_y = self.y
    self.moving = false
    self.inventory = {}
    self.equipped = nil
    return self
end

function Player:update(dt)
    if not self.moving then
        self.render_x = self.x
        self.render_y = self.y
        return
    end

    self.move_elapsed = math.min(self.move_duration, self.move_elapsed + (dt or 0))
    local t = self.move_elapsed / self.move_duration
    t = 1 - ((1 - t) * (1 - t))

    self.render_x = self.move_from_x + (self.move_to_x - self.move_from_x) * t
    self.render_y = self.move_from_y + (self.move_to_y - self.move_from_y) * t

    if self.move_elapsed >= self.move_duration then
        self.x = self.move_to_x
        self.y = self.move_to_y
        self.render_x = self.x
        self.render_y = self.y
        self.moving = false
    end
end

local function facing_for_delta(dx, dy)
    if dy < 0 then
        return "up"
    elseif dy > 0 then
        return "down"
    elseif dx < 0 then
        return "left"
    elseif dx > 0 then
        return "right"
    end

    return "down"
end

function Player:try_move(dx, dy, room)
    self.facing = facing_for_delta(dx, dy)

    if self.moving then
        return false
    end

    local new_x = self.x + dx
    local new_y = self.y + dy

    if room and room:is_blocked(new_x, new_y) then
        return false
    end

    self.move_from_x = self.x
    self.move_from_y = self.y
    self.move_to_x = new_x
    self.move_to_y = new_y
    self.move_elapsed = 0
    self.moving = true
    return true
end

function Player:front_tile()
    if self.facing == "up" then
        return self.x, self.y - 1
    elseif self.facing == "down" then
        return self.x, self.y + 1
    elseif self.facing == "left" then
        return self.x - 1, self.y
    elseif self.facing == "right" then
        return self.x + 1, self.y
    end

    return self.x, self.y
end

function Player:pixel_position(tile_size)
    local size = tile_size or 32
    return (self.render_x - 1) * size + size / 2,
        (self.render_y - 1) * size + size / 2
end

function Player:sort_y(tile_size)
    local size = tile_size or 32
    return (self.render_y - 1) * size + size
end

function Player:keypressed(key, room)
    if key == "up" then
        return self:try_move(0, -1, room)
    elseif key == "down" then
        return self:try_move(0, 1, room)
    elseif key == "left" then
        return self:try_move(-1, 0, room)
    elseif key == "right" then
        return self:try_move(1, 0, room)
    end

    return false
end

function Player:keyreleased(_)
end

function Player:addItem(item)
    if not item then
        return
    end

    self.inventory[item] = true
    if not self.equipped then
        self.equipped = item
    end
end

function Player:hasItem(item)
    return self.inventory[item] == true
end

function Player:draw(tile_size, camera)
    local size = tile_size or 32
    local sprite_id = "player_idle_" .. tostring(self.facing or "down")
    local image = Assets.images[sprite_id] or Assets.images.player_idle_down
    local draw_x = (self.render_x - 1) * size
    local draw_y = (self.render_y - 1) * size
    if camera and camera.snap_world then
        draw_x = camera:snap_world(draw_x)
        draw_y = camera:snap_world(draw_y)
    end

    if image then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(
            image,
            draw_x,
            draw_y,
            0,
            size / image:getWidth(),
            size / image:getHeight()
        )
        return
    end

    love.graphics.setColor(0.7, 0.7, 1)
    love.graphics.rectangle(
        "fill",
        draw_x + 8,
        draw_y + 8,
        16,
        16
    )
    love.graphics.setColor(1, 1, 1)
end

return Player
