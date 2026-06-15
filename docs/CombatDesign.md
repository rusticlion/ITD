# Into the Dreamlands — Combat Design Document v2.2
**The Symbol Dice System**
*Drafted June 2026. Supersedes v1 (numeric dice / Tech-Action model). v2.2 clarifies destination capacity, mixed-symbol validity, immediate Spend timing, the initial crest prototype set, and the Lua content definition shape.*

---

## 0. The Index Card

The complete universal ruleset. Everything else in this document is content, exception, or elaboration.

1. Each combatant is up to 6 Body Parts and 3 Hearts. Maiming a part costs its owner that part's Heart value. 0 Hearts = defeat.
2. Each Body Part carries one symbol die. Every round, all dice are rolled into the owner's pool.
3. During Allocation, each die goes to exactly one destination:
   - **Socket** (own part; capacity 1) — accepts a die showing at least one 🛡️; its 🛡️ defend that part.
   - **Rim** (enemy part; capacity 1) — accepts a die showing at least one 🗡️; its 🗡️ attack that part.
   - **Slot** (any number of dice) — accepts a die only if at least one shown symbol lights an unfilled cost pip; the die is consumed; surplus symbols are lost.
4. A die travels whole. Mixed-symbol faces are legal if any shown symbol is relevant to the destination; irrelevant symbols burn off. Unallocated dice are lost.
5. At Resolution, per part: if assigned 🗡️ exceed assigned 🛡️, the part takes one damage step (Healthy → Wounded → Maimed).
6. A slot triggers automatically the moment its cost track fills, enqueued FIFO, resolving at its declared timing window. Wounding a part vents its slot's charge. Maiming takes the slot offline.
7. Initiative governs allocation visibility (see §5). The player has initiative by default.

---

## 1. Core Philosophy

Combat is a strategic puzzle about reading a position and spending a hand of dice. Resolution is counting, not arithmetic. Depth lives in allocation decisions, slot timing, and target selection — never in rules text. **Universal rules stay on the index card; everything expressive lives in content** (dice layouts, slots, crests, rare keywords).

Design north stars carried forward from v1: no dominant strategy, meaningful damage, calculated risk, build expression, readable complexity, failforward.

---

## 2. Symbols & Dice

### 2.1 The Symbol Set
| Symbol | Name | Role |
|---|---|---|
| 🗡️ | Strike | Offense. Assigned via rims. |
| 🛡️ | Ward | Defense. Assigned via sockets. |
| ⚡️ | Essence | Slot fuel; primary crest-generation vector. |
| 🩸 | Blood | Injury byproduct. Generally inert; fuels specific slots. |
| ⚪ | Blank | Nothing. The variance dial. |

Faces may carry one, two, or (rarely) three symbols. Multi-symbol faces (🗡️🗡️, 🗡️🛡️, ⚡️⚡️) are how force concentrates under the one-die-per-destination cap, making them the premium design currency.

### 2.2 The Die as Character Portrait
Each Body Part's die is its mechanical fingerprint. Face distribution communicates personality at a glance:

- Reliable defender: `[🛡️][🛡️][🛡️][🛡️][🛡️][🗡️]`
- Glass cannon: `[🗡️🗡️🗡️][🗡️🗡️][⚪][⚪][⚪][⚪]`
- Versatile caster: `[⚡️][⚡️][🛡️][🗡️][⚡️🛡️][⚪]`

### 2.3 Degradation (🩸 Gunking)
Each part's data **predetermines** its wound-faces and maim-faces. This is an ironclad 2/2/2 structure: exactly two faces fall to Wounded, exactly two further faces fall to Maimed, and exactly two faces remain durable.

- **Wounded:** two specified faces are struck and replaced with 🩸.
- **Maimed:** two further specified faces are struck and replaced with 🩸. The part's die still rolls.

The player never loses dice; their pool gunks up with blood. Degradation paths are part of the fingerprint: a part that loses its blanks first *hardens under pain*; one that loses its 🗡️🗡️ faces first is *fragile brilliance*. Authoring rule: choose struck faces to express character, and remember 🩸 output makes blood-cost slots easier to feed — wounded combatants drift toward desperate techniques.

---

## 3. Body Parts

Each Body Part defines:

| Field | Notes |
|---|---|
| Name, type | HEAD / BODY / ARM ×2 / LEG ×2. Fewer than 6 parts is legal. |
| Heart value | Hearts lost by owner when this part is maimed (1–3). |
| Status | Healthy → Wounded → Maimed. |
| Die | 6 faces + predetermined wound-faces and maim-faces. |
| Slot | Usually exactly one (see §6). Zero or two are rare exceptions. |
| Keyword | Rare. Most parts have none (see §8). |
| Overworld tags | STRONG, SCHOLARLY, etc. **Never displayed in combat.** Drives exploration interactions and resonance. |

The v1 concepts of **Toughness** (dissolved into die composition and the rare Armored keyword) and **Techs** (collapsed into slots) no longer exist.

### 3.1 Combat Content Definitions

