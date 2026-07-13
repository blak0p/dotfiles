#!/usr/bin/env bash
# install.sh — Módulo Gaming
set -euo pipefail

echo "═══════════════════════════════════════════"
echo "  🎮 Módulo Gaming"
echo "═══════════════════════════════════════════"

echo ""
echo "  ── Steam autopicture service ──"

systemctl --user daemon-reload
systemctl --user enable --now steam-autopicture.service

echo "   ✅ steam-autopicture.service activado"

echo ""
echo "═══════════════════════════════════════════"
echo "  ✅ Módulo Gaming completado"
echo "═══════════════════════════════════════════"
