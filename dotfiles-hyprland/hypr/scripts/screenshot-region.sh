#!/usr/bin/env bash
# Select a region, save it to ~/Imágenes/Screenshots and copy it to the clipboard.
set -euo pipefail
pidof slurp >/dev/null && exit 0
dir="$HOME/Imágenes/Screenshots"
mkdir -p "$dir"
geom=$(slurp) || exit 0
file="$dir/screenshot-$(date +%F_%H.%M.%S).png"
grim -g "$geom" "$file"
wl-copy --type image/png < "$file"
