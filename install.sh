#!/usr/bin/env bash
# Monorepo installer — delegates to each component's install.sh.
set -eEuo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_DIR

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${BLUE}ℹ${NC} $1"; }
ok()    { echo -e "${GREEN}✓${NC} $1"; }
warn()  { echo -e "${YELLOW}⚠${NC} $1"; }
err()   { echo -e "${RED}✗${NC} $1"; }

show_help() {
    cat <<HELP
Dotfiles — monorepo installer

Usage:
  ./install.sh              Show this help
  ./install.sh --help       Show this help
  ./install.sh --all        Deploy all components
  ./install.sh --hyprland   Deploy Hyprland desktop configs
  ./install.sh --fish       Deploy fish shell + tooling
  ./install.sh --kitty      Deploy kitty terminal (alias for --fish)
  ./install.sh --nvim       Deploy Neovim editor config
HELP
}

run_installer() {
    local repo="$1"
    if [ ! -f "$DOTFILES_DIR/$repo/install.sh" ]; then
        err "$repo/install.sh not found — is the checkout complete?"
        return 1
    fi
    info "Running $repo/install.sh..."
    bash "$DOTFILES_DIR/$repo/install.sh"
}

main() {
    case "${1:-}" in
        --help) show_help ;;
        --all)
            run_installer dotfiles-hyprland
            run_installer dotfiles-shell
            run_installer dotfiles-editors
            ;;
        --hyprland) run_installer dotfiles-hyprland ;;
        --fish|--kitty) run_installer dotfiles-shell ;;
        --nvim) run_installer dotfiles-editors ;;
        *)
            show_help >&2
            [ -n "${1:-}" ] && err "Unknown flag: $1" && exit 1
            exit 0
            ;;
    esac
}

main "$@"