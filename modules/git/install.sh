# --- GIT ---
# .gitconfig con template interactivo

echo -e "\n${BLUE}═══ git ═══${NC}"

if [ -f "$HOME/.gitconfig" ]; then
    echo -e "  .gitconfig ya existe — se conserva"
    return
fi

if [ -z "${GIT_USER_NAME:-}" ]; then
    read -p "  Git user name: " GIT_USER_NAME
fi
if [ -z "${GIT_USER_EMAIL:-}" ]; then
    read -p "  Git user email: " GIT_USER_EMAIL
fi

sed -e "s/{{GIT_USER_NAME}}/$GIT_USER_NAME/g" \
    -e "s/{{GIT_USER_EMAIL}}/$GIT_USER_EMAIL/g" \
    -e "s|{{HOME}}|$HOME|g" \
    "$DOTFILES_DIR/modules/git/gitconfig.template" > "$HOME/.gitconfig"

echo -e "${GREEN}✅ .gitconfig generado${NC}"
