# Legacy Asset Provenance

Selected overworld assets are imported from the original GameMaker prototype:

- Repository: `https://github.com/rusticlion/IntoTheDreamlands`
- Pinned commit: `b8e4a35aa143728084ed97c8c1f7ab6d8b012f89`
- Original project license: MIT, copied beside this file after import.

The legacy project includes custom work by Russell L. Bates and visual vocabulary
derived from Kenney's CC0 1-Bit Pack. Imported runtime PNGs are palette-converted
for the current project's indigo, pale-ink, and blood-red presentation.

`tools/legacy_assets.json` is the curated selection and naming manifest.
`tools/import_legacy_assets.py` clones or reads the pinned source repository,
resolves GameMaker frame order, validates dimensions, imports the PNGs, and writes
`imported_assets.json` with source frame IDs and output hashes.

The importer requires Python 3 and Pillow:

```sh
python3 -m pip install -r tools/requirements.txt
python3 tools/import_legacy_assets.py
```

Use `--source /path/to/IntoTheDreamlands` to reuse an existing checkout and
`--dry-run` to validate the manifest without changing files.
