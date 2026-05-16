#!/bin/bash

# 1. Obtener IDs dinámicos buscando por nombre en la sección de Sinks
ID_RYZEN=$(wpctl status | sed -n '/Sinks:/,/Sources:/p' | grep -E "[0-9]+\. .*Ryzen" | grep -oP '\d+' | head -n 1)
ID_STEEL=$(wpctl status | sed -n '/Sinks:/,/Sources:/p' | grep -E "[0-9]+\. .*SteelSeries" | grep -oP '\d+' | head -n 1)

# 2. Detectar si Ryzen es el actual por defecto
IS_RYZEN_ACTIVE=$(wpctl status | sed -n '/Sinks:/,/Sources:/p' | grep -E "\*.*[0-9]+\. .*Ryzen" > /dev/null && echo "yes" || echo "no")

# 3. Lógica de conmutación
if [ "$IS_RYZEN_ACTIVE" == "yes" ]; then
    # --- CAMBIAR A CASCOS ---
    if [ ! -z "$ID_STEEL" ]; then
        wpctl set-default "$ID_STEEL"
        # Notificación con ID único para evitar bloqueos del sistema de notis
        notify-send "Audio" "Cambiado a: CASCOS 🎧" --icon=audio-headphones --urgency=normal --hint=int:transient:1
    else
        notify-send "Audio" "⚠️ Cascos no encontrados" --icon=dialog-warning --urgency=normal
    fi
else
    # --- CAMBIAR A ALTAVOCES ---
    if [ ! -z "$ID_RYZEN" ]; then
        wpctl set-default "$ID_RYZEN"
        # Notificación con ID único para evitar bloqueos
        notify-send "Audio" "Cambiado a: ALTAVOCES 🔊" --icon=audio-speakers --urgency=normal --hint=int:transient:1
    else
        notify-send "Audio" "❌ Error: No se halló la tarjeta Ryzen" --icon=dialog-error --urgency=critical
    fi
fi
