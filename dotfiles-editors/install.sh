#!/usr/bin/env bash
# dotfiles-editors installer — symlinks nvim to ~/.config/.
# Run directly (./dotfiles-editors/install.sh) or via the root ./install.sh.
set -eEuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO_ROOT
export DOTFILES_DIR="${DOTFILES_DIR:-$REPO_ROOT}"

BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${BLUE}ℹ${NC} $1"; }
ok()    { echo -e "${GREEN}✓${NC} $1"; }
warn()  { echo -e "${YELLOW}⚠${NC} $1"; }
err()   { echo -e "${RED}✗${NC} $1"; }

deploy_symlink() {
    local src="$1" dst="$2"
    local backup_parent backup_target current
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        if [ ! -L "$dst" ]; then
            warn "Backing up $dst -> $BACKUP_DIR/"
            backup_parent="$BACKUP_DIR/$(dirname "${dst#"$HOME"/}")"
            mkdir -p -- "$backup_parent"
            backup_target="$backup_parent/$(basename "$dst")"
            if [ -e "$backup_target" ] || [ -L "$backup_target" ]; then
                backup_target="$backup_target.$(date +%s%N)"
            fi
            mv -- "$dst" "$backup_target"
        else
            current="$(readlink "$dst")"
            if [ "$current" = "$src" ]; then
                return 0
            fi
            backup_parent="$BACKUP_DIR/$(dirname "${dst#"$HOME"/}")"
            mkdir -p -- "$backup_parent"
            backup_target="$backup_parent/$(basename "$dst").symlink"
            if [ -e "$backup_target" ] || [ -L "$backup_target" ]; then
                backup_target="$backup_target.$(date +%s%N)"
            fi
            ln -s -- "$current" "$backup_target" 2>/dev/null || true
            rm -f -- "$dst"
        fi
    fi
    mkdir -p -- "$(dirname "$dst")"
    ln -sf -- "$src" "$dst"
    ok "Symlink: $dst -> $src"
}

deploy_configs() {
    local entries=(nvim)
    for name in "${entries[@]}"; do
        if [ -e "$REPO_ROOT/$name" ]; then
            deploy_symlink "$REPO_ROOT/$name" "$HOME/.config/$name"
        else
            warn "Source not found, skipping: $REPO_ROOT/$name"
        fi
    done
}

main() {
    info "Deploying dotfiles-editors configs from $REPO_ROOT"
    deploy_configs
    # DOTFILES_SHELL_SPECIFIC_BLOCK
    ok "dotfiles-editors deploy complete"
}

main