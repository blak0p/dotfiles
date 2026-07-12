#!/usr/bin/env bash
# eden-symlinks.sh — Vincula Eden y PrismLauncher al disco Juegos
# Se puede correr en cualquier SO, detecta el disco por LABEL
set -euo pipefail

JUEGOS_LABEL="Juegos"
JUEGOS_MOUNT=""

# ─── Detectar disco Juegos ────────────────────────────────────────
detect_juegos_disk() {
    # Buscar por label en /dev/disk/by-label/
    local by_label="/dev/disk/by-label/$JUEGOS_LABEL"
    if [ -L "$by_label" ]; then
        local device
        device=$(readlink -f "$by_label")
        # Buscar dónde está montado
        JUEGOS_MOUNT=$(findmnt -n -o TARGET "$device" 2>/dev/null || true)
        if [ -n "$JUEGOS_MOUNT" ]; then
            echo "   ✅ Disco Juegos encontrado en: $JUEGOS_MOUNT"
            return 0
        fi
    fi

    # Fallback: buscar en mount points comunes
    for mp in /run/media/system/Juegos /mnt/Juegos /run/media/alejandro/Juegos /media/Juegos; do
        if [ -d "$mp" ] && mountpoint -q "$mp" 2>/dev/null; then
            JUEGOS_MOUNT="$mp"
            echo "   ✅ Disco Juegos encontrado en: $JUEGOS_MOUNT"
            return 0
        fi
    done

    # Fallback: buscar cualquier disco montado con label Juegos
    local found
    found=$(findmnt -n -l -o TARGET,LABEL 2>/dev/null | grep -i "Juegos" | head -1 | awk '{print $1}' || true)
    if [ -n "$found" ]; then
        JUEGOS_MOUNT="$found"
        echo "   ✅ Disco Juegos encontrado en: $JUEGOS_MOUNT"
        return 0
    fi

    echo "   ❌ No se encontró el disco Juegos. Montalo y volvé a correr."
    echo "      Buscá el disco con: lsblk -o NAME,LABEL,FSTYPE,SIZE,MOUNTPOINT"
    return 1
}

# ─── Crear symlinks ───────────────────────────────────────────────
create_symlink() {
    local target="$1"
    local link="$2"
    local name="$3"

    if [ -L "$link" ]; then
        local current
        current=$(readlink "$link")
        if [ "$current" = "$target" ]; then
            echo "   ✅ $name — ya vinculado correctamente"
            return 0
        fi
        echo "   ⚠️  $name — symlink apunta a otro lado ($current), reemplazando..."
        rm "$link"
    elif [ -e "$link" ]; then
        echo "   📦 $name — respaldando directorio local..."
        mv "$link" "${link}.bak.$(date +%Y%m%d-%H%M%S)"
    fi

    mkdir -p "$(dirname "$link")"
    ln -s "$target" "$link"
    echo "   ✅ $name — symlink creado: $link → $target"
}

setup_eden_symlinks() {
    echo ""
    echo "  ── Eden ──"
    create_symlink \
        "$JUEGOS_MOUNT/Emulation/storage/eden" \
        "$HOME/.local/share/eden" \
        "Eden partidas"

    create_symlink \
        "$JUEGOS_MOUNT/Emulation/storage/eden-config" \
        "$HOME/.config/eden" \
        "Eden config"
}

setup_prismlauncher_symlink() {
    echo ""
    echo "  ── PrismLauncher (Minecraft) ──"
    local prism_data="$HOME/.var/app/org.prismlauncher.PrismLauncher/data/PrismLauncher"
    local prism_target="$JUEGOS_MOUNT/minecraft/PrismLauncher-data"

    if [ ! -d "$prism_target" ]; then
        echo "   ⚠️  No se encontró PrismLauncher-data en el disco Juegos"
        echo "      Path esperado: $prism_target"
        echo "      Saltando symlink de PrismLauncher..."
        return
    fi

    create_symlink \
        "$prism_target" \
        "$prism_data" \
        "PrismLauncher datos"
}

# ─── Main ─────────────────────────────────────────────────────────
main() {
    echo "═══════════════════════════════════════════"
    echo "  🎮 Symlinks — Disco Juegos"
    echo "═══════════════════════════════════════════"

    if ! detect_juegos_disk; then
        exit 1
    fi

    setup_eden_symlinks
    setup_prismlauncher_symlink

    echo ""
    echo "═══════════════════════════════════════════"
    echo "  ✅ Symlinks listos"
    echo "═══════════════════════════════════════════"
}

main
