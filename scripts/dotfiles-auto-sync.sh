#!/bin/bash
# Auto-sync dotfiles: debounce 2 min, commit + push if there are changes
LOCK_FILE="/tmp/dotfiles-auto-sync.lock"
exec 9>"$LOCK_FILE"
flock -n 9 || exit 0  # ya hay uno corriendo, salir

sleep 120  # debounce — esperar 2 min desde el último cambio

cd "$HOME/dotfiles" 2>/dev/null || exit 1

git add -A

if git diff --cached --quiet; then
    exit 0  # nada nuevo
fi

git commit -m "auto: sync dotfiles ($(date '+%Y-%m-%d %H:%M'))"
git push origin master 2>/dev/null
