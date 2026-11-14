#!/usr/bin/env bash
# "Now playing · Title — Artist" for the first playing MPRIS player; nothing when idle.
set -eEuo pipefail

command -v playerctl >/dev/null 2>&1 || exit 0
[[ "$(playerctl status 2>/dev/null || true)" == "Playing" ]] || exit 0

title=$(playerctl metadata title 2>/dev/null || true)
artist=$(playerctl metadata artist 2>/dev/null || true)
[[ -n "$title" ]] || exit 0

line="$title${artist:+ — $artist}"
(( ${#line} > 70 )) && line="${line:0:69}…"
# hyprlock labels parse Pango markup: escape it.
line=${line//&/&amp;}; line=${line//</&lt;}; line=${line//>/&gt;}
echo "Now playing · <b>$line</b>"
