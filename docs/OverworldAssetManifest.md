# Overworld Asset Manifest

*Working list for overworld, dialog, and menu presentation assets. Keep this current as placeholder rectangles become real art.*

---

## Global Canvas Contract

- Target logical canvas: **960x540**.
- Logical overworld tile size: **32x32**. Art may be authored at **16x16** and upscaled, but exported tilesets and runtime footprints should compose on the 32x32 grid.
- UI asset folder: `assets/sprites/ui/`. This folder is scanned by `core/assets.lua`; asset IDs are filenames without `.png`.
- Overworld sprite folder: `assets/sprites/overworld/`. This folder is scanned by `core/assets.lua`; asset IDs are filenames without `.png`.

## Dialog UI

Current runtime state: `states.dialog` draws the assets below when present, then falls back to drawn placeholder rectangles and the existing text rendering path.

Current runtime placement:

- Dialog box: `x=24`, `y=388`, `w=912`, `h=128`.
- Speaker nameplate: `x=40`, `y=370`, `w<=220`, `h=28`.
- Response buttons: `112x26`; current slots are roughly `x=668` and `x=790`, `y=474`.
- Continue indicator: lower-right of the box, currently around `x=902`, `y=488`.

| Asset ID | Canvas | Status | Notes |
|---|---:|---|---|
| `dialog_box_frame` | `912x128` | needed | Full-width bottom RPG dialog frame. Keep text-safe area clear from `x+24,y+28` through `864px` width. |
| `dialog_nameplate` | `220x28` | needed | Speaker plate; should tolerate shorter speaker names by leaving right-side negative space. |
| `dialog_response_selected` | `112x26` | optional | Use only if we keep pill-style response selection. |
| `dialog_choice_cursor` | `8x12` | recommended | Preferred lightweight `>`-style selector for two short responses. |
| `dialog_continue` | `12x12` | recommended | Small animated or static continue prompt. `dialog_continue1`...`dialog_continue4` can be used if animated. |
| `dialog_portrait_frame` | `72x72` | later | Optional portrait slot: 64x64 portrait well plus frame/padding. |
| `dialog_open_blip1`...`dialog_open_blip4` | `912x128` | later | Optional open/close snap frames matching the main box footprint. |

Needed first: `dialog_box_frame`, `dialog_nameplate`, `dialog_choice_cursor`, `dialog_continue`.

Style notes:

- Dialog text should feel low-res and readable before ornate.
- Response labels are intentionally short: usually `Yes` and `No`, with support for alternate short labels.
- Keep dialog presentation compatible with the full-width bottom box used by early 2000s handheld RPGs.

---

## Menu UI

Current runtime state: `states.menu_sidebar` and `states.menu_screen` use drawn placeholder rectangles.

Current runtime placement:

- Sidebar panel: `x=732`, `y=18`, `w=210`, `h=256` on the 960x540 canvas.
- Sidebar rows: `186x28` visible row footprint, 32px vertical stride.
- Full-screen menu frame: `x=24`, `y=24`, `w=912`, `h=492`.
- Full-screen menu content area: `x=52`, `y=92`, `w=856`, `h=396`.

| Asset ID | Canvas | Status | Notes |
|---|---:|---|---|
| `menu_sidebar_frame` | `210x256` | needed | Pokemon-style right sidebar over the world. |
| `menu_cursor` | `8x12` | recommended | Shared `>` cursor for sidebar, Esoterica list, and compact choices. |
| `menu_full_frame` | `912x492` | needed | Full-screen menu frame. Header text lives around `x+24,y+22`; divider at `y+62`. |
| `menu_footer_panel` | `856x48` | optional | Status/help/save-message strip inside full-screen menu content area. |
| `menu_icon_inventory` | `16x16` | optional | Only needed if sidebar rows become icon+text. |
| `menu_icon_dreamform` | `16x16` | optional | Only needed if sidebar rows become icon+text. |
| `menu_icon_esoterica` | `16x16` | optional | Only needed if sidebar rows become icon+text. |
| `menu_icon_save` | `16x16` | optional | Only needed if sidebar rows become icon+text. |
| `menu_icon_options` | `16x16` | optional | Only needed if sidebar rows become icon+text. |
| `menu_icon_quit` | `16x16` | optional | Only needed if sidebar rows become icon+text. |
| `menu_save_pulse1`...`menu_save_pulse4` | `24x24` | later | Tiny save confirmation flourish. |

