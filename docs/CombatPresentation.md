# Into the Dreamlands — Combat Presentation & UI Specification v1.1
*Companion to Combat Design Document v2.1. Drafted June 2026.*

---

## 1. Governing Principles

1. **Geometry teaches the rules.** Receptacle shape communicates capacity and consumption; the player learns affordances by hand, not by text.
2. **Icons in the arena, words in the inspector.** The combat field is near-text-free. All rules text routes to one fixed inspection surface.
3. **Universal silhouette, expressive skin.** Component shapes and state machines are invariant; theming varies freely per part and per dream without touching legibility.
4. **The figure is the fantasy.** Art lives on the assembled dreamform, not on the data panels.

---

## 2. Shape Grammar

| Shape | Meaning |
|---|---|
| **Square** | A die, or a die-shaped hole (socket, rim latch, slot intake). Dice go in square holes — the player's one universal motor truth. |
| **Circle** | A pip — consumed energy on a slot track. No longer a die; it changed shape because it changed nature. |
| **Hexagon** | A crest chip in a combatant's tray. |
| **Dashed outline** | Affordance — an empty, legal destination. |
| **Solid** | Commitment — a placed die, a lit pip, an occupied state. |

During drag, every legal destination's dashed outline brightens. Occupied sockets and offline slots do not react. The one-die rule is never stated; full sockets simply aren't drop targets.

Destination validity is symbol-aware:

- A **socket** lights only for dice showing at least one 🛡️.
- A **rim latch** lights only for dice showing at least one 🗡️.
- A **slot hatch** opens only if the die would light at least one unfilled pip on that track.
- A mixed-symbol die may be placed anywhere at least one shown symbol is relevant. Relevant symbols commit; irrelevant symbols visibly burn off.
- A die with no relevant symbols for a destination receives no affordance there: no snap, no hatch, no click.

---

## 3. Component Inventory

