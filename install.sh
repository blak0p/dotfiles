#!/bin/bash

# --- COLORES ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo -e "${BLUE}🚀 Dotfiles — Instalación por módulos${NC}"

DOTFILES_DIR="$HOME/dev/dotfiles"
BACKUP_DIR="$DOTFILES_DIR/backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# --- Función para crear symlinks de forma segura ---
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

# --- Módulos disponibles ---
MODULE_NAMES=(
    "shell-core"
    "prompt"
    "apps"
    "gaming"
    "ai"
    "dev"
    "hardware"
    "kde"
)

MODULE_DESCS=(
    "Shell + git + bashrc.d base (SIEMPRE RECOMENDADO)"
    "oh-my-posh + starship"
    "kitty, btop, fastfetch"
    "Steam autopicture, ROM tools, auto-big-picture service"
    "Gentle AI, Ollama"
    "LazyGit, Axiom, scripts utilitarios"
    "Deepcool AK620 + daemon"
    "KDE Plasma — atajos, paneles, tema"
)

# --- Selección de módulos ---
echo -e "\n${BLUE}══════════════════════════════════════${NC}"
echo -e "${BLUE}  Seleccioná los módulos a instalar${NC}"
echo -e "${BLUE}══════════════════════════════════════${NC}"
echo ""

for i in "${!MODULE_NAMES[@]}"; do
    n=$((i + 1))
    printf "  ${YELLOW}%2d)${NC} %-12s %s\n" "$n" "${MODULE_NAMES[$i]}" "${MODULE_DESCS[$i]}"
done

echo ""
echo -e "  ${YELLOW}  a)${NC} Todos"
echo -e "  ${YELLOW}  q)${NC} Salir"
echo ""

read -p "  Elegí números separados por coma, rangos (1-4), o 'a' para todos: " SELECTION

# Procesar selección
SELECTED=()
if [[ "$SELECTION" == "q" ]]; then
    echo -e "\n${YELLOW}Instalación cancelada.${NC}"
    exit 0
elif [[ "$SELECTION" == "a" || "$SELECTION" == "A" ]]; then
    SELECTED=(1 2 3 4 5 6 7)
else
    # Expandir rangos (1-4 → 1 2 3 4) y splits por coma
    IFS=',' read -ra PARTS <<< "$SELECTION"
    for part in "${PARTS[@]}"; do
        part="${part// /}"  # trim spaces
        if [[ "$part" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            for ((j = ${BASH_REMATCH[1]}; j <= ${BASH_REMATCH[2]}; j++)); do
                SELECTED+=("$j")
            done
        elif [[ "$part" =~ ^[0-9]+$ ]]; then
            SELECTED+=("$part")
        fi
    done
    # Ordenar y deduplicar
    SELECTED=($(printf "%s\n" "${SELECTED[@]}" | sort -nu))
fi

# --- Mostrar resumen ---
echo ""
echo -e "${BLUE}══════════════════════════════════════${NC}"
echo -e "${BLUE}  Módulos seleccionados:${NC}"
echo -e "${BLUE}══════════════════════════════════════${NC}"
for idx in "${SELECTED[@]}"; do
    actual=$((idx - 1))
    if [ "$actual" -ge 0 ] && [ "$actual" -lt "${#MODULE_NAMES[@]}" ]; then
        echo -e "  ${GREEN}✅${NC} ${MODULE_NAMES[$actual]}"
    fi
done

# --- Ejecutar módulos ---
echo -e "\n${BLUE}══════════════════════════════════════${NC}"
echo -e "${BLUE}  Instalando...${NC}"
echo -e "${BLUE}══════════════════════════════════════${NC}"

for idx in "${SELECTED[@]}"; do
    actual=$((idx - 1))
    if [ "$actual" -ge 0 ] && [ "$actual" -lt "${#MODULE_NAMES[@]}" ]; then
        module="${MODULE_NAMES[$actual]}"
        script="$DOTFILES_DIR/modules/$module/install.sh"
        if [ -f "$script" ]; then
            echo -e "\n${BLUE}▶ Instalando módulo: $module${NC}"
            source "$script"
        else
            echo -e "\n${YELLOW}⚠️  Módulo '$module' no tiene install.sh${NC}"
        fi
    fi
done

echo -e "\n${GREEN}══════════════════════════════════════${NC}"
echo -e "${GREEN}✨ ¡Todo listo! Reiniciá la terminal para aplicar los cambios.${NC}"
echo -e "${GREEN}══════════════════════════════════════${NC}"
