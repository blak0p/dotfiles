#!/bin/bash

# --- COLORES ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DOTFILES_DIR="$HOME/dotfiles"
ERRORS=0
WARNINGS=0

echo -e "${BLUE}🩺 Dotfiles Doctor — Diagnóstico por módulos${NC}\n"

# --- HELPERS ---
check_dependency() {
    local cmd=$1
    if command -v "$cmd" >/dev/null 2>&1; then
        echo -e "${GREEN}[OK]${NC} $cmd"
    else
        echo -e "${RED}[ERR]${NC} $cmd — no instalado"
        ERRORS=$((ERRORS + 1))
    fi
}

check_symlink() {
    local target=$1
    local expected_source=$2
    local label=${3:-$target}

    if [ ! -e "$target" ] && [ ! -L "$target" ]; then
        echo -e "${RED}[ERR]${NC} $label — no existe"
        ERRORS=$((ERRORS + 1))
        return
    fi
    if [ ! -L "$target" ]; then
        echo -e "${YELLOW}[WARN]${NC} $label — existe pero no es symlink"
        WARNINGS=$((WARNINGS + 1))
        return
    fi
    local actual_source
    actual_source=$(readlink -f "$target")
    local resolved_expected
    resolved_expected=$(readlink -f "$expected_source")
    if [ "$actual_source" == "$resolved_expected" ]; then
        echo -e "${GREEN}[OK]${NC} $label"
    else
        echo -e "${RED}[ERR]${NC} $label → apunta a $actual_source (esperaba $expected_source)"
        ERRORS=$((ERRORS + 1))
    fi
}

# --- MÓDULOS ---

check_shell_core() {
    echo -e "\n${BLUE}═══ shell-core ═══${NC}"
    check_symlink "$HOME/.bashrc"       "$DOTFILES_DIR/home/.bashrc"
    check_symlink "$HOME/.zshrc"        "$DOTFILES_DIR/home/.zshrc"
    check_symlink "$HOME/.bash_profile" "$DOTFILES_DIR/home/.bash_profile"
    check_symlink "$HOME/.nanorc"       "$DOTFILES_DIR/home/.nanorc"

    for f in aliases completions fzf navigation paths system usr-local zoxide ble_config brew homebrew; do
        [ -f "$DOTFILES_DIR/home/.bashrc.d/${f}.sh" ] && \
            check_symlink "$HOME/.bashrc.d/${f}.sh" "$DOTFILES_DIR/home/.bashrc.d/${f}.sh"
    done

    for script in cambiar_audio.sh cambiar_micro.sh; do
        [ -f "$DOTFILES_DIR/modules/shell-core/scripts/$script" ] && \
            check_symlink "$HOME/scripts/$script" "$DOTFILES_DIR/modules/shell-core/scripts/$script"
    done

    check_dependency git
}

check_prompt() {
    echo -e "\n${BLUE}═══ prompt ═══${NC}"
    check_symlink "$HOME/.config/oh-my-posh" "$DOTFILES_DIR/modules/prompt/config/oh-my-posh"
    check_symlink "$HOME/.config/starship.tom" "$DOTFILES_DIR/modules/prompt/config/starship.tom"
    check_symlink "$HOME/.bashrc.d/prompt.sh" "$DOTFILES_DIR/modules/prompt/bashrc.d/prompt.sh"
    check_dependency oh-my-posh
    check_dependency starship
}

check_apps() {
    echo -e "\n${BLUE}═══ apps ═══${NC}"
    check_symlink "$HOME/.config/ghostty"   "$DOTFILES_DIR/modules/apps/config/ghostty"
    check_symlink "$HOME/.config/btop"      "$DOTFILES_DIR/modules/apps/config/btop"
    check_symlink "$HOME/.config/fastfetch" "$DOTFILES_DIR/modules/apps/config/fastfetch"
    check_dependency ghostty
    check_dependency btop
    check_dependency fastfetch
}

check_gaming() {
    echo -e "\n${BLUE}═══ gaming ═══${NC}"
    for script in steam_autopicture.sh steam_toggle.sh limpiar.sh organizar.sh convertir-nsz auto_nsz.sh; do
        check_symlink "$HOME/scripts/$script" "$DOTFILES_DIR/modules/gaming/scripts/$script"
    done
    check_symlink "$HOME/.config/auto-big-picture" "$DOTFILES_DIR/modules/gaming/config/auto-big-picture"
    check_symlink "$HOME/.config/systemd/user/auto-big-picture.service" "$DOTFILES_DIR/modules/gaming/systemd/auto-big-picture.service"
}

