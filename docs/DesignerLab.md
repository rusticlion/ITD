# Designer Lab

Launch the workbench with:

```sh
love . --designer-lab
```

The lab runs entirely in memory. Basement checkpoints disable autosave and never read or overwrite the normal save slot.

## Scenario Launcher

- `Tab` switches between combat scenarios and Basement checkpoints.
- Arrow keys select; `Enter` launches.
- `/` focuses search.
- Combat scenarios display their deterministic seed.
- Completed designer combats return a compact summary to the launcher.

Direct launch shortcuts:

```sh
love . --scenario=combat.mad_butcher
love . --scenario=combat.butcher_pressure
love . --checkpoint=basement.hidden_dark
love . --room=basement_1 --spawn=5,5
love . --encounter=basement.zombie --seed=1101
```

## Combat Iteration

- `R` restarts the encounter with the same seed.
- `Shift+R` restarts with a new seed.
- The designer end screen reports rounds, final Hearts, damage and healing events, Slot activations, maimed parts, and preserved enemy parts.
- `P` copies the summary to the clipboard.
- `Esc` returns to the lab.

Combat presets may declare initial Body Part statuses and banked Slot charge in `data/designer_scenarios.lua`.

## Basement Iteration

- `F4` toggles the room overlay: tile grid, collision, actors, regions, IDs, types, and player tile.
- `F5` reloads the room module while preserving player position, facing, inventory, held tool, flags, and actor state.
- `1`, `2`, `3` grant and equip FLASHLIGHT, SHOVEL, or RUSTY KEY.
- `0` empties the player's hands.
- `4` toggles `basement.passage_open`.
- `5` toggles `basement.lights_on`.
- `6` toggles `basement.key_found`.
- `7` toggles `basement.boss_door_unlocked`.
- `Esc` returns to the lab.

Checkpoint flags intentionally include planned Basement beats that are not all rendered yet. Tiled actors and runtime behavior can adopt these stable names as the room is authored.
