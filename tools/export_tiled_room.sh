#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
    echo "usage: tools/export_tiled_room.sh <source.tmx> <output.lua>" >&2
    exit 2
fi

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TILED_BIN=${TILED_BIN:-}

if [ -z "$TILED_BIN" ]; then
    if command -v tiled >/dev/null 2>&1; then
        TILED_BIN=$(command -v tiled)
    elif [ -x /Applications/Tiled.app/Contents/MacOS/Tiled ]; then
        TILED_BIN=/Applications/Tiled.app/Contents/MacOS/Tiled
    else
        echo "Tiled executable not found; set TILED_BIN." >&2
        exit 1
    fi
fi

cd "$ROOT_DIR"
"$TILED_BIN" --embed-tilesets --export-map lua "$1" "$2"
echo "exported $1 -> $2"
