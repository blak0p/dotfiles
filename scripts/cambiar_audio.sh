#!/bin/bash

# 1. Detectar quién es el dispositivo por defecto actualmente
# Usamos el nombre descriptivo porque es más humano
CURRENT_DESC=$(wpctl status | grep -A 15 "Sinks:" | grep '\*' | sed 's/^[│ ]*[* ]*[0-9]*\. //g' | cut -d '[' -f 1 | xargs)

# 2. Buscar IDs dinámicamente
ID_RYZEN=$(wpctl status | sed -n '/Sinks:/,/Sources:/p' | grep -i "Ryzen" | grep -oP '\d+' | head -n 1)
ID_STEEL=$(wpctl status | sed -n '/Sinks:/,/Sources:/p' | grep -i "SteelSeries" | grep -oP '\d+' | head -n 1)

# 3. Lógica de conmutación pura
if [[ "$CURRENT_DESC" == *"Ryzen"* ]]; then
    # Estamos en ALTAVOCES, queremos ir a CASCOS
    if [ ! -z "$ID_STEEL" ]; then
        wpctl set-default "$ID_STEEL"
        notify-send "Audio" "Cambiado a: CASCOS 🎧" --icon=audio-headphones --urgency=critical
    else
        # Si no hay cascos, avisamos pero no cambiamos
        notify-send "Audio" "⚠️ Cascos no detectados" --icon=dialog-warning --urgency=critical
    fi
else
    # Estamos en CASCOS (o cualquier otro), queremos ir a ALTAVOCES
    if [ ! -z "$ID_RYZEN" ]; then
        wpctl set-default "$ID_RYZEN"
        # Forzamos la notificación para que salga sí o sí
        notify-send "Audio" "Cambiado a: ALTAVOCES 🔊" --icon=audio-speakers --urgency=critical
    else
        notify-send "Audio" "❌ No se encontró la tarjeta Ryzen" --icon=dialog-error --urgency=critical
    fi
fi
