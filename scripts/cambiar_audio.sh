#!/bin/bash

# Aislamos el bloque de salidas (Sinks)
SINKS_BLOCK=$(wpctl status | sed -n '/Sinks:/,/Sources:/p')

# Capturamos IDs
# ID Cascos (SteelSeries)
ID_STEEL=$(echo "$SINKS_BLOCK" | grep -i "SteelSeries" | grep -oP '\d+' | head -n 1)
# ID Altavoces (Ryzen HD Audio)
ID_RYZEN=$(echo "$SINKS_BLOCK" | grep -i "Ryzen" | grep -oP '\d+' | head -n 1)

# Si no encontramos SteelSeries en Sinks (a veces desaparece si están apagados), usamos el ID por defecto si existiera
if [ -z "$ID_STEEL" ]; then
    ID_STEEL=$(wpctl status | grep -A 5 "Default Configured Devices" | grep "SteelSeries" | grep -oP '\d+' | head -n 1)
fi

# Detectamos el activo (*)
CURRENT=$(echo "$SINKS_BLOCK" | grep '\*' | grep -oP '\d+' | head -n 1)

if [ "$CURRENT" == "$ID_STEEL" ]; then
    wpctl set-default "$ID_RYZEN"
    notify-send "Audio" "Cambiado a: ALTAVOCES 🔊" --icon=audio-speakers
else
    # Si tenemos el ID de los cascos, cambiamos. Si no, avisamos.
    if [ ! -z "$ID_STEEL" ]; then
        wpctl set-default "$ID_STEEL"
        notify-send "Audio" "Cambiado a: CASCOS 🎧" --icon=audio-headphones
    else
        notify-send "Audio" "⚠️ No se detectaron los Cascos" --icon=dialog-warning
    fi
fi
