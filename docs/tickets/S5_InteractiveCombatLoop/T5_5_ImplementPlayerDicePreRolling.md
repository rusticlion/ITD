Implement Player Dice Pre-Rolling
Goal: Modify the combat engine to pre-roll the player's dice before the assignment phase and update the UI to display these settled values, aligning the implementation with the CombatPresentation.md design.
Tasks:
Engine: In combat/engine.lua, create a new internal structure to hold pre-rolled dice results for the current round.
Engine: At the beginning of the ATTACK_ASSIGN phase (within prepare_attack_assignments), iterate through the player combatant's tech. For any attack_roll or defense_roll actions, roll the dice immediately using core/dice.lua and store the result in your new structure.
Engine: When creating the metadata for an attack_assignment or defense_assignment input request, include the pre-rolled result for that specific action.
UI: In states/combat.lua, modify the build_assignment_context and sync_assignment_dice functions. The dice tokens should now source their primary display value from the new rolled_value field in the metadata, rather than just showing the die type.
Deliverables:
When the assignment phase begins, the player's dice on the Dice Shelf now display a specific number (e.g., "6") instead of the die type ("1d6").
The enemy's dice on their shelf remain visually "unsettled" (this is a visual effect we'll add later, for now they can just not display a value).
Design Notes/Pitfalls:
This change only affects the player's dice. The AI does not need pre-rolled dice as it makes its decisions instantly. The engine should continue to roll the AI's dice during the RESOLUTION phase as it does now. This maintains the information asymmetry that is key to the design.