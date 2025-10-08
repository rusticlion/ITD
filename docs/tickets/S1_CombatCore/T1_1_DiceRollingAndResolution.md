Dice Rolling & Basic Attack Resolution
Goal: Introduce dice rolling and a basic resolution mechanic where an attack's success is determined by comparing its roll against the target's Toughness.
Tasks:
Create a new, generic utility module (e.g., core/dice.lua) that can handle rolling different types of dice (d4, d6, d8) and return the results.
Modify the Tech data structure to support a new action type: { type = "attack_roll", dice_count = 1, dice_type = "d6" }.
In combat/engine.lua, during the RESOLUTION phase, modify resolve_action to handle this new attack_roll type.
When an attack_roll action is processed, use the new dice utility to generate a result. Emit a DICE_ROLLED event with the attacker, action, and result.
For now, the target will still be selected via select_target_body_part.
Compare the dice roll result directly against the target body part's toughness. If the roll is greater, apply 1 step of damage using apply_damage.
Update test_combat_cli.lua with new Techs that use attack_roll actions and verify that damage is applied correctly based on the rolls.
Deliverables:
A core/dice.lua module is created and functional.
Techs can be defined with attack_roll actions.
The combat engine correctly resolves these attacks by rolling dice and comparing the result to the target's toughness.
The test_combat_cli.lua script can run a full combat using the new dice-based resolution.
Design Notes/Pitfalls:
Decoupling: The dice utility should be completely independent of the combat engine. It should know nothing about combatants or techs; its only job is to roll dice.
Event Logging: Emitting a DICE_ROLLED event is crucial. Later, the UI will need to listen for this to display the dice roll animation before showing the result. Get this in the habit now.
Simplicity First: Resist the urge to add defense rolls or keywords in this ticket. The goal is to get the simplest version of the attack resolution formula working first: Attack Roll > Target Toughness.