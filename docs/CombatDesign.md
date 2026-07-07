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
| Flavor | Optional short prose string for planning screens, editors, claiming text, and other non-combat surfaces. |
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
| `slots` | Reusable named slot definitions: `id`, `name`, `cost`, `timing`, `effect`, optional `hungry` / `keywords`. |
| `parts` | Body Part definitions: `id`, `name`, `type`, `hp_value`, `die`, optional `slot`, optional `keywords`, optional overworld `tags`. |
| `loadouts` | Combatant assembly definitions: `id`, `name`, optional `is_player`, optional `crest_pool`, and ordered `parts`. |

Authoring rules:

- A die must define exactly 6 faces. Each face may be a symbol string (`"strike"`) or a list (`{ "strike", "ward" }`).
- `wound_faces` and `maim_faces` are face-index lists, 1–6. Each list must contain exactly two unique indexes, and the two lists may not overlap.
- A part's `slot` may be a key into `slots` or an inline slot table.
- Hungry slots still author a `cost` list to define track length, but display and resolve those pips as wildcards. Author as `hungry = true` or `keywords = { "Hungry" }`.
- A loadout's `parts` order is also its first-pass panel order in the current UI prototype. The UI reserves six fixed card slots per combatant.
- Validation catches missing names/types, missing die faces, invalid degradation indexes, unknown slot references, unknown effect payloads, unknown crest names, and loadouts pointing at unknown parts.

The current live alpha content starts in `data/combat/alpha_basement.lua`, with `data/combat/content_index.lua` listing modules that should be treated as authored game content. `data/combat/v2_demo_parts.lua` remains a useful fixture/sandbox bucket; don't treat it as the canonical alpha loop.

Combat entry points resolve through `data/combat/encounters.lua`: each encounter names a content module plus player/enemy loadouts. Existing debug IDs can remain as aliases while room content moves toward namespaced IDs like `basement.bone_demon`.

Launch a catalog encounter directly while iterating with:

```sh
love . --encounter=basement.zombie
love . --encounter=basement.mad_butcher
```

---

## 4. Round Structure

1. **Upkeep** — trigger/expire effects; resolve Upkeep-window queued slots; process crest passives.
2. **Roll** — all equipped dice roll into each combatant's pool. Automatic.
3. **Allocation** — the round's single input phase. Each combatant distributes dice to sockets, rims, and slots, and may expend crests. Visibility per initiative (§5). Ends on Confirm.
4. **Resolution** — per contested part, compare assigned 🗡️ vs assigned 🛡️; apply damage steps; fire On-Hit and On-Wound/Maim queued slots in FIFO order; process venting and gunking.
5. **End** — check victory; increment round.

### 4.1 Damage
A part is **hit** when assigned 🗡️ > assigned 🛡️ on that part. A hit advances status one step. Margin of overkill has no additional effect (open question — see §10).

Resolution counts 🗡️/🛡️ from an assignment's full effective face (`assignment.symbols`). `used_symbols` and `burned_symbols` classify destination relevance for affordances, animation, and spellmarks; they are not a second combat tally. Thus an Essence-only die accepted by a rim spellmark is visibly used by the mark but contributes zero 🗡️ pressure.

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
- A slot may declare a structured `dynamic_cost`. The first prototype rule, `opponent_damaged_parts`, shortens the active track at Upkeep for each Wounded or Maimed opposing part, down to its authored minimum. Banked charge persists. If contraction completes the active track, mandatory trigger fires immediately.

Banked charge is self-balancing: it paints a target (the battery demands a socket every round) while the attacker allocates with that knowledge. Turtling taxes itself.

### 6.3 Timing Windows
Every slot declares exactly one: **Spend** (fires immediately during Allocation), **On Hit**, **On Wound/Maim**, **Upkeep**. The engine exposes exactly these four hooks. Allocation is a sequence of committed moves, not a draft to be rewound; immediate Spend effects are allowed to modify the remaining allocation state (rerolls, symbol changes, next-die bonuses, sealed destinations, etc.).

Reactive timing is local to the Slot's Body Part. A filled On-Hit Slot arms during Allocation and resolves only after that part suffers a contested hit. Its On-Wound/Maim entries then resolve against the same completed damage event. Other parts' armed entries remain queued. Trigger context includes the attack, defense, symbol counts, attacker/target, and resulting status change.

