#!/bin/bash

LAUNCH_CMD="/usr/bin/bazzite-steam -bigpicture"
TOGGLE_FILE="$HOME/scripts/steam-autopicture.ignore"
LOG_FILE="$HOME/scripts/steam-autopicture.log"
LOG_MAX_LINES=500
LOG_KEEP_LINES=200

DECKY_BIN="$HOME/homebrew/services/PluginLoader"
DECKY_PID_FILE="/tmp/decky-loader.pid"

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

decky_start() {
    if [ -f "$DECKY_PID_FILE" ] && kill -0 "$(cat "$DECKY_PID_FILE")" 2>/dev/null; then
        log INFO "Decky Loader ya en ejecución"
        return
    fi
    log INFO "Arrancando Decky Loader"
    "$DECKY_BIN" &
    echo $! > "$DECKY_PID_FILE"
    sleep 1
    if kill -0 "$(cat "$DECKY_PID_FILE")" 2>/dev/null; then
        log INFO "Decky Loader arrancado (PID $(cat "$DECKY_PID_FILE"))"
    else
        log WARN "Decky Loader no pudo arrancar"
        rm -f "$DECKY_PID_FILE"
    fi
}

decky_stop() {
    [ ! -f "$DECKY_PID_FILE" ] && return
    local pid
    pid=$(cat "$DECKY_PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
        log INFO "Parando Decky Loader (PID $pid)"
        kill "$pid" 2>/dev/null
        sleep 2
        kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null
    fi
    rm -f "$DECKY_PID_FILE"
}

importar_entorno() {
    local env_vars
    env_vars=$(systemctl --user show-environment 2>/dev/null)
    if [ -n "$env_vars" ]; then
        local var
        for var in DISPLAY WAYLAND_DISPLAY XAUTHORITY XDG_SESSION_TYPE; do
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

    local parent_path
    parent_path=$(dirname "$sysfs_path")

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

    importar_entorno

    if ! pgrep -x steam >/dev/null 2>&1; then
        log INFO "Steam cerrado — lanzando Steam en Big Picture"
        notificar "🎮 $nombre detectado — Abriendo Steam"
        decky_start
        $LAUNCH_CMD &
        (sleep 15; while pgrep -x steam >/dev/null 2>&1; do sleep 15; done; decky_stop) &
    else
        log INFO "Steam abierto — abriendo Big Picture"
        notificar "🎮 $nombre detectado — Cambiando a Big Picture"
        decky_start
        /usr/bin/bazzite-steam steam://open/bigpicture &
    fi
}

escuchar() {
    local last_activation=0

    stdbuf -oL udevadm monitor --subsystem-match=input --udev 2>/dev/null | \
    while read -r line; do
        if [[ "$line" =~ (add|bind) ]] && [[ "$line" =~ /input/ ]]; then
            local sysfs_path=$(echo "$line" | grep -oP '(?<= )/devices/\S+')
            [ -z "$sysfs_path" ] && sysfs_path=$(echo "$line" | awk '{print $4}')

            if [[ ! "$sysfs_path" =~ /js[0-9] ]]; then
                sleep 0.3
                if ! udevadm info --query=property -p "$sysfs_path" 2>/dev/null | grep -q 'ID_INPUT_JOYSTICK=1'; then
                    continue
                fi
            fi

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
    for ev in /dev/input/js* /dev/input/event*; do
        [ -e "$ev" ] || continue
        local props
        props=$(udevadm info --query=property -n "$ev" 2>/dev/null)

        local is_joystick=0
        if [[ "$ev" =~ /dev/input/js[0-9]+ ]]; then
            is_joystick=1
        elif echo "$props" | grep -q 'ID_INPUT_JOYSTICK=1'; then
            is_joystick=1
        fi

        if [ "$is_joystick" -eq 1 ]; then
            local nombre
            nombre=$(echo "$props" | grep -oP 'ID_MODEL=\K.*' | head -1 | tr -d '"')
            [ -z "$nombre" ] && nombre="Mando"

            log INFO "Joystick detectado (poll): $nombre ($ev)"
            if [ -f "$TOGGLE_FILE" ]; then
                log INFO "Toggle activo — ignorado"
                return
            fi

            importar_entorno
            if ! pgrep -x steam >/dev/null 2>&1; then
                log INFO "Steam cerrado — lanzando Steam en Big Picture"
                notificar "🎮 $nombre detectado — Abriendo Steam"
                decky_start
                $LAUNCH_CMD &
                (sleep 15; while pgrep -x steam >/dev/null 2>&1; do sleep 15; done; decky_stop) &
            else
                log INFO "Steam abierto — abriendo Big Picture"
                notificar "🎮 $nombre detectado — Cambiando a Big Picture"
                decky_start
                /usr/bin/bazzite-steam steam://open/bigpicture &
            fi
            return
        fi
    done
}

esperar_entorno_grafico() {
    log INFO "Esperando a que el entorno gráfico esté listo..."
    local max_intentos=30
    local intento=0
    while [ $intento -lt $max_intentos ]; do
        local env_vars
        env_vars=$(systemctl --user show-environment 2>/dev/null)
        if echo "$env_vars" | grep -qE "^(DISPLAY|WAYLAND_DISPLAY)="; then
            log INFO "Entorno gráfico detectado."
            return 0
        fi
        intento=$((intento + 1))
        sleep 1
    done
    log WARN "No se detectó entorno gráfico después de $max_intentos segundos. Continuando de todos modos."
    return 1
}

main() {
    mkdir -p "$(dirname "$LOG_FILE")"
    rotar_log

    echo "" >> "$LOG_FILE"
    echo "======================================" >> "$LOG_FILE"
    log INFO "Daemon iniciado (PID $$)"
    echo "======================================" >> "$LOG_FILE"

    esperar_entorno_grafico

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
