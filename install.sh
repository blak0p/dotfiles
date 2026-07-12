#!/usr/bin/env bash
# install.sh — Dotfiles Installer (Host only)
# Solo servicios + symlinks. Nada de dev tools, nada de AI.
# Gentleman Dots se instala aparte con su TUI.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

# ─── Módulos disponibles ─────────────────────────────────────────
MODULE_NAMES=(
    "eden"
    "gaming"
    "hardware"
    "shell-core"
)

MODULE_DESCS=(
    "Symlinks de Eden y PrismLauncher al disco Juegos"
    "Steam autopicture, ROM tools, auto-big-picture service"
    "Deepcool AK620 + daemon"
    "cambiar_audio, cambiar_micro"
)

# ─── Colores ──────────────────────────────────────────────────────
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${BLUE}ℹ️${NC} $1"; }
ok()    { echo -e "${GREEN}✅${NC} $1"; }
warn()  { echo -e "${YELLOW}⚠️${NC} $1"; }
err()   { echo -e "${RED}❌${NC} $1"; }

# ─── Help ─────────────────────────────────────────────────────────
show_help() {
    echo "Dotfiles Installer — Host"
    echo ""
    echo "Uso:"
    echo "  ./install.sh              — Menú interactivo"
    echo "  ./install.sh --all        — Instalar todo"
    echo "  ./install.sh --module X   — Instalar solo un módulo"
    echo ""
    echo "Módulos:"
    for i in "${!MODULE_NAMES[@]}"; do
        printf "  %-15s %s\n" "${MODULE_NAMES[$i]}" "${MODULE_DESCS[$i]}"
    done
}

# ─── Instalar módulo ──────────────────────────────────────────────
install_module() {
    local name="$1"
    local dir="$DOTFILES_DIR/modules/$name"

    if [ ! -d "$dir" ]; then
        err "Módulo '$name' no encontrado en $dir"
        return 1
    fi

    if [ -f "$dir/install.sh" ]; then
        info "Instalando módulo: $name..."
        bash "$dir/install.sh"
        ok "Módulo '$name' instalado"
    else
        warn "Módulo '$name' no tiene install.sh, saltando"
    fi
}

# ─── Menú interactivo ─────────────────────────────────────────────
interactive_menu() {
    echo "═══════════════════════════════════════════"
    echo "  🛠️  Dotfiles — Host"
    echo "═══════════════════════════════════════════"
    echo ""

    for i in "${!MODULE_NAMES[@]}"; do
        echo "  $((i+1))) ${MODULE_NAMES[$i]} — ${MODULE_DESCS[$i]}"
    done
    echo "  a) Todos"
    echo "  q) Salir"
    echo ""

    read -rp "Elegí módulos (ej: 1,3 o 1-2 o a): " selection

    case "$selection" in
        q|Q) echo "Chau."; exit 0 ;;
        a|A)
            for name in "${MODULE_NAMES[@]}"; do install_module "$name"; done
            ;;
        *)
            local selected=()
            IFS=',' read -ra parts <<< "$selection"
            for part in "${parts[@]}"; do
                if [[ "$part" =~ ^([0-9]+)-([0-9]+)$ ]]; then
                    for i in $(seq "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"); do selected+=("$i"); done
                elif [[ "$part" =~ ^[0-9]+$ ]]; then
                    selected+=("$part")
                fi
            done
            for idx in "${selected[@]}"; do
                [ "$idx" -ge 1 ] && [ "$idx" -le "${#MODULE_NAMES[@]}" ] && install_module "${MODULE_NAMES[$((idx-1))]}" || warn "Índice $idx inválido"
            done
            ;;
    esac
}

# ─── Main ─────────────────────────────────────────────────────────
main() {
    case "${1:-}" in
        --help|-h) show_help ;;
        --all|-a)
            for name in "${MODULE_NAMES[@]}"; do install_module "$name"; done
            ;;
        --module|-m)
            [ -z "${2:-}" ] && { err "Falta el nombre del módulo"; exit 1; }
            install_module "$2"
            ;;
        *) interactive_menu ;;
    esac

    echo ""
    echo "═══════════════════════════════════════════"
    echo "  ✅ Host listo"
    echo "═══════════════════════════════════════════"
}

main "$@"
