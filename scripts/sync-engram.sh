#!/usr/bin/env bash
# sync-engram.sh — Exporta memorias de engram al repo y hace commit+push
#
# Uso:
#   ./scripts/sync-engram.sh              # sync + commit + push
#   ./scripts/sync-engram.sh --dry-run    # muestra qué se va a hacer sin ejecutar
#   ./scripts/sync-engram.sh --no-push    # sync + commit, sin push
#
# ¿Por qué existe?
#   El container (distrobox) es efímero. Si se borra, perdés el engram DB.
#   Este script exporta TODAS las memorias a .engram/chunks/ (portable),
#   las commitea al repo de dotfiles (bind-mount desde el host) y las
#   pushea a GitHub. Así sobreviven al container.

set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"
DRY_RUN=false
NO_PUSH=false

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --no-push) NO_PUSH=true ;;
        *) echo "❌ Argumento desconocido: $arg"; exit 1 ;;
    esac
done

cd "$DOTFILES"

# ── 1. Engram sync ──────────────────────────────────────────────
echo "📦 Exportando memorias de engram..."
if $DRY_RUN; then
    echo "  → engram sync --all (exportaría a .engram/chunks/)"
else
    engram sync --all
fi

# ── 2. Verificar si hay cambios ─────────────────────────────────
if git diff --quiet -- .engram/ && git diff --cached --quiet -- .engram/; then
    echo "✅ No hay cambios nuevos en .engram/ — nada que commitear"
    exit 0
fi

# ── 3. Commit ────────────────────────────────────────────────────
TIMESTAMP="$(date '+%Y-%m-%d %H:%M')"
MSG="sync engram memories — $TIMESTAMP"

echo "📝 Commiteando: $MSG"
if $DRY_RUN; then
    echo "  → git add .engram/"
    echo "  → git commit -m \"$MSG\""
else
    git add .engram/
    git commit -m "$MSG"
fi

# ── 4. Push ──────────────────────────────────────────────────────
if $NO_PUSH; then
    echo "⏭️  Push omitido (--no-push)"
else
    echo "⬆️  Pusheando a origin..."
    if $DRY_RUN; then
        echo "  → git push origin master"
    else
        git push origin master
        echo "✅ Push completado"
    fi
fi

echo "✨ Hecho — memorias respaldadas en dotfiles"
