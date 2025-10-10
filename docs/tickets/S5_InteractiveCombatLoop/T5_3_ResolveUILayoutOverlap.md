Resolve UI Layout Overlap
Goal: Adjust the screen resolution and UI layout anchoring to eliminate the visual overlap between the central UI panels (Tech/Dice Preview) and the combatants' anatomical displays, creating a clean and readable combat screen.
Tasks:
Increase Screen Resolution: In conf.lua, increase the vertical resolution of the game window. Change t.window.height from 608 to 768 to provide more vertical space for the UI elements.
Adjust Anatomical Display Anchors: In ui/layouts.lua, modify the get_anchor function. The goal is to shift the vertical center of the combatant displays higher on the screen. Change the line local center_y = height * 0.45 to local center_y = height * 0.40.
Verify All Layouts: After making the changes, run the combat state and ensure all layout calculations in ui/layouts.lua (for body parts, nameplates, heart points, crests) are still positioned correctly relative to the new anchor point.
Deliverables:
The game window now opens with a 800x768 resolution.
The combatant displays are visibly shifted higher on the screen.
There is a clear, empty space between the lowest body parts and the UI panels at the bottom of the screen, with no visual overlap at any stage of combat.
Design Notes/Pitfalls:
The "Why": The original layout failed because it mixed two anchoring strategies without enough space: the combatants were anchored to the vertical center, while the UI panels were anchored to the bottom. By increasing the space and shifting the center anchor up, we are creating dedicated zones for each, which is a much more robust layout strategy.
Magic Numbers: Continue to ensure that all layout calculations are done within ui/layouts.lua. The states/combat.lua file should remain free of hardcoded coordinates. This fix should only require changes in conf.lua and ui/layouts.lua.