#!/usr/bin/env python3
"""Wallpaper library and applier for the sky shell.

The shell's picker (wallpaper/WallpaperView.qml) is dumb on purpose: this
script owns the filesystem, the thumbnails and the backend commands.

  sky_wallpaper.py scan             JSON list of every wallpaper, for the grid
  sky_wallpaper.py apply <path>     apply it and remember it
  sky_wallpaper.py restore          re-apply the remembered one (login autostart)
  sky_wallpaper.py check            which optional tools and sources exist
  sky_wallpaper.py still <scene>    render a still of a scene (hyprlock)

Sources are the wallpaper folder (images and videos) and the Wallpaper Engine
scenes already owned through Steam. Wallpaper Engine is optional: without
`linux-wallpaperengine` on PATH no scene is listed, and nothing breaks.

  Image -> swww (or awww), daemon started on demand
  Video -> mpvpaper, auto-paused while a fullscreen window covers it
  Scene -> linux-wallpaperengine, one --screen-root per monitor
"""

from __future__ import annotations

import json
import os
import shutil
import signal
import subprocess
import sys
import time
from pathlib import Path

IMAGE_EXTENSIONS = frozenset({"jpg", "jpeg", "png", "webp", "bmp", "gif", "avif", "jxl", "tiff"})
VIDEO_EXTENSIONS = frozenset({"mp4", "mkv", "webm", "mov", "avi", "m4v"})

APP = "sky"
WORKSHOP_APP_ID = "431960"


# --- paths ------------------------------------------------------------------


def _xdg(var: str, fallback: str, home: Path | None = None) -> Path:
    value = os.environ.get(var)
    if value:
        return Path(value)
    return (home or Path.home()) / fallback


def config_home(home: Path | None = None) -> Path:
    return _xdg("XDG_CONFIG_HOME", ".config", home) / APP


def cache_root(home: Path | None = None) -> Path:
    return _xdg("XDG_CACHE_HOME", ".cache", home) / APP


def state_path(home: Path | None = None) -> Path:
    return config_home(home) / "wallpaper.json"


def blacklist_path(home: Path | None = None) -> Path:
    return config_home(home) / "scene-blacklist"


def default_dir(home: Path | None = None) -> Path | None:
    """Best guess for the wallpaper folder: a Pictures dir, Wallpapers inside it."""
    home = home or Path.home()
    pictures = os.environ.get("XDG_PICTURES_DIR")
    bases = [Path(pictures)] if pictures else []
    bases += [home / "Pictures", home / "Imágenes"]
    for base in bases:
        if (base / "Wallpapers").is_dir():
            return base / "Wallpapers"
        if base.is_dir():
            return base
    return None


# --- entries ----------------------------------------------------------------


def kind_of(path: Path) -> str | None:
    # A Wallpaper Engine scene is a directory (the workshop item), so it has no
    # extension to look at.
    if path.is_dir():
        return "scene"
    ext = path.suffix.lower().lstrip(".")
    if ext in IMAGE_EXTENSIONS:
        return "image"
    if ext in VIDEO_EXTENSIONS:
        return "video"
    return None


def _entry(path: Path, kind: str, title: str, thumb: Path | None) -> dict:
    return {
        "path": str(path),
        "kind": kind,
        "title": title,
        "thumb": str(thumb) if thumb else None,
    }


def scan_folder(directory: Path) -> list[dict]:
    """Images and videos in `directory` (flat, no hidden files).

    `.scene` entries are skipped on purpose: scenes come from the Workshop now,
    so a leftover staging symlink must not show the same wallpaper twice.
    """
    if not directory or not directory.is_dir():
        return []
    entries: list[dict] = []
    for child in directory.iterdir():
        if child.name.startswith(".") or child.name.endswith(".scene"):
            continue
        if not child.is_file():
            continue
        kind = kind_of(child)
        if kind is None:
            continue
        entries.append(_entry(child, kind, child.stem, child if kind == "image" else None))
    entries.sort(key=lambda e: e["title"].lower())
    return entries


