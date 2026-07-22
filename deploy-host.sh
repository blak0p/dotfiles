#!/usr/bin/env bash
# deploy-host.sh — Deploy dotfiles sub-repos to the current $HOME.
# Run from the host (not inside a container).
# Usage: bash deploy-host.sh
# Or:    curl -sL .../deploy-host.sh | bash

DOTFILES_PARENT="$HOME/dev"
DOTFILES_DIR="$DOTFILES_PARENT/dotfiles"
REPO_OWNER="blak0p"
REPOS=("dotfiles-hyprland" "dotfiles-shell" "dotfiles-editors")

log() { echo "==> $*"; }
err() { echo "ERR: $*" >&2; exit 1; }

[ -d "$HOME" ] || err "HOME no apunta a un directorio válido"
mkdir -p "$DOTFILES_PARENT"
cd "$DOTFILES_PARENT"

if [ ! -d "$DOTFILES_DIR" ]; then
    log "Cloning umbrella to $DOTFILES_DIR"
    git clone "git@github.com:$REPO_OWNER/dotfiles.git" "$DOTFILES_DIR"
else
    log "Umbrella already cloned at $DOTFILES_DIR — pulling latest"
    (cd "$DOTFILES_DIR" && git pull --ff-only)
fi

cd "$DOTFILES_DIR"
log "Initializing submodules"
git submodule update --init --recursive

for repo in "${REPOS[@]}"; do
    if [ -f "$repo/install.sh" ]; then
        log "Running $repo/install.sh"
        bash "$repo/install.sh"
    else
        echo "WARN: $repo/install.sh not found, skipping"
    fi
done

log "Verifying symlinks"
for s in fish starship.toml atuin carapace fastfetch kitty nvim \
         hypr waybar quickshell fuzzel gtk-3.0 gtk-4.0 xsettingsd \
         systemd btop cava; do
    if [ -L "$HOME/.config/$s" ]; then
        echo "  OK   $s -> $(readlink "$HOME/.config/$s")"
    else
        echo "  MISS $s"
    fi
done

log "Done"
