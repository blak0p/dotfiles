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

# ─── Deploy helpers ───────────────────────────────────────────────
# Deploy a single config entry (dir or file) from src to ~/.config/<name>
deploy_config_entry() {
    local src="$1" name="$2"
    deploy_symlink "$src" "$HOME/.config/$name"
}

# Shared configs: nvim, ghostty, starship.toml, fish, fastfetch.
# Deployed by both --host and --bunker. Idempotent.
deploy_shared() {
    info "Deployando shared config/ → ~/.config/..."
    local shared=(nvim ghostty fish fastfetch)
    for name in "${shared[@]}"; do
        [ -e "$DOTFILES_DIR/config/$name" ] && deploy_config_entry "$DOTFILES_DIR/config/$name" "$name"
    done
    for f in "$DOTFILES_DIR/config"/starship.toml; do
        [ -f "$f" ] && deploy_symlink "$f" "$HOME/.config/$(basename "$f")"
    done
}

# Domain deploy: links every entry under {domain}/config/ and {domain}/scripts/
# into ~/.config/ and ~/scripts/ respectively. Symlinks resolve to the original
# files under root config/ and scripts/ (relative symlinks).
deploy_domain() {
    local domain="$1"
    local dcfg="$DOTFILES_DIR/$domain/config"
    local dscripts="$DOTFILES_DIR/$domain/scripts"

    info "Deployando $domain/config/ → ~/.config/..."
    if [ -d "$dcfg" ]; then
        for entry in "$dcfg"/*; do
            [ -e "$entry" ] || continue
            deploy_config_entry "$entry" "$(basename "$entry")"
        done
    else
        info "no $domain configs to deploy"
    fi

    info "Deployando $domain/scripts/ → ~/scripts/..."
    mkdir -p "$HOME/scripts"
    if [ -d "$dscripts" ]; then
        for f in "$dscripts"/*; do
            [ -e "$f" ] || continue
            deploy_symlink "$f" "$HOME/scripts/$(basename "$f")"
        done
    fi
}

# Legacy: deploy everything under root config/ (kept for --config backward compat)
deploy_configs() {
    info "Deployando config/ → ~/.config/..."
    for dir in "$DOTFILES_DIR/config"/*/; do
        local name=$(basename "$dir")
        local src="$DOTFILES_DIR/config/$name"
        local dst="$HOME/.config/$name"
        deploy_symlink "$src" "$dst"
    done
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
    echo "  ./install.sh --host       — Host configs + shared + modules + deps + personal-pc"
    echo "  ./install.sh --bunker     — Bunker configs + shared (distrobox)"
    echo "  ./install.sh --all        — Host + bunker + shared (shared once) + modules + deps"
    echo "  ./install.sh --config     — Solo symlinks de config/ (legacy)"
    echo "  ./install.sh --scripts    — Solo symlinks de scripts/ (legacy)"
    echo "  ./install.sh --deps       — Solo instalar dependencias"
    echo "  ./install.sh --module X   — Solo un módulo"
    echo "  ./install.sh --help       — Esta ayuda"
    echo ""
    echo "Dominios:"
    echo "  host    Hyprland, Waybar, btop, cava, fuzzel, GTK, systemd, hardware"
    echo "  bunker  opencode, dev scripts (distrobox)"
    echo "  shared  nvim, ghostty, starship.toml, fish, fastfetch"
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
        --host)
            deploy_shared
            deploy_domain host
            for name in "${MODULE_NAMES[@]}"; do install_module "$name"; done
            bash "$DOTFILES_DIR/deps/install.sh"
            ;;
        --bunker)
            deploy_shared
            deploy_domain bunker
            ;;
        --all|-a)
            deploy_shared
            deploy_domain host
            deploy_domain bunker
            for name in "${MODULE_NAMES[@]}"; do install_module "$name"; done
            bash "$DOTFILES_DIR/deps/install.sh"
            ;;
        --config) deploy_configs ;;
        --scripts) deploy_scripts ;;
        --deps) bash "$DOTFILES_DIR/deps/install.sh" ;;
        --module|-m)
            [ -z "${2:-}" ] && { err "Falta el nombre del módulo"; exit 1; }
            install_module "$2"
            ;;
        *)
            echo "═══════════════════════════════════════════"
            echo "  🛠️  Dotfiles"
            echo "═══════════════════════════════════════════"
            echo ""
            show_help
            echo ""
            echo "Especificá un dominio: --host, --bunker o --all."
            echo "═══════════════════════════════════════════"
            exit 1
            ;;
    esac
}

main "$@"
