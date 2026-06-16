# Tiled Cheatsheet

*Working reference for authoring Into the Dreamlands overworld rooms in Tiled. Keep this file current whenever runtime expectations change.*

---

## Map Settings

- Orientation: orthogonal.
- Logical tile size: **32x32**.
- Target game canvas: **960x540**.
- Art may be authored at 16x16 and upscaled 2x before or during tileset preparation, but Tiled maps should compose against the 32x32 logical grid.
- Object positions are interpreted as top-left pixel coordinates in Tiled exports, then converted to 1-based tile coordinates by the runtime.

---

## Required Layer Names

Use these names exactly:

- `ground`: base floor tiles.
- `ground_detail`: optional non-colliding floor decoration.
- `walls`: visible wall/solid structure tiles.
- `objects_low`: optional tile props drawn before actors.
- `actors`: object layer for interactive/runtime actors.
- `objects_high`: optional foreground/overhead tile props drawn after actors.
- `effects`: optional decorative animated/effect layer.
- `regions`: object layer for invisible triggers, exits, compass spots, and camera zones.
- `collision`: optional tile layer for explicit collision. If present, nonzero tiles are solid. If absent, nonzero `walls` tiles are solid.

Unknown layers are allowed while experimenting, but they should not drive gameplay until documented here.

---

## Actor Objects

Actors live on the `actors` object layer.

Required:

- `name`: stable actor ID. Required for anything persistent or save-relevant.
- `type`: actor type, such as `pipe`, `crack`, `door`, or `pickup`.

Supported custom properties:

- `actor_type`: optional override if Tiled's built-in `type` field is inconvenient.
- `solid`: boolean; blocks movement when true.
- `interactable`: boolean; can be examined/used when true.
- `item`: item ID granted by a pickup-like actor.
- `flag`: flag key set or checked by the actor.
- `message`: default examine text.
- `empty_message`: text after an item has been removed.
- `missing_tool_message`: text shown when the player lacks the needed tool.
- `resolved_message`: text shown after a one-shot interaction has already resolved.
- `on_tool_use`: action payload for actors activated by an equipped/owned tool.
- `dialog`: dialog module path, e.g. `data.dialog.basement`.
- `dialog_id`: dialog tree ID inside the dialog module.

`type` should describe presentation and default behavior, not the full gameplay outcome. For example, `crack` means "draw and behave like a shovel-target crack"; the encounter or passage it opens belongs in `on_tool_use`.

Hand-authored Lua rooms may use nested payloads:

```lua
properties = {
    on_tool_use = {
        tool = "shovel",
        type = "encounter",
        encounter_id = "basement.zombie",
        message = "You dig through the wall. Something stirs in the dark."
    }
}
```

Tiled exports should use dotted property names if nested custom classes are inconvenient:

- `on_tool_use.tool`: equipped/owned tool ID required to activate the actor.
- `on_tool_use.type`: `message`, `encounter`, `passage`, or `item`.
- `on_tool_use.message`: text shown when the action resolves.
- `on_tool_use.encounter_id`: combat encounter/content ID to launch.
- `on_tool_use.target_room`: room ID or module path for exits.
- `on_tool_use.target_spawn`: spawn ID inside the target room.
- `on_tool_use.item`: item ID granted by an item action.
- `on_tool_use.once`: boolean; defaults to true for tool targets.

Interim hand-authored Lua rooms may use `tile_x` and `tile_y` directly. Tiled imports should prefer pixel `x`/`y`.

---

## Region Objects

Regions live on the `regions` object layer and should use stable `name` values when they affect save state or routing.

Common region types:

- `exit`: room transition.
- `encounter_trigger`: launches combat on touch or confirm.
- `camera_zone`: alters camera behavior.
- `hidden_poi`: hidden point of interest for the Compass/Shovel/Puzzle Box chain.
- `cutscene`: one-shot story trigger.

Supported custom properties overlap with actor objects: `target_room`, `target_spawn`, `encounter_id`, `flag`, and `message`. Hidden POIs should use generic reveal/discovery properties such as `hidden_poi`, `reveal_tool`, `reveal_flag`, and `reveals_actor` rather than tool-specific region names.

---

## Dialog Objects

Early dialog actors can use `type = "message"` plus `dialog` and `dialog_id` properties. Dialog trees live in Lua modules for now:

```lua
properties = {
    dialog = "data.dialog.basement",
    dialog_id = "whispering_wall"
}
```

Dialog supports:

- Branches based on flags, inventory, equipped item, or equipped Body Part tags.
- Two short player responses.
- End-of-tree effects such as `set_flag`, `clear_flag`, `give_item`, and result hooks such as `encounter`.
- Ambient-only overworld updates while dialog is open; actor movement and state-changing world updates are locked.

---

## Save-State Invariants

- Persistent objects need stable `name` values.
- Renaming a persistent object is a save migration.
- Runtime state is saved by `room_id.actor_name`, not by Tiled numeric object ID.
- One-shot actor interactions should save generic `resolved = true` state. Presentation may render that as dug, opened, drained, or exhausted.
- Prefer explicit flags for cross-room logic, e.g. `basement.shovel_found`, `basement.mad_butcher_defeated`.

---

## Current Runtime Actor Types

- `pipe`: examine/pickup actor. If it has `item`, the first interaction grants that item and marks the actor removed.
- `crack`: shovel-target presentation actor. Checks `on_tool_use.tool` when present, marks itself `resolved`, and resolves the generic `on_tool_use` action.
- `message`: simple inspectable text actor.

Add new actor types here when they become runtime-supported.
