local Overworld = {}
Overworld.__index = Overworld

local GameState = require("core.gamestate")
local Save = require("core.save")
local World = require("systems.world")

function Overworld:enter()
    local save_data, save_error = Save.load()
    if save_error then
        print("Save load failed: " .. tostring(save_error))
    end

    self.world = World.new({ save = save_data })
    self.world.on_encounter = function(encounter)
        self:start_combat(encounter)
    end
    self.world.on_dialog = function(dialog)
        self:start_dialog(dialog)
    end
end

function Overworld:start_combat(encounter)
    GameState.push(require("states.v2_combat"), {
        encounter_id = encounter and encounter.encounter_id or "debug.demo",
        encounter = encounter,
        run = self.world and self.world.run
    })
end

function Overworld:start_dialog(dialog)
    GameState.push(require("states.dialog"), {
        world = self.world,
        dialog = dialog and dialog.dialog,
        dialog_id = dialog and dialog.dialog_id,
        actor = dialog and self.world.room and self.world.room.actor_by_id[dialog.actor_id]
    })
end

function Overworld:resume(_, result)
    if self.world and result and result.type == "combat_result" then
        local summary = self.world:apply_combat_result(result)
        if summary then
            GameState.push(require("states.post_combat"), summary)
        end
    elseif self.world and result and result.type == "dialog_result" then
        self.world:apply_dialog_result(result)
    end
end

function Overworld:update(dt)
    self.world:update(dt)
end

function Overworld:draw()
    self.world:draw()
end

function Overworld:keypressed(key)
    if key == "c" then
        self:start_combat({ encounter_id = "debug.demo" })
        return
    end

    self.world:keypressed(key)
end

function Overworld:actionpressed(action)
    if action == "debug_combat" then
        self:start_combat({ encounter_id = "debug.demo" })
        return true
    elseif action == "menu" or action == "cancel" then
        GameState.push(require("states.menu_sidebar"), { world = self.world })
        return true
    end

    return self.world:actionpressed(action)
end

function Overworld:keyreleased(key)
    self.world:keyreleased(key)
end

return Overworld
