# --- GAMING ---
# Steam autopicture, toggle, ROM tools, auto-big-picture service

echo -e "\n${BLUE}═══ gaming ═══${NC}"

# Scripts
mkdir -p "$HOME/scripts"
for script in steam_autopicture.sh steam_toggle.sh limpiar.sh organizar.sh convertir-nsz auto_nsz.sh; do
    if [ -f "$DOTFILES_DIR/modules/gaming/scripts/$script" ]; then
        link_file "$DOTFILES_DIR/modules/gaming/scripts/$script" "$HOME/scripts/$script"
    fi
done
# eden-gyro directory
if [ -d "$DOTFILES_DIR/modules/gaming/scripts/eden-gyro" ]; then
    link_file "$DOTFILES_DIR/modules/gaming/scripts/eden-gyro" "$HOME/scripts/eden-gyro"
fi

# Config — auto-big-picture
link_file "$DOTFILES_DIR/modules/gaming/config/auto-big-picture" "$HOME/.config/auto-big-picture"

# Systemd — auto-big-picture service
mkdir -p "$HOME/.config/systemd/user"
link_file "$DOTFILES_DIR/modules/gaming/systemd/auto-big-picture.service" "$HOME/.config/systemd/user/auto-big-picture.service"
systemctl --user daemon-reload 2>/dev/null
if systemctl --user enable auto-big-picture 2>/dev/null; then
    systemctl --user start auto-big-picture 2>/dev/null
    echo -e "${GREEN}✅ auto-big-picture habilitado e iniciado${NC}"
fi
