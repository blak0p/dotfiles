#!/usr/bin/env bash
# install.sh — Dotfiles Installer
# Deploya config/ → ~/.config/ y scripts/ → ~/scripts/ via symlinks.
# Ejecuta módulos de modules/ si tienen install.sh.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

# ─── Colores ──────────────────────────────────────────────────────
BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${BLUE}ℹ️${NC} $1"; }
ok()    { echo -e "${GREEN}✅${NC} $1"; }
warn()  { echo -e "${YELLOW}⚠️${NC} $1"; }
err()   { echo -e "${RED}❌${NC} $1"; }

# ─── Deploy symlinks ──────────────────────────────────────────────
deploy_symlink() {
    local src="$1" dst="$2"
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        warn "Respaldando $dst → $BACKUP_DIR/"
        mkdir -p "$BACKUP_DIR/$(dirname "${dst#$HOME/}")"
        mv "$dst" "$BACKUP_DIR/$(dirname "${dst#$HOME/}")/"
    fi
    if [ -L "$dst" ]; then
        local current=$(readlink "$dst")
        if [ "$current" = "$src" ]; then
            return 0
        fi
        rm -f "$dst"
    fi
    ln -sf "$src" "$dst"
    ok "Symlink: $dst → $src"
}

deploy_configs() {
    info "Deployando config/ → ~/.config/..."
    for dir in "$DOTFILES_DIR/config"/*/; do
        local name=$(basename "$dir")
        local src="$DOTFILES_DIR/config/$name"
        local dst="$HOME/.config/$name"
        deploy_symlink "$src" "$dst"
    done
    # Archivos sueltos en config/
    for f in "$DOTFILES_DIR/config"/starship.toml; do
        [ -f "$f" ] && deploy_symlink "$f" "$HOME/.config/$(basename "$f")"
    done
}

deploy_scripts() {
    info "Deployando scripts/ → ~/scripts/..."
    mkdir -p "$HOME/scripts"
    for f in "$DOTFILES_DIR/scripts"/*; do
        [ -f "$f" ] && deploy_symlink "$f" "$HOME/scripts/$(basename "$f")"
    done
}

# ─── Modules ──────────────────────────────────────────────────────
MODULE_NAMES=(
    "eden"
    "gaming"
    "hardware"
)
MODULE_DESCS=(
    "Symlinks de Eden y PrismLauncher al disco Juegos"
    "Steam autopicture service"
    "Deepcool AK620 display daemon"
)

install_module() {
    local name="$1"
    local dir="$DOTFILES_DIR/modules/$name"
    if [ ! -d "$dir" ]; then
        err "Módulo '$name' no encontrado"
        return 1
    fi
    if [ -f "$dir/install.sh" ]; then
        info "Ejecutando módulo: $name..."
        bash "$dir/install.sh"
        ok "Módulo '$name' listo"
    else
        warn "Módulo '$name' no tiene install.sh, saltando"
    fi
}

# ─── Help ─────────────────────────────────────────────────────────
show_help() {
    echo "Dotfiles Installer"
    echo ""
    echo "Uso:"
    echo "  ./install.sh              — Menú interactivo"
    echo "  ./install.sh --all        — Deployar todo + módulos"
    echo "  ./install.sh --config     — Solo symlinks de config/"
    echo "  ./install.sh --scripts    — Solo symlinks de scripts/"
    echo "  ./install.sh --deps       — Solo instalar dependencias"
    echo "  ./install.sh --module X   — Solo un módulo"
    echo ""
    echo "Módulos:"
    for i in "${!MODULE_NAMES[@]}"; do
        printf "  %-15s %s\n" "${MODULE_NAMES[$i]}" "${MODULE_DESCS[$i]}"
    done
}

# ─── Main ─────────────────────────────────────────────────────────
main() {
    case "${1:-}" in
        --help|-h) show_help ;;
        --config) deploy_configs ;;
        --scripts) deploy_scripts ;;
        --deps) bash "$DOTFILES_DIR/deps/install.sh" ;;
        --module|-m)
            [ -z "${2:-}" ] && { err "Falta el nombre del módulo"; exit 1; }
            install_module "$2"
            ;;
        --all|-a)
            deploy_configs
            deploy_scripts
            for name in "${MODULE_NAMES[@]}"; do install_module "$name"; done
            ;;
        *)
            echo "═══════════════════════════════════════════"
            echo "  🛠️  Dotfiles"
            echo "═══════════════════════════════════════════"
            echo ""
            deploy_configs
            deploy_scripts
            echo ""
            echo "¿Instalar dependencias? (brew → pacman → AUR → flatpak) (s/N): "
            read -rn1 answer
            echo
            if [[ "$answer" =~ ^[sS]$ ]]; then
                bash "$DOTFILES_DIR/deps/install.sh"
            fi
            echo ""
            echo "¿Ejecutar módulos? (s/N): "
            read -rn1 answer
            echo
            if [[ "$answer" =~ ^[sS]$ ]]; then
                for name in "${MODULE_NAMES[@]}"; do install_module "$name"; done
            else
                info "Módulos omitidos. Corré ./install.sh --module <name> después."
            fi
            echo ""
            echo "═══════════════════════════════════════════"
            echo "  ✅ Listo"
            echo "═══════════════════════════════════════════"
            ;;
    esac
}

main "$@"
