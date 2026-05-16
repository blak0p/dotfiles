#!/bin/bash

# --- CONFIGURACIÓN ---
IGNORE_FILE="$HOME/scripts/steam-autopicture.ignore"
LOG_FILE="$HOME/scripts/steam-autopicture.log"
LOCK_FILE="/tmp/steam_autopicture.lock"

# Evitar múltiples instancias de forma profesional
exec 200>"$LOCK_FILE"
flock -n 200 || exit 0

export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}"

# --- FUNCIONES ---
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

notificar() {
    notify-send "Steam Autopicture" "$1" --icon=steam --hint=int:transient:1 2>/dev/null || true
}

# --- INICIO ---
truncate -s 0 "$LOG_FILE" # Limpiar log al empezar
log "🚀 Servicio de detección de mandos iniciado"

# Escuchamos el kernel por eventos de entrada
stdbuf -oL udevadm monitor --subsystem-match=input --udev | while read -r line; do
    log "DEBUG: Línea recibida: $line"
    # Buscamos eventos de "añadir" dispositivo
    if [[ "$line" == *"add"* ]] && [[ "$line" == *"/devices/"* ]]; then
        # Extraemos la ruta del dispositivo en el sistema
        dev_path=$(echo "$line" | grep -oP '/devices/\S+')
        [ -z "$dev_path" ] && continue

        # Verificamos si es un Joystick real
        if udevadm info -a -p "$dev_path" 2>/dev/null | grep -q 'ID_INPUT_JOYSTICK="1"'; then
            log "🎮 Mando detectado en: $dev_path"

            # ¿Está el modo automático desactivado?
            if [ -f "$IGNORE_FILE" ]; then
                log "🔇 Modo automático desactivado (archivo .ignore presente). Ignorando."
                continue
            fi

            # Pequeña pausa para evitar rebotes de eventos de hardware
            sleep 2

            if ! pgrep -x "steam" >/dev/null; then
                log "🚀 Steam cerrado. Iniciando en modo Big Picture..."
                notificar "Mando conectado: Iniciando Steam..."
                steam -bigpicture &
            else
                log "📺 Steam ya abierto. Cambiando a Big Picture..."
                notificar "Mando conectado: Abriendo Big Picture..."
                steam steam://open/bigpicture &
            fi

            # Pausa de enfriamiento (cooldown) para no procesar el mismo mando varias veces
            sleep 10
        fi
    fi
done
