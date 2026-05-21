#!/bin/bash

LAUNCH_CMD="steam -bigpicture"
TOGGLE_FILE="$HOME/scripts/steam-autopicture.ignore"
LOG_FILE="$HOME/scripts/steam-autopicture.log"
LOG_MAX_LINES=500
LOG_KEEP_LINES=200

export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}"

notificar() {
    notify-send "Steam Autopicture" "$1" 2>/dev/null || true
}

log() {
    local nivel="$1"
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$nivel] $*" >> "$LOG_FILE"
}

rotar_log() {
    if [ -f "$LOG_FILE" ] && [ "$(wc -l < "$LOG_FILE")" -gt "$LOG_MAX_LINES" ]; then
        tail -n "$LOG_KEEP_LINES" "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
        log INFO "Log rotado"
    fi
}

es_joystick() {
    udevadm info -a -p "$1" 2>/dev/null | grep -q 'ID_INPUT_JOYSTICK="1"'
}

nombre_dispositivo() {
    udevadm info --query=property -p "$1" 2>/dev/null \
        | grep -oP 'ID_MODEL_FROM_DATABASE=\K.*' \
        | head -1 | tr -d '"' \
        || echo "desconocido"
}

procesar_evento() {
    local sysfs_path

    sysfs_path=$(echo "$1" | grep -oP '(?<= )/devices/\S+')
    [ -z "$sysfs_path" ] && sysfs_path=$(echo "$1" | awk '{print $4}')

    if [ -z "$sysfs_path" ]; then
        log WARN "Path vacío, línea ignorada: $1"
        return
    fi

    if ! es_joystick "$sysfs_path"; then
        log INFO "Dispositivo ignorado (no es joystick): $sysfs_path"
        return
    fi

    local nombre
    nombre=$(nombre_dispositivo "$sysfs_path")
    log INFO "Joystick detectado: $nombre"

    if [ -f "$TOGGLE_FILE" ]; then
        log INFO "Toggle activo — acción ignorada"
        notificar "Ignorado: toggle activo"
        return
    fi

    if ! pgrep -x steam >/dev/null 2>&1; then
        log INFO "Steam cerrado — lanzando Steam en Big Picture"
        notificar "$nombre — Abriendo Steam"
        $LAUNCH_CMD &
    else
        log INFO "Steam abierto — abriendo Big Picture"
        notificar "$nombre — Abriendo Big Picture"
        steam steam://open/bigpicture &
    fi
}

escuchar() {
    local lanzamiento_en_curso=0

    stdbuf -oL udevadm monitor --subsystem-match=input --udev 2>/dev/null | \
    while read -r line; do
        if [[ "$line" =~ add ]] && [[ "$line" =~ event ]]; then
            if [ "$lanzamiento_en_curso" -eq 1 ]; then
                log INFO "Evento ignorado — lanzamiento ya en curso"
                continue
            fi

            lanzamiento_en_curso=1
            procesar_evento "$line"
            sleep 15
            lanzamiento_en_curso=0
        fi
    done
}

main() {
    mkdir -p "$(dirname "$LOG_FILE")"
    rotar_log

    echo "" >> "$LOG_FILE"
    echo "======================================" >> "$LOG_FILE"
    log INFO "Daemon iniciado (PID $$)"
    echo "======================================" >> "$LOG_FILE"

    local reintentos=0
    while true; do
        log INFO "Escuchando eventos udevadm..."
        escuchar
        reintentos=$((reintentos + 1))
        log ERROR "udevadm monitor terminó inesperadamente (intento $reintentos) — reintentando en 5s"
        sleep 5
    done
}

main
