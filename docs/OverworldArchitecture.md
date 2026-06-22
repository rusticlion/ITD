# Into the Dreamlands - Overworld Architecture Notes

*Drafted June 2026. These notes lock the first implementation target for exploration, room authoring, menus, and save plumbing.*

---

## 1. Locked Baseline

- The game uses a **960x540 logical canvas** across overworld and combat.
- Overworld maps use **32x32 logical tiles**.
- Most overworld art may be authored at **16x16 source resolution and upscaled 2x**, but direct 32x32 authoring is allowed when it reads better.
- Player movement is **tile-stepped with smooth interpolation**: collision and interaction reason in tile coordinates; presentation eases between tiles.
- Level art flow is **Aseprite mockup -> Tiled composition -> Lua runtime import**.

The goal is one stable visual grid and one stable camera/canvas contract. Combat already targets 960x540, so overworld should not invent a second resolution regime.

---

## 2. Authoring Pipeline

Initial maps should be mocked up in Aseprite for speed and mood. Final map composition happens in Tiled, where tile layers, object layers, collision regions, exits, and actor instances can be authored explicitly.

Runtime room loading should be designed around Tiled concepts even if early rooms remain hand-authored Lua tables:

- Tile layers for ground, details, walls, and foreground.
- Object layers for actors, regions, exits, encounter triggers, and tool targets.
- Stable object IDs or authored names for save-state keys.
- Custom properties for behavior data such as `actor_type`, `on_tool_use`, `target_room`, `encounter_id`, or `flag`.

Current runtime support accepts finite Lua exports with embedded tileset metadata. Tileset images resolve through `assets/sprites/overworld/` by `asset_id`, `image_id`, or image filename, and room load prints validation warnings for missing assets, unsupported layer shapes, duplicate IDs, unknown actor types, and diagonal tile flips.

Do not couple game logic to Aseprite output details. Aseprite establishes the look; Tiled establishes the playable room.

Keep `docs/TiledCheatsheet.md` current with exact layer names, object properties, and save-state invariants needed while authoring maps in Tiled.

---

## 3. Room Layers

Use a small, predictable layer vocabulary:

- `ground`: base floor tiles.
- `ground_detail`: stains, cracks, rugs, decals, and other non-colliding floor detail.
- `walls`: solid structural tiles.
- `objects_low`: low props that draw before actors.
- `actors`: player, NPCs, enemies, pickups, interactables, and movable objects.
- `objects_high`: overhead pipes, wall tops, canopies, and foreground occluders.
- `effects`: weather, glow, shimmer, ritual pulses, and other transient visuals.
- `regions`: invisible triggers, exits, camera zones, compass spots, and puzzle volumes.
- `collision`: explicit collision data when tile solidity is not expressive enough.

Actors and low props that share floor space should draw by `sort_y` so the player can stand naturally in front of or behind them.

---

## 4. World And Actor Model

Prefer a simple actor system over a full ECS.

Core objects:

- `World`: owns the current dream, current room, actors, camera, flags, inventory, encounter bridge, and save hooks.
- `Room`: owns tile layers, object layers, regions, spawn definitions, and room-local state.
- `Actor`: has a stable `id`, `type`, position, facing, layer/depth, optional collider, optional interaction, optional animator, and optional save state.
- `ActorTypeRegistry`: maps actor type IDs to behavior constructors.
- `Director`: an invisible actor or room controller for bespoke dream behavior such as rising water, periodic spawns, exams, faction state, or camera reveals.

Actor behavior should be composed from a small vocabulary before introducing custom code:

- `solid`
- `interactable`
- `pickup`
- `tool_target`
- `door`
- `room_exit`
- `encounter_trigger`
- `dialogue`
- `switch`
- `persistent_state`
- `director`

When a dream needs special behavior, add it as a named actor type or director instead of hardcoding it inside the global overworld state.

---

## 5. Animation

Use one general animation layer for overworld actors and animated props.

- `SpriteDef`: image path, frame size, origin, and named animations.
- `Animator`: current animation, frame timer, loop mode, and one-shot completion.
- Common animation names: `idle_down`, `idle_up`, `idle_left`, `idle_right`, `walk_down`, `walk_up`, `walk_left`, `walk_right`, `open`, `closed`, `glow`, `use_tool`.

Tile animations can be loaded from Tiled if they stay decorative. Interactive animated objects should be actors.

---

## 6. Save State

Save by stable IDs and flags, not serialized runtime objects.

Current save path:

- `saves/slot1.lua` through `love.filesystem`.

Current save shape:

- `profile`: player name, cat name, settings, unlocked meta knowledge, and long-term discoveries.
- `run`: current night state, current dream, current room, player position/inventory/tools, claimed body parts, resonance, defeated encounters, and puzzle flags.
- `rooms`: room-local actor state keyed by stable room ID and actor ID.

Examples:

```lua
{
    save_version = 1,
    profile = {},
    run = {
        current_room = "data.rooms.basement_1",
        player = {
            x = 5,
            y = 5,
            facing = "down",
            inventory = { shovel = true },
            equipped = "shovel"
        },
        dreamform = { ... },
        parts = { ... },
        encounters = { ... },
        flags = {}
    },
    rooms = {
        basement_1 = {
            pipe_shovel = { removed = true },
            crack_north = { resolved = true },
            mad_butcher_door = { unlocked = true }
        }
    }
}
```

