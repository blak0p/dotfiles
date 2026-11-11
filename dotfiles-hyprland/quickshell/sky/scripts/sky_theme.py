#!/usr/bin/env python3
"""Generate the desktop palette from the current wallpaper and apply it.

matugen extracts a Material scheme from the wallpaper; every role (accent
included) follows it. On top of that, a 16-color ANSI set keeps semantic hues
(red, green, ...) harmonized toward the wallpaper, and a base16 set feeds nvim.

Outputs (in --out-dir, default ~/.local/state/sky):
  colors.json     sky shell + nvim (palette, ansi, base16)
  kitty.conf      foreground, cursor, selection, ANSI (never the background)
  hyprland.lua    window borders
  hyprlock.conf   lock screen color variables
  gtk.css         GTK 4 named colors (libadwaita roles)
  gtk3.css        GTK 3 rules (literal colors: GTK 3 has no libadwaita roles)
  starship.toml   the user's starship.toml with a `sky` palette (accent for path/git)
  qt6ct-colors.conf  Qt palette for qt6ct (Qt apps, Dolphin included)
plus ~/.config/btop/themes/sky.theme, the `[Colors:*]` groups of
~/.config/kdeglobals and the scheme file ~/.local/share/color-schemes/Sky.colors
(KDE Frameworks apps such as Dolphin read them; without the file they fall back
to light Breeze). Kitty and Hyprland are reloaded.

Usage:
  sky_theme.py [WALLPAPER] [--out-dir DIR] [--no-reload]

WALLPAPER may be an image, a video, or a Wallpaper Engine scene directory.
Without it, the path saved in the shell's own wallpaper state is used.
"""
from __future__ import annotations

import argparse
import colorsys
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

FALLBACK_SEED = "#5cb8f0"
MAX_HARMONIZE = 15.0
# ANSI slots 1..6 and their reference hues: red, green, yellow, blue, magenta, cyan.
ANSI_HUES = {1: 0.0, 2: 120.0, 3: 50.0, 4: 215.0, 5: 300.0, 6: 180.0}

STATE_HOME = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state"))
CONFIG_HOME = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
CACHE_HOME = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
DEFAULT_OUT_DIR = STATE_HOME / "sky"
BTOP_THEME = CONFIG_HOME / "btop/themes/sky.theme"
STARSHIP_BASE = CONFIG_HOME / "starship.toml"
SKY_STATE = CONFIG_HOME / "sky/wallpaper.json"
THEME_PREFS = CONFIG_HOME / "sky/theme.json"
SCHEMES = {"scheme-tonal-spot", "scheme-vibrant", "scheme-expressive", "scheme-fidelity",
           "scheme-content", "scheme-neutral", "scheme-monochrome"}
KDEGLOBALS = CONFIG_HOME / "kdeglobals"
DATA_HOME = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
KDE_SCHEME = DATA_HOME / "color-schemes/Sky.colors"

VIDEO_EXT = {".mp4", ".mkv", ".webm", ".mov", ".avi"}
ANIMATED_EXT = {".gif", ".webp"}


def harmonize(hue: float, wall_hue: float) -> float:
    """Rotate `hue` halfway toward `wall_hue`, at most MAX_HARMONIZE degrees."""
    delta = ((wall_hue - hue + 540) % 360) - 180
    shift = min(max(delta / 2, -MAX_HARMONIZE), MAX_HARMONIZE)
    return (hue + shift) % 360


