#!/bin/bash

# ==========================================
# CONFIGURACIÓN (Dispositivos y Nombres)
# ==========================================
# Nombres parciales para buscar en PipeWire
NAME_PRIMARY="SteelSeries" # Tus cascos
NAME_SECONDARY="Ryzen"     # Tus altavoces (o lo que no sea cascos)

# Iconos y Etiquetas
LABEL_PRIMARY="CASCOS 🎧"
LABEL_SECONDARY="ALTAVOCES 🔊"
ICON_PRIMARY="audio-headphones"
ICON_SECONDARY="audio-speakers"
# ==========================================

# 1. Obtener IDs dinámicos
ID_PRIMARY=$(wpctl status | sed -n '/Sinks:/,/Sources:/p' | grep -E "[0-9]+\. .*$NAME_PRIMARY" | grep -oP '\d+' | head -n 1)
ID_SECONDARY=$(wpctl status | sed -n '/Sinks:/,/Sources:/p' | grep -E "[0-9]+\. .*$NAME_SECONDARY" | grep -oP '\d+' | head -n 1)

# 2. Detectar cuál está activo (con el asterisco *)
IS_SECONDARY_ACTIVE=$(wpctl status | sed -n '/Sinks:/,/Sources:/p' | grep -E "\*.*[0-9]+\. .*$NAME_SECONDARY" > /dev/null && echo "yes" || echo "no")

# 3. Lógica de cambio
if [ "$IS_SECONDARY_ACTIVE" == "yes" ]; then
    if [ ! -z "$ID_PRIMARY" ]; then
        wpctl set-default "$ID_PRIMARY"
        notify-send "Audio" "Cambiado a: $LABEL_PRIMARY" --icon=$ICON_PRIMARY --hint=int:transient:1
    else
        notify-send "Audio" "⚠️ $NAME_PRIMARY no detectado" --icon=dialog-warning
    fi
else
    if [ ! -z "$ID_SECONDARY" ]; then
        wpctl set-default "$ID_SECONDARY"
        notify-send "Audio" "Cambiado a: $LABEL_SECONDARY" --icon=$ICON_SECONDARY --hint=int:transient:1
    else
        notify-send "Audio" "❌ No se halló $NAME_SECONDARY" --icon=dialog-error --urgency=critical
    fi
fi