check_ai() {
    echo -e "\n${BLUE}═══ ai ═══${NC}"
    for script in gentleai-config.sh gentleai-restore.sh update-ollama-models.sh; do
        check_symlink "$HOME/scripts/$script" "$DOTFILES_DIR/modules/ai/scripts/$script"
    done
    for f in gentle ollama exports; do
        check_symlink "$HOME/.bashrc.d/${f}.sh" "$DOTFILES_DIR/modules/ai/bashrc.d/${f}.sh"
    done
}

check_dev() {
    echo -e "\n${BLUE}═══ dev ═══${NC}"
    for script in merge_md.py dotfiles-auto-sync.sh; do
        [ -f "$DOTFILES_DIR/modules/dev/scripts/$script" ] && \
            check_symlink "$HOME/scripts/$script" "$DOTFILES_DIR/modules/dev/scripts/$script"
    done
    check_symlink "$HOME/.bashrc.d/lazygit.sh"     "$DOTFILES_DIR/modules/dev/bashrc.d/lazygit.sh"
    check_symlink "$HOME/.bashrc.d/github-token.sh" "$DOTFILES_DIR/modules/dev/bashrc.d/github-token.sh"
    check_dependency lazygit
}

check_hardware() {
    echo -e "\n${BLUE}═══ hardware ═══${NC}"
    check_symlink "$HOME/deepcool-ak620-digital-linux" "$DOTFILES_DIR/modules/hardware/config/deepcool-ak620"
    check_symlink "$HOME/.config/systemd/user/ak620-digital.service" "$DOTFILES_DIR/modules/hardware/systemd/ak620-digital.service"
}

# --- MAIN ---

# Auto-detectar módulos instalados (por presencia de symlinks)
AUTO_MODULES=()
[ -L "$HOME/.bashrc" ] && AUTO_MODULES+=("shell-core")
[ -L "$HOME/.config/oh-my-posh" ] && AUTO_MODULES+=("prompt")
[ -L "$HOME/.config/ghostty" ] && AUTO_MODULES+=("apps")
[ -L "$HOME/scripts/steam_autopicture.sh" ] && AUTO_MODULES+=("gaming")
[ -L "$HOME/scripts/gentleai-config.sh" ] && AUTO_MODULES+=("ai")
[ -L "$HOME/scripts/merge_md.py" ] && AUTO_MODULES+=("dev")
[ -L "$HOME/deepcool-ak620-digital-linux" ] && AUTO_MODULES+=("hardware")

echo -e "Módulos detectados: ${AUTO_MODULES[*]:-ninguno}\n"

for mod in "${AUTO_MODULES[@]}"; do
    case "$mod" in
        shell-core) check_shell_core ;;
        prompt)     check_prompt ;;
        apps)       check_apps ;;
        gaming)     check_gaming ;;
        ai)         check_ai ;;
        dev)        check_dev ;;
        hardware)   check_hardware ;;
    esac
done

# --- GIT REMOTE CHECK ---
echo -e "\n${BLUE}🌐 Verificando repo remoto...${NC}"
if [ -d "$DOTFILES_DIR/.git" ]; then
    cd "$DOTFILES_DIR" || exit
    git fetch origin main --quiet 2>/dev/null
    LOCAL=$(git rev-parse HEAD)
    REMOTE=$(git rev-parse @{u} 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}[WARN]${NC} No se pudo verificar remoto (¿sin internet?)"
        WARNINGS=$((WARNINGS + 1))
    elif [ "$LOCAL" == "$REMOTE" ]; then
        echo -e "${GREEN}[OK]${NC} Repositorio actualizado."
    else
        echo -e "${YELLOW}[WARN]${NC} Hay cambios nuevos en el remoto. Hacé 'git pull'."
        WARNINGS=$((WARNINGS + 1))
    fi
fi

# --- RESUMEN ---
echo -e "\n--------------------------------------------------"
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "📊 Resumen: ${GREEN}Sistema saludable${NC}"
elif [ $ERRORS -gt 0 ]; then
    echo -e "📊 Resumen: ${RED}Errores: $ERRORS | Advertencias: $WARNINGS${NC}"
else
    echo -e "📊 Resumen: ${YELLOW}Advertencias: $WARNINGS${NC}"
fi
echo -e "--------------------------------------------------\n"
