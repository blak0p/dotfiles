#!/usr/bin/env bash
# doctor.sh — Diagnóstico del dotfiles
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
ok=0; warn=0; err=0

check() {
    if [ -e "$1" ]; then
        if [ -L "$1" ]; then
            local target=$(readlink "$1")
            if [ "$target" = "$2" ]; then
                echo -e "  ${GREEN}✓${NC} $1"
                ok=$((ok+1))
            else
                echo -e "  ${YELLOW}~${NC} $1 → $target (esperado: $2)"
                warn=$((warn+1))
            fi
        else
            echo -e "  ${YELLOW}~${NC} $1 existe pero no es symlink"
            warn=$((warn+1))
        fi
    else
        echo -e "  ${RED}✗${NC} $1 no existe"
        err=$((err+1))
    fi
}

echo "═══════════════════════════════════════════"
echo "  🔍 Doctor — Dotfiles"
echo "═══════════════════════════════════════════"
echo ""

# ─── Config symlinks ───
echo "📁 Config symlinks (~/.config/):"
for dir in "$DOTFILES_DIR/config"/*/; do
    name=$(basename "$dir")
    check "$HOME/.config/$name" "$DOTFILES_DIR/config/$name"
done
for f in "$DOTFILES_DIR/config"/starship.toml; do
    [ -f "$f" ] && check "$HOME/.config/$(basename "$f")" "$f"
done
echo ""

# ─── Script symlinks ───
echo "📜 Script symlinks (~/scripts/):"
for f in "$DOTFILES_DIR/scripts"/*; do
    [ -f "$f" ] && check "$HOME/scripts/$(basename "$f")" "$f"
done
echo ""

# ─── Host config ───
echo "🖥️  Host config:"
if [ -f "$DOTFILES_DIR/host/personal-pc/audio.sh" ]; then echo -e "  ${GREEN}✓${NC} host/personal-pc/audio.sh" && ok=$((ok+1)); else echo -e "  ${YELLOW}~${NC} Falta host/personal-pc/audio.sh" && warn=$((warn+1)); fi
if [ -f "$DOTFILES_DIR/host/personal-pc/monitors.lua" ]; then echo -e "  ${GREEN}✓${NC} host/personal-pc/monitors.lua" && ok=$((ok+1)); else echo -e "  ${YELLOW}~${NC} Falta host/personal-pc/monitors.lua" && warn=$((warn+1)); fi
echo ""

# ─── Resumen ───
echo "═══════════════════════════════════════════"
echo -e "  ${GREEN}$ok correctos${NC}, ${YELLOW}$warn advertencias${NC}, ${RED}$err errores${NC}"
echo "═══════════════════════════════════════════"

exit $(( err > 0 ? 1 : 0 ))
