#!/bin/bash
# KDE Plasma — restaura configs desde dotfiles
DOTFILES_DIR="$HOME/dev/dotfiles"
BACKUP_DIR="$DOTFILES_DIR/backups/$(date +%Y%m%d_%H%M%S)"

echo "📦 Backup de configs KDE actuales en $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

for f in kglobalshortcutsrc plasma-org.kde.plasma.desktop-appletsrc kwinrc kwinrulesrc kcminputrc kdeglobals konsolerc konsolesshconfig; do
    src="$DOTFILES_DIR/modules/kde/config/$f"
    dst="$HOME/.config/$f"

    if [ -f "$dst" ]; then
        cp "$dst" "$BACKUP_DIR/"
    fi

    cp "$src" "$dst"
    echo "  ✅ Restaurado: $f"
done

echo ""
echo "✅ KDE configs restauradas. Cerrá sesión y volvé a entrar para aplicar."