def hex_hue(color: str) -> float:
    c = color.lstrip("#")
    r, g, b = (int(c[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return colorsys.rgb_to_hls(r, g, b)[0] * 360


def hls_hex(hue: float, light: float, sat: float) -> str:
    r, g, b = colorsys.hls_to_rgb(hue / 360, light, sat)
    return "#{:02x}{:02x}{:02x}".format(round(r * 255), round(g * 255), round(b * 255))


def _role(dump: dict, name: str) -> str:
    return dump["colors"][name]["dark"]["color"].lower()


def build_ansi(wall: dict, wall_hue: float) -> list[str]:
    """16 terminal colors: Material neutrals plus harmonized semantic hues."""
    ansi = [""] * 16
    ansi[0] = _role(wall, "surface_container_high")
    ansi[7] = _role(wall, "on_surface_variant")
    ansi[8] = _role(wall, "outline")
    ansi[15] = _role(wall, "on_surface")
    for slot, ref in ANSI_HUES.items():
        hue = harmonize(ref, wall_hue)
        ansi[slot] = hls_hex(hue, 0.66, 0.80)
        ansi[slot + 8] = hls_hex(hue, 0.76, 0.85)
    return ansi


def build_palette(wall: dict) -> dict:
    """Every role comes from the wallpaper scheme."""
    wall_hue = hex_hue(_role(wall, "source_color"))
    ansi = build_ansi(wall, wall_hue)
    r = lambda name: _role(wall, name)  # noqa: E731
    base16 = {
        "base00": r("surface"), "base01": r("surface_container"),
        "base02": r("surface_container_high"), "base03": r("outline"),
        "base04": r("on_surface_variant"), "base05": r("on_surface"),
        "base06": r("on_surface"), "base07": ansi[15],
        "base08": ansi[1], "base09": hls_hex(harmonize(30, wall_hue), 0.72, 0.60),
        "base0A": ansi[3], "base0B": ansi[2],
        "base0C": r("secondary"), "base0D": r("primary"), "base0E": r("tertiary"),
        "base0F": hls_hex(harmonize(20, wall_hue), 0.55, 0.40),
    }
    return {
        "accent": r("primary"),
        "onAccent": r("on_primary"),
        "secondary": r("secondary"),
        "tertiary": r("tertiary"),
        "surface": r("surface"),
        "surface2": r("surface_container_high"),
        "widget": r("surface_container"),
        "on": r("on_surface"),
        "muted": r("on_surface_variant"),
        "outline": r("outline"),
        "outlineVariant": r("outline_variant"),
        "wallHue": round(wall_hue),
        "ansi": ansi,
        "base16": base16,
    }


def _h(color: str) -> str:
    return color.lstrip("#")


def render_kitty(p: dict) -> str:
    lines = ["# Generated by sky_theme.py from the wallpaper. Background is left to kitty.conf.",
             f"foreground {p['on']}",
             f"cursor {p['accent']}",
             f"cursor_text_color {p['onAccent']}",
             f"selection_foreground {p['on']}",
             f"selection_background {p['surface2']}",
             f"url_color {p['secondary']}",
             f"active_border_color {p['accent']}",
             f"inactive_border_color {p['outlineVariant']}",
             f"active_tab_foreground {p['onAccent']}",
             f"active_tab_background {p['accent']}",
             f"inactive_tab_foreground {p['muted']}",
             f"inactive_tab_background {p['widget']}"]
    lines += [f"color{i} {c}" for i, c in enumerate(p["ansi"])]
    return "\n".join(lines) + "\n"


def render_hyprland(p: dict) -> str:
    """Only the active border: inactive borders keep the user's own look."""
    return f"""-- Generated by sky_theme.py from the wallpaper.
hl.config({{
    general = {{
        col = {{
            active_border = "rgba({_h(p['accent'])}aa)",
        }},
    }},
}})
"""


def render_hyprlock(p: dict) -> str:
    return f"""# Generated by sky_theme.py from the wallpaper.
$text_color = rgba({_h(p['on'])}ff)
$entry_background_color = rgba({_h(p['surface'])}66)
$entry_border_color = rgba({_h(p['accent'])}88)
$entry_color = rgba({_h(p['on'])}ff)
"""


def render_gtk(p: dict) -> str:
    pairs = [("accent_color", p["accent"]), ("accent_fg_color", p["onAccent"]),
             ("accent_bg_color", p["accent"])]
    for name in ("window", "headerbar", "popover", "view", "card", "dialog"):
        pairs += [(f"{name}_bg_color", p["surface"]), (f"{name}_fg_color", p["on"])]
    lines = ["/* Generated by sky_theme.py from the wallpaper. */"]
    lines += [f"@define-color {k} {v};" for k, v in pairs]
    lines += ["@define-color sidebar_bg_color @window_bg_color;",
              "@define-color sidebar_fg_color @window_fg_color;"]
    return "\n".join(lines) + "\n"


def render_gtk3(p: dict) -> str:
    """GTK3 knows no libadwaita role names, so it needs literal rules.

    A theme that only ships `@define-color` defines no widget CSS, and GTK3 then
    paints no window background at all: every window turns transparent and its
    text floats over whatever is behind it.
    """
    bg, fg = p["surface"], p["on"]
    return f"""/* Generated by sky_theme.py from the wallpaper.
   GTK3 has no libadwaita role names, so these literal rules carry the palette.
   Keep them in sync with render_gtk. */
window, .background {{
    background-color: {bg};
    color: {fg};
}}

headerbar {{
    background-color: {bg};
    color: {fg};
    border-color: {p['outlineVariant']};
}}

popover, dialog {{
    background-color: {bg};
    color: {fg};
}}

.view, textview, treeview.view, iconview {{
    background-color: {bg};
    color: {fg};
}}
"""


def render_btop(p: dict) -> str:
    a = p["ansi"]
    theme = {
        "main_bg": "", "main_fg": p["on"], "title": p["on"], "hi_fg": p["accent"],
        "selected_bg": p["surface2"], "selected_fg": p["on"], "inactive_fg": p["outline"],
        "graph_text": p["muted"], "meter_bg": p["surface2"], "proc_misc": p["secondary"],
        "cpu_box": p["accent"], "mem_box": p["secondary"], "net_box": p["tertiary"],
        "proc_box": p["outline"], "div_line": p["outlineVariant"],
        "temp_start": a[2], "temp_mid": a[3], "temp_end": a[1],
        "cpu_start": p["accent"], "cpu_mid": p["tertiary"], "cpu_end": a[1],
        "free_start": a[2], "free_mid": a[10], "free_end": a[10],
        "cached_start": p["secondary"], "cached_mid": p["secondary"], "cached_end": p["secondary"],
        "available_start": p["tertiary"], "available_mid": p["tertiary"], "available_end": p["tertiary"],
        "used_start": a[3], "used_mid": a[9], "used_end": a[1],
        "download_start": p["accent"], "download_mid": p["accent"], "download_end": p["tertiary"],
        "upload_start": p["secondary"], "upload_mid": p["secondary"], "upload_end": p["tertiary"],
        "process_start": p["accent"], "process_mid": p["tertiary"], "process_end": a[1],
    }
    lines = ["# Generated by sky_theme.py from the wallpaper."]
    lines += [f'theme[{k}]="{v}"' for k, v in theme.items()]
    return "\n".join(lines) + "\n"


def render_qt6ct(p: dict) -> str:
    """qt6ct color scheme: one color per QPalette::ColorRole, in enum order."""
    def roles(text: str) -> list[str]:
        return [text, p["widget"], p["surface2"], p["surface2"], p["surface"], p["outlineVariant"],
                text, p["on"], text, p["surface"], p["surface"], "#000000", p["accent"],
                p["onAccent"], p["accent"], p["tertiary"], p["widget"], p["surface"],
                p["surface2"], p["on"], p["muted"], p["accent"]]
    groups = {"active_colors": roles(p["on"]), "disabled_colors": roles(p["outline"]),
              "inactive_colors": roles(p["on"])}
    lines = ["[ColorScheme]"] + [f"{k}={', '.join(v)}" for k, v in groups.items()]
    return "\n".join(lines) + "\n"


def _rgb(color: str) -> str:
    c = _h(color)
    return ",".join(str(int(c[i:i + 2], 16)) for i in (0, 2, 4))


def _kde_colors(p: dict) -> dict[str, dict[str, str]]:
    a = p["ansi"]

    def group(bg: str, alt: str, fg: str) -> dict[str, str]:
        return {"BackgroundNormal": _rgb(bg), "BackgroundAlternate": _rgb(alt),
                "ForegroundNormal": _rgb(fg), "ForegroundInactive": _rgb(p["muted"]),
                "ForegroundActive": _rgb(p["accent"]), "ForegroundLink": _rgb(p["accent"]),
                "ForegroundVisited": _rgb(p["tertiary"]), "ForegroundNegative": _rgb(a[1]),
                "ForegroundNeutral": _rgb(a[3]), "ForegroundPositive": _rgb(a[2]),
                "DecorationFocus": _rgb(p["accent"]), "DecorationHover": _rgb(p["accent"])}

    selection = group(p["accent"], p["accent"], p["onAccent"])
    selection["ForegroundInactive"] = _rgb(p["onAccent"])
    return {"Colors:Window": group(p["surface"], p["widget"], p["on"]),
            "Colors:View": group(p["surface"], p["widget"], p["on"]),
            "Colors:Button": group(p["widget"], p["surface2"], p["on"]),
            "Colors:Selection": selection,
            "Colors:Tooltip": group(p["surface2"], p["widget"], p["on"]),
            "Colors:Header": group(p["widget"], p["surface"], p["on"]),
            "Colors:Complementary": group(p["surface"], p["widget"], p["on"])}


def render_kdeglobals(base: str, p: dict) -> str:
    """The user's kdeglobals with our `[Colors:*]` groups and the `Sky` scheme selected.

    Every other group and key is kept as written; old color groups are replaced.
    """
    # UiSettings holds the explicit scheme choice KColorSchemeManager reads.
    colors = {**_kde_colors(p), "UiSettings": {"ColorScheme": "Sky"}}
    out, section, seen_general = [], None, False
    for line in base.splitlines():
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            section = stripped[1:-1]
            if section == "General" and not seen_general:
                seen_general = True
                out.append(line)
                out.append("ColorScheme=Sky")
                continue
        if section in colors:
            continue
        if section == "General" and stripped.split("=")[0].strip() in ("ColorScheme", "ColorSchemeHash"):
            continue
        out.append(line)
    if not seen_general:
        out = ["[General]", "ColorScheme=Sky", ""] + out
    while out and not out[-1].strip():
        out.pop()
    for name, keys in colors.items():
        out += ["", f"[{name}]"] + [f"{k}={v}" for k, v in keys.items()]
    return "\n".join(out).lstrip("\n") + "\n"


def render_kde_scheme(p: dict) -> str:
    """A KDE color scheme file (`Sky.colors`) so KColorSchemeManager finds `ColorScheme=Sky`."""
    effects = {"ColorEffects:Disabled": {"Color": "56,56,56", "ColorAmount": "0",
                                         "ColorEffect": "0", "ContrastAmount": "0.65",
                                         "ContrastEffect": "1", "IntensityAmount": "0.1",
                                         "IntensityEffect": "2"},
               "ColorEffects:Inactive": {"ChangeSelectionColor": "false", "Enable": "false"}}
    sections = {"General": {"Name": "Sky", "ColorScheme": "Sky"}, **_kde_colors(p), **effects}
    out = []
    for name, keys in sections.items():
        out += [f"[{name}]"] + [f"{k}={v}" for k, v in keys.items()] + [""]
    return "\n".join(out)


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


def render_starship(base: str, p: dict) -> str:
    """The user's starship config, switched to a `sky` palette built from the wallpaper.

    Path, user and git take the accent tones; green/red keep success/error meaning.
    """
    sky = {
        "text": p["on"], "subtext0": p["outline"], "subtext1": p["muted"],
        "blue": p["accent"], "sapphire": p["accent"], "sky": p["accent"],
        "mauve": p["tertiary"], "purple": p["tertiary"], "lavender": p["secondary"],
        "teal": p["secondary"], "cyan": p["secondary"], "pink": p["tertiary"],
        "yellow": "yellow", "orange": "bright-yellow", "peach": "bright-yellow",
        "green": "green", "red": "red", "maroon": "red", "flamingo": "bright-red",
    }
    lines = base.splitlines()
    out, replaced, in_root = [], False, True
    for line in lines:
        if line.lstrip().startswith("["):
            if in_root and not replaced:
                out.append('palette = "sky"')
                replaced = True
            in_root = False
        if in_root and line.split("=")[0].strip() == "palette":
            line, replaced = 'palette = "sky"', True
        out.append(line)
    if not replaced:
        out.append('palette = "sky"')
    out += ["", "# Generated by sky_theme.py from the wallpaper.", "[palettes.sky]"]
    out += [f'{k} = "{v}"' for k, v in sky.items()]
    return "\n".join(out) + "\n"


def write_atomic(out: Path, text: str) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=out.parent, prefix=f".{out.name}-")
    with os.fdopen(fd, "w") as f:
        f.write(text)
    os.replace(tmp, out)


def write_palette(out: Path, palette: dict) -> None:
    write_atomic(out, json.dumps(palette, indent=2))


def _run_quiet(argv: list[str]) -> None:
    try:
        subprocess.run(argv, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                       check=False, timeout=10)
    except (OSError, subprocess.TimeoutExpired):
        pass


def apply(palette: dict, out_dir: Path = DEFAULT_OUT_DIR, btop_theme: Path = BTOP_THEME,
          starship_base: Path = STARSHIP_BASE, kdeglobals: Path = KDEGLOBALS,
          kde_scheme: Path = KDE_SCHEME, run=_run_quiet) -> None:
    """Write every target, then ask the running programs to reload."""
    write_atomic(out_dir / "kitty.conf", render_kitty(palette))
    write_atomic(out_dir / "hyprland.lua", render_hyprland(palette))
    write_atomic(out_dir / "hyprlock.conf", render_hyprlock(palette))
    write_atomic(out_dir / "gtk.css", render_gtk(palette))
    write_atomic(out_dir / "gtk3.css", render_gtk3(palette))
    write_atomic(out_dir / "qt6ct-colors.conf", render_qt6ct(palette))
    write_atomic(btop_theme, render_btop(palette))
    try:
        kde_base = kdeglobals.read_text()
    except OSError:
        kde_base = ""
    write_atomic(kdeglobals, render_kdeglobals(kde_base, palette))
    write_atomic(kde_scheme, render_kde_scheme(palette))
    if starship_base.is_file():
        write_atomic(out_dir / "starship.toml", render_starship(starship_base.read_text(), palette))
    # colors.json last: the sky shell and nvim watch it.
    write_palette(out_dir / "colors.json", palette)
    run(["pkill", "-USR1", "-x", "kitty"])
    run(["hyprctl", "reload"])


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


def load_prefs(path: Path = THEME_PREFS) -> tuple[str | None, str | None]:
    """(scheme, accent) from the user's theme.json; missing/invalid values are None."""
    try:
        data = json.loads(path.read_text())
    except (OSError, ValueError):
        return None, None
    if not isinstance(data, dict):
        return None, None
    scheme, accent = data.get("scheme"), data.get("accent")
    if scheme not in SCHEMES:
        scheme = None
    if not (isinstance(accent, str) and re.fullmatch(r"#[0-9a-fA-F]{6}", accent)):
        accent = None
    return scheme, accent.lower() if accent else None


def generate(wallpaper: Path | None, prefs: Path = THEME_PREFS) -> dict:
    scheme, accent = load_prefs(prefs)
    extra = ["-t", scheme] if scheme else []
    src, kind = color_source(wallpaper) if wallpaper else (None, "none")
    with tempfile.TemporaryDirectory() as tmp:
        if accent:
            wall = _matugen("color", "hex", accent, *extra)
        elif src is None:
            wall = _matugen("color", "hex", FALLBACK_SEED, *extra)
        else:
            img = src if kind == "image" else _still_frame(src, kind, Path(tmp))
            wall = _matugen("image", str(img), "--prefer", "saturation",
                            "--fallback-color", FALLBACK_SEED, *extra)
    palette = build_palette(wall)
    palette["wallpaper"] = str(wallpaper) if wallpaper else ""
    return palette


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("wallpaper", nargs="?", type=Path)
    ap.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    ap.add_argument("--no-reload", action="store_true", help="write files only")
    args = ap.parse_args(argv)
    if not shutil.which("matugen"):
        print("sky_theme: matugen not found", file=sys.stderr)
        return 1
    wallpaper = args.wallpaper or current_wallpaper()
    palette = generate(wallpaper)
    apply(palette, args.out_dir, run=(lambda _argv: None) if args.no_reload else _run_quiet)
    print(json.dumps(palette))
    return 0


if __name__ == "__main__":
    sys.exit(main())
