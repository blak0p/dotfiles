#!/usr/bin/env bash
# install-deps.sh — Install domain packages using the system package manager.
# Auto-detects: Arch (pacman + paru/yay for AUR), Fedora (dnf/dnf5), or Debian/Ubuntu (apt).
# Usage: bash deps/install-deps.sh
set -eEuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${BLUE}ℹ${NC} $1"; }
ok()    { echo -e "${GREEN}✓${NC} $1"; }
warn()  { echo -e "${YELLOW}⚠${NC} $1"; }
err()   { echo -e "${RED}✗${NC} $1"; }

detect_pm() {
    if command -v pacman >/dev/null 2>&1; then
        echo "pacman"
    elif command -v dnf5 >/dev/null 2>&1; then
        echo "dnf5"
    elif command -v dnf >/dev/null 2>&1; then
        echo "dnf"
    elif command -v apt >/dev/null 2>&1 || command -v apt-get >/dev/null 2>&1; then
        echo "apt"
    else
        echo "unknown"
    fi
}

install_arch() {
    local list="$SCRIPT_DIR/packages.txt"
    [ ! -f "$list" ] && { err "Package list not found: $list"; exit 1; }

    if command -v paru >/dev/null 2>&1; then
        info "AUR helper 'paru' detected. Installing official and AUR packages..."
        grep -vE '^\s*(#|$)' "$list" | xargs paru -S --needed
        ok "Arch packages installed successfully via paru"
    elif command -v yay >/dev/null 2>&1; then
        info "AUR helper 'yay' detected. Installing official and AUR packages..."
        grep -vE '^\s*(#|$)' "$list" | xargs yay -S --needed
        ok "Arch packages installed successfully via yay"
    else
        warn "No AUR helper (paru/yay) detected. Filtering official repository packages..."
        local official_pkgs=()
        local aur_pkgs=()

        while IFS= read -r pkg; do
            [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue
            if pacman -Si "$pkg" >/dev/null 2>&1; then
                official_pkgs+=("$pkg")
            else
                aur_pkgs+=("$pkg")
            fi
        done < "$list"

        if [ "${#official_pkgs[@]}" -gt 0 ]; then
            info "Installing official repository packages via pacman..."
            sudo pacman -S --needed "${official_pkgs[@]}"
            ok "Official packages installed"
        fi

        if [ "${#aur_pkgs[@]}" -gt 0 ]; then
            warn "The following packages require an AUR helper (paru or yay) to install:"
            for ap in "${aur_pkgs[@]}"; do
                echo "    - $ap"
            done
            warn "Install paru (https://github.com/Morganamilo/paru) or yay (https://github.com/Jguer/yay) and rerun this script."
        fi
    fi
}

install_fedora() {
    local dnf_cmd="$1"
    local list="$SCRIPT_DIR/packages.dnf.txt"
    [ ! -f "$list" ] && { err "Package list not found: $list"; exit 1; }

    info "Installing Fedora packages via $dnf_cmd..."
    grep -vE '^\s*(#|$)' "$list" | xargs sudo "$dnf_cmd" install -y
    ok "Fedora packages installed successfully"
}

install_debian() {
    local list="$SCRIPT_DIR/packages.apt.txt"
    [ ! -f "$list" ] && { err "Package list not found: $list"; exit 1; }

    info "Installing Debian/Ubuntu packages via apt..."
    grep -vE '^\s*(#|$)' "$list" | xargs sudo apt install -y
    ok "Debian/Ubuntu packages installed successfully"
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
            err "No supported package manager found (need pacman, dnf, dnf5, or apt)"
            exit 1
            ;;
    esac
}

main "$@"
