# V2 Combat Asset Manifest

Native target: 960x540.

All sprite filenames below are addressed by ID through `core/assets.lua`: save PNGs in `assets/sprites/combat/` using the listed ID plus `.png`.

## Revised Visual Target

Combat is moving away from a paper-doll stage and sliding dice drawers. The screen should read as a dark tabletop with two Body Part tableaus facing each other.

Core presentation rules:

- Predominant background: `#222034`.
- Body Parts are cards/tabletop objects, not illustrations of anatomy.
- Dice settle into owner-side rows directly in front of each BP tableau. Do not draw a visible tray unless a specific state needs one.
- Crests render in a one-token-tall strip between each BP tableau and that combatant's settled dice row. The strip collapses completely when empty.
- The space between dice rows is a transit/conduit field for dice movement, spellmark pulses, slot-to-target lines, and brief activation blooms. It is not a paper-doll stage.
- Text belongs primarily in the right inspector/log. The main playfield should use names, symbols, pips, and very short transient labels only.

## Current Transitional Layout Measurements

These measurements match the current 960x540 renderer while the asset pass catches up. Names use the revised tabletop vocabulary even where old code still has `drawer`-named helpers.

Global constants:

- Main playfield x: 48
- Main playfield width: 744
- Left global spine: 8,8,32x524
- Right inspector rail: 800,8,152x524
- Enemy BP tableau band: 48,8,744x130
- Enemy dice row band: 48,144,744x54
- Conduit / no-man's-land: 48,204,744x132
- Player dice row band: 48,342,744x54
- Player BP tableau band: 48,402,744x130

Shared interaction footprints:

- BP card: 116x88
- Die/socket/rim/hatch: 36x36
- Symbol pip: 12x12
- Crest chip: 24x24
- Confirm chit: 84x48

BP card slots:

- Slot x positions: 52, 176, 300, 424, 548, 672
- Enemy card y: 34
- Player card y: 430
- Enemy title edge: far side from opponent, above/on top of the card.
- Player title edge: far side from opponent, below/on bottom of the card.
- BP card left sector: card x+4 to x+44; holds rim, socket, HP value, and future keyword badges.
- BP card right sector: card x+44 to x+112; holds slot title, hatch, and centered pip track.

Settled dice and crest strips:

- Enemy dice row: 144,153,548x36
- Player dice row: 144,351,548x36
- Enemy crest strip starts: 58,171
- Player crest strip starts: 58,345
- Crest gap: 7 px between 24x24 chips
- Player confirm: 700,345,84x48

Global spine internals:

- Enemy heart stack: 12,18,24x80
- Enemy initiative badge: 12,108,24x24
- Centered queue stack: 12,175,24x190
- Contested initiative badge: 12,258,24x24
- Player initiative badge: 12,408,24x24
- Player heart stack: 12,442,24x80

## Mirrored Card Grammar

Use semantic edges instead of absolute top/bottom when drawing BP card assets.

Opponent-facing edge:

- Holds the attackable rim latch.
- Holds the defense socket just inside the card from that rim.
- Faces the conduit/no-man's-land.
- Enemy cards: bottom edge.
- Player cards: top edge.

Owner-facing edge:

- Holds the BP title/name treatment and ownership identity.
- Faces away from the opponent.
- Enemy cards: top edge.
- Player cards: bottom edge.

Slot/hatch placement can be mirrored by side if it improves readability, but its footprint and states should remain invariant.

## Existing Wired Assets

These are already used by `states/v2_combat.lua`:

