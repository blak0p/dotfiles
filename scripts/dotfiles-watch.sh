#!/bin/bash
# Dotfiles watcher: inotifywait bloquea en kernel, 0 CPU en idle.
# Debounce: 60s sin cambios -> commit + push.
REPO="$HOME/dev/dotfiles"
cd "$REPO" || exit 1

inotifywait -m -r -e close_write,moved_to,moved_from,delete,delete_self --format '%w%f' "$REPO" \
  --exclude '\.git/' \
| while IFS= read -r file; do
    while IFS= read -t 60 -r next_file; do
      :
    done

    git add -A
    git diff --cached --quiet && continue

    git commit -m "auto: sync dotfiles ($(date '+%Y-%m-%d %H:%M'))"
    git push origin master 2>/dev/null || {
      sleep 2
      git pull --rebase origin master 2>/dev/null
      git push origin master 2>/dev/null
    }
done