def workshop_roots(home: Path | None = None, data: Path | None = None) -> list[Path]:
    """Every place Steam may keep the Wallpaper Engine workshop, native or Flatpak."""
    home = home or Path.home()
    data = data or _xdg("XDG_DATA_HOME", ".local/share", home)
    tail = Path("steamapps") / "workshop" / "content" / WORKSHOP_APP_ID
    bases = [
        data / "Steam",
        home / ".local/share/Steam",
        home / ".steam/steam",
        home / ".steam/root",
        home / ".var/app/com.valvesoftware.Steam/.local/share/Steam",
    ]
    seen: list[Path] = []
    seen_real: set[str] = set()
    for base in bases:
        root = base / tail
        real = os.path.realpath(root)
        if real in seen_real:
            continue  # ~/.steam/steam, ~/.steam/root and ~/.local/share/Steam are the same tree
        seen_real.add(real)
        seen.append(root)
    return seen


def _item_dir(item: Path) -> Path | None:
    """Workshop items nest either as <id>/ or as <id>/<id>/."""
    for candidate in (item, item / item.name):
        if (candidate / "project.json").is_file():
            return candidate
    return None


def _workshop_entry(item_dir: Path) -> dict | None:
    try:
        data = json.loads((item_dir / "project.json").read_text())
    except (OSError, ValueError):
        return None
    kind = str(data.get("type", "")).lower()
    preview = data.get("preview")
    thumb = item_dir / preview if preview else None
    if thumb is None or not thumb.is_file():
        return None
    title = data.get("title") or item_dir.name
    if kind == "scene":
        return _entry(item_dir, "scene", title, thumb)
    if kind not in ("image", "video"):
        return None
    payload = data.get("file")
    if not payload:
        return None
    path = item_dir / payload
    if not path.is_file():
        return None
    payload_kind = kind_of(path) or kind
    return _entry(path, payload_kind, title, thumb)


def scan_workshop(roots: list[Path], blacklist: set[str]) -> list[dict]:
    entries: list[dict] = []
    seen: set[str] = set()
    for root in roots:
        if not root.is_dir():
            continue
        for item in sorted(root.iterdir()):
            if not item.is_dir() or item.name in blacklist:
                continue
            real = os.path.realpath(item)
            if real in seen:
                continue  # the same Steam tree reached through another probe path
            seen.add(real)
            item_dir = _item_dir(item)
            if item_dir is None:
                continue
            entry = _workshop_entry(item_dir)
            if entry is not None:
                entries.append(entry)
    entries.sort(key=lambda e: e["title"].lower())
    return entries


def read_blacklist(home: Path | None = None, folder: Path | None = None) -> set[str]:
    """Workshop ids linux-wallpaperengine cannot render.

    Read from ~/.config/sky/scene-blacklist, falling back to the old
    `<wallpapers>/.scene-blacklist` the removed sync script used.
    """
    ids: set[str] = set()
    for path in (blacklist_path(home), (folder / ".scene-blacklist") if folder else None):
        if path is None or not path.is_file():
            continue
        try:
            for line in path.read_text().splitlines():
                line = line.strip()
                if line and not line.startswith("#"):
                    ids.add(line)
        except OSError:
            pass
    return ids


# --- state ------------------------------------------------------------------


def read_state(state: Path | None = None) -> dict:
    state = state or state_path()
    try:
        data = json.loads(state.read_text())
    except (OSError, ValueError):
        return {}
    return data if isinstance(data, dict) else {}


def save_state(path: Path, kind: str, state: Path | None = None) -> None:
    """Remember the applied wallpaper, keeping the configured folder."""
    state = state or state_path()
    data = read_state(state)
    data["path"] = str(path)
    data["kind"] = kind
    state.parent.mkdir(parents=True, exist_ok=True)
    tmp = state.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(data, indent=2) + "\n")
    tmp.replace(state)


