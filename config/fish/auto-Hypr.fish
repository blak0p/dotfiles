# Auto start Hyprland on tty1
# Skip in bunker (distrobox) — no display manager there
if set -q BUNKER
    return
end
if test -z "$DISPLAY" ;and test "$XDG_VTNR" -eq 1
    mkdir -p ~/.cache
    exec start-hyprland > ~/.cache/hyprland.log 2>&1
end
