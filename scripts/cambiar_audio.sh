#!/bin/bash

# Aislamos el bloque de salidas (Sinks)
SINKS_BLOCK=$(wpctl status | sed -n '/Sinks:/,/Sources:/p')

# 1. Buscamos el ID de los Altavoces (Ryzen / ALC897)
# Intentamos primero por nombre descriptivo
ID_RYZEN=$(echo "$SINKS_BLOCK" | grep -i "Ryzen" | grep -oP '\d+' | head -n 1)

# 2. Buscamos el ID de los Cascos (SteelSeries)
# Los SteelSeries a veces no aparecen en Sinks si están apagados o en standby.
ID_STEEL=$(echo "$SINKS_BLOCK" | grep -i "SteelSeries" | grep -oP '\d+' | head -n 1)

# Si no está en Sinks, lo buscamos en la config por defecto (Settings)
if [ -z "$ID_STEEL" ]; then
    ID_STEEL=$(wpctl status | grep -A 10 "Default Configured Devices" | grep -i "SteelSeries" | grep -oP '\d+' | head -n 1)
fi

# 3. Detectamos cuál tiene la estrella [*] (el activo)
CURRENT_ID=$(echo "$SINKS_BLOCK" | grep '\*' | grep -oP '\d+' | head -n 1)

# --- LÓGICA DE CAMBIO ---

# Si el actual es el de los Cascos (o si no es el de Ryzen), cambiamos a Ryzen (Altavoces)
if [ "$CURRENT_ID" == "$ID_STEEL" ] || [ -z "$ID_STEEL" ]; then
    if [ ! -z "$ID_RYZEN" ]; then
        wpctl set-default "$ID_RYZEN"
        notify-send "Audio" "Cambiado a: ALTAVOCES 🔊" --icon=audio-speakers --urgency=normal
    else
        notify-send "Audio" "⚠️ Error: No encuentro Altavoces" --icon=dialog-error
    fi
else
    # Si el actual es Ryzen (o cualquier otro), cambiamos a Cascos
    if [ ! -z "$ID_STEEL" ]; then
        wpctl set-default "$ID_STEEL"
        notify-send "Audio" "Cambiado a: CASCOS 🎧" --icon=audio-headphones --urgency=normal
    else
        notify-send "Audio" "⚠️ No se detectan los Cascos" --icon=dialog-warning
    fi
fi
