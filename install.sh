#!/bin/bash

# --- COLORES ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Iniciando instalación automática de Dotfiles de Alejandro...${NC}"

DOTFILES_DIR="$HOME/dotfiles"
BACKUP_DIR="$DOTFILES_DIR/backups/$(date +%Y%m%d_%H%M%S)"

mkdir -p "$BACKUP_DIR"

# Función para crear symlinks de forma segura
link_file() {
    local src=$1
    local dst=$2
    
    # Crear directorio padre si no existe
    mkdir -p "$(dirname "$dst")"
    
    # Si ya existe algo y no es un link, hacer backup
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        echo -e "📦 Backup de $dst guardado en backups/"
        mv "$dst" "$BACKUP_DIR/"
    fi
    
    # Crear el enlace (forzado para sobreescribir links viejos)
    ln -sf "$src" "$dst"
    echo -e "${GREEN}✅ Enlazado: $dst${NC}"
}

echo "🛠️ Creando enlaces simbólicos..."

# --- HOME ---
link_file "$DOTFILES_DIR/home/.bashrc" "$HOME/.bashrc"
link_file "$DOTFILES_DIR/home/.zshrc" "$HOME/.zshrc"
link_file "$DOTFILES_DIR/home/.bashrc.d" "$HOME/.bashrc.d"
link_file "$DOTFILES_DIR/home/.bash_profile" "$HOME/.bash_profile"
link_file "$DOTFILES_DIR/home/.gitconfig" "$HOME/.gitconfig"

# --- SCRIPTS ---
link_file "$DOTFILES_DIR/scripts" "$HOME/scripts"

# --- CONFIG ---
link_file "$DOTFILES_DIR/config/kitty" "$HOME/.config/kitty"
link_file "$DOTFILES_DIR/config/btop" "$HOME/.config/btop"
link_file "$DOTFILES_DIR/config/fastfetch" "$HOME/.config/fastfetch"
link_file "$DOTFILES_DIR/config/lazygit" "$HOME/.config/lazygit"
link_file "$DOTFILES_DIR/config/oh-my-posh" "$HOME/.config/oh-my-posh"
link_file "$DOTFILES_DIR/config/superfile" "$HOME/.config/superfile"
link_file "$DOTFILES_DIR/config/axiom" "$HOME/.config/axiom"
link_file "$DOTFILES_DIR/config/starship.tom" "$HOME/.config/starship.tom"
link_file "$DOTFILES_DIR/config/starship.tomls" "$HOME/.config/starship.tomls"

# --- DEV & HARDWARE ---
link_file "$DOTFILES_DIR/dev/axiom" "$HOME/Documentos/dev/axiom"
link_file "$DOTFILES_DIR/hardware/deepcool-ak620" "$HOME/deepcool-ak620-digital-linux"

# --- DEPENDENCIAS DE HARDWARE (Python) ---
echo -e "\n🐍 Configurando entorno Python para el disipador..."
if [ -d "$DOTFILES_DIR/hardware/deepcool-ak620" ]; then
    cd "$DOTFILES_DIR/hardware/deepcool-ak620"
    if [ ! -d "venv" ]; then
        python3 -m venv venv
    fi
    source venv/bin/activate
    pip install -r requirements.txt --quiet
    deactivate
    echo -e "${GREEN}✅ Dependencias de hardware instaladas.${NC}"
fi

echo -e "\n${GREEN}✨ ¡Todo listo! Reiniciá la terminal para aplicar los cambios.${NC}"
