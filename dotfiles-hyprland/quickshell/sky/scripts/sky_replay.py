#!/usr/bin/env python3
"""Instant replay (Medal-style clips) for the sky shell.

gpu-screen-recorder keeps the last N seconds in RAM; ReplayService.qml runs it
with the command built here and sends SIGUSR1 to save a clip. Options live in
the "replay" object of ~/.config/sky/settings.json.

  sky_replay.py cmd SETTINGS [SCREEN]      -> JSON argv for gpu-screen-recorder
  sky_replay.py set SETTINGS KEY VALUE     -> merge one replay option into SETTINGS
  sky_replay.py scan DIR                   -> JSON list of clips, newest first
  sky_replay.py delete DIR CLIP            -> delete one clip inside DIR
  sky_replay.py uri CLIP                   -> text/uri-list line for the clipboard
"""
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import urllib.parse
from pathlib import Path

MIN_SECONDS = 5
MAX_SECONDS = 600
FPS = (30, 60, 120, 144)
QUALITIES = ("medium", "high", "very_high", "ultra")
AUDIO = {"none": None, "desktop": "default_output", "desktop_mic": "default_output|default_input"}
VIDEO_EXT = {".mp4", ".mkv", ".webm", ".mov"}
BOOLS = {"true": True, "1": True, "on": True, "false": False, "0": False, "off": False}


def defaults() -> dict:
    return {"enabled": False, "seconds": 30, "fps": 60, "quality": "very_high",
            "audio": "desktop", "dir": str(Path.home() / "Videos" / "Clips")}


def _read_settings(path: Path) -> dict:
    if not path.is_file():
        return {}
    try:
        data = json.loads(path.read_text())
    except ValueError:
        raise ValueError("%s is not valid JSON; not touching it" % path)
    if not isinstance(data, dict):
        raise ValueError("%s is not a JSON object; not touching it" % path)
    return data


def _expand(d: str) -> str:
    return str(Path(os.path.expanduser(d)))


def load_options(path) -> dict:
    """Effective options: settings.json "replay" values over the defaults; bad values are ignored."""
    o = defaults()
    try:
        raw = _read_settings(Path(path)).get("replay")
    except (ValueError, OSError):
        raw = None
    if not isinstance(raw, dict):
        return o
    if isinstance(raw.get("enabled"), bool):
        o["enabled"] = raw["enabled"]
    s = raw.get("seconds")
    if isinstance(s, int) and not isinstance(s, bool):
        o["seconds"] = max(MIN_SECONDS, min(MAX_SECONDS, s))
    if raw.get("fps") in FPS:
        o["fps"] = raw["fps"]
    if raw.get("quality") in QUALITIES:
        o["quality"] = raw["quality"]
    if raw.get("audio") in AUDIO:
        o["audio"] = raw["audio"]
    if isinstance(raw.get("dir"), str) and raw["dir"].strip():
        o["dir"] = _expand(raw["dir"].strip())
    return o


def build_command(o: dict, screen: str = "") -> list:
    argv = ["gpu-screen-recorder", "-w", screen or "screen", "-f", str(o["fps"]), "-c", "mp4",
            "-r", str(o["seconds"]), "-q", o["quality"]]
    if AUDIO[o["audio"]]:
        argv += ["-a", AUDIO[o["audio"]]]
    return argv + ["-o", o["dir"]]


def parse_value(key: str, value: str):
    if key == "enabled":
        if value.lower() not in BOOLS:
            raise ValueError("enabled must be true or false")
        return BOOLS[value.lower()]
    if key == "seconds":
        try:
            n = int(value)
        except ValueError:
            raise ValueError("seconds must be a whole number")
        if not MIN_SECONDS <= n <= MAX_SECONDS:
            raise ValueError("seconds must be between %d and %d" % (MIN_SECONDS, MAX_SECONDS))
        return n
    if key == "fps":
        if not value.isdigit() or int(value) not in FPS:
            raise ValueError("fps must be one of: %s" % ", ".join(map(str, FPS)))
        return int(value)
    if key == "quality":
        if value not in QUALITIES:
            raise ValueError("quality must be one of: %s" % ", ".join(QUALITIES))
        return value
    if key == "audio":
        if value not in AUDIO:
            raise ValueError("audio must be one of: %s" % ", ".join(AUDIO))
        return value
    if key == "dir":
        if not value.strip():
            raise ValueError("dir must not be empty")
        return value.strip()
    raise ValueError("unknown option %r" % key)


