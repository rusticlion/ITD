# Body Part Editor

Launch with:

```sh
love . --bp-editor
```

This is a lightweight development tool for shaping v2 Body Part content. It is intentionally closer to a worksheet than a full database editor.

Current flow:

- Browse and search Body Parts from `data/combat/*.lua`.
- Fill in ID, name, type, Heart value, tags, and flavor text.
- Click a die face, then click symbol buttons to build that face.
- Configure an optional Slot with cost pips, timing, and a common effect template.
- Copy either a Lua definition or a notes-format description to the clipboard.

Slot effect guidance:

- The editor supports common templates: no effect, add next symbol, channel symbol, auto assign, spellmark, heal part, status-conditioned symbol bonuses, damage opponent part, and gain crest.
- Channel symbol exports `add_symbol_to_matching_dice`: dice showing one symbol gain another for the current Allocation, optionally limited to sockets, rims, or slots.
- Auto assign exports `assign_symbol_to_each_part`: create virtual Ward/Strike assignments on open sockets or rims, useful for effects like Force Field.
- Heal part can target the Slot's own Body Part, the combatant's most damaged Body Part, or a named allied Body Part type.
- Status-conditioned bonuses author effects such as Sadism: matching dice gain a chosen symbol only against Body Parts in the selected state.
- Slot costs can be fixed or contract by one pip per damaged opposing Body Part. The current control authors the shared `opponent_damaged_parts` rule with a minimum cost of one.
- Spellmark opens an existing rim or socket to Essence and authors a damage payload for the marked Body Part.
- Composed `actions` sequences are preserved when loaded and exported, but editing the sequence itself is still a Lua-side task.
- Bespoke effects should stay code-authored for now. The content schema can still hold them, but the editor should not become a general-purpose scripting language.
- If a bespoke effect becomes common enough to reuse across multiple Body Parts, promote it to a named engine effect and then add it as a template here.

The editor does not write directly to project files yet. Pasting exported Lua keeps review explicit and avoids accidental content churn while the schema is still moving.
