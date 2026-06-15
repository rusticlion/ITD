# V2 Combat Asset Manifest

Native target: 960x540.

All sprite filenames below are addressed by ID through `core/assets.lua`: save PNGs in `assets/sprites/combat/` using the listed ID plus `.png`.

## Current Layout Measurements

Global constants:

- Main playfield x: 48
- Main playfield width: 744
- Left global spine: 8,8,32x524
- Right inspector rail: 800,8,152x524
- Enemy BP strip: 48,8,744x130
- Enemy drawer: 48,144,744x54
- Center stage playmat: 48,204,744x132
- Player drawer: 48,342,744x54
- Player BP strip: 48,402,744x130

Shared interaction footprints:

- BP card: 116x88
- Die/socket/rim/hatch: 36x36
- Symbol pip: 12x12
- Crest chip: 24x24
- Confirm chit: 84x24

BP card slots:

- Slot x positions: 52, 176, 300, 424, 548, 672
- Enemy card y: 34
- Player card y: 430
- Enemy external label y: 20
- Player external label y: 520

Drawer internals:

- Enemy dice area: 144,153,548x36
- Player dice area: 144,351,548x36
- Enemy crest lip row starts: 58,171
- Player crest lip row starts: 58,345
- Crest gap: 7 px between 24x24 chips
- Player confirm: 700,345,84x24

Global spine internals:

- Round badge: 12,16,24x24
- Initiative badge: 12,48,24x24
- Queue stack: 12,82,24x190

## Existing Wired Assets

These are already used by `states/v2_combat.lua`:

- `bp_card` - 116x88 base BP card
- `die_socket` - 36x36 defense socket
- `die_rim` - 36x36 rim latch
- `die-hatch1` - 36x36 closed/rest hatch
- `die-hatch2` - 36x36 open/active hatch
- `die-hatch3` - 36x36 charged hatch
- `die-hatch4` - 36x36 offline/blocked hatch
- `empty_die` - 36x36 die/token base
- `sword_symbol`, `shield_symbol`, `lightning_symbol`, `blood_symbol` - 12x12 filled symbols
- `sword_symbol_outline`, `shield_symbol_outline`, `lightning_symbol_outline`, `blood_symbol_outline` - 12x12 unfilled symbols

## Facade Pass Targets

Recommended new assets for the next implementation pass:

- `combat_spine` - 32x524 global spine backing
- `combat_queue_stack` - 24x190 queue well
- `combat_round_badge` - 24x24 round badge frame
- `combat_initiative_badge` - 24x24 initiative badge frame
- `combat_stage_playmat` - 744x132 center stage backing
- `combat_enemy_strip` - 744x130 enemy BP strip backing
- `combat_player_strip` - 744x130 player BP strip backing
- `combat_enemy_drawer_open` - 744x54 enemy drawer, open state
- `combat_player_drawer_open` - 744x54 player drawer, open state
- `combat_enemy_drawer_closed` - 744x18 enemy drawer lip/retracted state
- `combat_player_drawer_closed` - 744x18 player drawer lip/retracted state
- `combat_confirm_chit` - 84x24 confirm control
- `combat_confirm_chit_hover` - 84x24 confirm hover/focus state
- `crest_valor_chip` - 24x24 Valor crest chip
- `crest_shadow_chip` - 24x24 Shadow crest chip
- `crest_empty_chip` - 24x24 inactive crest chip/backing

Authoring notes:

- Drawer open sprites should include the lip, any handle marks, and the recessed tray surface for dice.
- Closed drawer sprites should preserve the crest lip area so crest generation remains readable when dice trays retract.
- Keep meaningful art inside the listed footprint; the renderer will draw at these exact native dimensions first.
- Transparent internal padding is fine, especially for chips and badges, but the interaction hitboxes will remain rectangular.