def _atomic_write(target: Path, data: str):
    fd, tmp = tempfile.mkstemp(dir=str(target.parent), prefix=target.name + ".")
    try:
        with os.fdopen(fd, "w") as fh:
            fh.write(data)
            fh.flush()
            os.fsync(fh.fileno())
        if target.exists():
            shutil.copymode(target, tmp)
        os.replace(tmp, target)
    except BaseException:
        Path(tmp).unlink(missing_ok=True)
        raise


def set_option(path, key: str, value: str):
    parsed = parse_value(key, value)
    real = Path(path).resolve()
    data = _read_settings(real)
    replay = data.get("replay") if isinstance(data.get("replay"), dict) else {}
    replay[key] = parsed
    data["replay"] = replay
    real.parent.mkdir(parents=True, exist_ok=True)
    _atomic_write(real, json.dumps(data, indent=2, ensure_ascii=False) + "\n")


# --- clips ------------------------------------------------------------------


def _cache_dir() -> Path:
    base = os.environ.get("XDG_CACHE_HOME") or str(Path.home() / ".cache")
    return Path(base) / "sky" / "clip-thumbs"


def thumb(path: Path, mtime: int):
    """One cached still per clip (keyed by path and mtime). None without ffmpeg."""
    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg is None:
        return None
    cache = _cache_dir()
    try:
        cache.mkdir(parents=True, exist_ok=True)
    except OSError:
        return None
    out = cache / (hashlib.sha1(("%s:%d" % (path, mtime)).encode()).hexdigest() + ".jpg")
    if out.is_file() and out.stat().st_size > 0:
        return str(out)
    tmp = out.with_suffix(".tmp.jpg")
    r = subprocess.run([ffmpeg, "-y", "-ss", "1", "-i", str(path), "-frames:v", "1",
                        "-vf", "scale=480:-1", "-q:v", "4", str(tmp)],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
    if r.returncode != 0 or not tmp.is_file():
        tmp.unlink(missing_ok=True)
        return None
    os.replace(tmp, out)
    return str(out)


def scan(d) -> list:
    root = Path(_expand(str(d)))
    if not root.is_dir():
        return []
    items = []
    for p in root.iterdir():
        if p.is_file() and p.suffix.lower() in VIDEO_EXT and not p.name.startswith("."):
            st = p.stat()
            items.append({"path": str(p), "name": p.name, "size": st.st_size, "mtime": int(st.st_mtime)})
    items.sort(key=lambda i: (-i["mtime"], i["name"]))
    for i in items:
        i["thumb"] = thumb(Path(i["path"]), i["mtime"])
    return items


def delete(d, clip):
    root = Path(_expand(str(d))).resolve()
    target = Path(clip).resolve()
    if target.parent != root:
        raise ValueError("%s is not inside %s" % (clip, root))
    if target.suffix.lower() not in VIDEO_EXT or not target.is_file():
        raise ValueError("%s is not a clip" % clip)
    target.unlink()


def uri(clip) -> str:
    return "file://" + urllib.parse.quote(str(Path(clip).resolve())) + "\r\n"


def _run(cmd: str, args: list) -> int:
    if cmd == "cmd" and len(args) in (1, 2):
        o = load_options(args[0])
        Path(o["dir"]).mkdir(parents=True, exist_ok=True)
        print(json.dumps(build_command(o, args[1] if len(args) == 2 else "")))
    elif cmd == "options" and len(args) == 1:
        print(json.dumps(load_options(args[0])))
    elif cmd == "set" and len(args) == 3:
        set_option(*args)
    elif cmd == "scan" and len(args) == 1:
        print(json.dumps(scan(args[0])))
    elif cmd == "delete" and len(args) == 2:
        delete(*args)
    elif cmd == "uri" and len(args) == 1:
        print(uri(args[0]), end="")
    else:
        print(__doc__)
        return 2
    return 0


def main(argv) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 2
    try:
        return _run(argv[1], argv[2:])
    except (ValueError, OSError) as e:
        print("sky_replay: %s" % e, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
