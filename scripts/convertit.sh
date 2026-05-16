#!/bin/bash

# Ruta exacta que me diste
GAME_DIR="/var/mnt/Juegos/Roms/Emulation/roms/switch"

echo "🧹 Limpiando y convirtiendo juegos en $GAME_DIR..."

# Ejecutamos la conversión directa
# -D: Descomprimir a .nsp
# --rm-source: Borrar el .nsz original solo si la conversión sale bien
nsz -D "$GAME_DIR" --rm-source

echo "✨ Proceso terminado. Ahora solo tienes archivos .nsp."