- `combat_tabletop` - optional 960x540 full-screen tabletop backing
- `combat_spine` - optional 32x524 global spine backing
- `combat_queue_stack` - optional 24x190 queue pipeline/well; renderer overlays only actual queued symbols, not empty placeholder cells
- `combat_initiative_badge` - optional 24x24 initiative badge frame
- `heart_point` - 24x24 intact Heart Point icon
- `heart_point_depleted` - 24x24 depleted Heart Point icon
- `combat_enemy_tableau` - optional 744x130 enemy BP row backing
- `combat_player_tableau` - optional 744x130 player BP row backing
- `combat_conduit_field` - optional 744x132 no-man's-land backing
- `bp_card` - 116x88 base BP card
- `bp_card_empty` - optional 116x88 empty card placeholder
- `bp_card_hover1`, `bp_card_hover2` - optional 116x88 animated hover overlay frames
- `bp_card_selected` - optional 116x88 source-selected overlay
- `bp_card_valid` - optional 116x88 valid target overlay
- `bp_card_invalid` - optional 116x88 invalid/offline overlay
- `bp_card_wounded` - optional 116x88 wounded damage overlay
- `bp_card_maimed` - optional 116x88 maimed damage overlay
- `bp_title` - optional 116x16 BP title strip; drawn normally for enemies and flipped vertically for players
- `die_socket` - 36x36 defense socket
- `die_socket_valid1`...`die_socket_valid4` - optional animated valid socket frames
- `die_socket_occupied1`...`die_socket_occupied4` - optional animated occupied socket frames
- `die_socket_locked1`...`die_socket_locked4` - optional animated locked/offline socket frames
- `die_socket_spellmarked1`...`die_socket_spellmarked4` - optional animated spellmarked socket frames
- `die_rim` - 36x36 rim latch
- `die_rim_valid1`...`die_rim_valid4` - optional animated valid rim frames
- `die_rim_occupied1`...`die_rim_occupied4` - optional animated occupied rim frames
- `die_rim_locked1`...`die_rim_locked4` - optional animated locked/offline rim frames
- `die_rim_spellmarked1`...`die_rim_spellmarked4` - optional animated spellmarked rim frames
- `die-hatch1` - 36x36 completely closed/rest hatch
- `die-hatch2` - 36x36 halfway-open hatch for valid eligible destinations
- `die-hatch3` - 36x36 almost-open hatch for the hovered eligible destination
- `die-hatch4` - 36x36 open pit/no-door swallow frame
- `empty_die` - 36x36 die/token base
- `die_row_guideline_enemy` - optional 548x4 enemy dice row guide
- `die_row_guideline_player` - optional 548x4 player dice row guide
- `sword_symbol`, `shield_symbol`, `lightning_symbol`, `blood_symbol` - 12x12 filled symbols
- `sword_symbol_outline`, `shield_symbol_outline`, `lightning_symbol_outline`, `blood_symbol_outline` - 12x12 unfilled symbols
- `crest_strip_enemy` - optional one-token-tall enemy crest strip guide
- `crest_strip_player` - optional one-token-tall player crest strip guide

## Next Facade Pass Targets

Prioritize assets that make the tabletop tableau feel complete without requiring character illustration.

### Table And Chrome

- `combat_tabletop` - 960x540 dark tabletop background, primarily `#222034`
- `combat_spine` - 32x524 global spine backing
- `combat_queue_stack` - 24x190 queue pipeline/well
- `combat_initiative_badge` - 24x24 initiative badge frame
- `heart_point` - 24x24 intact Heart Point icon
- `heart_point_depleted` - 24x24 depleted Heart Point icon
- `combat_inspector_rail` - 152x524 right inspector/log backing
- `combat_enemy_tableau` - 744x130 enemy BP row backing
- `combat_player_tableau` - 744x130 player BP row backing
- `combat_conduit_field` - 744x132 subtle central transit field
- `combat_confirm_chit` - 84x48 confirm control
- `combat_confirm_chit_hover` - 84x48 confirm hover/focus state

### Body Part Cards

- `bp_card` - 116x88 base BP card, dark-table compatible
- `bp_card_empty` - 116x88 empty placeholder
- `bp_card_hover` - 116x88 hover outline/overlay
- `bp_card_selected` - 116x88 source-selected outline/overlay
- `bp_card_valid` - 116x88 valid target outline/overlay
- `bp_card_invalid` - 116x88 invalid/offline outline/overlay
- `bp_card_wounded` - 116x88 damage surface overlay
- `bp_card_maimed` - 116x88 ruined/offline surface overlay
- `bp_title` - 116x16 title strip treatment; enemy orientation is canonical, player render flips vertically
- `bp_hp_badge` - compact HP badge frame

