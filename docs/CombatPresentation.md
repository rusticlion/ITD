# Into the Dreamlands — Combat Presentation & UI Specification v1.2
*Companion to Combat Design Document v2.2. Drafted June 2026.*

---

## 1. Governing Principles

1. **Geometry teaches the rules.** Receptacle shape communicates capacity and consumption; the player learns affordances by hand, not by text.
2. **Icons in the arena, words in the inspector.** The combat field is near-text-free. All rules text routes to one fixed inspection surface.
3. **Universal silhouette, expressive skin.** Component shapes and state machines are invariant; theming varies freely per part and per dream without touching legibility.
4. **The figure is the fantasy.** Art lives on the assembled dreamform, not on the data panels.
5. **Fixed footprints, layered overlays.** Cards, dice, hatches, and chips have stable pixel dimensions. State, text, effects, and ownership render as overlays; components do not stretch to fit content.

---

## 2. Shape Grammar

| Shape | Meaning |
|---|---|
| **Square** | A die, or a die-shaped hole (socket, rim latch, slot intake). Dice go in square holes — the player's one universal motor truth. |
| **Symbol cell** | A cost/charge pip on a slot track, using the same symbol sprites as die faces. No longer a die; it changed context, not vocabulary. |
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
Fixed-size BP card sprite · external name label · **defense socket** (internal, shield-rimmed, holds one of the owner's assigned dice) · **rim latch** (outer edge, holds one enemy attack die) · **slot intake + track** · compact HP/keyword badge zone · damage-state surface treatment.

Defense lives *inside* the body; attacks *arrive at* it. The socket and rim are visual neighbors on the card edge facing center stage. The card interior is an interaction surface, not a status sheet: name, exact health text, and effect explanations live outside the surface or in the inspector.

There is **no resident die** on a Body Part panel. The originating die does not sit on the part during combat; it appears in the rolled pool and becomes meaningful only when allocated. The panel is the part's destination/control surface, not a storage place for its die.

### 3.2 Per Combatant
Heart pips · crest tray (clickable hex chips; expends resolve during Allocation; chips animate from source slot to tray on gain) · the assembled **figure** (§5).

### 3.3 Global
Rolled pool tray (dice are dragged from here to destinations; spent cells show dashed) · queue ticker (filled-slot chips in FIFO order — the untutorialized advanced read) · initiative + round banner · **Confirm** (the only phase-control button) · inspector rail (§6) · collapsible combat log.

Confirm performs soft validation only: "2 dice unallocated — confirm anyway?" Abandoning dice is legal.

Allocation moves are committed as made. There is no Undo button in the first implementation because Spend-window slot effects and crest expends may resolve immediately and change the remaining allocation state.

### 3.4 Rolled Dice — Origin Linking
Each pool die remains visually tied to its originating Body Part without living on that part:

- On hover, the die's source BP name and card highlight.
- If central figures are present, the corresponding limb glows at the same time.
- On the Roll step, each die may animate into the pool from its source BP or source limb, establishing ownership before allocation begins.
- The inspector for a pool die shows its source BP, current face, and gunked state.

The rule: a die is **from** a Body Part, but it is never **stored on** that Body Part during combat.

### 3.5 Fixed Footprints

The target native combat canvas is **960×540**. This is the game's current baseline render size: low enough to preserve the chunky, pixel-forward 2000s handheld feel, but large enough for six-part combat plus a fixed inspector.

The first real visual pass should commit to static component dimensions rather than stretching cards to fill the strip. The combat screen reserves **six BP card slots per combatant** even when a prototype loadout contains fewer than six parts. Empty slots render as placeholders; full content will usually occupy all six.

Fixed footprints support sprite replacement:

- BP cards are drawn from a fixed card sprite with text and state overlays.
- BP card footprint: **116×88**.
- Dice, socket, rim latch, and hatch intake share a **36×36** interaction footprint. Die art may include transparent internal margin, but the token never changes size between pool and assignment.
- Symbol sprites are **12×12** and are reused for die faces, slot costs, lit charge, and burn-off ghosts.
- Symbols are sprites layered inside dice faces and assignment previews.
- Socket, rim, and hatch locations are authored relative to the card footprint, not recalculated from card width.
- Body Part names render in a fixed external label strip on the edge away from center stage: enemy labels above their cards, player labels below. Long names truncate or wrap inside that label region; card size never changes to accommodate text.
- First-pass 960×540 layout: 12px outer margins, 180px inspector rail, six 116px cards + five 8px gaps = 736px card row inside a 744px main area.

### 3.6 Visual Component Checklist

This is the working asset/component inventory for the real combat screen. Wireframes may fake these with rectangles, but the implementation should reserve a stable conceptual slot for each item.

**BP card stack**

- Base card sprite: player / enemy tint variants.
- Empty card placeholder sprite.
- Hover, selected-source, valid-drop, invalid/offline, and targetable-state outline overlays.
- External name label and optional truncation/focus marquee behavior.
- Compact HP badge, eventually logographic rather than text.
- Damage surface treatment: healthy, wounded, maimed (cracks, discoloration, offline/ruined treatment) instead of a colored status pip.
- Rare keyword badge.
- Status/effect badges: Untargetable, sealed socket, shrouded slot, etc.

**Socket/rim assignment layer**

- Defense socket sprite: empty, valid-hover, occupied, locked/offline.
- Attack rim latch sprite: empty, valid-hover, occupied, locked/offline.
- Assigned die rendering in socket/rim, including owner tint and face symbols.
- Burn-off overlay for mixed-symbol waste on assignment.
- Future animation handles: die fly-in path, latch snap, socket dock, ejection.

**Slot/hatch layer**

- Hatch/intake sprite states: rest, hover-open, swallow, charging, full/enqueued, vented, offline.
- Slot track symbol cells: unlit/outline, preview, lit/charged, armed, vented, disabled.
- Slot name short label.
- Pip burn-off ghosts for surplus symbols.
- Queue-chip spawn point and slot-to-queue animation anchor.

**Dice pool**

- Pool cell sprite: empty, occupied, selected.
- Die token sprite with source-owner tint.
- Symbol sprites: Strike, Ward, Essence, Blood, Blank.
- Multi-symbol face layout rules for one-, two-, and three-symbol faces.
- Origin-link overlay: source BP/card glow, optional future limb glow.
- Drag ghost / cursor-follow token.

**Crests**

- Crest chip base sprite by type.
- Count badge.
- Spend-hover, spend-armed, disabled/empty, and passive-active overlays.
- Crest fly-to-tray animation target.

**Global chrome**

- Combatant heart pips.
- Initiative/round banner.
- Queue ticker chips and FIFO consume animation.
- Confirm button and warning state for unallocated dice.
- Inspector rail panels: object header, rules text, cost preview, unfolded die layout, log rows.
- Center-stage backdrop/negative-space plate for later paper dolls.
- Future paper-doll anchors, limb hover glows, wound flashes, and claiming/grafting animation targets.

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
- Rim latches face the center stage: enemy latches sit along the lower edge of enemy panels; player latches sit along the upper edge of player panels. Their corresponding defense sockets sit immediately inside the card on the same edge. Attacks visually arrive from the arena, and defense visually meets them at the border.
- **Hidden allocation (contested initiative):** enemy rims show face-down dice; enemy hatches play a swallow with no pip reveal. Feed *counts* leak by design (bluffing layer — flagged as an open decision in the design doc). **Enemy initiative:** the player's committed board renders locked while the enemy responds — the screen itself sells the information loss.

---

## 6. Inspector Rail

One fixed surface (right rail) for all text, all objects, one gesture: hover or select anything — a slot, a die, a crest, a queued chip, an enemy part — and its name + effect text appears in the same place every time. Eye-to-words is one saccade to one known location.

- **Live during drag:** cost preview, burn warning, pip forecast — readable mid-drag, when pop-ins would flicker.
- **Drag focus:** while a die is held, the rail shows only the resolved face, source Body Part, and current drop-target preview. Full die distribution / unfolded-cube detail is intentionally suppressed during drag; the player is placing a resolved token, not evaluating the part's whole die anatomy.
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