### 6.4 Queue
Filled slots enqueue in fill order and resolve FIFO within their window. Part-scoped reactive windows preserve FIFO among entries armed on that part without draining matching entries elsewhere. Deliberately untutorialized — discoverable through the queue ticker.

### 6.5 Example Slots
- **Bloodlust** — 🗡️🗡️🗡️ · Spend · This round's attacks from this combatant gain Brutal.
- **Hex** — ⚡️🗡️ · Spend · Target enemy part's socket is sealed this round.
- **Insight** — ⚡️⚡️ · Spend · Gain a Knowledge crest.
- **Last Resort** — 🩸🩸🩸 · Spend · Heal one of your parts one step. *(Blood costs come online as you bleed — the built-in comeback vector.)*
- **Overload** *(enemy ability)* — injects a charge into one of the player's tracks, weaponizing mandatory trigger by detonating the effect on the wrong round.

### 6.6 Prototype Effect Vocabulary

Slot effects may be authored as a single effect table:

```lua
effect = { type = "add_next_symbol", symbol = Symbols.STRIKE }
```

or as an ordered sequence:

```lua
effect = {
    actions = {
        { type = "add_symbol_to_matching_dice", match = Symbols.ESSENCE, symbol = Symbols.STRIKE, destination = "rim" },
        { type = "add_next_symbol", symbol = Symbols.WARD }
    }
}
```

Current structured effect types:

- `add_next_symbol` — add one or more symbols to the next die assigned this Allocation.
- `add_symbol_to_matching_dice` — until the next Upkeep, dice showing `match` gain `symbol`; optional `destination` can limit the bonus to `socket`, `rim`, or `slot`. Allocation modifiers all share this lifetime rather than carrying per-effect duration metadata.
- `assign_symbol_to_each_part` — create virtual assignments on every open matching destination, e.g. a Force Field that assigns one 🛡️ to each unwarded friendly socket.
- `open_spellmark` — temporarily alters existing rims or sockets to accept Essence; the first matching Essence assignment marks that part and resolves an `on_mark` payload.
- `heal_part` — heal the Slot's `source_part`, the combatant's `most_damaged` part, or an allied `part_type`.
- `add_symbol_against_status` — until the next Upkeep, dice showing `match` gain `symbol` when assigned to a destination on a Healthy or Wounded target. The target is part of symbol evaluation, so previews, validity, AI scoring, and resolution all see the same effective face.
- `damage_opponent_part`, `gain_crest` — early prototype utility effects.

This vocabulary intentionally models magical conversion as visible added symbols rather than hidden “counts as” state. Essence remains Essence; a Slot can temporarily make Essence dice carry extra tactical weight.

Prototype spellmark shape:

```lua
effect = {
    type = "open_spellmark",
    destination = "rim",
    symbol = Symbols.ESSENCE,
    on_mark = { type = "damage_marked_part", amount = 1 }
}
```

Spellmarks are not a third placement zone. They temporarily make an existing destination accept Essence, so an Essence-only die can mark an enemy rim but applies no Strike pressure, while a Strike+Essence face can both attack and mark.

---

## 7. Crests

Combatant-level resources held in a tray; never attached to parts; reset between combats. The beneficial/detrimental split and the expend paradigm carry forward from v1. Primary generation: ⚡️-fed slots and Resonance (overworld, capped — see v1 Resonance design, unchanged).

For the first v2 prototype, implement only enough crests to validate the pattern. Crests are the manipulation layer over dice, allocation timing, initiative, and targeting state:

| Crest | Expend |
|---|---|
| Valor | Add one 🗡️ to the next die you assign this Allocation. This may make a die rim-valid; if the die is assigned elsewhere, the added 🗡️ burns off like any irrelevant symbol. |
| Shadow | Until the next Upkeep, whenever one of your Body Part slots activates, that Body Part becomes Untargetable. If an attack die is already latched to that part, the latch is ejected and the attack die is lost. |
| Madness | **Detrimental — implemented.** Held: at 3+ Madness, the whispers move your hand — at the start of your Allocation one of your dice is committed to a random legal destination before you gain control (applies to either combatant). Expend ("pinch yourself"): wound a random **Healthy** Body Part you own to purge one Madness. The pinch cannot maim and is refused if no part is Healthy — you cannot pinch yourself awake when nothing is whole. Pinch wounds gunk your pool with 🩸, which feeds blood-cost slots: madness pays forward into desperation techniques. |
| Knowledge, Cunning | Hold for later prototypes; likely initiative/allocation manipulation. |
| Greed, Corruption | Detrimental set: expends function as costs paid to purge. TBD; Madness establishes the pattern. |

