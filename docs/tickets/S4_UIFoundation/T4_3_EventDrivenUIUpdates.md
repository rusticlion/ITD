Event-Driven UI Updates
Goal: Make the UI "live" by listening to events from the engine and updating the display in response, replacing the need to manually advance the state.
Tasks:
In states/combat.lua, subscribe to engine events (BP_STATUS_CHANGED, DAMAGE_DEALT, CREST_GAINED, CREST_EXPENDED).
When a BP_STATUS_CHANGED event is received, the UI should immediately update its visual state to request the new asset ID on the next draw call (e.g., it should now request ..._wounded instead of ..._healthy).
Update the update(dt) loop to automatically call engine:process_state() when not awaiting input.
Deliverables:
The UI now updates in real-time during an AI-vs-AI combat, swapping between the placeholder_healthy and placeholder_wounded sprites as damage is dealt.
Design Notes/Pitfalls:
Continue to reinforce that the UI is a "dumb" client. It just redraws based on the latest information from the engine's events; it doesn't decide the logic itself.
