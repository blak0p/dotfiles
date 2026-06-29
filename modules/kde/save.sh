#!/bin/bash
# KDE Plasma — guarda configs actuales en dotfiles
KDE_DIR="$HOME/dev/dotfiles/modules/kde/config"

for f in kglobalshortcutsrc plasma-org.kde.plasma.desktop-appletsrc kwinrc kwinrulesrc kcminputrc kdeglobals konsolerc konsolesshconfig; do
    cp "$HOME/.config/$f" "$KDE_DIR/"
    echo "  ✅ Guardado: $f"
done

echo ""
echo "✅ KDE configs sincronizadas con dotfiles. Hacé git add + commit."
