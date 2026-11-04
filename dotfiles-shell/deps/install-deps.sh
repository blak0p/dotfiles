#!/usr/bin/env bash
# install-deps.sh — Install domain packages using the system package manager.
# Auto-detects: Arch (pacman/paru/yay), Fedora (dnf), or Debian/Ubuntu (apt).
# Usage: bash deps/install-deps.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info() { echo -e "${BLUE}ℹ${NC} $1"; }
ok()   { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
err()  { echo -e "${RED}✗${NC} $1"; }

detect_pm() {
    if command -v pacman >/dev/null 2>&1; then echo "pacman"
    elif command -v dnf >/dev/null 2>&1 || command -v dnf5 >/dev/null 2>&1; then echo "dnf"
    elif command -v apt >/dev/null 2>&1; then echo "apt"
    else echo "unknown"
    fi
}

detect_aur_helper() {
    if command -v paru >/dev/null 2>&1; then echo "paru"
    elif command -v yay >/dev/null 2>&1; then echo "yay"
    else echo ""
    fi
}

install_arch() {
    local list="$SCRIPT_DIR/packages.txt"
    [ ! -f "$list" ] && { err "$list not found"; exit 1; }

    local aur_helper
    aur_helper="$(detect_aur_helper)"

    if [ -n "$aur_helper" ]; then
        info "Using AUR helper: $aur_helper"
        grep -vE '^\s*(#|$)' "$list" | xargs "$aur_helper" -S --needed --noconfirm
        # Install AUR packages
        info "Installing AUR packages (carapace-bin)..."
        "$aur_helper" -S --needed --noconfirm carapace-bin || warn "Failed to install carapace-bin via $aur_helper"
    else
        info "No AUR helper detected. Installing official packages with pacman..."
        grep -vE '^\s*(#|$)' "$list" | xargs sudo pacman -S --needed --noconfirm
        warn "carapace-bin requires an AUR helper (paru or yay). Install yay/paru or install carapace manually."
    fi
}

install_fedora() {
    local list="$SCRIPT_DIR/packages.dnf.txt"
    [ ! -f "$list" ] && { err "$list not found"; exit 1; }

    info "Installing official Fedora packages..."
    grep -vE '^\s*(#|$)' "$list" | xargs sudo dnf install -y

    # Starship on Fedora (available via COPR)
    if ! command -v starship >/dev/null 2>&1; then
        info "Enabling COPR repository atim/starship for starship..."
        if sudo dnf copr enable -y atim/starship 2>/dev/null && sudo dnf install -y starship; then
            ok "Installed starship via COPR"
        else
            warn "Failed to install starship via COPR. Installing via official installer script..."
            mkdir -p "$HOME/.local/bin"
            curl -sS https://starship.rs/install.sh | sh -s -- -y --bin-dir "$HOME/.local/bin" || warn "Could not install starship automatically."
        fi
    else
        ok "starship is already installed"
    fi

    # Carapace check
    if ! command -v carapace >/dev/null 2>&1; then
        warn "carapace is not in standard Fedora repositories. You can install it via Homebrew ('brew install carapace') or GitHub releases (https://github.com/carapace-sh/carapace-bin/releases)."
    fi
}

install_debian() {
    local list="$SCRIPT_DIR/packages.apt.txt"
    [ ! -f "$list" ] && { err "$list not found"; exit 1; }

    info "Updating apt cache and installing Debian/Ubuntu packages..."
    sudo apt update -y
    grep -vE '^\s*(#|$)' "$list" | xargs sudo apt install -y

    # Compatibility symlinks for Debian package name differences
    mkdir -p "$HOME/.local/bin"
    if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
        ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
        ok "Created symlink ~/.local/bin/bat -> $(command -v batcat)"
    fi
    if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
        ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
        ok "Created symlink ~/.local/bin/fd -> $(command -v fdfind)"
    fi

    # Starship on Debian/Ubuntu
    if ! command -v starship >/dev/null 2>&1; then
        info "Installing starship via official installer script..."
        curl -sS https://starship.rs/install.sh | sh -s -- -y --bin-dir "$HOME/.local/bin" || warn "Could not install starship automatically."
    fi

    # Atuin check
    if ! command -v atuin >/dev/null 2>&1; then
        warn "atuin is not in standard Debian/Ubuntu repos. Install via: curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh"
    fi

    # Fastfetch check
    if ! command -v fastfetch >/dev/null 2>&1; then
        warn "fastfetch not found in default repos. On Ubuntu: sudo add-apt-repository -y ppa:zhangsongcui3371/fastfetch && sudo apt install -y fastfetch"
    fi

    # Carapace check
    if ! command -v carapace >/dev/null 2>&1; then
        warn "carapace is not in default Debian/Ubuntu repos. Install .deb from https://github.com/carapace-sh/carapace-bin/releases"
    fi
}

setup_fish_plugins() {
    if command -v fish >/dev/null 2>&1; then
        info "Checking Fish plugin manager..."
        # If fisher is not installed, bootstrap it
        # shellcheck disable=SC2016
        fish -c '
            if not functions -q fisher; and not test -f "$__fish_config_dir/functions/fisher.fish"
                curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher
            end
        ' 2>/dev/null || true
        ok "Fish environment and plugins ready"
    else
        warn "Fish is not installed yet; skipping Fish plugin setup"
    fi
}

main() {
    local pm
    pm="$(detect_pm)"
    info "Detected package manager: $pm"

    case "$pm" in
        pacman) install_arch ;;
        dnf)    install_fedora ;;
        apt)    install_debian ;;
        *)
            err "No supported package manager found (need pacman, dnf, or apt)"
            exit 1
            ;;
    esac

    setup_fish_plugins
    ok "Dependencies installation finished successfully for dotfiles-shell."
}

main

