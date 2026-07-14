#!/bin/bash

LAUNCH_CMD="/usr/bin/steam -bigpicture"
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

nombre_dispositivo() {
    local sysfs_path="$1"
    local props
    props=$(udevadm info --query=property -p "$sysfs_path" 2>/dev/null)
    local nombre
    nombre=$(echo "$props" | grep -oP 'ID_MODEL_FROM_DATABASE=\K.*' | head -1 | tr -d '"')
    if [ -z "$nombre" ]; then
        nombre=$(echo "$props" | grep -oP 'NAME=\K.*' | head -1 | tr -d '"')
    fi
    if [ -z "$nombre" ]; then
        nombre=$(echo "$props" | grep -oP 'ID_MODEL=\K.*' | head -1 | tr -d '"')
    fi
    echo "${nombre:-desconocido}"
}

importar_entorno() {
    local env_vars
    env_vars=$(systemctl --user show-environment 2>/dev/null)
    if [ -n "$env_vars" ]; then
        local var
        for var in DISPLAY WAYLAND_DISPLAY XAUTHORITY; do
            local val
            val=$(echo "$env_vars" | grep "^${var}=" | cut -d= -f2-)
            if [ -n "$val" ]; then
                export "$var=$val"
                log INFO "Entorno importado: $var=$val"
            fi
        done
    fi
}

procesar_evento() {
    local sysfs_path

    sysfs_path=$(echo "$1" | grep -oP '(?<= )/devices/\S+')
    [ -z "$sysfs_path" ] && sysfs_path=$(echo "$1" | awk '{print $4}')

    if [ -z "$sysfs_path" ]; then
        log WARN "Path vacío, línea ignorada: $1"
        return
    fi

    # Subimos un nivel para obtener el path del input padre
    local parent_path
    parent_path=$(dirname "$sysfs_path")

    # Si no es /js*, verificamos que sea joystick de verdad
    if [[ ! "$sysfs_path" =~ /js[0-9] ]]; then
        local props
        props=$(udevadm info --query=property -p "$sysfs_path" 2>/dev/null)
        if ! echo "$props" | grep -q 'ID_INPUT_JOYSTICK=1'; then
            log INFO "No es joystick ($sysfs_path) — ignorado"
            return
        fi
    fi

    local nombre
    nombre=$(nombre_dispositivo "$parent_path")
    log INFO "Joystick detectado: $nombre ($sysfs_path)"

    if [ -f "$TOGGLE_FILE" ]; then
        log INFO "Toggle activo — acción ignorada"
        notificar "Ignorado: toggle activo"
        return
    fi

    # Importar entorno gráfico antes de lanzar notificaciones o Steam
    importar_entorno

    if ! pgrep -x steam >/dev/null 2>&1; then
        log INFO "Steam cerrado — lanzando Steam en Big Picture"
        notificar "$nombre — Abriendo Steam"
        $LAUNCH_CMD &
    else
        log INFO "Steam abierto — abriendo Big Picture"
        notificar "$nombre — Abriendo Big Picture"
        /usr/bin/steam steam://open/bigpicture &
    fi
}

escuchar() {
    local last_activation=0

    stdbuf -oL udevadm monitor --subsystem-match=input --udev 2>/dev/null | \
    while read -t 15 -r line; do
        if [[ "$line" =~ (add|bind) ]] && [[ "$line" =~ /input/ ]]; then
            local now
            now=$(date +%s)
            local diff=$((now - last_activation))
            if [ "$diff" -lt 10 ]; then
                log INFO "Evento ignorado — cooldown activo ($diff segundos transcurridos)"
                continue
            fi

            last_activation=$now
            procesar_evento "$line"
        fi
    done
}

escanear_mandos() {
    # Si Steam ya está abierto, no hacemos nada (evita loops)
    pgrep -x steam >/dev/null 2>&1 && return

    for ev in /dev/input/event*; do
        [ -e "$ev" ] || continue
        local props
        props=$(udevadm info --query=property -n "$ev" 2>/dev/null)
        if echo "$props" | grep -q 'ID_INPUT_JOYSTICK=1'; then
            local nombre
            nombre=$(echo "$props" | grep -oP 'ID_MODEL=\K.*' | head -1 | tr -d '"')
            log INFO "Joystick detectado (poll): ${nombre:-desconocido} ($ev)"
            if [ -f "$TOGGLE_FILE" ]; then
                log INFO "Toggle activo — ignorado"
                return
            fi
            importar_entorno
            log INFO "Steam cerrado — lanzando Steam en Big Picture"
            $LAUNCH_CMD &
            return
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
        escanear_mandos
        log INFO "Escuchando eventos udevadm..."
        escuchar
        reintentos=$((reintentos + 1))
        log ERROR "udevadm monitor terminó inesperadamente (intento $reintentos) — reintentando en 5s"
        sleep 5
    done
}

main
