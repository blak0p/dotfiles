#!/usr/bin/env python3
"""Shortcut helper for the sky settings Shortcuts page.

Lists the live Hyprland binds grouped by their description prefix, detects
collisions, and writes overrides ONLY to the user layer
($XDG_CONFIG_HOME/sky/hypr/keybinds.lua) as managed blocks:

    -- sky:shortcut <ORIGINAL COMBO> begin to=<NEW COMBO>
    hl.unbind("<original>") ... hl.bind("<new>", <same dispatcher>, <same options>)
    -- sky:shortcut <ORIGINAL COMBO> end

`hyprctl binds -j` cannot say what a bind does (the dispatcher is an opaque Lua
function), so the Lua expression is recovered from the repo's keybind files by
matching the combo. Binds built by loops/functions are shown read-only.

  sky_keybinds.py list
  sky_keybinds.py check COMBO [--current COMBO]
  sky_keybinds.py set   ID COMBO
  sky_keybinds.py reset ID
Options: --hypr-dir DIR (default ~/.config/hypr)  --user-dir DIR  --binds-file FILE (JSON, instead of hyprctl)
"""
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

MODS = [("SUPER", 64), ("CTRL", 4), ("ALT", 8), ("SHIFT", 1)]
MASK_BITS = {n: b for n, b in MODS}
ALIASES = {"WIN": "SUPER", "MOD4": "SUPER", "CONTROL": "CTRL", "MOD1": "ALT"}
ALL_MASK = 64 | 4 | 8 | 1
KEY_RE = re.compile(r"^([A-Za-z0-9_]{1,32}|(code|mouse):[0-9]{1,4})$")
SOURCES = ("hyprland/keybinds.lua", "custom/keybinds.lua", "custom/keybinds-extra.lua")
BEGIN = re.compile(r"^-- sky:shortcut (\S+) begin to=(\S+)[^\n]*$", re.M)


# ---------- combos ----------
def _key_name(key: str) -> str:
    return key.upper() if len(key) == 1 else key


def combo_from_bind(mask: int, key: str) -> str:
    return "+".join([n for n, b in MODS if mask & b] + [_key_name(key)])


def parse_combo(text: str, loose: bool = False):
    """Strict parse -> (modmask, key). Raises ValueError for anything unknown."""
    parts = [p.strip() for p in str(text).split("+")]
    if not parts or any(p == "" for p in parts):
        raise ValueError("Invalid shortcut")
    key = parts[-1]
    mask = 0
    for p in parts[:-1]:
        name = p.upper()
        name = ALIASES.get(name, name)
        if name not in MASK_BITS:
            raise ValueError("Invalid modifier")
        mask |= MASK_BITS[name]
    if key.upper() in MASK_BITS or key.upper() in ALIASES or not KEY_RE.match(key):
        raise ValueError("Invalid key")
    if mask == 0 and not loose and not re.match(r"^(XF86\w+|F[0-9]{1,2}|Print)$", key):
        raise ValueError("Add at least one modifier")
    return mask, _key_name(key)


def lua_combo(canonical: str) -> str:
    return " + ".join(canonical.split("+"))


def _norm(mask: int, key: str):
    return (mask & ALL_MASK, key.lower())


def _keys(mask: int, key: str):
    return [n for n, b in MODS if mask & b] + [_key_name(key)]


# ---------- Lua source scanning ----------
def _scan(text: str, i: int, stop):
    """Walk text from i, string/comment aware, tracking depth; stop(i, depth, ch) -> True ends. Returns index."""
    depth = 0
    n = len(text)
    while i < n:
        c = text[i]
        if c in "\"'":
            q = c
            i += 1
            while i < n and text[i] != q:
                i += 2 if text[i] == "\\" else 1
        elif text.startswith("--", i):
            while i < n and text[i] != "\n":
                i += 1
            continue
        else:
            if stop(i, depth, c):
                return i
            if c in "([{":
                depth += 1
            elif c in ")]}":
                depth -= 1
        i += 1
    return n


def _strip_strings(s: str) -> str:
    return re.sub(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'', '""', s)


def _safe_expr(expr: str, known: dict) -> bool:
    if "function" in expr:
        return False
    body = _strip_strings(expr)
    for m in re.finditer(r"(?<![\w.:])([A-Za-z_]\w*)\b(?!\s*=[^=])", body):
        name = m.group(1)
        if name in ("hl", "HOME", "true", "false", "nil") or name in known:
            continue
        return False
    return True