### Sockets, Rims, And Slots

- `die_socket` - 36x36 empty defense socket
- `die_socket_valid` - 36x36 valid-hover socket
- `die_socket_occupied` - 36x36 occupied socket treatment
- `die_socket_locked` - 36x36 sealed/offline socket
- `die_rim` - 36x36 empty attack rim latch
- `die_rim_valid` - 36x36 valid-hover rim latch
- `die_rim_occupied` - 36x36 occupied rim latch
- `die_rim_locked` - 36x36 sealed/offline rim latch
- `die_rim_spellmarked` - 36x36 rim temporarily accepting Essence
- `die_socket_spellmarked` - 36x36 socket temporarily accepting Essence
- `die-hatch1` - 36x36 completely closed/rest hatch
- `die-hatch2` - 36x36 halfway-open hatch for valid eligible destinations
- `die-hatch3` - 36x36 almost-open hatch for the hovered eligible destination
- `die-hatch4` - 36x36 open pit/no-door swallow frame
- `slot_cell_preview` - optional 12x12 backing behind an existing symbol sprite during charge preview
- `slot_cell_lit` - optional 12x12 backing behind an existing symbol sprite for charged pips
- `slot_cell_vent` - optional 12x12 backing/shatter frame for a vented pip

### Dice And Symbols

- `empty_die` - 36x36 die/token base
- `die_back_enemy` - 36x36 face-down enemy die
- `die_back_player` - 36x36 face-down player die if needed
- `die_shadow` - 36x36 table shadow under settled dice
- `die_row_guideline_enemy` - 548x4 subtle enemy magnet line
- `die_row_guideline_player` - 548x4 subtle player magnet line
- `sword_symbol`, `shield_symbol`, `lightning_symbol`, `blood_symbol` - 12x12 filled symbols
- `sword_symbol_outline`, `shield_symbol_outline`, `lightning_symbol_outline`, `blood_symbol_outline` - 12x12 outline symbols
- `blank_symbol` - 12x12 blank face mark if blanks need visible texture
- `burn_spark_strike`, `burn_spark_ward`, `burn_spark_essence`, `burn_spark_blood` - small burn-off particles or ghosts

### Crests

- `crest_valor_chip` - 24x24 Valor crest chip
- `crest_shadow_chip` - 24x24 Shadow crest chip
- `crest_count_badge` - small count badge backing
- `crest_strip_enemy` - optional one-token-tall enemy strip guide
- `crest_strip_player` - optional one-token-tall player strip guide

Do not draw empty crest slots. The crest strip appears only when at least one visible crest is present.

### Effect Overlays

- `effect_slot_pulse` - generic slot activation bloom
- `effect_spellmark_thread` - slot-to-rim/socket conduit line segment or particle
- `effect_wound_flash` - damage flash overlay
- `effect_vent_shatter` - slot charge vent overlay
- `effect_latch_eject` - rim ejection burst

These may also be generated procedurally in code. Only draw sprite assets here if repeated hand-authored texture will make them stronger than simple rectangles/lines.

## Authoring Notes

- Keep meaningful art inside the listed footprint; the renderer draws at native dimensions first.
- State overlays may be authored as one static PNG using the listed base ID, or as 2-4 animation frames using `1`...`4` suffixes, e.g. `die_socket_valid1.png`, `die_socket_valid2.png`.
- Transparent internal padding is fine, especially for chips and badges, but interaction hitboxes remain rectangular.
- Avoid light filled panels as the default. Prefer dark fills, pale outlines, and high-contrast symbol accents.
- Do not create paper-doll, limb, or full-body combat assets for this pass.
- If a component needs vertical mirroring, prefer a single sprite that can be flipped unless side-specific title or latch art is clearly better.
