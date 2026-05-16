#!/bin/bash

# 1. Definimos las rutas como variables (mantenibilidad)
WATCH_DIR="/var/mnt/Juegos/Roms/Emulation/roms/switch"
PROD_KEYS="$HOME/.switch/prod.keys"

echo "Servicio de conversión iniciado en $WATCH_DIR"

# 2. El comando inotifywait se queda escuchando la carpeta.
# -e close_write: Solo actúa cuando el archivo se termina de copiar por completo.
inotifywait -m -e close_write --format '%f' "$WATCH_DIR" | while read FILENAME
do
    # 3. Filtro: ¿Es un archivo .nsz?
    if [[ "$FILENAME" == *.nsz ]]; then
        echo "Detectado: $FILENAME. Iniciando conversión..."
        
        # 4. Ejecución de nsz
        # -D: Descomprime a .nsp
        # --rm-source: Elimina el .nsz original automáticamente si la conversión tiene éxito.
        nsz -D "$WATCH_DIR/$FILENAME" --output "$WATCH_DIR" --rm-source
        
        echo "Conversión finalizada y archivo original eliminado."
    fi
done
