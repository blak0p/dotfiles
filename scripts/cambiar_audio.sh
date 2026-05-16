#!/bin/bash

# 1. Definimos los nombres internos de WirePlumber (son estables)
SINK_RYZEN="alsa_output.pci-0000_0f_00.6.analog-stereo"
SINK_STEEL="alsa_output.usb-SteelSeries_SteelSeries_Arctis_Nova_5-00.iec958-stereo"

# 2. Obtenemos los IDs actuales para estos nombres
ID_RYZEN=$(wpctl status | grep "$SINK_RYZEN" -B 1 | grep -oP '\d+' | head -n 1)
# Los cascos a veces aparecen con el nombre largo en la lista de Sinks
ID_STEEL=$(wpctl status | grep -i "SteelSeries" | grep -oP '^\s*[│ ]\s*(\*?\s*)(\d+)\.' | grep -oP '\d+' | head -n 1)

# 3. Detectamos quién es el default actual (ID)
CURRENT_ID=$(wpctl status | grep -A 15 "Sinks:" | grep '\*' | grep -oP '\d+' | head -n 1)

# 4. Lógica de cambio
if [ "$CURRENT_ID" == "$ID_STEEL" ] || [ -z "$ID_STEEL" ]; then
    # Si estamos en cascos o no los encontramos, pasamos a Altavoces
    if [ ! -z "$ID_RYZEN" ]; then
        wpctl set-default "$ID_RYZEN"
        notify-send "Audio" "Cambiado a: ALTAVOCES 🔊" --icon=audio-speakers --urgency=normal
    fi
else
    # Si estamos en altavoces, pasamos a Cascos
    if [ ! -z "$ID_STEEL" ]; then
        wpctl set-default "$ID_STEEL"
        notify-send "Audio" "Cambiado a: CASCOS 🎧" --icon=audio-headphones --urgency=normal
    else
        notify-send "Audio" "⚠️ Cascos no detectados" --icon=dialog-warning
    fi
fi
