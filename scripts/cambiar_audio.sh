#!/bin/bash

# 1. Definimos los nombres internos de WirePlumber (son más fiables que los IDs)
SINK_RYZEN="alsa_output.pci-0000_0f_00.6.analog-stereo"
SINK_STEEL="alsa_output.usb-SteelSeries_SteelSeries_Arctis_Nova_5-00.iec958-stereo"

# 2. Obtenemos el nombre del dispositivo que tiene la estrella [*] (el activo)
# Usamos wpctl status para ver quién es el default actual
CURRENT_NAME=$(wpctl inspect @DEFAULT_AUDIO_SINK@ | grep "node.name" | cut -d '"' -f 2)

# 3. Lógica de cambio
if [[ "$CURRENT_NAME" == "$SINK_STEEL" ]]; then
    # Estamos en cascos, cambiamos a altavoces
    wpctl set-default "$SINK_RYZEN"
    notify-send "Audio" "Cambiado a: ALTAVOCES 🔊" --icon=audio-speakers --urgency=normal
else
    # Estamos en altavoces (o cualquier otro), cambiamos a cascos
    # Verificamos si los cascos están disponibles antes de intentar cambiar
    if wpctl status | grep -q "SteelSeries"; then
        wpctl set-default "$SINK_STEEL"
        notify-send "Audio" "Cambiado a: CASCOS 🎧" --icon=audio-headphones --urgency=normal
    else
        notify-send "Audio" "⚠️ Cascos SteelSeries no detectados" --icon=dialog-warning
    fi
fi
