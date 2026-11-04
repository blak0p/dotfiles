#!/usr/bin/env bash
# install-deps.sh — Install editor domain dependencies using the system package manager.
# Auto-detects: Arch (pacman/paru/yay), Fedora (dnf/dnf5), or Debian/Ubuntu (apt).
# Usage: bash deps/install-deps.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color formatting helpers
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info() { echo -e "${BLUE}ℹ${NC} $*"; }
ok()   { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
err()  { echo -e "${RED}✗${NC} $*" >&2; }

detect_pm() {
    if command -v pacman >/dev/null 2>&1; then echo "pacman"
    elif command -v dnf5 >/dev/null 2>&1; then echo "dnf5"
    elif command -v dnf >/dev/null 2>&1; then echo "dnf"
    elif command -v apt >/dev/null 2>&1 || command -v apt-get >/dev/null 2>&1; then echo "apt"
    else echo "unknown"
    fi
}

install_arch() {
    local list="$SCRIPT_DIR/packages.txt"
    [ ! -f "$list" ] && { err "$list not found"; exit 1; }

    # Parse package list removing comments and blank lines
    mapfile -t pkgs < <(grep -vE '^\s*(#|$)' "$list")
    [ ${#pkgs[@]} -eq 0 ] && { warn "No packages to install in $list"; return 0; }

    info "Installing Arch Linux / AUR packages..."
    if command -v paru >/dev/null 2>&1; then
        info "Detected paru AUR helper. Using: paru -S --needed"
        paru -S --needed "${pkgs[@]}"
    elif command -v yay >/dev/null 2>&1; then
        info "Detected yay AUR helper. Using: yay -S --needed"
        yay -S --needed "${pkgs[@]}"
    else
        warn "Neither paru nor yay found. Falling back to pacman (AUR packages will need manual installation)."
        sudo pacman -S --needed "${pkgs[@]}"
    fi
    ok "Arch package installation complete."
}

install_fedora() {
    local pm="$1"
    local list="$SCRIPT_DIR/packages.dnf.txt"
    [ ! -f "$list" ] && { err "$list not found"; exit 1; }

    mapfile -t pkgs < <(grep -vE '^\s*(#|$)' "$list")
    [ ${#pkgs[@]} -eq 0 ] && { warn "No packages to install in $list"; return 0; }

    info "Installing Fedora packages via $pm..."
    if ! sudo "$pm" install -y "${pkgs[@]}"; then
        warn "Batch installation with $pm encountered missing packages. Installing available packages individually..."
        for pkg in "${pkgs[@]}"; do
            if sudo "$pm" install -y "$pkg" 2>/dev/null; then
                ok "Installed $pkg"
            elif [ "$pkg" = "lazygit" ]; then
                warn "lazygit not found in standard repos. Trying COPR repository 'atim/lazygit'..."
                if sudo "$pm" copr enable -y atim/lazygit && sudo "$pm" install -y lazygit; then
                    ok "Installed lazygit from COPR"
                else
                    warn "Could not install lazygit via COPR. Please install manually from GitHub releases."
                fi
            else
                warn "Could not install $pkg via $pm."
            fi
        done
    fi
    ok "Fedora package installation complete."
}

install_debian() {
    local list="$SCRIPT_DIR/packages.apt.txt"
    [ ! -f "$list" ] && { err "$list not found"; exit 1; }

    mapfile -t pkgs < <(grep -vE '^\s*(#|$)' "$list")
    [ ${#pkgs[@]} -eq 0 ] && { warn "No packages to install in $list"; return 0; }

    info "Updating APT package indices..."
    sudo apt-get update -y

    info "Installing Debian/Ubuntu packages via apt..."
    if ! sudo apt-get install -y "${pkgs[@]}"; then
        warn "Batch apt install encountered missing packages. Installing available packages individually..."
        for pkg in "${pkgs[@]}"; do
            if sudo apt-get install -y "$pkg"; then
                ok "Installed $pkg"
            else
                warn "Could not install $pkg via apt (may require PPA, newer distro release, or manual install)"
            fi
        done
    fi

    # Set up fd alias/symlink if fd-find provides fdfind instead of fd
    if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
        info "Creating 'fd' symlink for 'fdfind' in ~/.local/bin..."
        mkdir -p "$HOME/.local/bin"
        ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
        ok "Symlinked $(command -v fdfind) -> $HOME/.local/bin/fd"
    fi

    ok "Debian/Ubuntu package installation complete."
}

main() {
    local pm
    pm="$(detect_pm)"
    info "Detected package manager: $pm"

    case "$pm" in
        pacman)
            install_arch
            ;;
        dnf|dnf5)
            install_fedora "$pm"
            ;;
        apt)
            install_debian
            ;;
        *)
            err "No supported package manager found (need pacman, dnf/dnf5, or apt)"
            exit 1
            ;;
    esac

    ok "All editor domain dependencies processed successfully!"
}

main "$@"
