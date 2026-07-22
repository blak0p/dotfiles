#!/usr/bin/env bash
# bootstrap-host.sh — One-shot setup for the dotfiles umbrella on a fresh host.
#
# Clones the umbrella + 3 public submodules, then runs each sub-repo installer.
# This is the same as `git clone --recurse-submodules && ./install.sh --all` but
# works for hosts that don't have the umbrella cloned yet.
#
# Usage:
#   bash bootstrap-host.sh              # full setup
#   bash bootstrap-host.sh --no-install  # clone only, don't run installers
#   bash bootstrap-host.sh --dir PATH   # install at PATH instead of ~/dotfiles
#
# Requires: git, bash. Run as the user who will own the configs (NOT root).

set -eEuo pipefail

REPO_OWNER="blak0p"
REPOS=("dotfiles-hyprland" "dotfiles-shell" "dotfiles-editors")
DEFAULT_DIR="$HOME/dotfiles"
INSTALL=true

while [ $# -gt 0 ]; do
    case "$1" in
        --no-install) INSTALL=false ;;
        --dir)        DEFAULT_DIR="$2"; shift ;;
        --owner)      REPO_OWNER="$2"; shift ;;
        -h|--help)
            sed -n '2,12p' "$0"
            exit 0
            ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
    shift
done

DOTFILES_DIR="$DEFAULT_DIR"

if [ -d "$DOTFILES_DIR" ]; then
    echo "ERR: $DOTFILES_DIR already exists. Remove it first or use --dir."
    exit 1
fi

echo "==> Cloning umbrella to $DOTFILES_DIR"
git clone "git@github.com:$REPO_OWNER/dotfiles.git" "$DOTFILES_DIR"
cd "$DOTFILES_DIR"

echo "==> Initializing submodules"
git submodule update --init --recursive

if $INSTALL; then
    for repo in "${REPOS[@]}"; do
        if [ -f "$repo/install.sh" ]; then
            echo "==> Running $repo/install.sh"
            bash "$repo/install.sh"
        else
            echo "WARN: $repo/install.sh not found, skipping"
        fi
    done
    echo ""
    echo "Bootstrap complete."
    echo "Hyprland configs in ~/.config/{hypr,waybar,quickshell,fuzzel,gtk-3.0,gtk-4.0,xsettingsd,systemd,btop,cava}"
    echo "Shell configs in ~/.config/{fish,kitty,fastfetch,atuin,carapace} + ~/.config/starship.toml"
    echo "Editor configs in ~/.config/nvim"
else
    echo ""
    echo "Cloned but did not install. Run ./install.sh --all inside $DOTFILES_DIR when ready."
fi
