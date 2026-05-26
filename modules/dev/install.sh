# --- DEV ---
# LazyGit, Axiom, scripts utilitarios

echo -e "\n${BLUE}═══ dev ═══${NC}"

# Scripts
mkdir -p "$HOME/scripts"
for script in merge_md.py dotfiles-auto-sync.sh; do
    if [ -f "$DOTFILES_DIR/modules/dev/scripts/$script" ]; then
        link_file "$DOTFILES_DIR/modules/dev/scripts/$script" "$HOME/scripts/$script"
    fi
done

# Configs
if [ -d "$DOTFILES_DIR/modules/dev/config/lazygit" ]; then
    link_file "$DOTFILES_DIR/modules/dev/config/lazygit" "$HOME/.config/lazygit"
fi
if [ -d "$DOTFILES_DIR/modules/dev/config/axiom" ]; then
    link_file "$DOTFILES_DIR/modules/dev/config/axiom" "$HOME/.config/axiom"
fi

# bashrc.d fragments
link_file "$DOTFILES_DIR/modules/dev/bashrc.d/lazygit.sh"      "$HOME/.bashrc.d/lazygit.sh"
link_file "$DOTFILES_DIR/modules/dev/bashrc.d/github-token.sh"  "$HOME/.bashrc.d/github-token.sh"

# Systemd
mkdir -p "$HOME/.config/systemd/user"
for svc in tokensave-daemon.service dotfiles-auto-sync.service dotfiles-auto-sync.path; do
    if [ -f "$DOTFILES_DIR/modules/dev/systemd/$svc" ]; then
        link_file "$DOTFILES_DIR/modules/dev/systemd/$svc" "$HOME/.config/systemd/user/$svc"
    fi
done
systemctl --user daemon-reload 2>/dev/null
for svc in tokensave-daemon dotfiles-auto-sync.path; do
    if systemctl --user enable "$svc" 2>/dev/null; then
        systemctl --user start "$svc" 2>/dev/null
        echo -e "${GREEN}✅ $svc habilitado${NC}"
    fi
done

# Axiom — proyecto (dev)
if [ -d "$DOTFILES_DIR/dev/axiom" ]; then
    mkdir -p "$HOME/dev"
    link_file "$DOTFILES_DIR/dev/axiom" "$HOME/dev/axiom"
fi
