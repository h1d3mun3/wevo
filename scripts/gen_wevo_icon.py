#!/usr/bin/env python3
"""Generate Wevo's app icon as an Icon Composer bundle (.icon).

The mark is a warifu (割符): one seal split in two along an interlocking
cut, each half held by one party. The halves only prove anything when they
are brought together, and no third party is needed to check that they match.

Usage:
    python3 gen_wevo_icon.py [output directory]

    To regenerate the bundle the app uses, run from the repository root:
        python3 scripts/gen_wevo_icon.py Wevo/Resources

Output:
    <output directory>/Wevo.icon/
        icon.json         manifest (background color, groups, layers)
        Assets/left.svg   the left half (blue)
        Assets/right.svg  the right half (coral)

Note: Apple has not published a specification for icon.json, so the
structure written here is inferred rather than taken from a specification.
"""
import json
import sys
from pathlib import Path

# ---- Design (edit these values and rerun to regenerate) ----
# "Dawn": the two parties get two different hues of equal weight, so neither
# half reads as the background to the other. The halves also differ in
# lightness, so the cut stays legible in the tinted and clear appearances,
# where hue is discarded.
COLORS = {
    "light": {
        "background": "#F6F7FA",
        "left": "#3D6FE0",   # blue
        "right": "#FF7A59",  # coral
    },
    "dark": {
        "background": "#13151B",
        "left": "#7FA2FF",
        "right": "#FF9877",
    },
}

# Coordinates are relative to the 0..100 tile square, matching the design canvas.
SEAL_CENTER_X = 50
SEAL_TOP, SEAL_BOTTOM = 20, 80
SEAL_RADIUS = 30
# The cut, from the bottom of the seal back up to the top.
CUT_POINTS = [(56, 68), (44, 56), (56, 44), (44, 32)]
# Each half is pushed this far away from the cut, so the halves read as two pieces.
HALF_GAP = 3

CANVAS = 1024
TILE_MIN, TILE_SIZE = 0, 100
BUNDLE_NAME = "Wevo.icon"


def to_canvas(v: float) -> float:
    """Convert a tile coordinate (0..100) to a 1024 px canvas coordinate."""
    return round((v - TILE_MIN) * CANVAS / TILE_SIZE, 2)


def to_canvas_length(v: float) -> float:
    return round(v * CANVAS / TILE_SIZE, 2)


def svg_doc(body: str) -> str:
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {CANVAS} {CANVAS}" '
        f'width="{CANVAS}" height="{CANVAS}">\n  {body}\n</svg>\n'
    )


def half_path(side: str) -> str:
    """The outline of one half: the seal's outer arc on that side, then the cut."""
    dx = -HALF_GAP if side == "left" else HALF_GAP
    # Drawing top to bottom, the left arc runs counter-clockwise, the right clockwise.
    sweep = 0 if side == "left" else 1
    r = to_canvas_length(SEAL_RADIUS)
    x = to_canvas(SEAL_CENTER_X + dx)
    parts = [
        f"M{x} {to_canvas(SEAL_TOP)}",
        f"A{r} {r} 0 0 {sweep} {x} {to_canvas(SEAL_BOTTOM)}",
    ]
    parts += [f"L{to_canvas(px + dx)} {to_canvas(py)}" for px, py in CUT_POINTS]
    parts.append("Z")
    return "".join(parts)


def half_svg(side: str) -> str:
    return svg_doc(f'<path d="{half_path(side)}" fill="{COLORS["light"][side]}"/>')


def icon_color(hex_color: str) -> str:
    h = hex_color.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return f"srgb:{r:.5f},{g:.5f},{b:.5f},1.00000"


def layer(side: str) -> dict:
    # The SVG carries the light color; dark appearance overrides the fill.
    return {
        "image-name": f"{side}.svg",
        "name": side,
        "glass": True,
        "fill-specializations": [
            {"appearance": "dark", "value": {"solid": icon_color(COLORS["dark"][side])}},
        ],
    }


def manifest() -> dict:
    return {
        "fill-specializations": [
            {"value": {"solid": icon_color(COLORS["light"]["background"])}},
            {"appearance": "dark", "value": {"solid": icon_color(COLORS["dark"]["background"])}},
        ],
        "groups": [
            {
                "name": "Foreground",
                "layers": [layer("left"), layer("right")],
            }
        ],
        "supported-platforms": {"squares": "shared"},
    }


def main() -> None:
    out_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
    bundle = out_dir / BUNDLE_NAME
    assets = bundle / "Assets"
    assets.mkdir(parents=True, exist_ok=True)
    for side in ("left", "right"):
        (assets / f"{side}.svg").write_text(half_svg(side), encoding="utf-8")
    (bundle / "icon.json").write_text(json.dumps(manifest(), indent=2) + "\n", encoding="utf-8")
    print(f"Generated {bundle}")


if __name__ == "__main__":
    main()
