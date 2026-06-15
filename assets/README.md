# Sprite Asset Guidelines

The combat prototype currently relies on programmer-art placeholders while the final pipeline is under construction.
All placeholder sprites should be authored as square PNGs with a resolution of **128x128 pixels** so they align with the
mocked UI layout used throughout the S4 UI Foundation sprint.

## Directory Overview

- `assets/sprites/bodyparts/`
  - State-specific placeholders such as `placeholder_healthy.png`, `placeholder_wounded.png`, and `placeholder_maimed.png`.
- `assets/sprites/icons/`
  - Generic UI glyphs, including the `placeholder_default.png` fallback used by the asset manager.
- `assets/fonts/dotgothic16/`
  - DotGothic16 Regular and its bundled SIL Open Font License text. Used by the v2 combat UI.

Each file is addressed by its filename (without the `.png` extension) through `core/assets.lua`. Avoid embedding
state or directory information in code outside of the asset manager—always request sprites by ID via
`Assets:get("asset_id")`.

See `docs/CombatAssetManifest.md` for the v2 combat layout measurements and the next facade-pass sprite ID list.
