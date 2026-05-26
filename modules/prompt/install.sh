# --- PROMPT ---
# oh-my-posh + starship

echo -e "\n${BLUE}═══ prompt ═══${NC}"

# oh-my-posh config + theme
link_file "$DOTFILES_DIR/modules/prompt/config/oh-my-posh" "$HOME/.config/oh-my-posh"

# starship
link_file "$DOTFILES_DIR/modules/prompt/config/starship.tom" "$HOME/.config/starship.tom"
link_file "$DOTFILES_DIR/modules/prompt/config/starship.tomls" "$HOME/.config/starship.tomls"

# bashrc.d fragment — prompt init
link_file "$DOTFILES_DIR/modules/prompt/bashrc.d/prompt.sh" "$HOME/.bashrc.d/prompt.sh"
