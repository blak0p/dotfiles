#!/bin/bash

LAUNCH_CMD="steam -bigpicture"
TOGGLE_FILE="$HOME/scripts/steam-autopicture.ignore"
LOG_FILE="$HOME/scripts/steam-autopicture.log"

export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}"

notificar() {
    local msg="$1"
    notify-send "Steam Autopicture" "$msg" 2>/dev/null || true
}

log() {
    echo "[$(date '+%H:%M:%S')] $*" >> "$LOG_FILE"
}

es_joystick() {
    local sysfs_path="$1"
    udevadm info -a -p "$sysfs_path" 2>/dev/null | grep -q "ID_INPUT_JOYSTICK=\"1\""
}

nombre_dispositivo() {
    local sysfs_path="$1"
    udevadm info --query=property -p "$sysfs_path" 2>/dev/null | grep -oP 'ID_MODEL_FROM_DATABASE=\K.*' | head -1 | tr -d '"' || echo "desconocido"
}

main() {
    log "Iniciado"
    stdbuf -oL udevadm monitor --subsystem-match=input --udev 2>/dev/null | \
    while read -r line; do
        if [[ "$line" =~ add ]] && [[ "$line" =~ event ]]; then
            sysfs_path=$(echo "$line" | awk '{print $4}')
            log "Evento: $sysfs_path"

            if [ -z "$sysfs_path" ] || ! es_joystick "$sysfs_path"; then
                log "No es joystick"
                continue
            fi

            nombre=$(nombre_dispositivo "$sysfs_path")
            log "Joystick detectado: $nombre"

            if [ -f "$TOGGLE_FILE" ]; then
                notificar "Ignorado: toggle activo"
                log "Toggle activo, ignorado"
                continue
            fi

            if ! pgrep -x steam >/dev/null 2>&1; then
                notificar "$nombre — Abriendo Steam"
                log "Abriendo Steam"
                $LAUNCH_CMD &
            else
                notificar "$nombre — Abriendo Big Picture"
                log "Abriendo Big Picture"
                steam steam://open/bigpicture &
            fi

            sleep 15
        fi
    done
}

main