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
import math
import os
import shutil
import tempfile
import re
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


def _mask(text: str) -> str:
    """Same-length copy of TEXT with Lua `--` comments blanked (strings respected)."""
    out, i, n, in_str = [], 0, len(text), False
    while i < n:
        c = text[i]
        if in_str:
            out.append(c)
            if c == "\\" and i + 1 < n:
                out.append(text[i + 1]); i += 1
            elif c == '"':
                in_str = False
        elif c == '"':
            in_str = True; out.append(c)
        elif text.startswith("--", i):
            j = text.find("\n", i)
            j = n if j < 0 else j
            out.append(" " * (j - i)); i = j; continue
        else:
            out.append(c)
        i += 1
    return "".join(out)


def _fields(block: str) -> dict:
    return {m.group(1): _value(m.group(3)) for m in FIELD.finditer(block[len("hl.monitor({"):-2])}


def parse_monitors(text: str) -> dict:
    """{output: {field: value}} for every hl.monitor block (comments ignored)."""
    out = {}
    for b in BLOCK.finditer(_mask(text)):
        f = _fields(b.group(0))
        if "output" in f:
            out[f["output"]] = f
    return out


def _span(masked: str, output: str):
    for b in BLOCK.finditer(masked):
        if _fields(b.group(0)).get("output") == output:
            return b
    return None


def _set(block: str, masked: str, key: str, value: str) -> str:
    """Replace KEY's value in BLOCK, locating it in the comment-masked copy."""
    body_start = len("hl.monitor({")
    for m in FIELD.finditer(masked, body_start):
        if m.group(1) == key:
            return block[:m.start(3)] + value + block[m.end(3):]
    m = next(m for m in FIELD.finditer(masked, body_start) if m.group(1) == "output")
    return block[:m.end()] + ", %s = %s" % (key, value) + block[m.end():]


def validate(output: str, mode: str, scale, position: str = "0x0") -> float:
    """Reject anything that is not a plain monitor name/mode/position/scale."""
    if not re.fullmatch(r"[\w.-]+", output or ""):
        raise ValueError("invalid output name: %r" % output)
    if not re.fullmatch(r"\d+x\d+@[\d.]+", mode or ""):
        raise ValueError("invalid mode: %r" % mode)
    if not re.fullmatch(r"-?\d+x-?\d+", position or ""):
        raise ValueError("invalid position: %r" % position)
    try:
        sc = float(scale)
    except (TypeError, ValueError):
        raise ValueError("invalid scale: %r" % scale)
    if not math.isfinite(sc) or sc <= 0:
        raise ValueError("invalid scale: %r" % scale)
    return sc


def rewrite(text: str, output: str, mode: str, scale, position: str = "0x0") -> str:
    scale = validate(output, mode, scale, position)
    masked = _mask(text)
    b = _span(masked, output)
    if b is None:
        raise ValueError("output %s not found in the monitors file" % output)
    blk = text[b.start():b.end()]
    blk = _set(blk, _mask(blk), "mode", '"%s"' % mode)
    blk = _set(blk, _mask(blk), "scale", fmt_num(scale))
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


def eval_call(text: str, output: str, mode: str, scale, position=None) -> str:
    """Lua for `hyprctl eval`: the file's block for OUTPUT with mode/scale replaced.
    A caller-supplied (live) position wins over the file's."""
    sc = validate(output, mode, scale, position or "0x0")
    cur = parse_monitors(text).get(output, {"output": output})
    cur = dict(cur, mode=mode, scale=sc, position=position or cur.get("position", "0x0"))
    order = ["output", "mode", "position", "scale"] + [k for k in cur if k not in ("output", "mode", "position", "scale")]
    parts = []
    for k in order:
        if k not in cur:
            continue
        v = cur[k]
        parts.append('%s = %s' % (k, '"%s"' % v if isinstance(v, str) else fmt_num(v)))
    return "hl.monitor({ %s })" % ", ".join(parts)


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
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


def save(path, output: str, mode: str, scale, position: str = "0x0", dry_run: bool = False) -> str:
    real = Path(path).resolve()
    if not real.is_file():
        raise ValueError("monitors file not found: %s" % path)
    old = real.read_text()
    if not parse_monitors(old):
        raise ValueError("no hl.monitor block found in %s" % path)
    new = rewrite(old, output, mode, scale, position)
    if not dry_run:
        _atomic_write(real.with_name(real.name + ".bak"), old)
        _atomic_write(real, new)
    return new


def main(argv) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 2
    cmd, args = argv[1], argv[2:]
    try:
        return _run(cmd, args)
    except (ValueError, OSError) as e:
        print("sky_monitors: %s" % e, file=sys.stderr)
        return 1


def _run(cmd, args) -> int:
    if cmd == "modes":
        print(json.dumps([{"res": r, "rates": rs} for r, rs in group_modes(args)]))
    elif cmd == "eval" and len(args) >= 4:
        f = Path(args[0])
        print(eval_call(f.read_text() if f.exists() else "", args[1], args[2], args[3], args[4] if len(args) > 4 and args[4] else None))
    elif cmd == "save" and len(args) >= 4:
        dry = "--dry-run" in args
        args = [a for a in args if a != "--dry-run"]
        out = save(args[0], args[1], args[2], args[3], args[4] if len(args) > 4 else "0x0", dry)
        if dry:
            print(out, end="")
    else:
        print(__doc__)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
