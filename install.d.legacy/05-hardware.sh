# --- DEV & HARDWARE ---
link_file "$DOTFILES_DIR/dev/axiom" "$HOME/dev/axiom"
link_file "$DOTFILES_DIR/hardware/deepcool-ak620" "$HOME/deepcool-ak620-digital-linux"

# --- DEPENDENCIAS DE HARDWARE (Python) ---
echo -e "\n🐍 Configurando entorno Python para el disipador..."
if [ -d "$DOTFILES_DIR/hardware/deepcool-ak620" ]; then
    (cd "$DOTFILES_DIR/hardware/deepcool-ak620" || exit
    if [ ! -d "venv" ]; then
        python3 -m venv venv
    fi
    source venv/bin/activate
    pip install -r requirements.txt --quiet
    deactivate)
    echo -e "${GREEN}✅ Dependencias de hardware instaladas.${NC}"
fi
