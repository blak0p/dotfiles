#!/bin/bash

# Aislamos el bloque de salidas (Sinks)
SINKS_BLOCK=$(wpctl status | sed -n '/Sinks:/,/Sources:/p')

# Capturamos IDs
ID_STEEL=$(echo "$SINKS_BLOCK" | grep "SteelSeries" | grep -oP '\d+' | head -n 1)
ID_RYZEN=$(echo "$SINKS_BLOCK" | grep "Ryzen" | grep -oP '\d+' | head -n 1)

# Detectamos el activo (*)
CURRENT=$(echo "$SINKS_BLOCK" | grep '\*' | grep -oP '\d+' | head -n 1)

if [ "$CURRENT" == "$ID_STEEL" ]; then
    wpctl set-default "$ID_RYZEN"
    notify-send "Audio" "Cambiado a: ALTAVOCES" --icon=audio-speakers
else
    wpctl set-default "$ID_STEEL"
    notify-send "Audio" "Cambiado a: CASCOS" --icon=audio-headphones
fi
