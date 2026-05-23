#!/bin/bash

# --- COLORES ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 Iniciando instalación automática de Dotfiles de Alejandro...${NC}"

DOTFILES_DIR="$HOME/dotfiles"
BACKUP_DIR="$DOTFILES_DIR/backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Función para crear symlinks de forma segura
link_file() {
    local src=$1
    local dst=$2

    mkdir -p "$(dirname "$dst")"
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        echo -e "📦 Backup de $dst guardado en backups/"
        mv "$dst" "$BACKUP_DIR/"
    fi
    ln -sf "$src" "$dst"
    echo -e "${GREEN}✅ Enlazado: $dst${NC}"
}

echo -e "\n${BLUE}══════════════════════════════════════${NC}"
echo -e "${BLUE}  Ejecutando módulos de instalación...${NC}"
echo -e "${BLUE}══════════════════════════════════════${NC}"

for script in "$DOTFILES_DIR/install.d/"*.sh; do
    [ -f "$script" ] || continue
    echo -e "\n${BLUE}▶ ${script##*/}...${NC}"
    source "$script"
done

echo -e "\n${GREEN}✨ ¡Todo listo! Reiniciá la terminal para aplicar los cambios.${NC}"
