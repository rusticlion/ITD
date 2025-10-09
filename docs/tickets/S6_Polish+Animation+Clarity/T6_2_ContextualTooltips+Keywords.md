Contextual Tooltips & Keywords
Goal: Add the final layer of informational clarity by implementing mouse-over tooltips and displaying keyword iconography.
Tasks:
Implement a generic tooltip system that can display a box with text near the mouse cursor.
In the UI's update loop, perform hit-testing to see what game element the mouse is currently hovering over.
Create and display tooltips for: Body Parts (showing full stats), Crests (explaining their passive and expend effects), and Tech cards.
Modify the Dice Shelf and Selected Tech UI to display small icons for any associated Keywords.
Implement a tooltip for these keyword icons that explains their function (e.g., "Brutal: This attack deals +1 damage on a successful hit.").
Deliverables:
Hovering the mouse over any key game element provides the player with detailed, contextual information.
Keywords are visually represented and explained, removing ambiguity from Techs and dice.
The game is now fully playable and understandable without needing to reference outside documentation.
Design Notes/Pitfalls:
Data-Driven Text: Do not hardcode tooltip text in your UI code. Create a separate data file (e.g., data/ui_text.lua) that maps IDs (tooltips.brutal, tooltips.valor_crest) to strings. This makes editing, proofreading, and future localization much, much easier.