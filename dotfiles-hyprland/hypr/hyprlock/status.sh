#!/usr/bin/env bash
# Status chips for the lock card: keyboard layout, network and battery (when present),
# joined by a wide separator. Every probe is optional; a failing one is skipped.
set -eEuo pipefail

chips=()

layout=$(hyprctl devices -j 2>/dev/null | jq -r '[.keyboards[] | select(.main) | .active_keymap][0] // empty' 2>/dev/null || true)
if [[ -n "$layout" ]]; then
    # "English (US, intl., with dead keys)" -> "English (US)"
    chips+=("${layout%%,*}$([[ "$layout" == *,* ]] && echo ')')")
fi

if command -v nmcli >/dev/null 2>&1; then
    net=$(nmcli -t -f TYPE,STATE,CONNECTION device 2>/dev/null \
        | awk -F: '$2=="connected" && ($1=="wifi" || $1=="ethernet") {print $1":"$3; exit}' || true)
    case "$net" in
        wifi:*) chips+=("Wi-Fi ${net#wifi:}") ;;
        ethernet:*) chips+=("Ethernet") ;;
        *) chips+=("Offline") ;;
    esac
fi

for bat in /sys/class/power_supply/BAT*; do
    [[ -r "$bat/capacity" ]] || continue
    chips+=("$(<"$bat/capacity")%")
    break
done

out=""
for chip in "${chips[@]}"; do
    out+="${out:+     ·     }$chip"
done
echo "$out"