def load_dir(state: Path | None = None, home: Path | None = None) -> Path | None:
    """The wallpaper folder: configured here, else migrated once from wallfliper."""
    configured = read_state(state).get("dir")
    if configured:
        return Path(configured)
    legacy = (_xdg("XDG_CONFIG_HOME", ".config", home) / "wallfliper" / "config.json")
    if legacy.is_file():
        try:
            old = json.loads(legacy.read_text()).get("wallpaper_dir")
        except (OSError, ValueError, AttributeError):
            old = None
        if old:
            return Path(old)
    return default_dir(home)


def ensure_state(state: Path | None = None, home: Path | None = None) -> None:
    """Create the state file once, migrating the wallpaper the old app had.

    Theme.qml and WallpaperService watch this file, so it must exist before the
    first apply or the palette would only start following wallpapers after a
    shell restart. The migration keeps whatever wallfliper had applied.
    """
    state = state or state_path()
    if state.is_file():
        return
    data: dict = {}
    folder = load_dir(state, home)
    if folder:
        data["dir"] = str(folder)
    legacy = _xdg("XDG_CONFIG_HOME", ".config", home) / "wallfliper" / "state.json"
    try:
        old = json.loads(legacy.read_text())
    except (OSError, ValueError):
        old = {}
    if old.get("path"):
        # Old scenes were `.scene` staging symlinks; the picker points at the
        # workshop directory itself, so resolve it on the way in.
        path = Path(old["path"])
        if path.name.endswith(".scene") and path.is_symlink():
            path = path.resolve()
        data["path"] = str(path)
        data["kind"] = old.get("kind", "image")
    try:
        state.parent.mkdir(parents=True, exist_ok=True)
        state.write_text(json.dumps(data, indent=2) + "\n")
    except OSError:
        pass


def scan(state: Path | None = None, home: Path | None = None) -> list[dict]:
    """Every wallpaper the shell can offer, with a usable thumbnail."""
    state = state or state_path()
    ensure_state(state, home)
    folder = load_dir(state, home)
    entries = scan_folder(folder) if folder else []
    entries += scan_workshop(workshop_roots(home), read_blacklist(home, folder))
    seen: set[str] = set()
    out: list[dict] = []
    for entry in entries:
        real = os.path.realpath(entry["path"])
        if real in seen:
            continue
        seen.add(real)
        if entry["kind"] == "video" and not entry["thumb"]:
            entry["thumb"] = video_thumb(Path(entry["path"]))
        out.append(entry)
    return out


# --- thumbnails -------------------------------------------------------------


def video_thumb(path: Path, cache: Path | None = None) -> str | None:
    """One still frame per video, cached. None without ffmpeg (the card goes flat)."""
    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg is None:
        return None
    cache = cache or cache_root() / "thumbnails"
    try:
        cache.mkdir(parents=True, exist_ok=True)
    except OSError:
        return None
    out = cache / f"{abs(hash(str(path))):x}.jpg"
    if out.is_file() and out.stat().st_size > 0:
        return str(out)
    tmp = out.with_suffix(".tmp.jpg")
    result = subprocess.run(
        [ffmpeg, "-y", "-ss", "1", "-i", str(path), "-frames:v", "1",
         "-vf", "scale=640:-1", "-q:v", "4", str(tmp)],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False,
    )
    if result.returncode != 0 or not tmp.is_file():
        tmp.unlink(missing_ok=True)
        return None
    tmp.replace(out)
    return str(out)


# --- backends ---------------------------------------------------------------

_MPV_OPTIONS = " ".join([
    "loop", "--no-audio", "no-config", "no-osd", "--hwdec=no",
    "--video-fit=cover", "--video-sync=audio", "pause=no",
])

_ENGINE_FLAGS = ["--disable-mouse", "--disable-parallax", "--disable-particles",
                 "--scaling", "fill", "--silent", "--fps", "30"]


def image_cmd(tool: str, path: Path) -> list[str]:
    return [tool, "img", "--transition-type", "grow",
            "--transition-duration", "0.8", str(path)]


def video_cmd(mpvpaper: str, path: Path) -> list[str]:
    return [mpvpaper, "-o", _MPV_OPTIONS, "*", str(path)]


