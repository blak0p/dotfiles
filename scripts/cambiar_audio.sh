#!/bin/bash

# 1. Obtenemos el ID de los Cascos (SteelSeries)
# Los buscamos en Sinks o en Settings
ID_STEEL=$(wpctl status | grep -i "SteelSeries" | grep -oP '\d+\.' | grep -oP '\d+' | head -n 1)

# Si el ID es 0, significa que los cascos no están en Sinks (ID 0 suele ser la referencia de Settings)
# En ese caso, intentamos buscar por el nombre descriptivo en todo el status
if [ "$ID_STEEL" == "0" ] || [ -z "$ID_STEEL" ]; then
    ID_STEEL=$(wpctl status | grep -i "SteelSeries" | grep -oP '^\s*[│ ]\s*(\*?\s*)(\d+)\.' | grep -oP '\d+' | head -n 1)
fi

# 2. Obtenemos el ID de los Altavoces (Ryzen)
ID_RYZEN=$(wpctl status | grep -i "Ryzen" | grep -i "Sink" -B 1 | grep -oP '\d+' | head -n 1)
# Si falló la anterior, buscamos Ryzen en cualquier lugar de Sinks
if [ -z "$ID_RYZEN" ]; then
    ID_RYZEN=$(wpctl status | sed -n '/Sinks:/,/Sources:/p' | grep -i "Ryzen" | grep -oP '\d+' | head -n 1)
fi

# 3. Detectamos quién es el default actual (ID)
CURRENT_ID=$(wpctl status | sed -n '/Sinks:/,/Sources:/p' | grep '\*' | grep -oP '\d+' | head -n 1)

# 4. Lógica de cambio
# Si estamos en cascos (o no los encontramos), pasamos a Altavoces
if [ "$CURRENT_ID" == "$ID_STEEL" ] || [ -z "$ID_STEEL" ]; then
    if [ ! -z "$ID_RYZEN" ]; then
        wpctl set-default "$ID_RYZEN"
        notify-send "Audio" "Cambiado a: ALTAVOCES 🔊" --icon=audio-speakers --urgency=normal
    fi
else
    # Si estamos en altavoces, pasamos a Cascos
    if [ ! -z "$ID_STEEL" ] && [ "$ID_STEEL" != "0" ]; then
        wpctl set-default "$ID_STEEL"
        notify-send "Audio" "Cambiado a: CASCOS 🎧" --icon=audio-headphones --urgency=normal
    else
        notify-send "Audio" "⚠️ Cascos no detectados o apagados" --icon=dialog-warning
    fi
fi
