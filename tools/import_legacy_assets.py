#!/usr/bin/env python3
"""Import selected GameMaker sprite frames under stable current-project IDs."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

try:
    from PIL import Image
except ImportError as exc:
    raise SystemExit(
        "This importer requires Pillow. Run it with the workspace Python runtime "
        "or install Pillow for your Python interpreter."
    ) from exc


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "tools" / "legacy_assets.json"
FRAME_PATTERN = re.compile(
    r'"resourceType":"GMSpriteFrame".*?"name":"(?P<frame>[0-9a-f-]+)"'
)
SIZE_PATTERN = {
    "width": re.compile(r'"width":\s*(\d+)'),
    "height": re.compile(r'"height":\s*(\d+)'),
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--manifest",
        type=Path,
        default=DEFAULT_MANIFEST,
        help="Import manifest (default: tools/legacy_assets.json).",
    )
    parser.add_argument(
        "--source",
        type=Path,
        help="Existing checkout of the legacy GameMaker repository.",
    )
    parser.add_argument(
        "--no-palette",
        action="store_true",
        help="Copy source pixels without applying the current project palette.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Validate and list outputs without writing files.",
    )
    return parser.parse_args()


def run(command: list[str], cwd: Path | None = None) -> str:
    result = subprocess.run(
        command,
        cwd=cwd,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return result.stdout.strip()


def source_checkout(manifest: dict, supplied: Path | None, stack) -> Path:
    if supplied:
        source = supplied.resolve()
    else:
        source = Path(stack.enter_context(tempfile.TemporaryDirectory()))
        run([
            "git",
            "clone",
            "--depth",
            "1",
            manifest["source"]["repository"],
            str(source),
        ])

    if not (source / ".git").exists():
        raise ValueError(f"Legacy source is not a git checkout: {source}")

    expected = manifest["source"]["commit"]
    actual = run(["git", "rev-parse", "HEAD"], cwd=source)
    if actual != expected:
        raise ValueError(
            f"Legacy source is at {actual}, but the manifest pins {expected}."
        )
    return source


def sprite_metadata(source: Path, sprite_name: str) -> tuple[list[str], tuple[int, int]]:
    sprite_dir = source / "sprites" / sprite_name
    yy_path = sprite_dir / f"{sprite_name}.yy"
    if not yy_path.exists():
        raise ValueError(f"Missing GameMaker sprite metadata: {yy_path}")

    text = yy_path.read_text(encoding="utf-8")
    frame_ids = [match["frame"] for match in FRAME_PATTERN.finditer(text)]
    if not frame_ids:
        raise ValueError(f"No ordered frames found in {yy_path}")

    width_match = SIZE_PATTERN["width"].search(text)
    height_match = SIZE_PATTERN["height"].search(text)
    if not width_match or not height_match:
        raise ValueError(f"Missing dimensions in {yy_path}")

    return frame_ids, (int(width_match[1]), int(height_match[1]))


def hex_color(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    if len(value) != 6:
        raise ValueError(f"Expected six-digit color, got {value!r}")
    return tuple(int(value[index:index + 2], 16) for index in (0, 2, 4))


def recolor(image: Image.Image, palette: dict) -> Image.Image:
    dark = hex_color(palette["dark"])
    ink = hex_color(palette["ink"])
    blood = hex_color(palette["blood"])
    pixels = image.convert("RGBA")
    output = []

    pixel_data = (
        pixels.get_flattened_data()
        if hasattr(pixels, "get_flattened_data")
        else pixels.getdata()
    )
    for red, green, blue, alpha in pixel_data:
        if alpha == 0:
            output.append((0, 0, 0, 0))
            continue

        if red >= 48 and red > green * 1.55 and red > blue * 1.55:
            intensity = max(0.45, red / 255)
            mapped = tuple(round(channel * intensity) for channel in blood)
        else:
            value = ((red + green + blue) / (3 * 255)) ** 0.8
            mapped = tuple(
                round(low + (high - low) * value)
                for low, high in zip(dark, ink)
            )
        output.append((*mapped, alpha))

    pixels.putdata(output)
    return pixels


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


def selected_frames(frame_spec, frame_ids: list[str]) -> list[tuple[int, str]]:
    if frame_spec == "all":
        return list(enumerate(frame_ids, start=1))

    selected = []
    for frame_number in frame_spec:
        if frame_number < 1 or frame_number > len(frame_ids):
            raise ValueError(
                f"Frame {frame_number} is outside 1..{len(frame_ids)}."
            )
        selected.append((frame_number, frame_ids[frame_number - 1]))
    return selected


def output_path(stem: str, number: int, count: int) -> Path:
    suffix = str(number) if count > 1 else ""
    return ROOT / f"{stem}{suffix}.png"


def import_assets(
    manifest: dict,
    source: Path,
    apply_palette: bool,
    dry_run: bool,
) -> list[dict]:
    report = []
    metadata_cache = {}
    report_path = ROOT / "assets" / "legacy" / "imported_assets.json"
    previous_destinations = set()
    if report_path.exists():
        previous = json.loads(report_path.read_text(encoding="utf-8"))
        previous_destinations = {
            item["destination"] for item in previous.get("assets", [])
        }

    for entry in manifest["assets"]:
        sprite_name = entry["sprite"]
        if sprite_name not in metadata_cache:
            metadata_cache[sprite_name] = sprite_metadata(source, sprite_name)
        frame_ids, size = metadata_cache[sprite_name]

        expected_size = tuple(entry["expected_size"])
        if size != expected_size:
            raise ValueError(
                f"{sprite_name} is {size[0]}x{size[1]}, expected "
                f"{expected_size[0]}x{expected_size[1]}."
            )

        frames = selected_frames(entry["frames"], frame_ids)
        for frame_number, frame_id in frames:
            source_path = source / "sprites" / sprite_name / f"{frame_id}.png"
            if not source_path.exists():
                raise ValueError(f"Missing source frame: {source_path}")

            destination = output_path(entry["output"], frame_number, len(frames))
            print(f"{sprite_name}[{frame_number}] -> {destination.relative_to(ROOT)}")

            if not dry_run:
                destination.parent.mkdir(parents=True, exist_ok=True)
                with Image.open(source_path) as source_image:
                    output_image = (
                        recolor(source_image, manifest["palette"])
                        if apply_palette
                        else source_image.convert("RGBA")
                    )
                    output_image.save(destination, format="PNG", optimize=True)

            report.append({
                "asset_id": destination.stem,
                "destination": str(destination.relative_to(ROOT)),
                "source_sprite": sprite_name,
                "source_frame": frame_number,
                "source_frame_id": frame_id,
                "width": size[0],
                "height": size[1],
            })

    if not dry_run:
        provenance_dir = ROOT / "assets" / "legacy"
        provenance_dir.mkdir(parents=True, exist_ok=True)
        current_destinations = {item["destination"] for item in report}
        for stale in sorted(previous_destinations - current_destinations):
            stale_path = (ROOT / stale).resolve()
            if ROOT not in stale_path.parents or "assets" not in stale_path.parts:
                raise ValueError(f"Refusing to remove stale path outside assets: {stale}")
            if stale_path.exists():
                stale_path.unlink()
                print(f"removed stale import {stale}")

        shutil.copyfile(
            source / "LICENSE",
            provenance_dir / "IntoTheDreamlands-LICENSE.txt",
        )
        report_path.write_text(
            json.dumps({
                "source": manifest["source"],
                "palette_applied": apply_palette,
                "assets": report,
            }, indent=2) + "\n",
            encoding="utf-8",
        )
        for item in report:
            item["sha256"] = sha256(ROOT / item["destination"])
        report_path.write_text(
            json.dumps({
                "source": manifest["source"],
                "palette_applied": apply_palette,
                "assets": report,
            }, indent=2) + "\n",
            encoding="utf-8",
        )

    return report


def main() -> int:
    args = parse_args()
    manifest_path = args.manifest.resolve()
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))

    from contextlib import ExitStack

    with ExitStack() as stack:
        source = source_checkout(manifest, args.source, stack)
        report = import_assets(
            manifest,
            source,
            apply_palette=not args.no_palette,
            dry_run=args.dry_run,
        )

    print(f"Validated {len(report)} imported PNGs.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, subprocess.CalledProcessError, ValueError) as exc:
        print(f"legacy asset import failed: {exc}", file=sys.stderr)
        raise SystemExit(1)
