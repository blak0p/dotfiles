#!/usr/bin/env bash
# doctor.sh — Diagnóstico del dotfiles
# Verifica symlinks por dominio (host, bunker, shared).
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
ok=0; warn=0; err=0

# Per-domain counters
declare -A domain_ok domain_warn domain_err

check() {
    if [ -e "$1" ]; then
        if [ -L "$1" ]; then
            local target=$(readlink -f "$1" 2>/dev/null || readlink "$1")
            local expected=$(readlink -f "$2" 2>/dev/null || echo "$2")
            # Strip /run/host/ prefix for distrobox bind-mount compatibility
            target="${target#/run/host}"
            expected="${expected#/run/host}"
            if [ "$target" = "$expected" ]; then
                echo -e "  ${GREEN}✓${NC} $1"
                ok=$((ok+1)); domain_ok[${3:-shared}]=$(( ${domain_ok[${3:-shared}]:-0} + 1 ))
            else
                echo -e "  ${YELLOW}~${NC} $1 → $target (esperado: $2)"
                warn=$((warn+1)); domain_warn[${3:-shared}]=$(( ${domain_warn[${3:-shared}]:-0} + 1 ))
            fi
        else
            echo -e "  ${YELLOW}~${NC} $1 existe pero no es symlink"
            warn=$((warn+1)); domain_warn[${3:-shared}]=$(( ${domain_warn[${3:-shared}]:-0} + 1 ))
        fi
    else
        echo -e "  ${RED}✗${NC} $1 no existe"
        err=$((err+1)); domain_err[${3:-shared}]=$(( ${domain_err[${3:-shared}]:-0} + 1 ))
    fi
}

# Verify all symlinks in {domain}/config/ and {domain}/scripts/ resolve
# to their expected targets under root config/ and scripts/.
verify_domain() {
    local domain="$1"
    local dcfg="$DOTFILES_DIR/$domain/config"
    local dscripts="$DOTFILES_DIR/$domain/scripts"

    echo "🖥️  Dominio: $domain"
    if [ -d "$dcfg" ]; then
        for entry in "$dcfg"/*; do
            [ -e "$entry" ] || continue
            local name=$(basename "$entry")
            check "$HOME/.config/$name" "$entry" "$domain"
        done
    else
        echo -e "  ${YELLOW}~${NC} $dcfg no existe (dominio no deployado)"
    fi
    if [ -d "$dscripts" ]; then
        for f in "$dscripts"/*; do
            [ -e "$f" ] || continue
            check "$HOME/scripts/$(basename "$f")" "$f" "$domain"
        done
    fi
    echo ""
}

# Verify shared configs (nvim, ghostty, starship.toml, fish, fastfetch)
verify_shared() {
    local shared=(nvim ghostty fish fastfetch)
    echo "📁 Shared configs (~/.config/):"
    for name in "${shared[@]}"; do
        [ -e "$DOTFILES_DIR/config/$name" ] && \
            check "$HOME/.config/$name" "$DOTFILES_DIR/config/$name" "shared"
    done
    for f in "$DOTFILES_DIR/config"/starship.toml; do
        [ -f "$f" ] && check "$HOME/.config/$(basename "$f")" "$f" "shared"
    done
    echo ""
}

# Verify host-only hardware files (present in repo, not symlinks)
verify_host_files() {
    echo "🖥️  Host config files (host/personal-pc/):"
    if [ -f "$DOTFILES_DIR/host/personal-pc/audio.sh" ]; then echo -e "  ${GREEN}✓${NC} host/personal-pc/audio.sh" && ok=$((ok+1)); else echo -e "  ${YELLOW}~${NC} Falta host/personal-pc/audio.sh" && warn=$((warn+1)); fi
    if [ -f "$DOTFILES_DIR/host/personal-pc/monitors.lua" ]; then echo -e "  ${GREEN}✓${NC} host/personal-pc/monitors.lua" && ok=$((ok+1)); else echo -e "  ${YELLOW}~${NC} Falta host/personal-pc/monitors.lua" && warn=$((warn+1)); fi
    echo ""
}

show_help() {
    echo "Dotfiles Doctor"
    echo ""
    echo "Uso:"
    echo "  ./doctor.sh --host       — Verificar dominio host + shared"
    echo "  ./doctor.sh --bunker     — Verificar dominio bunker + shared"
    echo "  ./doctor.sh --all        — Verificar todo (host + bunker + shared)"
    echo "  ./doctor.sh --help       — Esta ayuda"
    echo "  ./doctor.sh              — Verificar dominios presentes"
}

# ─── Main ─────────────────────────────────────────────────────────
echo "═══════════════════════════════════════════"
echo "  🔍 Doctor — Dotfiles"
echo "═══════════════════════════════════════════"
echo ""

case "${1:-}" in
    --help|-h) show_help; exit 0 ;;
    --host)
        verify_shared
        verify_domain host
        verify_host_files
        ;;
    --bunker)
        verify_shared
        verify_domain bunker
        ;;
    --all)
        verify_shared
        verify_domain host
        verify_domain bunker
        verify_host_files
        ;;
    *)
        # No flag: verify all domains that have deploy markers
        verify_shared
        [ -d "$DOTFILES_DIR/host/config" ] && verify_domain host && verify_host_files
        [ -d "$DOTFILES_DIR/bunker/config" ] && verify_domain bunker
        ;;
esac

# ─── Resumen ───
echo "═══════════════════════════════════════════"
for d in shared host bunker; do
    [ -z "${domain_ok[$d]:-}" ] && [ -z "${domain_warn[$d]:-}" ] && [ -z "${domain_err[$d]:-}" ] && continue
    printf "  %s: ${GREEN}%s OK${NC}, ${YELLOW}%s advertencias${NC}, ${RED}%s errores${NC}\n" \
        "$d" "${domain_ok[$d]:-0}" "${domain_warn[$d]:-0}" "${domain_err[$d]:-0}"
done
echo -e "  Total: ${GREEN}$ok correctos${NC}, ${YELLOW}$warn advertencias${NC}, ${RED}$err errores${NC}"
echo "═══════════════════════════════════════════"

exit $(( err > 0 ? 1 : 0 ))