#!/bin/bash

# --- CONFIGURACIÓN ---
IGNORE_FILE="$HOME/scripts/steam-autopicture.ignore"
LOG_FILE="$HOME/scripts/steam-autopicture.log"
LOCK_FILE="/tmp/steam_autopicture.lock"

# Evitar múltiples instancias
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

activar_modo_juego() {
    log "🎮 Mando real detectado. Activando Modo Performance e iniciando Steam Big Picture..."
    notificar "Mando conectado: Modo Performance Activado"
    
    # Intentamos activar el perfil de rendimiento
    sudo tuned-adm profile throughput-performance-bazzite 2>/dev/null || log "⚠️ No se pudo cambiar el perfil de tuned"

    if ! pgrep -x "steam" >/dev/null; then
        log "🚀 Steam cerrado. Iniciando..."
        steam -bigpicture &
    else
        log "📺 Steam ya abierto. Cambiando a Big Picture..."
        steam steam://open/bigpicture &
    fi
}

# --- INICIO ---
truncate -s 0 "$LOG_FILE"
log "🚀 Servicio de detección de mandos iniciado (v2.1)"

# 1. Chequeo inicial: si ya hay un mando conectado al arrancar
# Buscamos 'ID_INPUT_JOYSTICK=1' (sin comillas, que es como sale en udevadm info)
for js in /dev/input/js*; do
    [ -e "$js" ] || continue
    if udevadm info -n "$js" | grep -q 'ID_INPUT_JOYSTICK=1' && ! udevadm info -n "$js" | grep -qi 'ASRock'; then
        log "✅ Mando ya conectado al inicio: $js"
        activar_modo_juego
        # No salimos con break aquí por si hay más de uno, pero con uno basta para lanzar Steam
        break
    fi
done

# 2. Monitoreo de eventos para nuevas conexiones
LAST_ACTIVATION=0
COOLDOWN_SEC=10

stdbuf -oL udevadm monitor --udev | while read -r line; do
    if [[ "$line" == *"add"* || "$line" == *"bind"* ]]; then
        # Pequeña espera para que udev termine de procesar el dispositivo
        sleep 1
        
        for js in /dev/input/js*; do
            [ -e "$js" ] || continue
            if udevadm info -n "$js" | grep -q 'ID_INPUT_JOYSTICK=1' && ! udevadm info -n "$js" | grep -qi 'ASRock'; then
                if [ -f "$IGNORE_FILE" ]; then
                    log "🔇 Modo automático desactivado. Ignorando."
                    continue
                fi

                CURRENT_TIME=$(date +%s)
                if (( CURRENT_TIME - LAST_ACTIVATION > COOLDOWN_SEC )); then
                    activar_modo_juego
                    LAST_ACTIVATION=$CURRENT_TIME
                else
                    log "⏳ Ignorando evento múltiple (cooldown activo)"
                fi
                break
            fi
        done
    fi
done
