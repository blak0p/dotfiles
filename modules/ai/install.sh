# --- AI ---
# Gentle AI, Ollama

echo -e "\n${BLUE}═══ ai ═══${NC}"

# Scripts
mkdir -p "$HOME/scripts"
for script in gentleai-config.sh gentleai-restore.sh update-ollama-models.sh; do
    if [ -f "$DOTFILES_DIR/modules/ai/scripts/$script" ]; then
        link_file "$DOTFILES_DIR/modules/ai/scripts/$script" "$HOME/scripts/$script"
    fi
done
# gentle-magic directory
if [ -d "$DOTFILES_DIR/modules/ai/scripts/gentle-magic" ]; then
    link_file "$DOTFILES_DIR/modules/ai/scripts/gentle-magic" "$HOME/scripts/gentle-magic"
fi

# bashrc.d fragments
link_file "$DOTFILES_DIR/modules/ai/bashrc.d/gentle.sh"   "$HOME/.bashrc.d/gentle.sh"
link_file "$DOTFILES_DIR/modules/ai/bashrc.d/ollama.sh"   "$HOME/.bashrc.d/ollama.sh"
link_file "$DOTFILES_DIR/modules/ai/bashrc.d/exports.sh"  "$HOME/.bashrc.d/exports.sh"
