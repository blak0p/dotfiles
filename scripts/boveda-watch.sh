#!/bin/bash
# Boveda watcher: inotifywait bloquea en kernel, 0 CPU en idle.
# Debounce: 60s sin cambios -> commit + push.
VAULT="$HOME/dev/Boveda"
cd "$VAULT" || exit 1

inotifywait -m -r -e close_write,moved_to,moved_from,delete,delete_self --format '%w%f' "$VAULT" \
  --exclude '(.git|\.trash|\.obsidian/cache)' \
| while IFS= read -r file; do
    [[ "$file" != *.md && "$file" != *.png && "$file" != *.jpg && "$file" != *.pdf ]] && continue

    # Debounce: acumula eventos hasta 60s de silencio
    while IFS= read -t 60 -r next_file; do
      [[ "$next_file" != *.md && "$next_file" != *.png && "$next_file" != *.jpg && "$next_file" != *.pdf ]] && continue
    done

    git add -A
    git diff --cached --quiet && continue

    COUNT=$(git diff --cached --name-only --diff-filter=AM | wc -l)
    CHANGED=$(git diff --cached --name-only --diff-filter=AM | head -1)
    if [ "$COUNT" -eq 1 ] && [ -n "$CHANGED" ]; then
      HEADING=$(head -1 "$CHANGED" 2>/dev/null | sed -n 's/^# //p')
      if [ -n "$HEADING" ]; then
        git commit -m "vault: $HEADING"
      else
        git commit -m "vault: $CHANGED"
      fi
    elif [ "$COUNT" -gt 1 ]; then
      git commit -m "vault: +$COUNT archivos"
    else
      git commit -m "vault backup: $(date '+%Y-%m-%d %H:%M')"
    fi

    git push origin main 2>/dev/null || {
      sleep 2
      git pull --rebase origin main 2>/dev/null
      git push origin main 2>/dev/null
    }
done
