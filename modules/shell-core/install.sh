# --- SHELL CORE ---
# bashrc, bashrc.d base, zshrc, nanorc, gitconfig

echo -e "\n${BLUE}═══ shell-core ═══${NC}"

# 1. Home files
link_file "$DOTFILES_DIR/home/.bashrc"       "$HOME/.bashrc"
link_file "$DOTFILES_DIR/home/.zshrc"        "$HOME/.zshrc"
link_file "$DOTFILES_DIR/home/.bash_profile" "$HOME/.bash_profile"
link_file "$DOTFILES_DIR/home/.nanorc"       "$HOME/.nanorc"

# 2. Gitconfig — generar desde template si no existe
if [ ! -f "$HOME/.gitconfig" ]; then
    if [ -z "${GIT_USER_NAME:-}" ]; then
        read -p "  Git user name: " GIT_USER_NAME
    fi
    if [ -z "${GIT_USER_EMAIL:-}" ]; then
        read -p "  Git user email: " GIT_USER_EMAIL
    fi
    sed -e "s/{{GIT_USER_NAME}}/$GIT_USER_NAME/g" \
        -e "s/{{GIT_USER_EMAIL}}/$GIT_USER_EMAIL/g" \
        -e "s|{{HOME}}|$HOME|g" \
        "$DOTFILES_DIR/home/.gitconfig.template" > "$HOME/.gitconfig"
    echo -e "${GREEN}✅ .gitconfig generado desde template${NC}"
else
    echo -e "  .gitconfig ya existe — se conserva"
fi

# 3. bashrc.d — migrar de symlink a directorio real con links individuales
if [ -L "$HOME/.bashrc.d" ]; then
    OLD_TARGET=$(readlink -f "$HOME/.bashrc.d")
    echo -e "  Migrando ~/.bashrc.d: $OLD_TARGET → directorio real"
    rm "$HOME/.bashrc.d"
fi
mkdir -p "$HOME/.bashrc.d"

# Core bashrc.d files (siempre)
CORE_BASHRC=(
    aliases completions fzf navigation paths system usr-local zoxide ble_config
)

for name in "${CORE_BASHRC[@]}"; do
    src="$DOTFILES_DIR/home/.bashrc.d/${name}.sh"
    if [ -f "$src" ]; then
        link_file "$src" "$HOME/.bashrc.d/${name}.sh"
    fi
done

# brew.sh — link si existe
if [ -f "$DOTFILES_DIR/home/.bashrc.d/brew.sh" ]; then
    link_file "$DOTFILES_DIR/home/.bashrc.d/brew.sh" "$HOME/.bashrc.d/brew.sh"
fi
if [ -f "$DOTFILES_DIR/home/.bashrc.d/homebrew.sh" ]; then
    link_file "$DOTFILES_DIR/home/.bashrc.d/homebrew.sh" "$HOME/.bashrc.d/homebrew.sh"
fi

# 4. scripts/ — migrar de symlink a directorio real
# Cada módulo linkea sus propios scripts adentro
if [ -L "$HOME/scripts" ]; then
    OLD_TARGET=$(readlink -f "$HOME/scripts")
    echo -e "  Migrando ~/scripts: $OLD_TARGET → directorio real"
    rm "$HOME/scripts"
fi
mkdir -p "$HOME/scripts"