Autosave currently fires at safe boundaries: item pickup, passage opening, and combat result application. Later room transitions, wake/death, and explicit menu saves should call the same world autosave hook.

---

## 7. Combat Bridge And Dreamform State

Combat is a progression boundary, not just a win/loss minigame. The overworld/run layer owns persistent player combat state, then hands combat a runtime combatant built from that state.

Run state should track:

- `dreamform`: the currently equipped Body Part instance IDs by slot.
- `parts`: the currently embodied Body Part instances only. A replaced BP leaves the run; this is not an inventory.
- `discovered_parts`: Body Part definition IDs that the Esoterica database can reveal.
- `encounters`: defeated, cleared, or otherwise resolved encounter IDs.
- `combat_history`: optional debug/playtest records such as round count, winner, claimed part, and defeat reason.

Use stable Body Part definition IDs for content identity, and separate runtime instance IDs when a claimed part may carry per-run state. The likely shape is:

```lua
run = {
    dreamform = {
        head = "part_inst_dreamer_head",
        body = "part_inst_dreamer_body",
        arm_l = "part_inst_dreamer_left_arm",
        arm_r = "part_inst_bone_demon_claw",
        leg_l = "part_inst_dreamer_left_leg",
        leg_r = "part_inst_dreamer_right_leg"
    },
    parts = {
        part_inst_dreamer_head = { def_id = "dreamer_head" },
        part_inst_dreamer_body = { def_id = "dreamer_body" },
        part_inst_bone_demon_claw = { def_id = "bone_demon_right_claw", claimed_from = "basement.bone_demon" }
    }
}
```

Combat entry should receive an `encounter_id` plus the current `dreamform`. Combat exit should return a structured result:

```lua
{
    outcome = "victory", -- victory, defeat, fled, scripted
    encounter_id = "basement.bone_demon",
    player_parts = { ... }, -- current combat-exit statuses before recovery
    claimable_parts = {
        { def_id = "bone_demon_skull", status = "wounded" },
        { def_id = "bone_demon_right_claw", status = "healthy" }
    },
    claimed_part = { def_id = "bone_demon_right_claw" }, -- nil if skipped
    claimed_slot = "arm_r",
    replaced_part = { def_id = "dreamer_right_arm" }
}
```

The claim ceremony happens on the combat screen immediately after victory. Combat identifies non-maimed enemy parts as claimable; the player may skip the claim. If the player claims a BP, the result names both the claimed part and the target dreamform slot. The run layer then creates a new current part instance, equips it into that slot, records the definition in `discovered_parts`, and deletes the replaced instance from `run.parts`.

Locked first-pass recovery rule: Body Part damage persists through combat exit, then every equipped surviving Body Part heals one step before the next combat begins. `maimed` becomes `wounded`, `wounded` becomes `healthy`, and `healthy` remains `healthy`. Claimed non-maimed parts receive the same one-step recovery as they take root. This keeps damage pressure without allowing a BP to begin the next fight already offline.

The post-combat stack overlay now summarizes outcome, recovery, and the chosen mutation. It is no longer the claim UI.

---

## 8. Menus And State Stack

`core.gamestate` supports a stack:

- `switch(state, ...)`: hard scene change; exits the whole stack and enters one state.
- `push(state, ...)`: overlay or modal; pauses the previous state and enters the new one.
- `pop(...)`: exits the top state and resumes the state beneath it.
- `replace(state, ...)`: swaps only the current top state.

Only the top state updates and receives input. Drawing walks from bottom to top unless a state sets `opaque = true`, in which case lower states are hidden.

This supports pause menus, dialogue boxes, inventory/tool selection, dreamform planning, claiming, and options screens without turning every game state into a menu manager.

The first input layer is `core.input`, a thin action map rather than a full control-remapping UI. States that are part of the normal overworld/menu flow should prefer actions over raw keys:

- `move_up`, `move_down`, `move_left`, `move_right`
- `confirm`
- `cancel`
- `menu`
- `debug_combat`

Raw key handlers remain useful for debug-only states, editor text fields, and combat interactions that still need bespoke mouse/keyboard handling.

The main menu follows the 2000s handheld RPG pattern: pressing `menu` opens a narrow sidebar over the world, and `cancel` closes it. The sidebar lists menu screens and has a cursor for navigation. `confirm` opens the selected full-screen menu state on top of the sidebar. Full-screen menu states cover the game world and return to the sidebar on `cancel`.

Current screens: Inventory, Dreamform, Esoterica, Save, Options, and Quit. Inventory/Dreamform/Esoterica are read-only review screens for now; Save calls the current autosave hook; Options and Quit are placeholders.

---

## 9. Dialog

Dialog is a stack overlay. The overworld remains visible underneath, but only ambient visual updates run while dialog is active. Actor movement, player movement, encounters, timers that alter game state, and other world simulation should remain paused until dialog resolves.

Dialog trees are data-first Lua tables for now. Nodes can advance linearly, branch by condition, present up to two short player responses, and return a `dialog_result` when finished. The world applies dialog result effects after the dialog state pops, which keeps combat starts and flag changes out of the middle of the overlay lifecycle.

Supported first-pass condition checks:

- flag set/unset
- inventory item owned
- equipped item
- equipped Body Part tag

Supported first-pass end effects:

- `set_flag`
- `clear_flag`
- `give_item`
- result hooks such as `encounter`

Dialog presentation assets are tracked in `docs/OverworldAssetManifest.md`.
