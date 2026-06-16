#!/bin/bash
# Forza el volumen hardware del ALC897 al maximo real (87/87)
# Cuando PipeWire usa perfil pro-audio, el slider de KDE no controla
# el Master de ALSA, y a veces queda bajo sin que te des cuenta.

CARD=2

amixer -c "$CARD" sset Master 87 2>/dev/null || {
    notify-send "fix-audio-volume" "No se encontro la tarjeta $CARD" -i dialog-error
    exit 1
}

notify-send "fix-audio-volume" "Volumen hardware ALC897 forzado a 100%" -i audio-volume-high --urgency=low
