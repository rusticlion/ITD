# Overworld Asset Manifest

*Working list for overworld, dialog, and menu presentation assets. Keep this current as placeholder rectangles become real art.*

---

## Dialog UI

Current runtime state: `states.dialog` uses drawn placeholder rectangles and the existing text rendering path.

Needed:

- Dialog box frame for the 960x540 canvas.
- Speaker nameplate frame.
- Two-option response selector/cursor.
- Continue indicator.
- Optional portrait slot frame for later character dialogs.
- Dialog box open/close blip animation frames, if we want that GBA-ish snap.

Style notes:

- Dialog text should feel low-res and readable before ornate.
- Response labels are intentionally short: usually `Yes` and `No`, with support for alternate short labels.
- Keep dialog presentation compatible with the full-width bottom box used by early 2000s handheld RPGs.

---

## Menu UI

Current runtime state: `states.menu_sidebar` and `states.menu_screen` use drawn placeholder rectangles.

Needed:

- Sidebar panel frame.
- Full-screen menu frame.
- Selected-row highlight.
- Small status text panel or footer.
- Icons for Inventory, Dreamform, Esoterica, Save, Options, and Quit if we keep icon+text rows.
- Dreamform Body Part card frame for menu review.
- Esoterica scroll-list frame and cursor.
- Shared Inspector panel frame compatible with combat, Dreamform, and Esoterica layouts.
- Save confirmation flourish or tiny pulse.

---

## Overworld Placeholders

Current runtime state: actors and tile layers are simple color rectangles.

Needed soon:

- Basement floor and wall tiles.
- Crack/shovel-target tiles or actor sprites.
- Drainage pipe actor sprite.
- Hidden/inspectable wall marker for early dialog testing.
- Player placeholder walk/idle sprites.

---

## Later

- Ambient water/grass/fire/sparkle tile animations.
- Tool-use effects such as shovel scrape, reveal puff, and passage opening.
- Combat bridge transition flourish from overworld into the tabletop combat scene.
