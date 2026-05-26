#!/bin/bash

# --- COLORES ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Listar módulos disponibles en install.d/
MODULES_DIR="$(dirname "$0")"
SCRIPTS=("$MODULES_DIR"/*.sh)

# Mostrar un listado de módulos amigable
echo -e "${BLUE}Módulos disponibles para instalar:${NC}"
for i in "${!SCRIPTS[@]}"; do
    BASENAME="$(basename "${SCRIPTS[$i]}")"
    echo "[$i] ${BASENAME}"
done

# Leer selección del usuario
echo -e "\n${BLUE}Seleccione los módulos que desea instalar (separados por espacio, o * para todos):${NC}"
read -p "> " seleccion

# Procesar selección del usuario
if [[ $seleccion == "*" ]]; then
    SELECCIONADOS=("${SCRIPTS[@]}")
else
    for i in $seleccion; do
        SELECCIONADOS+=("${SCRIPTS[$i]}")
    done
fi

# Ejecutar los módulos seleccionados
echo -e "\n${BLUE}Ejecutando módulos seleccionados...${NC}"
for script in "${SELECCIONADOS[@]}"; do
    BASENAME="$(basename "$script")"
    if [ "$BASENAME" != "gestor.sh" ]; then
        echo -e "${BLUE}▶ Ejecutando: ${BASENAME}...${NC}"
        source "$script"
    fi
done

echo -e "\n${GREEN}¡Instalación completada!${NC}"