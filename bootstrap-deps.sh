#!/usr/bin/env bash
# bootstrap-deps.sh — Install packages for all sub-repos on this system.
# Auto-detects Arch vs Fedora and uses the right packages list.
# Usage: bash bootstrap-deps.sh

set -euo pipefail
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBS=(dotfiles-hyprland dotfiles-shell dotfiles-editors)

for sub in "${SUBS[@]}"; do
    if [ -f "$DOTFILES_DIR/$sub/deps/install-deps.sh" ]; then
        echo "==> $sub/deps/install-deps.sh"
        bash "$DOTFILES_DIR/$sub/deps/install-deps.sh"
    else
        echo "WARN: $sub/deps/install-deps.sh not found, skipping"
    fi
done

echo ""
echo "All domain packages installed."
echo "After this, run bash $DOTFILES_DIR/deploy-host.sh to symlink configs."
