Combat State & Static Display
Goal: Create the main combat game state and render the static "Anatomical Display" layout, drawing data directly from the combat engine using the new Asset Manager.
Tasks:
Create a new game state file: states/combat.lua.
In this state's enter function, instantiate a combat Engine, create two demo Combatants, add them, and start the combat.
Create ui/layouts.lua to manage coordinates for the anatomical displays.
In the combat.lua draw function, iterate through engine.combatants.
For each Body Part, construct the asset ID from its id and status (e.g., "player_arm" .. "_" .. "healthy").
Call Assets:get(asset_id) to retrieve the correct sprite (which will be the placeholder art for now).
Draw the retrieved sprite in the correct anatomical position determined by the layout module.
Draw the combatant's Heart Points and Crests as simple text or placeholder icons.
Deliverables:
A new states/combat.lua that starts a combat and renders two opposing "paper dolls" using sprites served by the Asset Manager.
The displayed sprites (e.g., green for healthy, yellow for wounded) accurately reflect the status of the Body Parts in the engine.
Design Notes/Pitfalls:
This ticket now serves as the first real-world test of the Asset Manager. Ensure the fallback logic is working correctly by having some combatants with "real" (placeholder) assets and some without, to verify both paths.
