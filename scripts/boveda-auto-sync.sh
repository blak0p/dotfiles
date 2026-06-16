#!/bin/bash
# Auto-sync Boveda: debounce 2 min, commit + push if there are changes
LOCK_FILE="/tmp/boveda-auto-sync.lock"
exec 9>"$LOCK_FILE"
flock -n 9 || exit 0  # ya hay uno corriendo, salir

sleep 120  # debounce — esperar 2 min desde el último cambio

cd "$HOME/dev/Boveda" 2>/dev/null || exit 1

git add -A

if git diff --cached --quiet; then
    exit 0  # nada nuevo
fi

# Intentar usar el título del archivo modificado si es único
CHANGED=$(git diff --cached --name-only --diff-filter=AM)
if [ "$(echo "$CHANGED" | wc -l)" -eq 1 ] && [[ "$CHANGED" == *.md ]]; then
    TITLE=$(head -1 "$CHANGED" | sed -n 's/^# //p')
    if [ -n "$TITLE" ]; then
        git commit -m "vault: $TITLE"
        git push origin main 2>/dev/null
        exit 0
    fi
fi

git commit -m "vault backup: $(date '+%Y-%m-%d %H:%M')"
git push origin main 2>/dev/null
exit 0