Shadow is intentionally near the complexity ceiling for crest expends in the first implementation. Madness validates the detrimental pattern: the passive is a pressure the opponent inflicts, and the expend is a self-mutilating pressure valve. Primary infliction vector: enemy slots with `gain_crest` targeting the opponent (see the Whisperer, §9).

---

## 8. Keywords (Expressive Exceptions)

Rare, badge-displayed rules modifiers. Keep them sparse: usually one part keyword at most, with Hungry appearing as slot behavior. The universal rules never depend on a keyword being present.

- **Armored** *(rim)* — dice cannot be assigned to this BP's rim unless they show at least 🗡️🗡️. This is target legality, not damage reduction.
- **Brittle** *(body)* — damage to this BP always maims it.
- **Absorbent** *(socket)* — if this BP is attacked and takes no damage while its socket holds a die, feed that die to its Slot.
- **Hungry** *(slot)* — this Slot uses wildcard pips. Any nonblank symbol lights one unfilled pip, regardless of identity. Visual tell: hatch always open; cost pips render as wildcard circles.

---

## 9. Strategy Space (Design Intent)

The system must support two coherent archetypes, each demanding different dice, slots, and defensive answers:

- **Tall** — concentrate multi-symbol faces on one part; maim it; race Hearts. Counterplay: Bulwark, Armored, Shadow.
- **Wide** — chip wounds across many parts; gunk the opponent's entire pool with 🩸; win the symbol economy. Counterplay: Brace, healing, fast aggression.

Head-punching is kept honest not by toughness stats but by: the one-die-per-destination cap, asymmetric part value across enemies (the scary die on a 1-Heart arm forces the disarm-vs-race fork), venting (wounding *any* charged part steals tempo), and wide play's pool-degradation payoff.

The Basement Zombie is the first explicit route-versus-reward example. Its 3-Heart Brain Pan offers a two-hit victory, but maiming it destroys the most desirable claim. Every other part carries **Regrowth** (🩸 · Spend · heal this part one step), while the preserved head spends 🩸🩸 on **Bite** to add 🗡️🗡️ to its next assigned die. The hard kill therefore preserves the prize while giving the Zombie more time and Blood with which to threaten the player.

The Basement Bone Demon establishes an early **caster** identity: dice are ingredients before they are direct actions. Its **Demon Skull** feeds ⚡ into **Speak Doom**, while its 2-Heart **Hollow Ribcage** feeds 🗡️ into **Bonestorm**, which assigns one 🗡️ to every open opposing rim. Ward faces take priority over either ritual and defend these two batteries; only surplus fuel becomes direct offense. This creates two visible charge threats and asks the player which one to vent, while the Demon spends much of its pool building and protecting future turns.

AI contract for this encounter:

1. Assign 🛡️ to sockets, prioritizing the Demon Skull and Hollow Ribcage.
2. Feed ⚡ to Speak Doom.
3. Feed 🗡️ to Bonestorm.
4. Use remaining legal dice for direct attacks or broader defense.

The Basement Mad Butcher is a boss-shaped route puzzle built around persistent Head pressure. His 3-Heart **Welding Mask** is both the immediate victory target and the prize the player gives up by taking that route. His 1-Heart **Broad Shoulders** spend 🩸🩸 on **Stitch Up**, healing the allied Head rather than the Body carrying the Slot. The two 1-Heart arms carry concentrated multi-🗡️ faces, while his legs literally reuse the Zombie's Regrowth parts.

**Sadism** begins as a four-🗡️ track. At each Upkeep it costs one fewer pip per damaged opposing Body Part, minimum one. When it fires, dice already showing 🗡️ gain another 🗡️ against Wounded opposing parts for that round. This makes the player's accumulating wounds both the timer and the payoff: spreading damage accelerates the threat, while focused arm attacks convert existing wounds into maims.

