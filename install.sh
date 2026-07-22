#!/usr/bin/env bash
# install.sh — Dotfiles Installer
# Deploya config/ → ~/.config/ y scripts/ → ~/scripts/ via symlinks.
# Ejecuta módulos de modules/ si tienen install.sh.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

# Name of the bunker distrobox container. Change to "bunker" once the new
# bootstrap is validated; defaults to "bunker-test" so the existing container
# stays untouched during development.
BUNKER_CONTAINER_NAME="${BUNKER_CONTAINER_NAME:-bunker-test}"

# ─── Colores ──────────────────────────────────────────────────────
BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${BLUE}ℹ️${NC} $1"; }
ok()    { echo -e "${GREEN}✅${NC} $1"; }
warn()  { echo -e "${YELLOW}⚠️${NC} $1"; }
err()   { echo -e "${RED}❌${NC} $1"; }

# ─── Deploy symlinks ──────────────────────────────────────────────
deploy_symlink() {
    local src="$1" dst="$2"
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        warn "Respaldando $dst → $BACKUP_DIR/"
        mkdir -p "$BACKUP_DIR/$(dirname "${dst#$HOME/}")"
        mv "$dst" "$BACKUP_DIR/$(dirname "${dst#$HOME/}")/"
    fi
    if [ -L "$dst" ]; then
        local current=$(readlink "$dst")
        if [ "$current" = "$src" ]; then
            return 0
        fi
        rm -f "$dst"
    fi
    ln -sf "$src" "$dst"
    ok "Symlink: $dst → $src"
}

# ─── Deploy helpers ───────────────────────────────────────────────
# Deploy a single config entry (dir or file) from src to ~/.config/<name>
deploy_config_entry() {
    local src="$1" name="$2"
    deploy_symlink "$src" "$HOME/.config/$name"
}

# Shared configs: nvim, ghostty, starship.toml, fish, fastfetch.
# Deployed by both --host and --bunker. Idempotent.
deploy_shared() {
    info "Deployando shared config/ → ~/.config/..."
    local shared=(nvim ghostty fish fastfetch)
    for name in "${shared[@]}"; do
        [ -e "$DOTFILES_DIR/config/$name" ] && deploy_config_entry "$DOTFILES_DIR/config/$name" "$name"
    done
    for f in "$DOTFILES_DIR/config"/starship.toml; do
        [ -f "$f" ] && deploy_symlink "$f" "$HOME/.config/$(basename "$f")"
    done
}

# Domain deploy: links every entry under {domain}/config/ and {domain}/scripts/
# into ~/.config/ and ~/scripts/ respectively. Symlinks resolve to the original
# files under root config/ and scripts/ (relative symlinks).
deploy_domain() {
    local domain="$1"
    local dcfg="$DOTFILES_DIR/$domain/config"
    local dscripts="$DOTFILES_DIR/$domain/scripts"

    info "Deployando $domain/config/ → ~/.config/..."
    if [ -d "$dcfg" ]; then
        for entry in "$dcfg"/*; do
            [ -e "$entry" ] || continue
            deploy_config_entry "$entry" "$(basename "$entry")"
        done
    else
        info "no $domain configs to deploy"
    fi

    info "Deployando $domain/scripts/ → ~/scripts/..."
    mkdir -p "$HOME/scripts"
    if [ -d "$dscripts" ]; then
        for f in "$dscripts"/*; do
            [ -e "$f" ] || continue
            deploy_symlink "$f" "$HOME/scripts/$(basename "$f")"
        done
    fi
}

# ─── Bunker bootstrap phases ──────────────────────────────────────
# Phased distrobox bootstrap invoked by `install.sh --bunker`. Each phase is
# idempotent: it guards with an existence check and skips when its goal is
# already met. All container commands run via:
#   distrobox enter "$BUNKER_CONTAINER_NAME" -- <cmd>
# The container has the dotfiles repo bind-mounted at the same host path, so
# deploy_shared / deploy_domain work unchanged inside it.

# Filter deps/brew.txt down to container-appropriate packages. Host-only
# entries (distrobox, podman, ghostty, wireplumber, pipewire) are removed by a
# skip-list regex; comments and blank lines are also dropped. Prints the
# filtered package names, one per line, to stdout.
_bunker_filter_brew_packages() {
    grep -vE '^\s*#|^\s*$' "$DOTFILES_DIR/deps/brew.txt" \
        | grep -vE 'distrobox|podman|ghostty|wireplumber|pipewire'
}

# All phase functions implemented inline below. Kept as distinct functions so each
# can be sourced and tested independently (`source install.sh && bunker_preflight_host`).

# Phase 1: ensure podman + distrobox are installed on the host.
bunker_preflight_host() {
    info "Preflight: verificando podman y distrobox en el host..."
    if command -v podman >/dev/null 2>&1 && command -v distrobox >/dev/null 2>&1; then
        ok "podman y distrobox ya presentes en el host"
        return 0
    fi
    warn "Faltan podman y/o distrobox en el host — instalando via pacman..."
    sudo pacman -S --noconfirm podman distrobox
    ok "podman y distrobox instalados en el host"
}

# Phase 2: create the bunker container from fedora:45, or prompt to replace.
bunker_create_container() {
    info "Verificando contenedor '$BUNKER_CONTAINER_NAME'..."
    if distrobox list | awk 'NR>1{print $1}' | grep -qx "$BUNKER_CONTAINER_NAME"; then
        warn "El contenedor '$BUNKER_CONTAINER_NAME' ya existe."
        local reply
        read -rp "Container '$BUNKER_CONTAINER_NAME' exists. Replace? [y/N] " reply
        case "$reply" in
            y|Y)
                info "Eliminando contenedor existente..."
                distrobox rm --force "$BUNKER_CONTAINER_NAME"
                ;;
            *)
                ok "Reutilizando contenedor existente '$BUNKER_CONTAINER_NAME'"
                return 0
                ;;
        esac
    fi
    info "Creando contenedor '$BUNKER_CONTAINER_NAME' desde fedora:45..."
    distrobox create \
        --name "$BUNKER_CONTAINER_NAME" \
        --image fedora:45 \
        --home $DOTFILES_DIR
    ok "Contenedor '$BUNKER_CONTAINER_NAME' creado"
}

# Phase 3: install system dependencies inside the container (git, curl, etc.).
# Homebrew needs git to install itself, and Fedora minimal images don't ship it.
bunker_install_system_deps() {
    info "Instalando dependencias del sistema en '$BUNKER_CONTAINER_NAME'..."
    distrobox enter "$BUNKER_CONTAINER_NAME" -- \
        sudo dnf install -y git curl which procps-ng >/dev/null 2>&1
    ok "Dependencias del sistema instaladas en '$BUNKER_CONTAINER_NAME'"
}

# Phase 4: install Homebrew inside the container (idempotent).
bunker_install_brew() {
    info "Verificando Homebrew en '$BUNKER_CONTAINER_NAME'..."
    if distrobox enter "$BUNKER_CONTAINER_NAME" -- command -v brew >/dev/null 2>&1; then
        ok "Homebrew ya presente en '$BUNKER_CONTAINER_NAME'"
        return 0
    fi
    warn "Homebrew ausente — instalando..."
    distrobox enter "$BUNKER_CONTAINER_NAME" -- \
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    ok "Homebrew instalado en '$BUNKER_CONTAINER_NAME'"
}

# Phase 4: install filtered brew packages inside the container.
bunker_install_packages() {
    info "Instalando paquetes de brew filtrados en '$BUNKER_CONTAINER_NAME'..."
    local pkgs
    pkgs="$(_bunker_filter_brew_packages | tr '\n' ' ')"
    if [ -z "$pkgs" ]; then
        warn "La lista de paquetes filtrados está vacía — nada que instalar"
        return 0
    fi
    # brew is idempotent: already-installed packages are skipped.
    # shellcheck disable=SC2086
    distrobox enter "$BUNKER_CONTAINER_NAME" -- brew install $pkgs
    ok "Paquetes brew instalados en '$BUNKER_CONTAINER_NAME'"
}

# Phase 5: deploy shared + bunker domain configs inside the container.
bunker_deploy_configs() {
    info "Deployando configs (shared + bunker) en '$BUNKER_CONTAINER_NAME'..."
    # The dotfiles repo is bind-mounted at the same host path, so install.sh
    # can re-exec itself inside the container to run the deploy functions.
    distrobox enter "$BUNKER_CONTAINER_NAME" -- \
        /bin/bash -c "$DOTFILES_DIR/install.sh --bunker-deploy-only"
    ok "Configs deployados en '$BUNKER_CONTAINER_NAME'"
}

# Phase 6: set BUNKER=1 as a universal fish variable inside the container.
bunker_set_env() {
    info "Seteando BUNKER=1 (universal fish var) en '$BUNKER_CONTAINER_NAME'..."
    if [ "$(distrobox enter "$BUNKER_CONTAINER_NAME" -- fish -c 'echo $BUNKER' 2>/dev/null)" = "1" ]; then
        ok "BUNKER ya está seteado en '$BUNKER_CONTAINER_NAME'"
        return 0
    fi
    distrobox enter "$BUNKER_CONTAINER_NAME" -- fish -c 'set -Ux BUNKER 1'
    ok "BUNKER=1 seteado en '$BUNKER_CONTAINER_NAME'"
}

# Phase 7: verify brew, all filtered packages, BUNKER var, and config symlinks.
bunker_verify() {
    info "Verificando setup de '$BUNKER_CONTAINER_NAME'..."
    local failures=0

    if ! distrobox enter "$BUNKER_CONTAINER_NAME" -- brew --version >/dev/null 2>&1; then
        err "brew no disponible en '$BUNKER_CONTAINER_NAME'"
        failures=$((failures + 1))
    fi

    local missing
    # Pipe the filtered package list (one per line) into the container and
    # loop over stdin there, so word-splitting bugs can't drop packages.
    missing="$(_bunker_filter_brew_packages | distrobox enter "$BUNKER_CONTAINER_NAME" -- bash -c '
        while IFS= read -r p; do
            [ -n "$p" ] || continue
            brew list --versions "$p" >/dev/null 2>&1 || echo "$p"
        done
    ' 2>/dev/null)"
    if [ -n "$missing" ]; then
        err "Paquetes faltantes en '$BUNKER_CONTAINER_NAME':"
        echo "$missing" | sed 's/^/    - /' >&2
        failures=$((failures + 1))
    fi

    if [ "$(distrobox enter "$BUNKER_CONTAINER_NAME" -- fish -c 'echo $BUNKER' 2>/dev/null)" != "1" ]; then
        err "BUNKER != 1 en '$BUNKER_CONTAINER_NAME'"
        failures=$((failures + 1))
    fi

    # Key symlinks expected under the container's ~/.config.
    # Use the container's own HOME (not the host's) via bash -c.
    local links=(nvim fish fastfetch starship.toml opencode)
    for name in "${links[@]}"; do
        if ! distrobox enter "$BUNKER_CONTAINER_NAME" -- \
            bash -c "test -L \"\$HOME/.config/$name\"" 2>/dev/null; then
            err "Symlink faltante: ~/.config/$name"
            failures=$((failures + 1))
        fi
    done

    if [ "$failures" -gt 0 ]; then
        err "Verificación fallida: $failures problema(s) en '$BUNKER_CONTAINER_NAME'"
        return 1
    fi
    ok "Verificación de '$BUNKER_CONTAINER_NAME' OK"
}

# ─── Bunker bootstrap dispatcher ──────────────────────────────────
# Runs every phase in order. Used by `--bunker`. The deploy-only entry point
# below is invoked from inside the container by bunker_deploy_configs.
bunker_bootstrap() {
    bunker_preflight_host
    bunker_create_container
    bunker_install_system_deps
    bunker_install_brew
    bunker_install_packages
    bunker_deploy_configs
    bunker_set_env
    bunker_verify
}

# Internal entry point re-entered inside the container to run the deploy
# functions directly (the repo is bind-mounted at the same path inside).
# Handled in main() below (not at source time) so `source install.sh` keeps
# working for ad-hoc phase testing.

# Legacy: deploy everything under root config/ (kept for --config backward compat)
deploy_configs() {
    info "Deployando config/ → ~/.config/..."
    for dir in "$DOTFILES_DIR/config"/*/; do
        local name=$(basename "$dir")
        local src="$DOTFILES_DIR/config/$name"
        local dst="$HOME/.config/$name"
        deploy_symlink "$src" "$dst"
    done
    for f in "$DOTFILES_DIR/config"/starship.toml; do
        [ -f "$f" ] && deploy_symlink "$f" "$HOME/.config/$(basename "$f")"
    done
}

deploy_scripts() {
    info "Deployando scripts/ → ~/scripts/..."
    mkdir -p "$HOME/scripts"
    for f in "$DOTFILES_DIR/scripts"/*; do
        [ -f "$f" ] && deploy_symlink "$f" "$HOME/scripts/$(basename "$f")"
    done
}

# ─── Modules ──────────────────────────────────────────────────────
MODULE_NAMES=(
    "eden"
    "gaming"
    "hardware"
)
MODULE_DESCS=(
    "Symlinks de Eden y PrismLauncher al disco Juegos"
    "Steam autopicture service"
    "Deepcool AK620 display daemon"
)

install_module() {
    local name="$1"
    local dir="$DOTFILES_DIR/modules/$name"
    if [ ! -d "$dir" ]; then
        err "Módulo '$name' no encontrado"
        return 1
    fi
    if [ -f "$dir/install.sh" ]; then
        info "Ejecutando módulo: $name..."
        bash "$dir/install.sh"
        ok "Módulo '$name' listo"
    else
        warn "Módulo '$name' no tiene install.sh, saltando"
    fi
}

# ─── Help ─────────────────────────────────────────────────────────
show_help() {
    echo "Dotfiles Installer"
    echo ""
    echo "Uso:"
    echo "  ./install.sh --host       — Host configs + shared + modules + deps + personal-pc"
    echo "  ./install.sh --bunker     — Full bunker bootstrap (host tools, container, brew, configs)"
    echo "  ./install.sh --all        — Host + bunker + shared (shared once) + modules + deps"
    echo "  ./install.sh --config     — Solo symlinks de config/ (legacy)"
    echo "  ./install.sh --scripts    — Solo symlinks de scripts/ (legacy)"
    echo "  ./install.sh --deps       — Solo instalar dependencias"
    echo "  ./install.sh --module X   — Solo un módulo"
    echo "  ./install.sh --help       — Esta ayuda"
    echo ""
    echo "Dominios:"
    echo "  host    Hyprland, Waybar, btop, cava, fuzzel, GTK, systemd, hardware"
    echo "  bunker  opencode, dev scripts (distrobox)"
    echo "  shared  nvim, ghostty, starship.toml, fish, fastfetch"
    echo ""
    echo "Módulos:"
    for i in "${!MODULE_NAMES[@]}"; do
        printf "  %-15s %s\n" "${MODULE_NAMES[$i]}" "${MODULE_DESCS[$i]}"
    done
}

# ─── Main ─────────────────────────────────────────────────────────
main() {
    case "${1:-}" in
        --help|-h) show_help ;;
        --host)
            deploy_shared
            deploy_domain host
            for name in "${MODULE_NAMES[@]}"; do install_module "$name"; done
            bash "$DOTFILES_DIR/deps/install.sh"
            ;;
        --bunker)
            bunker_bootstrap
            ;;
        --bunker-deploy-only)
            # Re-entered inside the container by bunker_deploy_configs.
            deploy_shared
            deploy_domain bunker
            ;;
        --all|-a)
            deploy_shared
            deploy_domain host
            deploy_domain bunker
            for name in "${MODULE_NAMES[@]}"; do install_module "$name"; done
            bash "$DOTFILES_DIR/deps/install.sh"
            ;;
        --config) deploy_configs ;;
        --scripts) deploy_scripts ;;
        --deps) bash "$DOTFILES_DIR/deps/install.sh" ;;
        --module|-m)
            [ -z "${2:-}" ] && { err "Falta el nombre del módulo"; exit 1; }
            install_module "$2"
            ;;
        *)
            echo "═══════════════════════════════════════════"
            echo "  🛠️  Dotfiles"
            echo "═══════════════════════════════════════════"
            echo ""
            show_help
            echo ""
            echo "Especificá un dominio: --host, --bunker o --all."
            echo "═══════════════════════════════════════════"
            exit 1
            ;;
    esac
}

main "$@"
