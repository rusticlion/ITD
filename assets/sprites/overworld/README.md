# Overworld Sprites

This folder is scanned by `core/assets.lua` for `.png` files.

Expected first-pass IDs are tracked in `docs/OverworldAssetManifest.md`; Tiled authoring invariants live in `docs/TiledCheatsheet.md`.

Selected sprites from the original GameMaker prototype are imported through
`tools/import_legacy_assets.py`. Edit `tools/legacy_assets.json` to curate the
selection or stable asset IDs; do not copy GameMaker's UUID-named PNGs manually.
Import provenance and hashes live in `assets/legacy/`.
