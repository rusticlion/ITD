local GameState = require("core.gamestate")
local Dialog = require("systems.dialog")
local Overworld = require("states.overworld")
local World = require("systems.world")

local world = World.new({ autosave = false })
local actor = world.room.actor_by_id.whispering_wall
assert(actor, "expected whispering_wall actor")

local actor_result = actor:interact(world, world.player)
assert(actor_result.type == "dialog", "expected actor to start dialog")
assert(actor_result.dialog == "data.dialog.basement", "expected dialog module")
assert(actor_result.dialog_id == "whispering_wall", "expected dialog id")

local dialog = Dialog.new("data.dialog.basement", "whispering_wall", { world = world })
assert(dialog:current_node().text == "Something inside the wall whispers through the plaster.")
assert(dialog:advance() == nil, "first line should advance")
assert(dialog:current_node().responses[1].label == "Yes", "expected yes response")
dialog:advance(1)
local result = dialog:advance()
assert(result.type == "dialog_result", "expected dialog result")
assert(result.effects[1].flag == "basement.whispering_wall_heard", "expected heard flag effect")
assert(result.result.type == "encounter", "expected encounter result")

local triggered
world.on_encounter = function(encounter)
    triggered = encounter.encounter_id
end
world:apply_dialog_result(result)
assert(world:get_flag("basement.whispering_wall_heard") == true, "expected flag to be set")
assert(triggered == "basement.whisperer", "expected whisperer encounter")

local repeat_dialog = Dialog.new("data.dialog.basement", "whispering_wall", { world = world })
assert(repeat_dialog:current_node().text == "The wall is quiet now, but it remembers the shape of your ear.")
local repeat_result = repeat_dialog:advance()
world:apply_dialog_result(repeat_result)
assert(world:get_flag("basement.whispering_wall_revisited") == true, "expected revisit flag")

local refusal_world = World.new({ autosave = false })
GameState.clear()
GameState.switch(Overworld)
Overworld:start_dialog({
    dialog = "data.dialog.basement",
    dialog_id = "whispering_wall"
})
assert(GameState.size() == 2, "dialog should be stacked over overworld")
assert(GameState.actionpressed("confirm") == true, "confirm should advance first line")
assert(GameState.actionpressed("cancel") == true, "cancel should select the second response")
assert(GameState.size() == 1, "dialog should close after no response")
assert(Overworld.world:get_flag("basement.whispering_wall_refused") == true, "expected refused flag")

local no_dialog = Dialog.new("data.dialog.basement", "whispering_wall", { world = refusal_world })
no_dialog:advance()
local no_result = no_dialog:cancel()
refusal_world:apply_dialog_result(no_result)
assert(refusal_world:get_flag("basement.whispering_wall_refused") == true, "expected no branch flag")

print("dialog smoke test passed.")