Prototype combat content lives in Lua table modules under `data/combat/`. The engine does not construct ad hoc parts directly; content definitions pass through `combat/v2_content.lua`, which validates references and builds runtime `BodyPart` / `Combatant` objects.

Each content module returns three top-level tables:

| Table | Purpose |
|---|---|
| `slots` | Reusable named slot definitions: `id`, `name`, `cost`, `timing`, `effect`. |
| `parts` | Body Part definitions: `id`, `name`, `type`, `hp_value`, `die`, optional `slot`, optional `keywords`, optional overworld `tags`. |
| `loadouts` | Combatant assembly definitions: `id`, `name`, optional `is_player`, optional `crest_pool`, and ordered `parts`. |

Authoring rules:

- A die must define exactly 6 faces. Each face may be a symbol string (`"strike"`) or a list (`{ "strike", "ward" }`).
- `wound_faces` and `maim_faces` are face-index lists, 1–6. Each list must contain exactly two unique indexes, and the two lists may not overlap.
- A part's `slot` may be a key into `slots` or an inline slot table.
- A loadout's `parts` order is also its first-pass panel order in the current UI prototype. The UI reserves six fixed card slots per combatant.
- Validation catches missing names/types, missing die faces, invalid degradation indexes, unknown slot references, and loadouts pointing at unknown parts.

The first live example is `data/combat/v2_demo_parts.lua`. Keep it intentionally tiny: it exists to validate the pattern, not to balance real content.

---

## 4. Round Structure

1. **Upkeep** — trigger/expire effects; resolve Upkeep-window queued slots; process crest passives.
2. **Roll** — all equipped dice roll into each combatant's pool. Automatic.
3. **Allocation** — the round's single input phase. Each combatant distributes dice to sockets, rims, and slots, and may expend crests. Visibility per initiative (§5). Ends on Confirm.
4. **Resolution** — per contested part, compare assigned 🗡️ vs assigned 🛡️; apply damage steps; fire On-Hit and On-Wound/Maim queued slots in FIFO order; process venting and gunking.
5. **End** — check victory; increment round.

### 4.1 Damage
A part is **hit** when assigned 🗡️ > assigned 🛡️ on that part. A hit advances status one step. Margin of overkill has no additional effect (open question — see §10).

---

## 5. Initiative

Initiative is a combat state governing allocation information. **The player holds initiative by default** — the tilt is deliberate: against an AI, hidden commitment is a coin flip wearing a trenchcoat; visible enemy allocation makes every round a legible puzzle.

| State | Allocation visibility |
|---|---|
| **Player initiative** (default) | Enemy allocates first, fully visible. Player allocates with complete information. |
| **Contested** | Hidden simultaneous allocation; reveal at Resolution. Elite encounters. |
| **Enemy initiative** | Player commits first; enemy responds with full information. Boss phases. Oppressive; use rarely. |

Game effects shift initiative: crest expends (Knowledge), enemy abilities that steal it, boss phase transitions. Difficulty escalates through information, not stat inflation. **Balance every standard encounter assuming the player sees enemy allocation**; if ordinary fights need initiative theft to threaten, the dice need sharpening instead.

---

## 6. Slots

A slot is: **a name + a cost track of symbol pips + an effect + a timing window.**

