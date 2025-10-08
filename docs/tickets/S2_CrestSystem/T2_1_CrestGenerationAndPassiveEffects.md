Crest Generation & Passive Effects
Goal: Implement the ability for Techs to generate Crests and for those Crests to apply passive effects.
Tasks:
Define a new action type: { type = "gain_crest", crest = "Valor", amount = 1 }.
In resolve_action, add a case to handle gain_crest actions, adding the specified crest to the combatant's crest_pool.
Emit a CREST_GAINED event when a crest is added.
In the UPKEEP phase of states.lua, add a new step where the engine iterates through all combatants and checks for passive crest effects (e.g., "At 2+ Valor...").
Store the logic for passive effects in a clean, scalable way. A table mapping crest types to functions is a good approach, e.g., CrestPassives.Valor(combatant).
Update the test combatants in test_combat_cli.lua with Techs that generate crests and verify that passive effects are applied.
Deliverables:
Combatants can gain crests from Tech actions.
A system for checking and applying passive crest effects during the Upkeep phase is functional.
The CLI test can demonstrate a combatant gaining a crest and a passive effect activating on a subsequent turn.
Design Notes/Pitfalls:
Stat Modification: Passive effects will often modify a combatant's stats for the duration of the round. You need a clean way to apply and then clear these temporary modifiers. One approach is a combatant.modifiers table that is cleared at the end of each round.
Data-Driven: Avoid hardcoding passive effect logic inside engine.lua. Keep it in a separate module (combat/crests.lua?) so you can add new crests and passive effects without touching the core engine.