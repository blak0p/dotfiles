#!/usr/bin/env bash
# Prints a warning while Caps Lock is on on the main keyboard; prints nothing otherwise.
set -eEuo pipefail

caps=$(hyprctl devices -j 2>/dev/null | jq -r '[.keyboards[] | select(.main) | .capsLock][0] // false') || caps=false
if [[ "$caps" == "true" ]]; then
    echo "Caps Lock is on"
fi
