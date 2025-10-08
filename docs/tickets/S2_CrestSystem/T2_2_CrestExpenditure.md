Crest Expenditure
Goal: Allow players to actively expend Crests from their pool to trigger one-shot effects.
Tasks:
Decide on a "timing window" for when crests can be expended. A good starting point is during the Tech Selection phase, before a Tech is locked in.
Create a new input request that asks the player if they wish to expend a crest. This will likely need to be a new sub-state or a loop within the TECH_SELECT phase.
Implement the logic for expend effects (e.g., "Expend Shadow: Target body part becomes Untargetable").
Emit a CREST_EXPENDED event.
Ensure that expending a detrimental crest (like Madness) correctly applies its effect.
Update test_combat_cli.lua to include a prompt for expending crests.
Deliverables:
The player is prompted and can choose to expend an available crest during a designated phase.
The effects associated with expending a crest are correctly applied.
The expended crest is removed from the combatant's crest_pool.
Design Notes/Pitfalls:
UI Complexity: This feature adds significant complexity to the player's decision-making process. In the CLI, a simple "Expend a crest? (y/n)" prompt is fine. Architecturally, make sure the input request is flexible enough to eventually support a proper UI where a player can click on their crest pool at any valid time.
Timing is Everything: Be very deliberate about when crests can be spent. Allowing them to be spent at any time is a recipe for complexity. Tying it to specific phases (like Tech Select or Defense Assign) makes the system much more manageable.