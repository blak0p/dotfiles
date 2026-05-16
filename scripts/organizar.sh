#!/bin/bash

# Rutas
DIR_SWITCH="/var/mnt/Juegos/Roms/Emulation/roms/switch"
DIR_EXTRAS="$DIR_SWITCH/updates_y_dlc"

# Crear la carpeta para la basura si no existe
mkdir -p "$DIR_EXTRAS"

echo "📦 Organizando archivos para limpiar Steam..."

# Mover todo lo que sea Update (v seguido de números grandes) o DLC
# Usamos comodines inteligentes
mv "$DIR_SWITCH"/*\[v[1-9]*\]*.nsp "$DIR_EXTRAS/" 2>/dev/null
mv "$DIR_SWITCH"/*DLC*.nsp "$DIR_EXTRAS/" 2>/dev/null
mv "$DIR_SWITCH"/*[001]*.nsp "$DIR_EXTRAS/" 2>/dev/null

echo "✅ ¡Listo! Los juegos base se han quedado en la raíz."
echo "✅ Las actualizaciones y DLCs se han movido a: $DIR_EXTRAS"
