#!/usr/bin/env bash
# install.sh — Módulo Hardware: Deepcool AK620
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "═══════════════════════════════════════════"
echo "  🖥️  Módulo Hardware"
echo "═══════════════════════════════════════════"

# ─── Python dependencies ───
echo ""
echo "  ── Deepcool AK620 dependencies ──"

if command -v pip &> /dev/null; then
    pip install --user -r "$SCRIPT_DIR/deepcool-ak620/requirements.txt"
    echo "   ✅ Dependencias Python instaladas"
else
    echo "   ⚠️  pip no disponible, instalá manualmente:"
    echo "      pip install -r $SCRIPT_DIR/deepcool-ak620/requirements.txt"
fi

# ─── systemd service ───
echo ""
echo "  ── ak620-digital service ──"

SERVICE_SRC="$SCRIPT_DIR/systemd/ak620-digital.service"
SERVICE_DST="$HOME/.config/systemd/user/ak620-digital.service"

mkdir -p "$HOME/.config/systemd/user"
cp "$SERVICE_SRC" "$SERVICE_DST"
systemctl --user daemon-reload
systemctl --user enable --now ak620-digital.service

echo "   ✅ ak620-digital.service activado"

echo ""
echo "═══════════════════════════════════════════"
echo "  ✅ Módulo Hardware completado"
echo "═══════════════════════════════════════════"
