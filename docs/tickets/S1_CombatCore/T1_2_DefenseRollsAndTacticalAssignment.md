Defense Rolls & Tactical Assignment
Goal: Implement the Attack and Defense Assignment phases, allowing players to make tactical choices about where to apply their dice rolls.
Tasks:
Introduce a defense_roll action type for Techs: { type = "defense_roll", dice_count = 1, dice_type = "d4" }.
In combat/engine.lua, create new data structures to store assignments for the current round, e.g., engine.attack_assignments and engine.defense_assignments. These will map a combatant to their chosen targets.
Flesh out the ATTACK_ASSIGN state. For each combatant with attack_roll actions, the engine must prompt for a target body part for each attack. For now, AI can continue to use select_target_body_part. The player will be prompted via request_input.
Flesh out the DEFENSE_ASSIGN state, following the same pattern for defense_roll actions, where combatants assign them to their own body parts.
Update the RESOLUTION phase logic. When resolving an attack, it must now check the attack_assignments table for its target. The resolution formula is now: Attack Roll > (Target Toughness + Assigned Defense Roll).
If a body part is targeted by multiple attacks or defended by multiple defense rolls, ensure the logic handles this correctly (e.g., sum the defense rolls).
Update test_combat_cli.lua to handle the new input prompts for assigning attacks and defenses.
Deliverables:
The ATTACK_ASSIGN and DEFENSE_ASSIGN states now correctly prompt the player for input and store their choices.
The RESOLUTION state uses the stored assignments to determine targets.
The full resolution formula, including defense rolls, is implemented.
Design Notes/Pitfalls:
State Management: The assignment data must be cleared at the start of each ATTACK_ASSIGN phase to prevent data from leaking between rounds.
Data Structure: A good structure for assignments might be engine.attack_assignments[attacker_id] = {{tech=tech, roll_index=1, target_id=target_part_id}}. This is explicit and scalable.
Asynchronous Flow: This is a major test of the request_input system. Ensure the engine correctly pauses, waits for all players to assign all their rolls, and only then proceeds to the next state.