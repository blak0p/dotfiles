#!/usr/bin/env python3
"""AI plan usage for the island, via the CodexBar CLI (`codexbar`).

Usage: fetch_usage.py PROVIDER [PROVIDER ...]
Queries every provider in parallel and prints one JSON object:
  {"available": bool, "providers": [normalized provider, ...]}
A provider that fails is still listed, with ok=false and a short error,
so the UI can say why instead of silently dropping it.
"""
import json
import os
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

NAMES = {"claude": "Claude", "codex": "Codex", "antigravity": "Antigravity", "openai": "OpenAI",
         "copilot": "Copilot", "gemini": "Gemini"}
WINDOW_KEYS = ("primary", "secondary", "tertiary")
TIMEOUT_S = 25


def find_codexbar():
    path = shutil.which("codexbar")
    if path:
        return path
    for candidate in ("/home/linuxbrew/.linuxbrew/bin/codexbar", os.path.expanduser("~/.local/bin/codexbar")):
        if os.access(candidate, os.X_OK):
            return candidate
    return None


def display_name(provider):
    return NAMES.get(provider, provider.capitalize())


def window_title(key, window, labels):
    if labels.get(key):
        return labels[key]
    minutes = window.get("windowMinutes") or 0
    if minutes == 300:
        return "5-hour"
    if minutes == 10080:
        return "Weekly"
    if minutes == 1440:
        return "Daily"
    return {"primary": "Session", "secondary": "Weekly", "tertiary": "Other"}[key]


def short_error(message):
    text = (message or "").strip()
    lowered = text.lower()
    if "401" in text or "token_expired" in lowered or "expired" in lowered:
        return "Session expired, sign in again"
    first = text.splitlines()[0] if text else "Unknown error"
    return first.split(": ")[0][:80]


def failed(provider, error):
    return {"provider": provider, "name": display_name(provider), "ok": False, "error": error,
            "plan": "", "status": None, "windows": []}


def normalize(entry):
    provider = entry.get("provider") or ""
    status = entry.get("status") or None
    if status:
        status = {"indicator": status.get("indicator", ""), "description": status.get("description", "")}

    if entry.get("error"):
        result = failed(provider, short_error(entry["error"].get("message")))
        result["status"] = status
        return result

    usage = entry.get("usage") or {}
    labels = entry.get("rateWindowLabels") or {}
    pace = entry.get("pace") or {}
    windows = []
    for key in WINDOW_KEYS:
        w = usage.get(key)
        if not w:
            continue
        windows.append({"title": window_title(key, w, labels), "usedPercent": w.get("usedPercent", 0),
                        "resetsAt": w.get("resetsAt", ""), "pace": (pace.get(key) or {}).get("summary", "")})

    # Named extra windows: rename a generic window that shares the reset time,
    # otherwise add them as their own row.
    for extra in usage.get("extraRateWindows") or []:
        w = (extra or {}).get("window") or {}
        title = extra.get("title") or ""
        if not w or not title:
            continue
        twin = next((x for x in windows if x["resetsAt"] and x["resetsAt"] == w.get("resetsAt")), None)
        if twin:
            twin["title"] = title
        else:
            windows.append({"title": title, "usedPercent": w.get("usedPercent", 0),
                            "resetsAt": w.get("resetsAt", ""), "pace": ""})

    identity = usage.get("identity") or {}
    plan = identity.get("plan") or usage.get("loginMethod") or identity.get("loginMethod") or ""
    return {"provider": provider, "name": display_name(provider), "ok": True, "error": "",
            "plan": plan, "status": status, "windows": windows}


def parse_output(provider, text):
    try:
        data = json.loads(text)
    except (ValueError, TypeError):
        return failed(provider, "Unreadable codexbar output")
    if isinstance(data, list):
        data = data[0] if data else None
    if not isinstance(data, dict):
        return failed(provider, "No data")
    return normalize(data)


def query(codexbar, provider):
    cmd = [codexbar, "usage", "--provider", provider, "--format", "json", "--status", "--no-color"]
    try:
        run = subprocess.run(cmd, capture_output=True, text=True, timeout=TIMEOUT_S)
    except subprocess.TimeoutExpired:
        return failed(provider, "Timed out")
    except OSError as exc:
        return failed(provider, str(exc)[:80])
    # codexbar exits non-zero on provider errors but still prints the JSON payload.
    if run.stdout.strip():
        return parse_output(provider, run.stdout)
    return failed(provider, short_error(run.stderr) if run.stderr.strip() else f"codexbar exited {run.returncode}")


def main(argv):
    providers = argv[1:]
    codexbar = find_codexbar()
    if not codexbar:
        print(json.dumps({"available": False, "providers": []}))
        return 0
    with ThreadPoolExecutor(max_workers=max(1, len(providers))) as pool:
        results = list(pool.map(lambda p: query(codexbar, p), providers))
    print(json.dumps({"available": True, "providers": results}))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
