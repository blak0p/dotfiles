#!/bin/bash

# Carpeta de los juegos
DIR="/var/mnt/Juegos/Roms/Emulation/roms/switch"

echo "🧼 Limpiando nombres para que Steam no se confunda..."

cd "$DIR" || exit

for archivo in *.nsp; do
    # 1. Extraer la parte del nombre antes del primer corchete [
    # 2. Quitar espacios sobrantes al final
    nuevo_nombre=$(echo "$archivo" | sed 's/ \[.*//')
    
    # Solo renombramos si el nombre realmente cambia
    if [ "$archivo" != "$nuevo_nombre.nsp" ]; then
        mv "$archivo" "$nuevo_nombre.nsp"
        echo "✅ Renombrado: $nuevo_nombre.nsp"
    fi
done

echo "✨ Nombres purificados. Ahora SRM te reconocerá todo a la primera."
