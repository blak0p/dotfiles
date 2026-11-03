#!/usr/bin/env python3
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time

os.environ["LC_ALL"] = "C"
os.environ["LANG"] = "C"

STATE_DIR = os.path.expanduser("~/.local/state/sky")
CACHE_FILE = os.path.join(STATE_DIR, "updates.json")


def get_updates():
    pkgs = []
    pacman_count = 0
    aur_count = 0
    brew_count = 0

    # 1. pacman (via checkupdates)
    if shutil.which("checkupdates"):
        try:
            res = subprocess.run(
                ["checkupdates"], capture_output=True, text=True, timeout=15
            )
            if res.stdout:
                for line in res.stdout.strip().split("\n"):
                    parts = line.split()
                    if len(parts) >= 4 and parts[2] == "->":
                        pkgs.append(
                            {
                                "name": parts[0],
                                "old": parts[1],
                                "new": parts[3],
                                "source": "pacman",
                                "repo": "pacman",
                                "description": "",
                            }
                        )
                        pacman_count += 1
        except Exception as e:
            print(f"Error checking pacman: {e}", file=sys.stderr)

    # 2. aur (paru or yay)
    aur_bin = shutil.which("paru") or shutil.which("yay")
    if aur_bin:
        try:
            res = subprocess.run(
                [aur_bin, "-Qua", "--color=never"],
                capture_output=True,
                text=True,
                timeout=15,
            )
            if res.stdout:
                for line in res.stdout.strip().split("\n"):
                    parts = line.split()
                    if len(parts) >= 4 and parts[2] == "->":
                        pkg_name = parts[0]
                        if not any(p["name"] == pkg_name for p in pkgs):
                            pkgs.append(
                                {
                                    "name": pkg_name,
                                    "old": parts[1],
                                    "new": parts[3],
                                    "source": "aur",
                                    "repo": "aur",
                                    "description": "",
                                }
                            )
                            aur_count += 1
        except Exception as e:
            print(f"Error checking aur: {e}", file=sys.stderr)

    # 3. brew
    brew_bin = shutil.which("brew")
    if not brew_bin and os.path.exists("/home/linuxbrew/.linuxbrew/bin/brew"):
        brew_bin = "/home/linuxbrew/.linuxbrew/bin/brew"

    if brew_bin:
        try:
            res = subprocess.run(
                [brew_bin, "outdated", "--json=v2"],
                capture_output=True,
                text=True,
                timeout=20,
            )
            if res.returncode == 0 and res.stdout.strip():
                data = json.loads(res.stdout)
                for f in data.get("formulae", []):
                    inst = f.get("installed_versions", ["?"])[0]
                    curr = f.get("current_version", "?")
                    pkgs.append(
                        {
                            "name": f.get("name"),
                            "old": inst,
                            "new": curr,
                            "source": "brew",
                            "repo": "brew",
                            "description": f.get("desc", ""),
                        }
                    )
                    brew_count += 1
                for c in data.get("casks", []):
                    inst = c.get("installed_version", "?")
                    curr = c.get("current_version", "?")
                    pkgs.append(
                        {
                            "name": c.get("name"),
                            "old": inst,
                            "new": curr,
                            "source": "brew",
                            "repo": "brew",
                            "description": c.get("desc", ""),
                        }
                    )
                    brew_count += 1
        except Exception as e:
            print(f"Error checking brew: {e}", file=sys.stderr)

    # Descriptions for pacman packages (fast batch)
    pacman_names = [p["name"] for p in pkgs if p["source"] == "pacman"]
    if pacman_names:
        try:
            info_proc = subprocess.run(
                ["pacman", "-Qi"] + pacman_names,
                capture_output=True,
                text=True,
                timeout=10,
            )
            desc_map = {}
            current_name = None
            for line in info_proc.stdout.split("\n"):
                if " : " in line:
                    k, v = line.split(" : ", 1)
                    k, v = k.strip(), v.strip()
                    if k == "Name":
                        current_name = v
                    elif k == "Description" and current_name:
                        desc_map[current_name] = v
            for p in pkgs:
                if p["name"] in desc_map:
                    p["description"] = desc_map[p["name"]]
        except Exception:
            pass

    # Descriptions for AUR packages (fast batch)
    aur_names = [p["name"] for p in pkgs if p["source"] == "aur"]
    if aur_names and aur_bin:
        try:
            info_proc = subprocess.run(
                [aur_bin, "-Si"] + aur_names,
                capture_output=True,
                text=True,
                timeout=8,
            )
            desc_map = {}
            current_name = None
            for line in info_proc.stdout.split("\n"):
                if " : " in line:
                    k, v = line.split(" : ", 1)
                    k, v = k.strip(), v.strip()
                    if k == "Name":
                        current_name = v
                    elif k == "Description" and current_name:
                        desc_map[current_name] = v
            for p in pkgs:
                if p["name"] in desc_map:
                    p["description"] = desc_map[p["name"]]
        except Exception:
            pass

    # Fallback descriptions if blank
    for p in pkgs:
        if not p["description"]:
            p["description"] = f"{p['source'].capitalize()} update: {p['old']} -> {p['new']}"

    output = {
        "checked_at": int(time.time()),
        "pending": {
            "total": len(pkgs),
            "pacman": pacman_count,
            "aur": aur_count,
            "brew": brew_count,
        },
        "packages": pkgs,
    }
    return output


def main():
    os.makedirs(STATE_DIR, exist_ok=True)
    data = get_updates()

    # Save to updates.json atomically
    temp_fd, temp_path = tempfile.mkstemp(dir=STATE_DIR, prefix="updates_", suffix=".tmp")
    with os.fdopen(temp_fd, "w") as f:
        json.dump(data, f, indent=2)
    os.replace(temp_path, CACHE_FILE)

    # Print to stdout
    print(json.dumps(data))


if __name__ == "__main__":
    main()