def scene_cmd(engine: str, scene_dir: Path, monitors: list[str]) -> list[str]:
    argv = [engine]
    for monitor in monitors:
        argv += ["--screen-root", monitor]
    if monitors:
        argv += ["--bg", str(scene_dir)]
    else:
        argv += ["--bg", str(scene_dir)]
    return argv + _ENGINE_FLAGS


def _first(candidates: tuple[str, ...]) -> str | None:
    for name in candidates:
        found = shutil.which(name)
        if found:
            return found
    return None


def _run(argv: list[str], timeout: float = 15.0) -> int:
    try:
        return subprocess.run(argv, stdout=subprocess.DEVNULL,
                              stderr=subprocess.DEVNULL, check=False,
                              timeout=timeout).returncode
    except (OSError, subprocess.TimeoutExpired):
        return 1


def _spawn(argv: list[str]) -> None:
    subprocess.Popen(argv, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                     stdin=subprocess.DEVNULL, start_new_session=True)


def monitors() -> list[str]:
    try:
        out = subprocess.run(["hyprctl", "monitors", "-j"], capture_output=True,
                             text=True, check=False, timeout=5.0).stdout
        names = [m["name"] for m in json.loads(out) if "name" in m]
        return names
    except (OSError, ValueError, subprocess.TimeoutExpired):
        return []


def _kill_by_program(basenames: set[str], proc: Path = Path("/proc")) -> None:
    """SIGTERM processes whose executed program is one of `basenames`.

    Matched on argv[0] instead of `pkill -f`: a full-command-line match also
    hits any shell, editor or log tailer that merely mentions the name, which
    is how `pkill -f linux-wallpaperengine` kills its own caller.
    """
    me = os.getpid()
    for entry in proc.iterdir():
        if not entry.name.isdigit():
            continue
        pid = int(entry.name)
        if pid == me:
            continue
        try:
            argv = (entry / "cmdline").read_bytes().split(b"\0")
        except OSError:
            continue
        if not argv or not argv[0]:
            continue
        name = os.path.basename(argv[0].decode(errors="replace")).lower()
        if name not in basenames:
            continue
        try:
            os.kill(pid, signal.SIGTERM)
        except OSError:
            pass


def _stop_video() -> None:
    _kill_by_program({"mpvpaper"})


def _stop_scene() -> None:
    _kill_by_program({"linux-wallpaperengine"})


def _ensure_swww(tool: str) -> bool:
    if _run([tool, "query"]) == 0:
        return True
    daemon = _first((Path(tool).name + "-daemon",))
    if daemon is None:
        return False
    _spawn([daemon])
    for _ in range(30):
        if _run([tool, "query"]) == 0:
            return True
        time.sleep(0.1)
    return False


# --- apply ------------------------------------------------------------------


def apply(path: Path, kind: str | None = None) -> int:
    kind = kind or kind_of(path)
    if kind is None:
        print(f"sky_wallpaper: unsupported wallpaper: {path}", file=sys.stderr)
        return 2

    if kind == "image":
        _stop_video()
        _stop_scene()
        tool = _first(("swww", "awww"))
        if tool is None:
            print("sky_wallpaper: install swww for image wallpapers", file=sys.stderr)
            return 1
        if not _ensure_swww(tool):
            print("sky_wallpaper: swww daemon did not start", file=sys.stderr)
            return 1
        code = _run(image_cmd(tool, path))
    elif kind == "video":
        _stop_scene()
        _stop_video()
        tool = _first(("mpvpaper",))
        if tool is None:
            print("sky_wallpaper: install mpvpaper for video wallpapers", file=sys.stderr)
            return 1
        _spawn(video_cmd(tool, path))
        code = 0
    else:
        _stop_video()
        _stop_scene()
        tool = _first(("linux-wallpaperengine",))
        if tool is None:
            print("sky_wallpaper: install linux-wallpaperengine for scenes", file=sys.stderr)
            return 1
        scene_dir = path if path.is_dir() else path.resolve()
        _spawn(scene_cmd(tool, scene_dir, monitors()))
        code = 0

    if code == 0:
        save_state(path, kind)
        if kind == "scene":
            _spawn([sys.executable, str(Path(__file__).resolve()), "still", str(path)])
    return code


