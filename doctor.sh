#!/bin/bash

# --- COLORES ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- CONFIGURACIÓN ---
DOTFILES_DIR="$HOME/dotfiles"
ERRORS=0
WARNINGS=0

echo -e "${BLUE}🩺 Iniciando Dotfiles Doctor — Diagnosticando salud del sistema...${NC}\n"

# --- FUNCIONES DE AYUDA ---

# Comprobar si un comando existe
check_dependency() {
    local cmd=$1
    if command -v "$cmd" >/dev/null 2>&1; then
        echo -e "${GREEN}[OK]${NC} Dependencia instalada: $cmd"
    else
        echo -e "${RED}[ERROR]${NC} Dependencia faltante: $cmd"
        ERRORS=$((ERRORS + 1))
    fi
}

# Comprobar si un enlace simbólico es correcto
check_symlink() {
    local target=$1
    local expected_source=$2

    if [ ! -e "$target" ] && [ ! -L "$target" ]; then
        echo -e "${RED}[ERROR]${NC} No existe: $target"
        ERRORS=$((ERRORS + 1))
        return
    fi

    if [ ! -L "$target" ]; then
        echo -e "${YELLOW}[WARNING]${NC} $target existe pero no es un enlace simbólico."
        WARNINGS=$((WARNINGS + 1))
        return
    fi

    local actual_source
    actual_source=$(readlink -f "$target")
    local resolved_expected
    resolved_expected=$(readlink -f "$expected_source")

    if [ "$actual_source" == "$resolved_expected" ]; then
        echo -e "${GREEN}[OK]${NC} Enlace correcto: $target -> $expected_source"
    else
        echo -e "${RED}[ERROR]${NC} Enlace incorrecto: $target apunta a $actual_source (se esperaba $expected_source)"
        ERRORS=$((ERRORS + 1))
    fi
}

# --- 1. CHEQUEO DE DEPENDENCIAS ---
echo -e "${BLUE}📦 Verificando herramientas de software...${NC}"
DEPS=("kitty" "btop" "fastfetch" "lazygit" "starship" "oh-my-posh" "superfile" "python3" "git")
for dep in "${DEPS[@]}"; do
    check_dependency "$dep"
done

# --- 2. CHEQUEO DE ENLACES SIMBÓLICOS ---
echo -e "\n${BLUE}🔗 Verificando enlaces simbólicos...${NC}"

# Home
check_symlink "$HOME/.bashrc" "$DOTFILES_DIR/home/.bashrc"
check_symlink "$HOME/.zshrc" "$DOTFILES_DIR/home/.zshrc"
check_symlink "$HOME/.bashrc.d" "$DOTFILES_DIR/home/.bashrc.d"
check_symlink "$HOME/.bash_profile" "$DOTFILES_DIR/home/.bash_profile"
check_symlink "$HOME/.gitconfig" "$DOTFILES_DIR/home/.gitconfig"

# Scripts
check_symlink "$HOME/scripts" "$DOTFILES_DIR/scripts"

# Config
check_symlink "$HOME/.config/kitty" "$DOTFILES_DIR/config/kitty"
check_symlink "$HOME/.config/btop" "$DOTFILES_DIR/config/btop"
check_symlink "$HOME/.config/fastfetch" "$DOTFILES_DIR/config/fastfetch"
check_symlink "$HOME/.config/lazygit" "$DOTFILES_DIR/config/lazygit"
check_symlink "$HOME/.config/oh-my-posh" "$DOTFILES_DIR/config/oh-my-posh"
check_symlink "$HOME/.config/superfile" "$DOTFILES_DIR/config/superfile"
check_symlink "$HOME/.config/axiom" "$DOTFILES_DIR/config/axiom"
check_symlink "$HOME/.config/starship.tom" "$DOTFILES_DIR/config/starship.tom"
check_symlink "$HOME/.config/starship.tomls" "$DOTFILES_DIR/config/starship.tomls"

# Dev & Hardware
check_symlink "$HOME/dev/axiom" "$DOTFILES_DIR/dev/axiom"
check_symlink "$HOME/deepcool-ak620-digital-linux" "$DOTFILES_DIR/hardware/deepcool-ak620"

# --- 3. CHEQUEO DE HARDWARE (Python Venv) ---
echo -e "\n${BLUE}🐍 Verificando entorno de hardware (Deepcool)...${NC}"
if [ -d "$DOTFILES_DIR/hardware/deepcool-ak620" ]; then
    if [ -d "$DOTFILES_DIR/hardware/deepcool-ak620/venv" ]; then
        echo -e "${GREEN}[OK]${NC} Entorno virtual (venv) encontrado."
    else
        echo -e "${YELLOW}[WARNING]${NC} Entorno virtual (venv) no encontrado. Ejecutá install.sh para configurarlo."
        WARNINGS=$((WARNINGS + 1))
    fi
fi

# --- 4. CHEQUEO DE ACTUALIZACIONES GIT ---
echo -e "\n${BLUE}🌐 Verificando actualizaciones del repositorio...${NC}"
if [ -d "$DOTFILES_DIR/.git" ]; then
    cd "$DOTFILES_DIR" || exit
    git fetch origin main --quiet 2>/dev/null
    LOCAL=$(git rev-parse HEAD)
    REMOTE=$(git rev-parse @{u} 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}[WARNING]${NC} No se pudo verificar el estado remoto (¿sin internet?)"
        WARNINGS=$((WARNINGS + 1))
    elif [ "$LOCAL" == "$REMOTE" ]; then
        echo -e "${GREEN}[OK]${NC} Repositorio actualizado."
    else
        echo -e "${YELLOW}[WARNING]${NC} Hay cambios nuevos en el repositorio remoto. Considerá hacer 'git pull'."
        WARNINGS=$((WARNINGS + 1))
    fi
fi

# --- RESUMEN FINAL ---
echo -e "\n--------------------------------------------------"
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "📊 Resumen: ${GREEN}Sistema saludable${NC}"
    echo -e "✨ ¡Todo perfecto! Tu setup está impecable."
else
    echo -e "📊 Resumen: ${YELLOW}Se requieren ajustes${NC}"
    [ $ERRORS -gt 0 ] && echo -e "${RED}❌ Errores detectados: $ERRORS${NC}"
    [ $WARNINGS -gt 0 ] && echo -e "${YELLOW}⚠️ Advertencias: $WARNINGS${NC}"
    echo -e "\n💡 Revisa los puntos anteriores para poner todo en orden."
fi
echo -e "--------------------------------------------------\n"
