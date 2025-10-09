Drag-and-Drop Dice Assignment
Goal: Implement the tactile drag-and-drop interface for assigning dice to attack and defense slots.
Tasks:
When the engine requests input for attack_assignment or defense_assignment, the UI should enter an "Assignment" mode.
Render the player's dice on their "Dice Shelf" as interactable objects.
In love.mousepressed, check if a die was clicked. If so, "pick it up" by attaching its visual representation to the cursor.
In love.mousereleased, check if the die was "dropped" over a valid target slot (an enemy BP for attack, a friendly BP for defense).
If the drop is valid, call engine:provide_input(target_index) with the appropriate index from the metadata.options. The die should visually "snap" into the assignment slot.
The UI must also render the enemy's unsettled, rolling dice being assigned to their targets.
Deliverables:
The player can successfully assign all their attack and defense dice using a drag-and-drop interface.
The engine correctly receives these assignments.
A full combat round is now playable from start to finish using only the mouse.
Design Notes/Pitfalls:
UI State Management: The UI will need its own state variables to manage the drag-and-drop action, such as ui_state.dragged_die = { die_data, x, y }. This state is purely visual and should be kept separate from the engine's game state.
Clear Affordances: Use visual cues (highlighting, glowing outlines) to clearly show the player which targets are valid drop zones for the die they are currently dragging.