def scene_still(scene_dir: Path) -> Path | None:
    """Screenshot of a scene, cached, for hyprlock and the fallback layer.

    linux-wallpaperengine has no headless mode: it presents through a
    wlr-layer-shell surface, so a short-lived second instance renders the same
    pixels, writes them with --screenshot and is killed immediately.
    """
    engine = _first(("linux-wallpaperengine",))
    if engine is None or not scene_dir.is_dir():
        return None
    out = cache_root() / "scene-stills" / f"{scene_dir.name}.png"
    if out.is_file() and out.stat().st_size > 0:
        return out
    try:
        out.parent.mkdir(parents=True, exist_ok=True)
    except OSError:
        return None
    proc = subprocess.Popen(
        [engine, "--screenshot", str(out), "--bg", str(scene_dir),
         "--fps", "30", "--silent", "--disable-mouse", "--disable-parallax",
         "--disable-particles", "--scaling", "fill"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        stdin=subprocess.DEVNULL, start_new_session=True,
    )
    deadline = time.monotonic() + 20.0
    try:
        while time.monotonic() < deadline:
            if out.is_file() and out.stat().st_size > 0:
                return out
            if proc.poll() is not None:
                break
            time.sleep(0.2)
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=2.0)
        except subprocess.TimeoutExpired:
            proc.kill()
    out.unlink(missing_ok=True)
    return None


def sync_hyprlock(still: Path, home: Path | None = None) -> bool:
    """Point hyprlock's $background_image at `still`.

    Written to local state, sourced by hyprlock.conf, so the machine-specific
    path never lands in the tracked config.
    """
    state = Path(os.environ.get("XDG_STATE_HOME") or (home or Path.home()) / ".local" / "state")
    conf = state / "sky" / "hyprlock-background.conf"
    wanted = f"$background_image = {still}\n"
    try:
        if conf.is_file() and conf.read_text() == wanted:
            return False
        conf.parent.mkdir(parents=True, exist_ok=True)
        conf.write_text(wanted)
    except OSError:
        return False
    return True


# --- reporting --------------------------------------------------------------


def check(which=shutil.which, state: Path | None = None, home: Path | None = None) -> dict:
    tools = {name: bool(which(name)) for name in
             ("swww", "awww", "mpvpaper", "linux-wallpaperengine", "ffmpeg")}
    folder = load_dir(state)
    roots = [root for root in workshop_roots(home) if root.is_dir()]
    scenes = scan_workshop(roots, read_blacklist(home, folder))
    return {
        "tools": tools,
        "sources": {
            "folder": str(folder) if folder else None,
            "folder_exists": bool(folder and folder.is_dir()),
            "workshop_roots": [str(root) for root in roots],
            "scenes": len(scenes),
        },
    }


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    command = args.pop(0) if args else "scan"

    if command == "scan":
        print(json.dumps(scan()))
        return 0
    if command == "check":
        print(json.dumps(check(), indent=2))
        return 0
    if command == "apply":
        if not args:
            print("sky_wallpaper: apply needs a path", file=sys.stderr)
            return 2
        # The picker knows the kind from the scan; passing it avoids guessing.
        return apply(Path(args[0]), args[1] if len(args) > 1 else None)
    if command == "restore":
        state = read_state()
        saved = state.get("path")
        if not saved:
            return 0
        path = Path(saved)
        if not path.exists():
            print(f"sky_wallpaper: saved wallpaper missing: {path}", file=sys.stderr)
            return 1
        return apply(path, state.get("kind"))
    if command == "still":
        if not args:
            return 2
        still = scene_still(Path(args[0]))
        if still is None:
            return 1
        sync_hyprlock(still)
        return 0

    print(f"sky_wallpaper: unknown command: {command}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
