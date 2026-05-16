#!/bin/bash

TOGGLE_FILE="$HOME/scripts/steam-autopicture.ignore"

export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}"

if [ -f "$TOGGLE_FILE" ]; then
    rm -f "$TOGGLE_FILE"
    notify-send "Steam Autopicture" "✅ Activado" 2>/dev/null || true
else
    mkdir -p "$(dirname "$TOGGLE_FILE")"
    touch "$TOGGLE_FILE"
    notify-send "Steam Autopicture" "❌ Desactivado" 2>/dev/null || true
fi