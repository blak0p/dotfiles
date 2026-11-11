#!/usr/bin/env python3
"""Monitor settings helper for the sky settings Displays page.

Reads and rewrites hypr/monitors.lua (hl.monitor({...}) blocks), keeping every
field and line it does not change, and builds the Lua call used to apply a mode
live through `hyprctl eval`.

  sky_monitors.py modes  <availableModes...>                      -> JSON grouped modes
  sky_monitors.py eval   FILE OUTPUT MODE SCALE [POSITION]        -> Lua to pass to hyprctl eval
  sky_monitors.py save   FILE OUTPUT MODE SCALE [--dry-run]       -> rewrite FILE (keeps FILE.bak)
"""
import json
import re
import shutil
import sys
from pathlib import Path

BLOCK = re.compile(r"hl\.monitor\(\{.*?\}\)", re.S)
FIELD = re.compile(r'(\w+)(\s*=\s*)("[^"]*"|[^\s,}]+)')


def _value(raw: str):
    if raw.startswith('"'):
        return raw[1:-1]
    try:
        f = float(raw)
    except ValueError:
        return raw
    return int(f) if f == int(f) else f


def fmt_num(n) -> str:
    f = float(n)
    return str(int(f)) if f == int(f) else ("%.4f" % f).rstrip("0")


def fmt_rate(rate: float) -> str:
    return fmt_num(round(rate, 2))


def _fields(block: str) -> dict:
    return {m.group(1): _value(m.group(3)) for m in FIELD.finditer(block[len("hl.monitor({"):-2])}


def parse_monitors(text: str) -> dict:
    """{output: {field: value}} for every hl.monitor block (comments ignored)."""
    code = "\n".join(l for l in text.split("\n") if not l.lstrip().startswith("--"))
    out = {}
    for b in BLOCK.finditer(code):
        f = _fields(b.group(0))
        if "output" in f:
            out[f["output"]] = f
    return out


def _span(text: str, output: str):
    for b in BLOCK.finditer(text):
        # skip blocks inside a comment line
        line_start = text.rfind("\n", 0, b.start()) + 1
        if text[line_start:b.start()].lstrip().startswith("--"):
            continue
        if _fields(b.group(0)).get("output") == output:
            return b
    return None


def _set(block: str, key: str, value: str) -> str:
    body_start = len("hl.monitor({")
    for m in FIELD.finditer(block, body_start):
        if m.group(1) == key:
            return block[:m.start(3)] + value + block[m.end(3):]
    # missing: add after the output field
    m = next(m for m in FIELD.finditer(block, body_start) if m.group(1) == "output")
    return block[:m.end()] + ", %s = %s" % (key, value) + block[m.end():]


def rewrite(text: str, output: str, mode: str, scale, position: str = "0x0") -> str:
    b = _span(text, output)
    if b is None:
        block = 'hl.monitor({\n    output = "%s",\n    mode = "%s",\n    position = "%s",\n    scale = %s\n})\n' % (output, mode, position, fmt_num(scale))
        return text + ("" if text.endswith("\n") or not text else "\n") + ("\n" if text else "") + block
    blk = _set(_set(b.group(0), "mode", '"%s"' % mode), "scale", fmt_num(scale))
    return text[:b.start()] + blk + text[b.end():]


def group_modes(modes) -> list:
    """['2560x1440@59.95Hz', ...] -> [('2560x1440', [180.0, 59.95]), ...], biggest first."""
    seen = {}
    for m in modes:
        g = re.fullmatch(r"(\d+)x(\d+)@([\d.]+)Hz", m)
        if not g:
            continue
        res, rate = "%sx%s" % (g.group(1), g.group(2)), round(float(g.group(3)), 2)
        if rate not in seen.setdefault(res, []):
            seen[res].append(rate)
    key = lambda r: tuple(int(x) for x in r.split("x"))
    return [(r, sorted(seen[r], reverse=True)) for r in sorted(seen, key=key, reverse=True)]


def eval_call(text: str, output: str, mode: str, scale, position: str = "0x0") -> str:
    """Lua for `hyprctl eval`: the file's block for OUTPUT with mode/scale replaced."""
    cur = parse_monitors(text).get(output, {"output": output, "position": position})
    cur = dict(cur, mode=mode, scale=scale)
    order = ["output", "mode", "position", "scale"] + [k for k in cur if k not in ("output", "mode", "position", "scale")]
    parts = []
    for k in order:
        if k not in cur:
            continue
        v = cur[k]
        parts.append('%s = %s' % (k, '"%s"' % v if isinstance(v, str) else fmt_num(v)))
    return "hl.monitor({ %s })" % ", ".join(parts)


def save(path, output: str, mode: str, scale, position: str = "0x0", dry_run: bool = False) -> str:
    path = Path(path)
    old = path.read_text() if path.exists() else ""
    new = rewrite(old, output, mode, scale, position)
    if not dry_run:
        if path.exists():
            shutil.copy2(path, str(path) + ".bak")
        path.write_text(new)
    return new


def main(argv) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 2
    cmd, args = argv[1], argv[2:]
    if cmd == "modes":
        print(json.dumps([{"res": r, "rates": rs} for r, rs in group_modes(args)]))
    elif cmd == "eval" and len(args) >= 4:
        f = Path(args[0])
        print(eval_call(f.read_text() if f.exists() else "", args[1], args[2], float(args[3]), args[4] if len(args) > 4 else "0x0"))
    elif cmd == "save" and len(args) >= 4:
        dry = "--dry-run" in args
        args = [a for a in args if a != "--dry-run"]
        out = save(args[0], args[1], args[2], float(args[3]), args[4] if len(args) > 4 else "0x0", dry)
        if dry:
            print(out, end="")
    else:
        print(__doc__)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