def parse_source(text: str):
    """-> (locals {name: rhs}, statements [{combo:(mask,key), expr, opts, uses}])"""
    locs = {}
    for m in re.finditer(r"^local (\w+) =\s*", text, re.M):
        begin = m.end()
        while begin < len(text) and text[begin] in " \t\n":
            begin += 1
        end = _scan(text, begin, lambda i, d, c: c == "\n" and d == 0)
        locs[m.group(1)] = text[begin:end].strip()
    stmts = []
    for m in re.finditer(r"^hl\.bind\(", text, re.M):
        start = m.end()
        args, last = [], start

        def stop(i, d, c):
            nonlocal last
            if d == 0 and c == ",":
                args.append(text[last:i])
                last = i + 1
            return d == 0 and c == ")"
        end = _scan(text, start, stop)
        args.append(text[last:end])
        if len(args) < 2:
            continue
        lit = re.fullmatch(r'\s*"([^"]*)"\s*', args[0])
        if not lit:
            continue
        try:
            parts = [p.strip() for p in lit.group(1).split("+")]
            mask = 0
            for p in parts[:-1]:
                name = ALIASES.get(p.upper(), p.upper())
                mask |= MASK_BITS[name]
            combo = _norm(mask, parts[-1])
        except KeyError:
            continue
        stmts.append({"combo": combo, "expr": args[1].strip(),
                      "opts": args[2].strip() if len(args) > 2 else ""})
    return locs, stmts


def load_globals(hypr_dir: Path):
    """Names the variables files define as globals (browser, fileManager...): usable from the user layer."""
    names = set()
    for rel in ("hyprland/variables.lua", "custom/variables.lua"):
        f = Path(hypr_dir) / rel
        if f.is_file():
            names |= set(re.findall(r"^(\w+)\s*=[^=]", f.read_text(), re.M))
    return names


def load_sources(hypr_dir: Path):
    out = []
    glob = load_globals(hypr_dir)
    for rel in SOURCES:
        f = Path(hypr_dir) / rel
        if f.is_file():
            locs, stmts = parse_source(f.read_text())
            known = dict(locs, **{g: "" for g in glob if g not in locs})
            for s in stmts:
                s["locals"] = locs
                s["safe"] = _safe_expr(s["expr"], known) and s["expr"].startswith("hl.dsp.") and \
                    all(_safe_expr(locs[k], known) for k in _used(s["expr"], locs))
            out += stmts
    return out


def _used(expr: str, locs: dict, seen=None):
    seen = seen if seen is not None else []
    for m in re.finditer(r"(?<![\w.:])([A-Za-z_]\w*)\b", _strip_strings(expr)):
        n = m.group(1)
        if n in locs and n not in seen:
            seen.append(n)
            _used(locs[n], locs, seen)
    return seen


# ---------- user layer blocks ----------
def read_overrides(user_dir: Path):
    """-> {id: new canonical combo}"""
    f = Path(user_dir) / "keybinds.lua"
    if not f.is_file():
        return {}
    return {m.group(1): m.group(2) for m in BEGIN.finditer(f.read_text())}


def _block_re(cid: str):
    return re.compile(r"^-- sky:shortcut %s begin .*?^-- sky:shortcut %s end[ \t]*\n?" % (re.escape(cid), re.escape(cid)),
                      re.M | re.S)


