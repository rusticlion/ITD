# Into the Dreamlands — Juice Layer

*Drafted July 2026. Companion to `docs/CombatPresentation.md` §10 (Animation Choreography). Covers the feedback primitives: tweens/timers, screen effects, and the audio cue grammar.*

---

## 1. Principles

1. **Juice budget follows frequency inversely.** Per-round events (settles, snaps, ticks) stay subtle and short. Rare beats (heart loss, venting, claiming) get ceremony.
2. **Feedback teaches.** Each sound/effect reinforces a rule: three destinations have three sounds; gunked dice land wetter; burn-off stings slightly.
3. **Decoupled by design.** The juice layer hangs off the combat engine's event stream. Removing `combat/juice.lua` changes nothing mechanical.
4. **Everything respects the global juice scale.** `ScreenFX.set_juice(0)` is reduced motion: no hit-stop, shake, flash, or desaturation. Audio volume is a separate dial (`Audio.set_volume`).

---

## 2. Primitives

### `core/tween.lua`
Group-based tweens and timers. Each owner runs its own group and updates it:

```lua
local group = Tween.group()
group:to(rect, 0.3, { x = 100 }, { ease = "out_cubic", on_complete = fn })
group:after(0.12, function() Audio.play("burn_off") end)
group:update(dt) -- owner's update loop
```

No love dependency; safe in CLI tests. Handles cancel (`Tween.group().cancel(handle)`) and timers scheduled from inside callbacks.

### `core/screenfx.lua`
Global screen effect layer, integrated once in `main.lua`:

```lua
GameState.update(ScreenFX.update(dt)) -- hit-stop filters the game's dt
ScreenFX.begin_frame() / GameState.draw() / ScreenFX.end_frame()
```

- `ScreenFX.hitstop(duration)` — freeze game time (extends, never stacks).
- `ScreenFX.shake(magnitude, duration)` — integer-snapped, capped at 4px. Restraint is the point.
- `ScreenFX.flash(color, duration, peak_alpha)` — full-screen overlay fade.
- `ScreenFX.desaturate(strength, duration)` — canvas+shader pulse; sharp attack, smooth release. Canvas only allocates while active.

### `core/audio.lua` + `data/audio_cues.lua`
Cues are named patches played by id: `Audio.play("assign_rim", { pitch = 1.1 })`. Until real files exist, every cue synthesizes from layered waveforms (sine/triangle/square/noise with glide and decay) — programmer art for the ears. Dropping `assets/sounds/<cue_id>.ogg` (or `.wav`) overrides a cue with no code change. Per-cue pitch variance keeps repetition organic. Unknown cues warn once; `Audio.validate()` surfaces malformed patches. `Audio.on_play` is the test hook.

---

## 3. Combat Sound Grammar

The cue vocabulary mirrors the shape grammar. Keep it stable as sounds improve.

| Domain | Cues |
|---|---|
| Dice | `die_settle`, `die_settle_gunked` (wetter — pool degradation is audible), `die_pick` |
| Destinations | `assign_rim` (latch-clack), `assign_socket` (dock-thunk), `slot_feed` (swallow) |
| Slot bookkeeping | `pip_lit` (pitch rises per pip), `burn_off` (slightly feel-bad on purpose), `slot_armed`, `slot_resolved` |
| Damage tiers | `parry_tick`, `strike_parried`, `strike_hit`, `wound`, `maim`, `heart_loss`, `vent` |
| Resources | `heal`, `crest_gain`, `crest_expend`, `latch_ejected` |
| UI / stings | `invalid`, `victory`, `defeat` |

Big-beat pairings in `combat/juice.lua`:

- **Heart loss:** `heart_loss` + hit-stop 0.18s + red flash + desaturation pulse.
- **Maim:** `maim` + small shake.
- **Vent:** `vent` shatter + small shake — deliberately the best-feeling effect in the game, because venting is the tempo play we want players to chase.

---

## 4. Timing Domains (the one subtle rule)

The combat state presents engine events in two ways, and juice must match:

1. **Real-time events** (Allocation and Upkeep: assignments, feeds, crest expends, immediate Spend damage) are juiced directly from engine subscriptions in `CombatJuice:subscribe()`.
2. **Resolution events** fire in a synchronous burst at Confirm and are replayed through the state's timed playback. These are juiced from `CombatJuice:reveal_resolution(entry)` as each entry reveals. Engine-time handlers skip anything emitted while `engine.state == "RESOLUTION"`.

`build_resolution_entries` carries `vented` onto playback entries so the shatter lands with the wound that caused it. Skipping playback skips the sounds with it.

**Resolution-as-counting.** The playback performs the damage rule instead of announcing it: each entry presents its strike and ward symbols in paired columns, matched pairs dim one tick at a time (`parry_tick`, pitch rising), and only unanswered strikes land. The card frame stays neutral until the outcome tick so the count itself delivers the verdict. Timeline constants (`RESOLUTION_PRESENT_TIME`, `RESOLUTION_TICK_INTERVAL`, tails) live at the top of `states/v2_combat.lua`; entry duration is dynamic in the pair count. When a damage step lands, two 🩸 ghosts rise from the card — the two faces just struck — so pool degradation is witnessed at the moment it happens, not discovered on the next roll.

When adding a new juiced event, first ask which domain it resolves in. Getting this wrong plays the sound seconds before the player sees the cause.

---

## 5. Extending

- **New cue:** add a patch to `data/audio_cues.lua` (validated shape: `layers` with `wave`, `duration`, `freq` unless noise), play it from the appropriate domain hook.
- **Real sounds:** drop files in `assets/sounds/` named by cue id. No code change.
- **Overworld juice:** `Tween`, `ScreenFX`, and `Audio` are already global-safe; overworld states can adopt them directly (footsteps by ground layer, transition signatures, dialog blips are the intended first users).
- **Settings:** `ScreenFX.set_juice()` and `Audio.set_volume()` / `Audio.set_enabled()` are the intended Options-screen bindings; they are not yet persisted in the save profile.
