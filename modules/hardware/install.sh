# --- HARDWARE ---
# Deepcool AK620 digital fan

echo -e "\n${BLUE}═══ hardware ═══${NC}"

# Deepcool — symlink y entorno virtual
link_file "$DOTFILES_DIR/modules/hardware/config/deepcool-ak620" "$HOME/deepcool-ak620-digital-linux"

echo -e "  Configurando entorno Python para el disipador..."
if [ -d "$DOTFILES_DIR/modules/hardware/config/deepcool-ak620" ]; then
    (cd "$DOTFILES_DIR/modules/hardware/config/deepcool-ak620" || exit
    if [ ! -d "venv" ]; then
        python3 -m venv venv
    fi
    source venv/bin/activate
    pip install -r requirements.txt --quiet
    deactivate)
    echo -e "${GREEN}✅ Dependencias de hardware instaladas.${NC}"
fi

# Systemd
mkdir -p "$HOME/.config/systemd/user"
link_file "$DOTFILES_DIR/modules/hardware/systemd/ak620-digital.service" "$HOME/.config/systemd/user/ak620-digital.service"
systemctl --user daemon-reload 2>/dev/null
if systemctl --user enable ak620-digital 2>/dev/null; then
    systemctl --user start ak620-digital 2>/dev/null
    echo -e "${GREEN}✅ ak620-digital habilitado e iniciado${NC}"
fi
