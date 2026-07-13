#!/usr/bin/env bash
# install.sh — Módulo Eden: instala Eden, PrismLauncher y crea symlinks
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "═══════════════════════════════════════════"
echo "  🎮 Módulo Eden"
echo "═══════════════════════════════════════════"

# ─── 1. Instalar PrismLauncher (flatpak) ──────────────────────
echo ""
echo "  ── PrismLauncher (Minecraft) ──"
if flatpak list 2>/dev/null | grep -q org.prismlauncher.PrismLauncher; then
    echo "   ✅ PrismLauncher ya instalado"
else
    echo "   Instalando PrismLauncher desde flatpak..."
    flatpak install -y flathub org.prismlauncher.PrismLauncher
    echo "   ✅ PrismLauncher instalado"
fi

# ─── 2. Instalar Eden desde GitLab ────────────────────────────
echo ""
echo "  ── Eden (emulador) ──"
EDEN_INSTALL_DIR="$HOME/.local/share/eden-app"
EDEN_BIN="$EDEN_INSTALL_DIR/eden"

if [ -f "$EDEN_BIN" ]; then
    echo "   ✅ Eden ya instalado en $EDEN_INSTALL_DIR"
else
    echo "   Instalando Eden desde GitLab..."
    mkdir -p "$EDEN_INSTALL_DIR"

    # Detectar arquitectura
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)  EDEN_ARCH="amd64" ;;
        aarch64) EDEN_ARCH="aarch64" ;;
        *)
            echo "   ⚠️  Arquitectura no soportada: $ARCH"
            echo "   Instalá Eden manualmente desde: https://git.eden-emu.dev/eden-emu/eden/releases"
            echo "   Saltando instalación automática..."
            ;;
    esac

    if [ -n "${EDEN_ARCH:-}" ]; then
        # Descargar última release desde eden-emu.dev
        echo "   Descargando Eden para $EDEN_ARCH..."
        EDEN_VERSION="v0.2.1"
        EDEN_URL="https://stable.eden-emu.dev/${EDEN_VERSION}/Eden-Linux-${EDEN_VERSION}-${EDEN_ARCH}-gcc-standard.AppImage"

        curl -fsSL "$EDEN_URL" -o "$EDEN_INSTALL_DIR/Eden.AppImage"

        # Asegurar permisos
        chmod +x "$EDEN_INSTALL_DIR/Eden.AppImage"

        # Crear symlink para que el binario se llame 'eden'
        ln -sf "$EDEN_INSTALL_DIR/Eden.AppImage" "$EDEN_BIN"

        echo "   ✅ Eden instalado en $EDEN_INSTALL_DIR"
    fi

    # Agregar al PATH si no está
    if ! echo "$PATH" | grep -q "$EDEN_INSTALL_DIR"; then
        mkdir -p "$HOME/.config/fish/conf.d"
        cat > "$HOME/.config/fish/conf.d/eden-path.fish" << 'EOF'
# Eden PATH
set -gx PATH $PATH $HOME/.local/share/eden-app
EOF
        echo "   ✅ Eden agregado al PATH (fish)"
    fi
fi

echo ""
echo "═══════════════════════════════════════════"
echo "  ✅ Módulo Eden completado"
echo "═══════════════════════════════════════════"
