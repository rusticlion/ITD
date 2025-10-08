AI Strategy & Decision Making
Goal: Replace the placeholder "select first tech" AI with a system capable of basic tactical decision-making.
Tasks:
Create a new module, combat/ai.lua.
The ai.lua module should contain functions that take the engine state (or the AI combatant and the opponent) as input and return a decision.
Create an ai.choose_tech(ai_combatant, opponent) function. It should evaluate available techs based on simple heuristics (e.g., prefer high-damage techs, use a defensive tech if HP is low).
Create an ai.assign_targets(ai_combatant, opponent, tech) function. It should prioritize targeting wounded body parts over healthy ones.
In engine.lua, replace the call to select_first_tech with a call to the new AI module.
Deliverables:
An ai.lua module exists and is used by the engine for non-player combatants.
The AI no longer picks the first tech by default.
The AI can intelligently assign attacks to the most damaged enemy body part.
Design Notes/Pitfalls:
Keep it Simple (Stupid): Do not try to build a deep-learning neural net. A simple scoring system is more than enough. Score each possible move based on potential damage, defensive value, and crest generation. The AI then picks the highest-scoring move.
Personality: You can give different AIs different "personalities" by changing their scoring weights. An "aggressive" AI will over-value damage, while a "defensive" AI will prioritize defense rolls and healing. This is a great way to create enemy variety.