def _write_atomic(path: Path, text: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        (path.parent / (path.name + ".bak")).write_text(path.read_text())
    fd, tmp = tempfile.mkstemp(dir=str(path.parent), prefix=".keybinds.", suffix=".tmp")
    with os.fdopen(fd, "w") as fh:
        fh.write(text)
    os.replace(tmp, path)


# ---------- listing ----------
def _title(desc: str, stmt) -> str:
    if desc:
        return desc.split(":", 1)[1].strip() if ":" in desc else desc
    if stmt:
        t = re.sub(r"\s+", " ", stmt["expr"].replace("hl.dsp.", "", 1))
        return t if len(t) <= 60 else t[:57] + "…"
    return ""


def _fix(binds):
    """Keycode binds report key "" and a keycode: name them code:N."""
    return [dict(b, key=b["key"] or "code:%s" % b.get("keycode", 0)) for b in binds]


def list_binds(binds, hypr_dir, user_dir):
    binds = _fix(binds)
    sources = load_sources(hypr_dir)
    overrides = read_overrides(user_dir)
    by_new = {}
    for cid, new in overrides.items():
        try:
            by_new[_norm(*parse_combo(new, True))] = cid
        except ValueError:
            pass
    seen = {}
    hidden = 0
    for b in binds:
        if b.get("submap"):
            hidden += 1
            continue
        k = _norm(b["modmask"], b["key"])
        cur = seen.setdefault(k, {"mask": b["modmask"] & ALL_MASK, "key": b["key"], "desc": ""})
        cur["desc"] = cur["desc"] or b.get("description", "")
    groups = {}
    for k, v in seen.items():
        cid = by_new.get(k) or combo_from_bind(v["mask"], v["key"])
        omask, okey = parse_combo(cid, True)
        stmts = [s for s in sources if s["combo"] == _norm(omask, okey)]
        title = _title(v["desc"], stmts[0] if stmts else None)
        if not title:
            hidden += 1
            continue
        editable = bool(stmts) and all(s["safe"] for s in stmts)
        note = ""
        if not stmts:
            note = "Created by a loop or a script in your Hyprland config; edit the Lua file to change it"
        elif not editable:
            note = "Runs custom Lua code; edit the Lua file to change it"
        name = v["desc"].split(":", 1)[0].strip() if ":" in v["desc"] else "Other"
        groups.setdefault(name, []).append({
            "id": cid, "title": title, "group": name, "keys": _keys(v["mask"], v["key"]),
            "combo": combo_from_bind(v["mask"], v["key"]), "editable": editable, "note": note,
            "custom": k in by_new, "original": _keys(omask, okey) if k in by_new else []})
    ordered = sorted(groups, key=lambda g: (g == "Other", g.lower()))
    return {"groups": [{"name": g, "rows": sorted(groups[g], key=lambda r: r["title"].lower())} for g in ordered],
            "hidden": hidden}


def find_collision(binds, combo, ignore=None):
    binds = _fix(binds)
    k = _norm(*parse_combo(combo))
    own = _norm(*parse_combo(ignore, True)) if ignore else None
    if own == k:
        return None
    for b in binds:
        if b.get("submap") or _norm(b["modmask"], b["key"]) != k:
            continue
        desc = b.get("description", "")
        title = desc.split(":", 1)[1].strip() if ":" in desc else desc
        return {"title": title or "Unnamed shortcut", "combo": combo_from_bind(b["modmask"], b["key"]),
                "keys": _keys(b["modmask"], b["key"])}
    return None


# ---------- write ----------
def set_override(cid, combo, binds, hypr_dir, user_dir):
    omask, okey = parse_combo(cid, True)
    nmask, nkey = parse_combo(combo)
    new = combo_from_bind(nmask, nkey)
    original = combo_from_bind(omask, okey)
    if new.lower() == original.lower():
        return reset_override(original, user_dir)
    stmts = [s for s in load_sources(hypr_dir) if s["combo"] == _norm(omask, okey)]
    if not stmts or not all(s["safe"] for s in stmts):
        raise ValueError("This shortcut cannot be changed from here")
    lines = ["-- sky:shortcut %s begin to=%s (managed by Settings > Shortcuts)" % (original, new),
             'hl.unbind("%s")' % lua_combo(original), 'hl.unbind("%s")' % lua_combo(new), "do"]
    names = []
    for s in stmts:
        for n in _used(s["expr"], s["locals"]):
            if n not in names:
                names.append(n)
    for n in reversed(names):
        lines.append("    local %s = %s" % (n, stmts[0]["locals"][n]))
    for s in stmts:
        opts = ", " + s["opts"] if s["opts"] else ""
        lines.append('    hl.bind("%s", %s%s)' % (lua_combo(new), s["expr"], opts))
    lines += ["end", "-- sky:shortcut %s end" % original]
    block = "\n".join(lines) + "\n"
    f = Path(user_dir) / "keybinds.lua"
    text = f.read_text() if f.is_file() else ""
    text = _block_re(original).sub("", text)
    if text and not text.endswith("\n"):
        text += "\n"
    _write_atomic(f, text + block)
    return {"id": original, "to": new}


def reset_override(cid, user_dir):
    omask, okey = parse_combo(cid, True)
    original = combo_from_bind(omask, okey)
    f = Path(user_dir) / "keybinds.lua"
    if f.is_file():
        text = f.read_text()
        out = _block_re(original).sub("", text)
        if out != text:
            _write_atomic(f, out)
    return {"id": original, "to": None}


# ---------- CLI ----------
def live_binds(binds_file=None):
    if binds_file:
        return json.loads(Path(binds_file).read_text())
    return json.loads(subprocess.run(["hyprctl", "binds", "-j"], capture_output=True, text=True, check=True).stdout)


def main(argv):
    opts = {"--hypr-dir": os.path.expanduser("~/.config/hypr"),
            "--user-dir": (os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")) + "/sky/hypr",
            "--binds-file": None, "--current": None}
    rest = []
    it = iter(argv)
    for a in it:
        if a in opts:
            opts[a] = next(it, None)
        else:
            rest.append(a)
    if not rest:
        print(__doc__)
        return 2
    cmd, args = rest[0], rest[1:]
    hypr, user = Path(opts["--hypr-dir"]), Path(opts["--user-dir"])
    try:
        if cmd == "list":
            out = list_binds(live_binds(opts["--binds-file"]), hypr, user)
        elif cmd == "check" and args:
            parse_combo(args[0])
            out = {"valid": True, "collision": find_collision(live_binds(opts["--binds-file"]), args[0], opts["--current"])}
        elif cmd == "set" and len(args) == 2:
            out = set_override(args[0], args[1], None, hypr, user)
        elif cmd == "reset" and len(args) == 1:
            out = reset_override(args[0], user)
        else:
            print(__doc__)
            return 2
    except ValueError as e:
        print(json.dumps({"error": str(e)}))
        return 1
    print(json.dumps(out))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
