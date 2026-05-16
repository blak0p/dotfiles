#!/bin/bash

IGNORE_FILE="$HOME/scripts/steam-autopicture.ignore"

export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}"

if [ -f "$IGNORE_FILE" ]; then
    rm -f "$IGNORE_FILE"
    notify-send "Steam Autopicture" "✅ Activado" --icon=steam --hint=int:transient:1
else
    mkdir -p "$(dirname "$IGNORE_FILE")"
    touch "$IGNORE_FILE"
    notify-send "Steam Autopicture" "❌ Desactivado" --icon=steam --hint=int:transient:1
fi
