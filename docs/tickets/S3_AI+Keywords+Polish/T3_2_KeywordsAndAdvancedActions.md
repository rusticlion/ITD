Keywords & Advanced Actions
Goal: Implement the Keyword system and other action types to add variety and strategic depth to Techs.
Tasks:
Modify the Tech and Action data structures to include a keywords table (e.g., keywords = {"Piercing": 1}).
Refactor the main resolution formula in engine.lua. Instead of a single calculation, make it a pipeline of functions where keywords can modify the values at different steps.
Implement the logic for a few key keywords: Brutal (+1 damage on hit), Piercing (ignore X points of defense), Consistent (force dice to a specific value).
Implement other action types from the design doc, such as Heal Body Part.
Update test combatants to use Techs with these new keywords and actions, and verify the outcomes.
Deliverables:
Techs can be defined with a list of keywords.
The resolution logic correctly applies the effects of Brutal, Piercing, and Consistent.
A Heal Body Part action is functional.
Design Notes/Pitfalls:
The Pipeline Pattern: The best way to handle keywords is with a pipeline. Start with a context object like { attack_roll: 10, defense_roll: 4, target_toughness: 3 }. Then, pass this object through a series of functions, one for each keyword, that modifies it. This is far cleaner than a massive if/elseif block and allows you to add new keywords without touching existing code.
Event Data: When emitting events like DAMAGE_DEALT, include the context. Did the damage come from a Brutal hit? Was Piercing involved? This information will be invaluable for the UI later.