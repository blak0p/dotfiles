#!/bin/bash

# Aislamos el bloque de micrófonos para no confundir IDs de salida con entrada
SOURCES_BLOCK=$(wpctl status | sed -n '/Sources:/,/Filters:/p')

# Capturamos IDs
ID_HYPERX=$(echo "$SOURCES_BLOCK" | grep "SoloCast" | grep -oP '\d+' | head -n 1)
ID_STEEL_MIC=$(echo "$SOURCES_BLOCK" | grep "SteelSeries" | grep -oP '\d+' | head -n 1)

# Detectamos el activo (*)
CURRENT=$(echo "$SOURCES_BLOCK" | grep '\*' | grep -oP '\d+' | head -n 1)

if [ "$CURRENT" == "$ID_HYPERX" ]; then
    wpctl set-default "$ID_STEEL_MIC"
    notify-send "Micrófono" "Cambiado a: MICRO CASCOS" --icon=audio-input-microphone
else
    wpctl set-default "$ID_HYPERX"
    notify-send "Micrófono" "Cambiado a: SOLO CAST (Bueno)" --icon=audio-input-microphone
fi
