#!/usr/bin/env bash
# install.sh — Dependencias del dotfiles
# Orden: brew → pacman → flatpak → aviso manual
set -euo pipefail

DEPS_DIR="$(cd "$(dirname "$0")" && pwd)"
BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${BLUE}ℹ️${NC} $1"; }
ok()    { echo -e "${GREEN}✅${NC} $1"; }
warn()  { echo -e "${YELLOW}⚠️${NC} $1"; }
err()   { echo -e "${RED}❌${NC} $1"; }

HAVE_BREW=false
command -v brew &>/dev/null && HAVE_BREW=true

echo "═══════════════════════════════════════════"
echo "  📦 Dependencias"
echo "═══════════════════════════════════════════"
echo ""

# ─── 1. Homebrew ───
if $HAVE_BREW; then
    echo "🍺 Homebrew"
    while IFS= read -r pkg; do
        [[ "$pkg" =~ ^#.*$ || -z "$pkg" ]] && continue
        if brew list "$pkg" &>/dev/null; then
            ok "$pkg ya instalado"
        else
            info "Instalando $pkg..."
            brew install "$pkg" 2>/dev/null && ok "$pkg" || warn "Falló brew: $pkg"
        fi
    done < "$DEPS_DIR/brew.txt"
else
    warn "Homebrew no instalado. Los paquetes brew se instalarán con pacman si están disponibles."
fi

# ─── 2. Pacman (solo lo que no instaló brew) ───
echo ""
echo "📦 Pacman"
while IFS= read -r pkg; do
    [[ "$pkg" =~ ^#.*$ || -z "$pkg" ]] && continue
    if pacman -Q "$pkg" &>/dev/null; then
        ok "$pkg ya instalado"
    else
        info "Instalando $pkg..."
        sudo pacman -S --noconfirm --needed "$pkg" 2>/dev/null && ok "$pkg" || warn "Falló pacman: $pkg (tal vez AUR)"
    fi
done < "$DEPS_DIR/pacman.txt"

# ─── 3. AUR (paru) ───
echo ""
echo "🏗️  AUR (paru)"
AUR_PKGS=(
    # caelestia removido
    "qtengine-git"
    "zen-browser-bin"
    "spicetify-cli-git"
    "spicetify-marketplace-bin"
    "equibop-bin"
    "carapace-bin"
    "darkly-bin"
)
for pkg in "${AUR_PKGS[@]}"; do
    if pacman -Q "$pkg" &>/dev/null; then
        ok "$pkg ya instalado"
    else
        info "Instalando $pkg desde AUR..."
        paru -S --noconfirm --needed "$pkg" 2>/dev/null && ok "$pkg" || warn "Falló paru: $pkg"
    fi
done

# ─── 4. Flatpak ───
echo ""
echo "📦 Flatpak"
FLATPAK_APPS=(
    "org.prismlauncher.PrismLauncher"
    "com.steamgriddb.steam-rom-manager"
    "io.github.kolunmi.Bazaar"
    "com.github.tchx84.Flatseal"
)
for app in "${FLATPAK_APPS[@]}"; do
    if flatpak list 2>/dev/null | grep -q "$app"; then
        ok "$app ya instalado"
    else
        info "Instalando $app..."
        flatpak install -y flathub "$app" 2>/dev/null && ok "$app" || warn "Falló flatpak: $app"
    fi
done

echo ""
echo "═══════════════════════════════════════════"
echo "  ✅ Dependencias listas"
echo "═══════════════════════════════════════════"
