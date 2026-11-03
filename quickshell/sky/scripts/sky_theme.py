#!/usr/bin/env python3
"""Generate the sky shell palette from the current wallpaper.

The accent stays sky blue: matugen extracts the wallpaper's source color, the
wallpaper hue may pull the accent at most 40 degrees, scaled by (1 - bias).
Surfaces and the tertiary tone come from the wallpaper's own scheme, so the
frame blends with the background while the accent stays recognisable.

Usage:
  sky_theme.py [WALLPAPER] [--bias 0..1] [--out PATH]

WALLPAPER may be an image, a video, or a Wallpaper Engine scene directory.
Without it, the path saved in the shell's own wallpaper state is used.
"""
from __future__ import annotations

import argparse
import colorsys
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

SKY_HUE = 205.0
MAX_PULL = 40.0
DEFAULT_BIAS = 0.7
FALLBACK_SEED = "#5cb8f0"

STATE_HOME = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state"))
CONFIG_HOME = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
CACHE_HOME = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
DEFAULT_OUT = STATE_HOME / "sky/colors.json"
SKY_STATE = CONFIG_HOME / "sky/wallpaper.json"

VIDEO_EXT = {".mp4", ".mkv", ".webm", ".mov", ".avi"}
ANIMATED_EXT = {".gif", ".webp"}


def sky_accent_hue(wall_hue: float, bias: float) -> float:
    """Accent hue: SKY_HUE pulled toward wall_hue by at most MAX_PULL, scaled by 1 - bias."""
    bias = min(max(bias, 0.0), 1.0)
    delta = ((wall_hue - SKY_HUE + 540) % 360) - 180
    delta = min(max(delta, -MAX_PULL), MAX_PULL)
    return (SKY_HUE + delta * (1 - bias)) % 360


def hex_hue(color: str) -> float:
    c = color.lstrip("#")
    r, g, b = (int(c[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return colorsys.rgb_to_hls(r, g, b)[0] * 360


def seed_for_hue(hue: float) -> str:
    r, g, b = colorsys.hls_to_rgb(hue / 360, 0.6, 0.8)
    return "#{:02x}{:02x}{:02x}".format(round(r * 255), round(g * 255), round(b * 255))


def _role(dump: dict, name: str) -> str:
    return dump["colors"][name]["dark"]["color"]


def build_palette(accent: dict, wall: dict, wall_hue: float, accent_hue: float) -> dict:
    """Merge the accent scheme (from the biased seed) with the wallpaper scheme."""
    return {
        "accent": _role(accent, "primary"),
        "onAccent": _role(accent, "on_primary"),
        "secondary": _role(accent, "secondary"),
        "tertiary": _role(wall, "primary"),
        "surface": _role(wall, "surface"),
        "surface2": _role(accent, "surface_container_high"),
        "widget": _role(wall, "surface_container"),
        "on": _role(accent, "on_surface"),
        "muted": _role(accent, "on_surface_variant"),
        "outline": _role(accent, "outline"),
        "wallHue": round(wall_hue),
        "accentHue": round(accent_hue),
    }


def color_source(path: Path) -> tuple[Path | None, str]:
    """Return (file to extract colors from, kind) for an image, video or scene dir."""
    if path.is_dir():
        try:
            preview = json.loads((path / "project.json").read_text()).get("preview")
        except (OSError, ValueError):
            preview = None
        if preview and (path / preview).is_file():
            p = path / preview
            return p, "animated" if p.suffix.lower() in ANIMATED_EXT else "image"
        return None, "none"
    if not path.is_file():
        return None, "none"
    ext = path.suffix.lower()
    if ext in VIDEO_EXT:
        return path, "video"
    if ext in ANIMATED_EXT:
        return path, "animated"
    return path, "image"


def current_wallpaper(state_file: Path = SKY_STATE) -> Path | None:
    try:
        p = json.loads(state_file.read_text()).get("path")
    except (OSError, ValueError):
        return None
    return Path(p) if p else None


def write_palette(out: Path, palette: dict) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=out.parent, prefix=".colors-", suffix=".json")
    with os.fdopen(fd, "w") as f:
        json.dump(palette, f, indent=2)
    os.replace(tmp, out)


def _still_frame(src: Path, kind: str, workdir: Path) -> Path:
    """Flatten animated/video sources to one small PNG matugen can read."""
    frame = workdir / "frame.png"
    if kind == "video":
        subprocess.run(["ffmpeg", "-y", "-ss", "1", "-i", str(src), "-frames:v", "1",
                        "-vf", "scale=320:-2", str(frame)], check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    else:
        subprocess.run(["magick", f"{src}[0]", "-resize", "320x>", str(frame)], check=True)
    return frame


def _matugen(*args: str) -> dict:
    out = subprocess.run(["matugen", *args, "--dry-run", "-j", "hex", "-q", "-m", "dark"],
                         check=True, capture_output=True, text=True)
    return json.loads(out.stdout)


def generate(wallpaper: Path | None, bias: float) -> dict:
    src, kind = color_source(wallpaper) if wallpaper else (None, "none")
    with tempfile.TemporaryDirectory() as tmp:
        if src is None:
            wall = _matugen("color", "hex", FALLBACK_SEED)
        else:
            img = src if kind == "image" else _still_frame(src, kind, Path(tmp))
            wall = _matugen("image", str(img), "--prefer", "saturation",
                            "--fallback-color", FALLBACK_SEED)
    wall_hue = hex_hue(_role(wall, "source_color"))
    accent_hue = sky_accent_hue(wall_hue, bias)
    accent = _matugen("color", "hex", seed_for_hue(accent_hue))
    palette = build_palette(accent, wall, wall_hue, accent_hue)
    palette["wallpaper"] = str(wallpaper) if wallpaper else ""
    return palette


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("wallpaper", nargs="?", type=Path)
    ap.add_argument("--bias", type=float, default=DEFAULT_BIAS)
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = ap.parse_args(argv)
    if not shutil.which("matugen"):
        print("sky_theme: matugen not found", file=sys.stderr)
        return 1
    wallpaper = args.wallpaper or current_wallpaper()
    palette = generate(wallpaper, args.bias)
    write_palette(args.out, palette)
    print(json.dumps(palette))
    return 0


if __name__ == "__main__":
    sys.exit(main())
