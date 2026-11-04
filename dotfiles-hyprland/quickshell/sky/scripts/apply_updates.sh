#!/usr/bin/env bash
# Runs the system updaters in order: cachy-update, then brew update + upgrade.
# Launched in its own terminal by UpdateService.applyAll().

brew_bin="$(command -v brew || true)"
[ -z "$brew_bin" ] && [ -x /home/linuxbrew/.linuxbrew/bin/brew ] && brew_bin=/home/linuxbrew/.linuxbrew/bin/brew

cachy-update

if [ -n "$brew_bin" ]; then
    "$brew_bin" update && "$brew_bin" upgrade
fi

echo
read -rp "Press Enter to close..."