### 3.1 Per Body Part — the Panel
Name · Heart value · damage state · **defense socket** (internal, shield-rimmed, holds one of the owner's assigned dice) · **rim latch** (outer edge, holds one enemy attack die) · **slot intake + track** · keyword badge (rare; absent on the median part).

Defense lives *inside* the body; attacks *arrive at* it. The median panel displays zero words of rules text.

There is **no resident die** on a Body Part panel. The originating die does not sit on the part during combat; it appears in the rolled pool and becomes meaningful only when allocated. The panel is the part's destination/control surface, not a storage place for its die.

### 3.2 Per Combatant
Heart pips · crest tray (clickable hex chips; expends resolve during Allocation; chips animate from source slot to tray on gain) · the assembled **figure** (§5).

### 3.3 Global
Rolled pool tray (drains as allocated; spent cells show dashed) · queue ticker (filled-slot chips in FIFO order — the untutorialized advanced read) · initiative + round banner · **Confirm** (the only phase-control button) · inspector rail (§6) · collapsible combat log.

Confirm performs soft validation only: "2 dice unallocated — confirm anyway?" Abandoning dice is legal.

Allocation moves are committed as made. There is no Undo button in the first implementation because Spend-window slot effects and crest expends may resolve immediately and change the remaining allocation state.

### 3.4 Rolled Dice — Origin Linking
Each pool die remains visually tied to its originating Body Part without living on that part:

- On hover, the die's source BP name and card highlight.
- If central figures are present, the corresponding limb glows at the same time.
- On the Roll step, each die may animate into the pool from its source BP or source limb, establishing ownership before allocation begins.
- The inspector for a pool die shows its source BP, current face, and gunked state.

The rule: a die is **from** a Body Part, but it is never **stored on** that Body Part during combat.

---

## 4. The Slot Intake — Hatch State Machine

A die-shaped intake with a pip track extending from one fixed edge. Physical metaphor: the coin slot. States:

1. **Rest** — hatch shut, unlit pips dashed.
2. **Hover** — hatch opens *only if at least one pip would light* (rules enforcement at the affordance layer). Pips that would light glow as a preview; symbols that would burn are shown as fading ghosts past the track end. The player evaluates mixed-face waste before releasing the button.
3. **Swallow** — hatch closes on the die mid-drop. Consumption, animated.
4. **Count** — pips light *sequentially* (payment counted frame by frame); surplus symbols drift off the track and fade (waste shown, not implied).
5. **Charging** — lit pips persist across rounds. Distinct color from —
6. **Full → enqueued** — track flips to the armed color; a chip joins the queue ticker. A pending event, no longer a resource.
7. **Vented** — on wound: pips shatter, hatch rattles.
8. **Offline** — on maim: hatch boarded over, track grayed.

Exception tell: a **Hungry** slot's hatch is always open — the visual exception matches the mechanical one, legible before any text is read.

**Skinning:** hatch art is diegetic per part (furnace door on the Butcher's arm; a textbook cover on the Scholar's hand; something wetly organic in the Jungle). Silhouette, footprint, track edge, and state set never vary.

---

## 5. Stage Layout

```
┌──────────────────────────────────────────────┬───────────┐
│  ENEMY PANEL STRIP   · hearts · crest tray   │           │
├──────────────────────────────────────────────┤ INSPECTOR │
│                 [enemy figure]               │   RAIL    │
│        CENTER STAGE                          │  (fixed,  │
│  [player figure]                             │  collaps- │
├──────────────────────────────────────────────┤  ible)    │
│  POOL · queue · initiative · CONFIRM         │  + log    │
├──────────────────────────────────────────────┤           │
│  PLAYER PANEL STRIP  · hearts · crest tray   │           │
└──────────────────────────────────────────────┴───────────┘
```

- **The figure is anatomical; the panels are rational.** Each combatant's figure is eventually a composite sprite assembled from its six part-sprites on a fixed anchor rig. Panels sit in dense, regular strips. Hover-linking glues them: hovering a panel highlights its limb and vice versa.
- **First implementation:** the center stage may omit paper-doll figures entirely. Leave negative space for future figures and resolution animation, but make the BP cards the complete interaction surface.
- **Pokemon diagonal:** when figures are present, player figure lower-left and enemy upper-right — the Gen-era battle composition, declaring the aesthetic lineage before a sprite exists.
- The figure is a future **drop-target alias**: dropping a die on a limb equals dropping it on that limb's panel. Until figures exist, cards are the only drop targets.
- The center stage hosts resolution: dice fly to rims, slots flash, and later wounds and 🩸 render diegetically on the figures.
- Rim latches face the center stage: enemy latches sit along the lower edge of enemy panels; player latches sit along the upper edge of player panels. Attacks visually arrive from the arena.
- **Hidden allocation (contested initiative):** enemy rims show face-down dice; enemy hatches play a swallow with no pip reveal. Feed *counts* leak by design (bluffing layer — flagged as an open decision in the design doc). **Enemy initiative:** the player's committed board renders locked while the enemy responds — the screen itself sells the information loss.

---

## 6. Inspector Rail

One fixed surface (right rail) for all text, all objects, one gesture: hover or select anything — a slot, a die, a crest, a queued chip, an enemy part — and its name + effect text appears in the same place every time. Eye-to-words is one saccade to one known location.

- **Live during drag:** cost preview, burn warning, pip forecast — readable mid-drag, when pop-ins would flicker.
- **Idle state:** queue detail, initiative explanation, collapsible combat log (a free renderer over the engine's event stream — debugging tool and player-trust tool in one).
- **Collapsible with pin toggle** for minimalists, who fall back to cursor-adjacent mini-tooltips.
- Rejected alternative, for the record: far-side-from-cursor pop-in. It places the same object's text in different screen locations depending on approach direction, preventing reading-reflex formation, and it fights the drag state.

---

## 7. The Planning Screen (Out of Combat)

Each owned part displays as **one unfolded cube with its wounds painted on**: the healthy face layout shown directly, wound-struck faces marked with a light overlay (crack motif), maim-struck faces with a heavy one. One layout, all three states legible — the degradation path read as annotation. Overworld tags (STRONG, SCHOLARLY) display here and only here. Slot text via the same inspector pattern.

---

## 8. The Claiming Ceremony

On victory, the enemy figure stands wounded; the player selects a non-maimed part; it visibly **detaches from their body and grafts onto yours** before the next dream. Five seconds that make the entire progression system tangible — and the body-horror beat the jam playtesters loved before they understood a single rule. Budget polish here disproportionately.

---

## 9. Art Pipeline Spec

The anchor rig converts part art from negotiation to folder convention:

- One standard canvas size per part type (HEAD, BODY, ARM, LEG), registered to the rig's attachment point.
- Deliverable per part: sprite states for healthy / wounded / maimed (wounds and 🩸 visible on the flesh), plus the hatch skin.
- **Mismatched proportions are the fantasy, not a defect.** A dreamform with a monstrous butcher arm and a delicate scholar hand is the intended exquisite-corpse image; dream logic waives the harmony requirement that usually makes modular sprite systems expensive.
- Part art is exactly as data-driven as part dice: `parts/<dream>/<part_id>/` containing die definition, slot definition, and sprite set.

---

## 10. Animation Choreography Notes

- Hatch sequence (§4) is the rules tutorial; never skip frames 2–4 on a player's first feeds.
- Venting and offline states reuse one component's vocabulary — the whole damage model legible through the slot intake alone.
- Crest gain: chip flies slot → tray (teaches the source).
- Queue resolution: chips consume left-to-right off the ticker (teaches FIFO by observation).
- Keep the full allocation→resolution loop snappy; resolution animations must be batch-accelerable or skippable from the first build, or 3–5 round fights will drag by round two of playtesting.