The intended routes are:

1. Maim Broad Shoulders, then the Welding Mask for the fast kill; the Head prize is destroyed.
2. Maim Broad Shoulders and two 1-Heart limbs for the slower hard kill; the Welding Mask remains claimable.
3. Pressure the Head without disabling Broad Shoulders and risk watching that progress repaired.

Mad Butcher AI should repair a Wounded Head first, bank but not waste Sadism when no target is Wounded, attack Wounded parts with concentrated Arm dice, and use Regrowth only after Head survival is handled. He has little interest in Ward.

The Basement Whisperer is the thing the whispering wall was holding in, and the roster's first **mind-attacker**: its clock is Madness accumulation, not Heart damage. It is also the keyword showcase — one keyword per part, each doing identity work. Its 2-Heart **Mouthless Face** is **Armored** (you cannot easily strike what has no face) and spends ⚡ on **Whisper** (opponent gains 1 Madness). Its 1-Heart **Plaster Husk** is **Absorbent** with the **Hungry** slot **Feed the Walls** — a successfully warding socketed die is devoured as wildcard pips, so your blocked violence literally becomes more whispers. Its **Brittle** **Scratcher** arm concentrates the creature's only real 🗡️ faces and shatters on any hit: the disarm is one strike away, but a maimed Scratcher is a destroyed claim. **Skitter Legs** spend 🩸🩸 on **Reknit Plaster** to patch whatever the player chips.

The intended forks: the Armored face is rim-illegal for most starting dice, but Clarity (+🗡️ to the next die) manufactures a 🗡️🗡️ face — the player's own head is the counter-tool. Racing the body means feeding the walls; sparing the Scratcher for the claim means eating its concentrated dice. Madness itself is the fight's real price: by round 3 the player chooses each round between a hijacked die and a self-inflicted pinch wound. Simulated at the balanced-AI floor: ~4.3 rounds, face preserved as a claimable prize in ~44% of runs.

---

## 10. Open Questions — Paper Prototype Checklist

Testable with blank dice + stickers (or d6s + lookup cards), index cards per part, coins for pips. Run before any engine code.

1. **Pacing.** With ~6 attack-capable dice and a 1-net-🗡️ wound threshold, do fights end in 2 rounds of mutual shredding? If too fast, candidate brake: hits on Healthy wound; only hits on Wounded maim (already implied by steps — verify it's enough).
2. **Overkill margin.** Should beating defense by 3+ matter (e.g., skip Wounded)? Default: no.
3. **Blanks.** Pure whiffs, or soft currency (two blanks → a reroll)? Default: pure whiffs; revisit if feel-bad.
4. **Allocation time.** Must stay under ~1 minute at the table with 6 dice + slots + crests. If it drags physically, no UI saves it.
5. **Mixed faces.** Do the validity and burn-off affordances make whole-die travel read as "flexible hedge" rather than "wasteful trap"? Split's value depends on the answer.
6. **Hidden-feed leakage.** Under contested initiative, the swallow animation reveals feed *counts* but not pips. Keep (bluffing layer) or fully hide? Current lean: keep.
7. **Crest expansion.** Madness now validates the detrimental pattern (inflicted pressure + purge-at-a-price expend). Greed and Corruption should follow it; Knowledge and Cunning still await initiative/allocation designs. Open sub-question from simulation: end-of-combat Madness is currently consequence-free (crests reset between fights), so "ignore the whispers and race" is viable against a lone Whisperer — does leftover Madness need a sting at combat exit (e.g., suppressing recovery steps), or is per-round seizure pressure enough once encounters chain?
8. **Multi-slot parts / slotless parts.** How rare? Default: exactly one slot per part for the alpha.

## 11. Balance Targets (carried from v1, revised)

- Average combat: 3–5 rounds. Decisions per round: one allocation puzzle of 6–8 placements.
- Player win rate: ~40% learning → ~80% mastered.
- RNG impact: the roll sets the hand; the allocation plays it. Variance is authored per part via blanks and multi-faces, not global.
- Combat remains strictly 1v1.

---

*Companion document: `docs/CombatPresentation.md` — UI, shape grammar, animation choreography, art pipeline.*