### 6.1 Feeding
- During Allocation, any number of dice may be fed to a slot.
- A fed die is consumed. Each of its symbols lights a matching unlit pip; symbols with no matching pip **burn off** (lost).
- A feed is only legal if at least one pip would light (enforced at the affordance layer — the hatch won't open).

### 6.2 Charge
- Partially lit tracks **persist between rounds**. No decay.
- No overcharge: a track cannot hold more than its cost.
- **Mandatory trigger:** the instant the last pip lights, the slot fires — enqueued FIFO, resolving at its timing window. **Spend-window effects resolve immediately during Allocation**, before the player assigns later dice. Timing control is preserved because feeding is voluntary: hold at cost-minus-one and choose your round.
- **Venting:** wounding a part shatters all charge on its slot (slot remains operational).
- **Offline:** maiming a part disables its slot entirely. Wound *robs*; maim *disables*.
- All charge resets between combats.

Banked charge is self-balancing: it paints a target (the battery demands a socket every round) while the attacker allocates with that knowledge. Turtling taxes itself.

### 6.3 Timing Windows
Every slot declares exactly one: **Spend** (fires immediately during Allocation), **On Hit**, **On Wound/Maim**, **Upkeep**. The engine exposes exactly these four hooks. Allocation is a sequence of committed moves, not a draft to be rewound; immediate Spend effects are allowed to modify the remaining allocation state (rerolls, symbol changes, next-die bonuses, sealed destinations, etc.).

### 6.4 Queue
Filled slots enqueue in fill order and resolve FIFO within their window. Deliberately untutorialized — discoverable through the queue ticker.

### 6.5 Example Slots
- **Bloodlust** — 🗡️🗡️🗡️ · Spend · This round's attacks from this combatant gain Brutal.
- **Hex** — ⚡️🗡️ · Spend · Target enemy part's socket is sealed this round.
- **Insight** — ⚡️⚡️ · Spend · Gain a Knowledge crest.
- **Last Resort** — 🩸🩸🩸 · Spend · Heal one of your parts one step. *(Blood costs come online as you bleed — the built-in comeback vector.)*
- **Overload** *(enemy ability)* — injects a charge into one of the player's tracks, weaponizing mandatory trigger by detonating the effect on the wrong round.

---

## 7. Crests

Combatant-level resources held in a tray; never attached to parts; reset between combats. The beneficial/detrimental split and the expend paradigm carry forward from v1. Primary generation: ⚡️-fed slots and Resonance (overworld, capped — see v1 Resonance design, unchanged).

For the first v2 prototype, implement only enough crests to validate the pattern. Crests are the manipulation layer over dice, allocation timing, initiative, and targeting state:

| Crest | Expend |
|---|---|
| Valor | Add one 🗡️ to the next die you assign this Allocation. This may make a die rim-valid; if the die is assigned elsewhere, the added 🗡️ burns off like any irrelevant symbol. |
| Shadow | Until the next Upkeep, whenever one of your Body Part slots activates, that Body Part becomes Untargetable. If an attack die is already latched to that part, the latch is ejected and the attack die is lost. |
| Knowledge, Cunning | Hold for later prototypes; likely initiative/allocation manipulation. |
| Madness, Greed, Corruption | Detrimental set: expends function as costs paid to purge. TBD. |

Shadow is intentionally near the complexity ceiling for crest expends in the first implementation. If Shadow is readable and implementable, simpler expends should fit the model.

---

## 8. Keywords (Expressive Exceptions)

Rare, badge-displayed, one per part at most. The universal rules never reference them. Provisional catalog:

- **Armored** — ignores the first assigned 🗡️ each round. (For enemies whose puzzle is "you cannot chip this; commit.")
- **Hungry** — this part's slot accepts any die; every symbol lights a generic pip. (Visual tell: hatch always open.)
- **Brace** *(slot effect)* — add one 🛡️ to every part where you assigned a 🛡️. Wide defense.
- **Flurry** *(slot effect)* — add one 🗡️ to every enemy part where you assigned a 🗡️. Wide offense.
- **Bulwark** *(slot effect)* — one defended part cannot be maimed this round. Tall defense.
- **Split** *(slot effect)* — divide one mixed-face die's symbols between two destinations. (Makes 🗡️🛡️-heavy dice a build-around.)
- **Meld** *(slot effect)* — combine two dice into one assignment token before placement. The target socket/rim still has capacity 1; Meld changes the token, not the destination rule.

---

## 9. Strategy Space (Design Intent)

The system must support two coherent archetypes, each demanding different dice, slots, and defensive answers:

- **Tall** — concentrate multi-symbol faces on one part; maim it; race Hearts. Counterplay: Bulwark, Armored, Shadow.
- **Wide** — chip wounds across many parts; gunk the opponent's entire pool with 🩸; win the symbol economy. Counterplay: Brace, healing, fast aggression.

Head-punching is kept honest not by toughness stats but by: the one-die-per-destination cap, asymmetric part value across enemies (the scary die on a 1-Heart arm forces the disarm-vs-race fork), venting (wounding *any* charged part steals tempo), and wide play's pool-degradation payoff.

---

## 10. Open Questions — Paper Prototype Checklist

Testable with blank dice + stickers (or d6s + lookup cards), index cards per part, coins for pips. Run before any engine code.

1. **Pacing.** With ~6 attack-capable dice and a 1-net-🗡️ wound threshold, do fights end in 2 rounds of mutual shredding? If too fast, candidate brake: hits on Healthy wound; only hits on Wounded maim (already implied by steps — verify it's enough).
2. **Overkill margin.** Should beating defense by 3+ matter (e.g., skip Wounded)? Default: no.
3. **Blanks.** Pure whiffs, or soft currency (two blanks → a reroll)? Default: pure whiffs; revisit if feel-bad.
4. **Allocation time.** Must stay under ~1 minute at the table with 6 dice + slots + crests. If it drags physically, no UI saves it.
5. **Mixed faces.** Do the validity and burn-off affordances make whole-die travel read as "flexible hedge" rather than "wasteful trap"? Split's value depends on the answer.
6. **Hidden-feed leakage.** Under contested initiative, the swallow animation reveals feed *counts* but not pips. Keep (bluffing layer) or fully hide? Current lean: keep.
7. **Crest expansion.** After Valor and Shadow validate the pattern, which crests earn prototype slots next?
8. **Multi-slot parts / slotless parts.** How rare? Default: exactly one slot per part for the alpha.

## 11. Balance Targets (carried from v1, revised)

- Average combat: 3–5 rounds. Decisions per round: one allocation puzzle of 6–8 placements.
- Player win rate: ~40% learning → ~80% mastered.
- RNG impact: the roll sets the hand; the allocation plays it. Variance is authored per part via blanks and multi-faces, not global.
- Combat remains strictly 1v1.

---

*Companion document: `docs/CombatPresentation.md` — UI, shape grammar, animation choreography, art pipeline.*
