local Actor = require("systems.actor")
local Assets = require("core.assets")

local Registry = {
    definitions = {}
}

local TILE_SIZE = 32

local COLORS = {
    crack = { 0.08, 0.08, 0.09, 1 },
    pipe = { 0.3, 0.3, 0.4, 1 },
    shovel = { 0.62, 0.42, 0.2, 1 },
    message = { 0.36, 0.28, 0.42, 1 }
}

local function set_color(color)
    love.graphics.setColor(color)
end

local function sprite_property(actor, key)
    return actor.properties and actor.properties[key]
end

local function actor_sprite_candidates(actor, default_id)
    local explicit = sprite_property(actor, "asset_id")
        or sprite_property(actor, "sprite_id")
        or sprite_property(actor, "sprite")
    local candidates = {}
    local function add(id)
        if id then
            table.insert(candidates, id)
        end
    end

    if actor.state and actor.state.resolved then
        add(sprite_property(actor, "resolved_asset_id"))
        add(sprite_property(actor, "resolved_sprite_id"))
        if explicit then
            add(explicit .. "_resolved")
        end
        if default_id then
            add(default_id .. "_resolved")
        end
    end

    add(explicit)
    add(default_id)

    return candidates
end

local function draw_actor_sprite(actor, default_id)
    for _, id in ipairs(actor_sprite_candidates(actor, default_id)) do
        local image = id and Assets.images[id]
        if image then
            local x, y, w, h = actor:tile_rect(TILE_SIZE)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(image, x, y, 0, w / image:getWidth(), h / image:getHeight())
            return true
        end
    end

    return false
end

local function player_has_tool(player, tool)
    if not tool then
        return true
    end

    return player and (player.equipped == tool or (player.hasItem and player:hasItem(tool)))
end

local function bool_value(value, default)
    if value == nil then
        return default
    end
    return value == true or value == "true" or value == 1
end

local function nested_action(properties, key)
    properties = properties or {}
    local action = properties[key]

    if type(action) == "table" then
        return action
    elseif type(action) == "string" then
        return { type = action }
    end

    local prefix = key .. "."
    local nested = {}
    for prop_key, value in pairs(properties) do
        if type(prop_key) == "string" and prop_key:sub(1, #prefix) == prefix then
            nested[prop_key:sub(#prefix + 1)] = value
        end
    end

    if next(nested) then
        return nested
    end

    return nil
end

local function action_result(actor, action, fallback_message)
    action = action or {}
    local action_type = action.type or "message"
    local text = action.message or actor.properties.message or fallback_message

    if action_type == "encounter" or action_type == "start_encounter" then
        return {
            type = "encounter",
            encounter_id = action.encounter_id or actor.properties.encounter_id,
            text = text
        }
    elseif action_type == "passage" or action_type == "open_passage" then
        return {
            type = "passage",
            target_room = action.target_room or actor.properties.target_room,
            target_spawn = action.target_spawn or actor.properties.target_spawn,
            text = text
        }
    elseif action_type == "item" or action_type == "give_item" then
        return {
            type = "item",
            item = action.item or actor.properties.item,
            text = text
        }
    end

    return {
        type = "message",
        text = text or "There is nothing special here."
    }
end

local function tool_use_result(actor, player, defaults)
    defaults = defaults or {}

    if actor.state.resolved then
        return {
            type = "message",
            text = actor.properties.resolved_message
                or defaults.resolved_message
                or "There is nothing else to do here."
        }
    end

    local action = nested_action(actor.properties, "on_tool_use") or {}
    local required_tool = action.tool or defaults.tool
    if not player_has_tool(player, required_tool) then
        return {
            type = "message",
            text = actor.properties.missing_tool_message
                or defaults.missing_tool_message
                or "You need the right tool."
        }
    end

    if bool_value(action.once, defaults.once ~= false) then
        actor.state.resolved = true
    end

    return action_result(actor, action, defaults.message)
end

local function draw_pipe(actor)
    if draw_actor_sprite(actor, "actor_pipe") then
        return
    end

    local x, y = actor:tile_rect(TILE_SIZE)
    set_color(COLORS.pipe)
    love.graphics.rectangle("fill", x + 4, y + 8, 24, 16)

    if actor.properties.item and not actor.state.removed then
        set_color(COLORS.shovel)
        love.graphics.rectangle("fill", x + 10, y + 24, 12, 4)
    end
end

local function draw_crack(actor)
    if draw_actor_sprite(actor, "actor_crack") then
        return
    end

    local x, y = actor:tile_rect(TILE_SIZE)
    set_color(COLORS.crack)
    love.graphics.rectangle("fill", x + 12, y + 4, 8, 24)

    if actor.state.resolved then
        love.graphics.rectangle("fill", x + 7, y + 10, 18, 12)
    end
end

local function draw_message(actor)
    if draw_actor_sprite(actor, "actor_hidden_wall_marker") then
        return
    end

    local x, y = actor:tile_rect(TILE_SIZE)
    set_color(COLORS.message)
    love.graphics.rectangle("fill", x + 8, y + 8, 16, 16)
end

function Registry.register(actor_type, definition)
    Registry.definitions[actor_type] = definition
end

function Registry.has(actor_type)
    return Registry.definitions[actor_type] ~= nil
end

function Registry.apply(actor)
    local definition = Registry.definitions[actor.type]
    if not definition then
        return actor
    end

    if definition.configure then
        definition.configure(actor)
    end

    actor.draw_fn = definition.draw or actor.draw_fn
    actor.update_fn = definition.update or actor.update_fn
    actor.ambient_update_fn = definition.update_ambient or actor.ambient_update_fn
    actor.interact_fn = definition.interact or actor.interact_fn

    if definition.solid ~= nil and actor.properties.solid == nil then
        actor.solid = definition.solid
    end
    if definition.interactable ~= nil and actor.properties.interactable == nil then
        actor.interactable = definition.interactable
    end

    return actor
end

function Registry.create(data, room)
    local actor = Actor.new(data, room)
    return Registry.apply(actor)
end

Registry.register("pipe", {
    interactable = true,
    draw = draw_pipe,
    interact = function(actor)
        if actor.properties.item and not actor.state.removed then
            local item = actor.properties.item
            actor.state.removed = true
            return {
                type = "item",
                item = item,
                text = actor.properties.message or ("Found: " .. item .. "!")
            }
        end

        return {
            type = "message",
            text = actor.properties.empty_message or actor.properties.message or "An empty drainage pipe."
        }
    end
})

Registry.register("crack", {
    interactable = true,
    draw = draw_crack,
    interact = function(actor, world, player)
        return tool_use_result(actor, player, {
            tool = "shovel",
            once = true,
            message = "You dig through the wall.",
            missing_tool_message = "The crack is too narrow to fit through...",
            resolved_message = "The opening has already been dug."
        })
    end
})

Registry.register("message", {
    interactable = true,
    draw = draw_message,
    interact = function(actor)
        if actor.properties.dialog or actor.properties.dialog_id then
            return {
                type = "dialog",
                dialog = actor.properties.dialog,
                dialog_id = actor.properties.dialog_id,
                actor_id = actor.id
            }
        end

        return {
            type = "message",
            text = actor.properties.message or "There is nothing special here."
        }
    end
})

return Registry