Current Dreamform screen component footprints:

| Component | Canvas / Runtime Size | Notes |
|---|---:|---|
| BP cards | reuse combat BP cards, `116x88` card / `116x134` total footprint | Do not create a separate Dreamform BP card unless we deliberately fork the look. |
| Dice pool panel | `435x240` | Current lower-left Dreamform panel at 960x540. |
| Shared inspector panel | `403x240` | Current lower-right Dreamform panel. |

Current Esoterica screen component footprints:

| Component | Canvas / Runtime Size | Notes |
|---|---:|---|
| Esoterica list panel | `238x396` | Left column. Rows are `218x26` visible footprints with 30px stride. |
| Viewed BP card | `232x268` total footprint | 2x scale of shared combat BP card footprint. |
| Shared inspector panel | `291x396` | Right column, includes die diagram. |

---

## Overworld Tiles And Sprites

Current runtime state: Tiled-style Lua tile layers render from embedded tilesets when their image asset can be resolved. Missing tilesets/sprites fall back to the simple color rectangle placeholders.

| Asset ID | Canvas | Status | Notes |
|---|---:|---|---|
| `basement_tiles` | variable, 32x32 grid | needed soon | First Tiled tileset sheet. Keep `tilewidth=32`, `tileheight=32`, and filename/tileset `asset_id` aligned with this ID. |
| `basement_floor_tile` | `32x32` | needed soon | May be authored at 16x16 and upscaled into a 32x32 tileset. |
| `basement_wall_tile` | `32x32` | needed soon | Solid wall tile; collision is authored separately in Tiled. |
| `basement_ground_detail_*` | `32x32` | optional | Non-colliding floor variation. |
| `actor_crack` | `16x16` source / `32x32` runtime | imported | Shovel target / passage reveal marker. Legacy variants include open and enemy-revealed states. |
| `actor_pipe` | `16x16` source / `32x32` runtime | imported | Drainage pipe actor. `actor_pipe_shovel` preserves the item-present state. |
| `actor_hidden_wall_marker` | `32x32` | needed soon | Early inspectable/dialog test marker. |
| `player_idle_down` | `16x16` source / `32x32` runtime | imported | Current player sprite, enlarged with nearest-neighbor rendering. |
| `player_idle_up` | `16x16` source / `32x32` runtime | imported | Same footprint. |
| `player_idle_left` | `16x16` source / `32x32` runtime | imported | Same footprint. |
| `player_idle_right` | `16x16` source / `32x32` runtime | imported | Same footprint. |
| `player_walk_down1`...`player_walk_down4` | `16x16` source / `32x32` runtime | imported | 4-frame legacy walk set. |
| `player_walk_up1`...`player_walk_up4` | `16x16` source / `32x32` runtime | imported | 4-frame legacy walk set. |
| `player_walk_left1`...`player_walk_left4` | `16x16` source / `32x32` runtime | imported | 4-frame legacy walk set. |
| `player_walk_right1`...`player_walk_right4` | `16x16` source / `32x32` runtime | imported | 4-frame legacy walk set. |

Imported legacy assets are curated through `tools/legacy_assets.json`; provenance
and exact source frame IDs live in `assets/legacy/imported_assets.json`.

Needed first: a compact Basement floor/wall tileset and `actor_hidden_wall_marker`.

---

## Later

- Ambient water/grass/fire/sparkle tile animations.
- Tool-use effects such as shovel scrape, reveal puff, and passage opening.
- Combat bridge transition flourish from overworld into the tabletop combat scene.
