# --- APPS ---
# ghostty, btop, fastfetch

echo -e "\n${BLUE}═══ apps ═══${NC}"

link_file "$DOTFILES_DIR/modules/apps/config/ghostty"   "$HOME/.config/ghostty"
link_file "$DOTFILES_DIR/modules/apps/config/btop"      "$HOME/.config/btop"
link_file "$DOTFILES_DIR/modules/apps/config/fastfetch" "$HOME/.config/fastfetch"
