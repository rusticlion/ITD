local GameState = require("core.gamestate")
local World = require("systems.world")

local DesignerOverworld = {}
DesignerOverworld.__index = DesignerOverworld
DesignerOverworld.opaque = true

local FLAG_KEYS = {
    [4] = "basement.passage_open",
    [5] = "basement.lights_on",
    [6] = "basement.key_found",
    [7] = "basement.boss_door_unlocked"
}

local function copy_table(source)
    if type(source) ~= "table" then
        return source
    end

    local copy = {}
    for key, value in pairs(source) do
        copy[key] = copy_table(value)
    end
    return copy
end

local function scenario_run(scenario)
    return {
        current_room = scenario.room,
        flags = copy_table(scenario.flags or {}),
        encounters = copy_table(scenario.encounters or {}),
        player = copy_table(scenario.player or {})
    }
end

function DesignerOverworld:enter(context)
    self.scenario = context and context.scenario or {}
    local player = self.scenario.player or {}
    self.world = World.new({
        room = self.scenario.room,
        player_x = player.x,
        player_y = player.y,
        spawn = self.scenario.spawn,
        player = player,
        run = scenario_run(self.scenario),
        flags = self.scenario.flags,
        room_states = self.scenario.room_states,
        autosave = false
    })
    self.world.debug_overlay = true
    self.world.on_encounter = function(encounter)
        GameState.push(require("states.v2_combat"), {
            encounter_id = encounter and encounter.encounter_id,
            encounter = encounter,
            run = self.world.run,
            designer_mode = true,
            seed = self.seed or 4401
        })
    end
    self.world.on_dialog = function(dialog)
        GameState.push(require("states.dialog"), {
            world = self.world,
            dialog = dialog and dialog.dialog,
            dialog_id = dialog and dialog.dialog_id,
            actor = dialog and self.world.room and self.world.room.actor_by_id[dialog.actor_id]
        })
    end
end

function DesignerOverworld:resume(_, result)
    if result and result.type == "combat_result" then
        self.last_summary = result.playtest_summary
        self.world:apply_combat_result(result)
    elseif result and result.type == "dialog_result" then
        self.world:apply_dialog_result(result)
    end
end

function DesignerOverworld:pause()
    if self.world and self.world.player then
        self.world.player:clear_direction_input()
    end
end

function DesignerOverworld:update(dt)
    self.world:update(dt)
end

function DesignerOverworld:draw()
    self.world:draw()

    local width = love.graphics.getWidth()
    local actor_count = math.min(8, #(self.world.room and self.world.room.actors or {}))
    local region_count = math.min(4, #(self.world.room and self.world.room.regions or {}))
    local panel_w = 334
    local panel_h = 154 + actor_count * 15 + region_count * 15
    local x = width - panel_w - 12
    local y = 12
    love.graphics.setColor(0.035, 0.04, 0.06, 0.92)
    love.graphics.rectangle("fill", x, y, panel_w, panel_h, 4, 4)
    love.graphics.setColor(0.66, 0.68, 0.78, 0.8)
    love.graphics.rectangle("line", x, y, panel_w, panel_h, 4, 4)
    love.graphics.setColor(0.96, 0.95, 1, 1)
    love.graphics.print(self.scenario.name or "Designer Checkpoint", x + 10, y + 9)
    love.graphics.setColor(0.72, 0.71, 0.8, 1)
    love.graphics.print("F4 overlay   F5 reload export", x + 10, y + 31)
    love.graphics.print("1 flashlight   2 shovel   3 key   0 empty hands", x + 10, y + 49)
    love.graphics.print("4 passage   5 lights   6 key flag   7 boss door", x + 10, y + 67)
    love.graphics.print("Esc return to lab", x + 10, y + 85)

    local equipped = self.world.player.equipped or "nothing"
    love.graphics.setColor(0.3, 0.86, 0.7, 1)
    love.graphics.print("Held: " .. equipped, x + 10, y + 109)

    local legend_y = y + 132
    love.graphics.setColor(0.96, 0.78, 0.25, 1)
    for index = 1, actor_count do
        local actor = self.world.room.actors[index]
        love.graphics.print(string.format(
            "#%d %s [%s] @ %d,%d",
            index,
            tostring(actor.id),
            tostring(actor.type),
            actor.x,
            actor.y), x + 10, legend_y)
        legend_y = legend_y + 15
    end

    love.graphics.setColor(0.3, 0.8, 1, 1)
    for index = 1, region_count do
        local region = self.world.room.regions[index]
        love.graphics.print(string.format(
            "R%d %s [%s]",
            index,
            tostring(region.id),
            tostring(region.type)), x + 10, legend_y)
        legend_y = legend_y + 15
    end
end

function DesignerOverworld:grant_and_equip(item)
    self.world.player:addItem(item)
    self.world.player.equipped = item
    self.world:set_message("Designer tool: " .. item)
end

function DesignerOverworld:close()
    if GameState.size and GameState.size() > 1 then
        GameState.pop()
    else
        GameState.switch(require("states.designer_lab"))
    end
end

function DesignerOverworld:keypressed(key)
    if key == "escape" then
        self:close()
        return
    elseif key == "f4" then
        self.world.debug_overlay = not self.world.debug_overlay
        return
    elseif key == "f5" then
        self.world:reload_room()
        self.world:set_message("Reloaded " .. tostring(self.world.room_module))
        return
    elseif key == "1" then
        self:grant_and_equip("flashlight")
        return
    elseif key == "2" then
        self:grant_and_equip("shovel")
        return
    elseif key == "3" then
        self:grant_and_equip("rusty_key")
        return
    elseif key == "0" then
        self.world.player.equipped = nil
        self.world:set_message("Hands empty.")
        return
    end

    local number = tonumber(key)
    local flag = number and FLAG_KEYS[number]
    if flag then
        local value = not self.world:get_flag(flag)
        self.world:set_flag(flag, value)
        self.world:set_message(flag .. ": " .. tostring(value))
        return
    end

    self.world:keypressed(key)
end

function DesignerOverworld:actionpressed(action)
    if action == "cancel" or action == "menu" then
        self:close()
        return true
    end
    return self.world:actionpressed(action)
end

function DesignerOverworld:actionreleased(action)
    return self.world:actionreleased(action)
end

function DesignerOverworld:keyreleased(key)
    self.world:keyreleased(key)
end

return DesignerOverworld
