Asset Manager & Placeholder Infrastructure
Goal: Create a centralized, data-driven Asset Manager to decouple game code from asset files. This system must handle loading assets by ID and gracefully fall back to placeholder "programmer art" when final assets are missing.
Tasks:
Create a new module: core/assets.lua.
Implement the Assets:load() function. This function should be called once at game startup. It will scan specified asset directories (e.g., assets/sprites/bodyparts/, assets/sprites/icons/) and load all .png files, using their filenames (without the extension) as their unique ID.
Implement the Assets:get(id) function. This will be the primary interface for all game code. It must contain the crucial fallback logic:
First, try to find the exact ID (dreamblade_arm_healthy).
If not found, parse the ID for a state suffix (e.g., _healthy, _wounded) and try a generic placeholder for that state (placeholder_healthy).
If no specific placeholder is found, try a final default (placeholder_default).
If nothing is found, print a warning to the console and return nil. The game must not crash.
Create the initial set of programmer art. These should be simple colored squares that conform to the art spec (e.g., 128x128 PNGs):
assets/sprites/bodyparts/placeholder_healthy.png (Green)
assets/sprites/bodyparts/placeholder_wounded.png (Yellow)
assets/sprites/bodyparts/placeholder_maimed.png (Red/Grey)
assets/sprites/icons/placeholder_default.png (White)
Update main.lua to require the new asset manager and call Assets:load() within the love.load() function.
Deliverables:
A functional core/assets.lua module exists.
The game loads all assets from specified directories on startup without errors.
Calling Assets:get("some_id_healthy") correctly returns the placeholder_healthy asset if some_id_healthy.png does not exist.
Calling Assets:get("some_real_asset_healthy") returns the correct asset if the file does exist.
Design Notes/Pitfalls:
Code Against IDs: This is the Golden Rule. No part of the game outside of assets.lua should ever reference a file path. All rendering code must use Assets:get(id).
No Game Logic: The Asset Manager should be completely "dumb." It knows about files and IDs, nothing more. It should not know what a "Body Part" is or have any combat-specific logic.
Error, Don't Crash: A missing asset should be a recoverable error that logs a warning, not a fatal crash. This makes development robust.