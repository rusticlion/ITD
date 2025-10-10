Correct UI Event Handling for Drag-and-Drop
Goal: Resolve the drag-and-drop failure by refactoring the UI event handling to prevent premature state destruction.
Tasks:
Refactor love.mousereleased: In states/combat.lua, simplify the mousereleased callback. Remove the logic that checks metadata and rebuilds self.assignment_ui. The function should now only do two things: update the mouse position and, if self.assignment_ui exists, call handle_assignment_mousereleased.
Verify update Loop: Confirm that the main update_interactive_input function is correctly handling the creation and destruction of the self.assignment_ui context once per frame based on the engine's state. This is the correct location for that logic.
Test: Perform a full drag-and-drop assignment. The handle_assignment_mousereleased function should now execute correctly, using the state that was present during the drag, successfully find the hovered_target, and call engine:provide_input().
Deliverables:
The player can successfully click and drag a die from their Dice Shelf.
Dropping the die onto a valid, highlighted enemy (for attack) or friendly (for defense) body part correctly assigns the die.
The engine receives the input, and the UI updates to show the next assignment prompt or advances to the next combat phase.
Design Notes/Pitfalls:
This is a classic case of separating state updates from event handling. Events should be lightweight notifications. The main update loop is responsible for observing the game state and synchronizing the UI to it. This fix will make our UI architecture much more stable and predictable.