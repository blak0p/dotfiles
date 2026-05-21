#!/bin/bash

TOGGLE_FILE="$HOME/scripts/steam-autopicture.ignore"
LOCK_FILE="/tmp/steam-autopicture-toggle.lock"
LOG_FILE="$HOME/scripts/steam-autopicture.log"

export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}"

log() {
    local nivel="$1"
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$nivel] $*" >> "$LOG_FILE"
}

notificar() {
    notify-send "Steam Autopicture" "$1" 2>/dev/null || true
}

if [ -e "$LOCK_FILE" ]; then
    log WARN "Toggle ya en ejecución, saliendo"
    notificar "⚠️ Toggle ya en ejecución"
    exit 1
fi
touch "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

mkdir -p "$(dirname "$TOGGLE_FILE")"

if [ -f "$TOGGLE_FILE" ]; then
    rm -f "$TOGGLE_FILE"
    log INFO "Toggle desactivado → daemon activado"
    notificar "✅ Activado"
else
    touch "$TOGGLE_FILE"
    log INFO "Toggle activado → daemon desactivado"
    notificar "❌ Desactivado"
fi
