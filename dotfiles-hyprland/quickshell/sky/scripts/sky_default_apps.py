#!/usr/bin/env python3
"""Installed applications that can open a MIME type, for the settings page.

    sky_default_apps.py apps <mime>   -> JSON [{"id": "x.desktop", "name": "X"}]
"""
import json
import os
import sys
from pathlib import Path


def data_dirs() -> list:
    home = os.environ.get("XDG_DATA_HOME") or str(Path.home() / ".local/share")
    system = os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share"
    return [Path(home)] + [Path(p) for p in system.split(":") if p]


def parse(path: Path):
    """Main-section keys of a .desktop file, or None when unreadable."""
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return None
    keys, inside = {}, False
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("["):
            inside = line == "[Desktop Entry]"
        elif inside and "=" in line and not line.startswith("#"):
            k, v = line.split("=", 1)
            keys.setdefault(k.strip(), v.strip())
    return keys


def apps_for(mime: str, dirs=None) -> list:
    found = {}
    for base in dirs if dirs is not None else data_dirs():
        folder = Path(base) / "applications"
        if not folder.is_dir():
            continue
        for f in sorted(folder.rglob("*.desktop")):
            ident = "-".join(f.relative_to(folder).parts)
            if ident in found:
                continue
            keys = parse(f)
            found[ident] = keys
    out = []
    for ident, keys in found.items():
        if not keys or keys.get("Type") != "Application":
            continue
        if keys.get("NoDisplay", "").lower() == "true" or keys.get("Hidden", "").lower() == "true":
            continue
        if mime in [m for m in keys.get("MimeType", "").split(";") if m]:
            out.append({"id": ident, "name": keys.get("Name") or ident})
    return sorted(out, key=lambda a: a["name"].lower())


def main(argv: list) -> int:
    if len(argv) != 3 or argv[1] != "apps":
        print(__doc__, file=sys.stderr)
        return 2
    print(json.dumps(apps_for(argv[2])))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
