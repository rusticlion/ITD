 Implement Robust Tech Selection Interaction
Goal: Fix the bug preventing Tech card selection by refactoring the UI's hover and click logic. The system should allow a player to move their mouse from a body part onto its "fan" of Tech cards and click one without the fan disappearing.
Tasks:
Refactor UI State: In states/combat.lua, modify the build_tech_selection_context function. The context it builds (stored in self.tech_selection_ui) needs a new field to track the currently "active" fan of cards, e.g., context.active_part_entry.
Update Hover Logic: Modify the evaluate_tech_selection_hover function.
When the mouse is over a new body part, set that part's entry as the active_part_entry.
The logic that calculates the layout for the Tech cards (update_tech_card_layout) should now be called for the active_part_entry, not just the hovered_part_entry.
The draw_tech_selection_ui function must be updated to draw the cards for the active_part_entry so they remain visible.
Implement Clearing Logic: The active_part_entry should only be set to nil when the mouse moves a significant distance away from both the active body part and its fan of cards. This prevents the fan from vanishing the moment the cursor leaves the body part's rectangle.
Verify Click Logic: In love.mousepressed (within CombatState), ensure the check for a context.hovered_option now works correctly, as it will be continuously updated against the visible fan of cards.
Deliverables:
Hovering over a player body part causes its fan of Tech cards to appear and stay visible.
The player can then move their mouse off the body part and onto one of the displayed Tech cards.
The card being hovered is highlighted.
Clicking a highlighted Tech card successfully provides the input to the engine and advances the combat state.
Design Notes/Pitfalls:
State Decoupling: This fix is a practical lesson in UI state management. We are decoupling the "currently open menu" (active_part_entry) from the "currently highlighted button" (hovered_option). This is a common and essential pattern for creating non-frustrating user interfaces.
"Stickiness": The trickiest part will be determining the "stickiness" of the active card fan. A simple solution is to define a larger bounding box around the body part and its card fan; as long as the mouse is within this larger box, the active_part_entry remains. If the mouse leaves this box, clear it.