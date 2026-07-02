local GameState = require("core.gamestate")
local Input = require("core.input")
local Overworld = require("states.overworld")
local MenuSidebar = require("states.menu_sidebar")
local World = require("systems.world")

local function memory_filesystem()
    local files = {}
    return {
        files = files,
        getInfo = function(path)
            return files[path] and { type = "file" } or nil
        end,
        read = function(path)
            return files[path]
        end,
        write = function(path, source)
            files[path] = source
            return true
        end,
        createDirectory = function()
            return true
        end
    }
end

local actions = Input.keypressed("space")
assert(actions[1] == "confirm", "space should map to confirm")
assert(Input.is_down("confirm") == true, "confirm should be down")
assert(Input.was_pressed("confirm") == true, "confirm should be pressed")
Input.update()
assert(Input.was_pressed("confirm") == false, "pressed actions should clear on update")
assert(Input.is_down("confirm") == true, "down action should persist until release")
Input.keyreleased("space")
assert(Input.is_down("confirm") == false, "confirm should release")
assert(Input.action_for_key("tab") == "menu", "tab should map to menu")
assert(Input.actions_for_button("a")[1] == "confirm", "gamepad a should map to confirm")

GameState.clear()
GameState.switch(Overworld)
assert(GameState.size() == 1, "overworld should be the only state")
assert(GameState.actionpressed("menu") == true, "menu action should be handled")
assert(GameState.size() == 2, "menu should push sidebar")
assert(GameState.current.selected_index == 1, "sidebar selection should start at inventory")
assert(GameState.actionpressed("move_down") == true, "sidebar should handle move_down")
assert(GameState.current.selected_index == 2, "sidebar selection should move down")
assert(GameState.actionpressed("cancel") == true, "cancel should close sidebar")
assert(GameState.size() == 1, "sidebar should close")

local fs = memory_filesystem()
local world = World.new({ save_backend = fs, save_path = "saves/menu_save.lua" })
local start_x = world.player.x
local start_y = world.player.y
assert(world:actionpressed("move_left") == true, "movement press should be handled")
assert(world.player.facing == "left", "movement press should turn immediately")
world:update(0.05)
assert(world.player.x == start_x and world.player.moving == false, "brief direction hold should not step")
assert(world:actionreleased("move_left") == true, "movement release should be handled")
world:update(0.20)
assert(world.player.x == start_x and world.player.y == start_y, "released tap should remain in place")

world:actionpressed("move_left")
world:update(0.11)
assert(world.player.moving == true, "held direction should begin a step")
world:actionreleased("move_left")
world:update(world.player.move_duration)
assert(world.player.x == start_x - 1 and world.player.y == start_y, "held direction should complete one step")

GameState.clear()
GameState.push(MenuSidebar, { world = world })
GameState.actionpressed("move_down")
GameState.actionpressed("move_down")
assert(GameState.current.items[GameState.current.selected_index].label == "Esoterica", "expected esoterica item")
assert(GameState.actionpressed("confirm") == true, "confirm should open esoterica screen")
assert(GameState.current.screen == "esoterica", "expected esoterica screen")
assert(GameState.actionpressed("move_down") == true, "esoterica should handle move_down")
assert(GameState.current.selected_index == 2, "esoterica selection should move down")
assert(GameState.actionpressed("cancel") == true, "cancel should return to sidebar")
GameState.actionpressed("move_down")
assert(GameState.current.items[GameState.current.selected_index].label == "Save", "expected save item")
assert(GameState.actionpressed("confirm") == true, "confirm should open save screen")
assert(GameState.size() == 2, "save screen should stack over sidebar")
assert(GameState.current.screen == "save", "expected save screen")
assert(GameState.actionpressed("confirm") == true, "save action should be handled")
assert(fs.files["saves/menu_save.lua"], "expected manual save file")
assert(GameState.current.status == "Saved.", "expected save status")
assert(GameState.actionpressed("cancel") == true, "cancel should return to sidebar")
assert(GameState.current.items[GameState.current.selected_index].label == "Save", "expected sidebar underneath save screen")

GameState.clear()
GameState.push(require("states.menu_screen"), { world = world, screen = "dreamform", title = "Dreamform" })
assert(GameState.current.selected_index == 1, "dreamform should start on first part")
assert(GameState.actionpressed("move_right") == true, "dreamform should handle move_right")
assert(GameState.current.selected_index == 2, "dreamform selection should move right")

print("input/menu smoke test passed.")
