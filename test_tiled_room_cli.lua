love = {
    graphics = {}
}

local draw_calls = {}
local rectangles = {}
local quads = {}

function love.graphics.setColor(...)
end

function love.graphics.newQuad(x, y, width, height, image_width, image_height)
    local quad = {
        x = x,
        y = y,
        width = width,
        height = height,
        image_width = image_width,
        image_height = image_height
    }
    table.insert(quads, quad)
    return quad
end

function love.graphics.draw(image, quad, x, y, rotation, scale_x, scale_y)
    table.insert(draw_calls, {
        image = image,
        quad = quad,
        x = x,
        y = y,
        rotation = rotation,
        scale_x = scale_x,
        scale_y = scale_y
    })
end

function love.graphics.rectangle(...)
    table.insert(rectangles, { ... })
end

local function fake_image(width, height)
    return {
        getWidth = function()
            return width
        end,
        getHeight = function()
            return height
        end
    }
end

local Assets = require("core.assets")
Assets.images = {
    basement_tiles = fake_image(64, 32),
    actor_pipe = fake_image(32, 32),
    actor_pipe_shovel = fake_image(32, 32),
    player_idle_down = fake_image(32, 32),
    player_walk_right2 = fake_image(32, 32),
    player_walk_right3 = fake_image(32, 32)
}

local Player = require("systems.player")
local Room = require("systems.room")

local room = Room.new({
    id = "tiled_test",
    width = 2,
    height = 2,
    tilewidth = 32,
    tileheight = 32,
    tilesets = {
        {
            firstgid = 1,
            name = "basement",
            image = "../overworld/basement_tiles.png",
            imagewidth = 64,
            imageheight = 32,
            tilewidth = 32,
            tileheight = 32,
            tilecount = 2,
            columns = 2
        }
    },
    layers = {
        {
            name = "ground",
            type = "tilelayer",
            width = 2,
            height = 2,
            data = {
                1, 2147483650,
                0, 1
            }
        },
        {
            name = "collision",
            type = "tilelayer",
            visible = false,
            width = 2,
            height = 2,
            data = {
                0, 1,
                0, 0
            }
        },
        {
            name = "actors",
            type = "objectgroup",
            objects = {
                {
                    id = 7,
                    name = "pipe_spawn",
                    type = "pipe",
                    x = 32,
                    y = 32,
                    width = 32,
                    height = 32,
                    properties = {
                        { name = "item", value = "shovel" }
                    }
                }
            }
        },
        {
            name = "regions",
            type = "objectgroup",
            objects = {
                {
                    id = 8,
                    name = "close_room",
                    type = "camera_zone",
                    x = 0,
                    y = 0,
                    width = 64,
                    height = 32,
                    properties = {
                        { name = "camera_zoom", value = "close" },
                        { name = "camera_bounds", value = true }
                    }
                }
            }
        }
    }
}, { room_states = {} })

assert(#room.validation.errors == 0, "expected no Tiled validation errors")
assert(#room.validation.warnings == 0, "expected no Tiled validation warnings")
assert(room:tile_at("ground", 2, 1) == 2147483650, "expected raw GID lookup")
assert(room:is_tile_solid(2, 1) == true, "expected collision layer to drive solidity")

local actor = room.actor_by_id.pipe_spawn
assert(actor, "expected named Tiled actor")
assert(actor.x == 2 and actor.y == 2, "expected Tiled pixel coordinates to convert to tile coordinates")
assert(actor:tile_rect(32) == 32, "expected actor world x")

local near_grid_actor = require("systems.actor").new({
    id = 9,
    name = "near_grid",
    type = "message",
    x = 63.99,
    y = 31.99,
    width = 32,
    height = 32
}, room)
assert(near_grid_actor.x == 3 and near_grid_actor.y == 2,
    "expected near-grid Tiled coordinates to snap to the intended tile")

local camera_zone = room:camera_zone_at(16, 16)
assert(camera_zone and camera_zone.id == "close_room", "expected camera zone lookup")
assert(camera_zone:property("camera_zoom") == "close", "expected camera zone mode")
assert(camera_zone:property("camera_bounds") == true, "expected camera zone bounds flag")
local region_x, region_y = room:region_center("close_room", "camera_zone")
assert(region_x == 32 and region_y == 16, "expected exact region center lookup")

room:draw_tile_layer(room:layer("ground"))
assert(#draw_calls == 3, "expected three tile draw calls")
assert(#rectangles == 0, "expected tileset-backed drawing to avoid fallback rectangles")
assert(draw_calls[2].quad.x == 32 and draw_calls[2].quad.y == 0, "expected second tile quad")
assert(draw_calls[2].x == 64 and draw_calls[2].scale_x == -1, "expected horizontal GID flip")

draw_calls = {}
actor:draw({})
assert(#draw_calls == 1, "expected actor sprite draw")
assert(draw_calls[1].image == Assets.images.actor_pipe_shovel, "expected actor sprite asset")

draw_calls = {}
actor.state.removed = true
actor:draw({})
assert(#draw_calls == 1, "expected removed actor sprite draw")
assert(draw_calls[1].image == Assets.images.actor_pipe,
    "expected removed pipe item to use empty pipe sprite")

draw_calls = {}
local player = Player.new(1, 1)
player:draw(32)
assert(#draw_calls == 1, "expected player sprite draw")
assert(draw_calls[1].image == Assets.images.player_idle_down, "expected player idle sprite asset")

draw_calls = {}
player:press_direction("move_right", 1, 0)
player:update(0.11, {
    is_blocked = function()
        return false
    end
})
player:draw(32)
assert(#draw_calls == 1, "expected moving player sprite draw")
assert(draw_calls[1].image == Assets.images.player_walk_right2, "expected step pose before translation")

draw_calls = {}
player:update(0.11, {
    is_blocked = function()
        return false
    end
})
player:draw(32)
assert(draw_calls[1].image == Assets.images.player_walk_right3,
    "expected still pose during the end of translation")

print("tiled room smoke test passed.")
