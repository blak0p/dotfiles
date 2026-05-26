# --- SHELL CORE ---
# bashrc, bashrc.d base, zshrc, nanorc, scripts base

echo -e "\n${BLUE}═══ shell-core ═══${NC}"

# 1. Home files
link_file "$DOTFILES_DIR/home/.bashrc"       "$HOME/.bashrc"
link_file "$DOTFILES_DIR/home/.zshrc"        "$HOME/.zshrc"
link_file "$DOTFILES_DIR/home/.bash_profile" "$HOME/.bash_profile"
link_file "$DOTFILES_DIR/home/.nanorc"       "$HOME/.nanorc"

# 2. bashrc.d — migrar de symlink a directorio real con links individuales
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

# Scripts base (audio) — generar desde template
TEMPLATES_DIR="$DOTFILES_DIR/modules/shell-core/scripts"
AUDIO_CONF="$HOME/.config/audio-devices.conf"

if [ ! -f "$AUDIO_CONF" ]; then
    echo ""
    echo -e "  ${YELLOW}Configurando dispositivos de audio...${NC}"
    echo -e "  Dejá vacío y presioná Enter para saltar."
    read -p "  Nombre de tus CASCOS (ej: SteelSeries, HyperX): " AUDIO_HEADSET
    read -p "  Nombre de tus ALTAVOCES (ej: Ryzen, HDMI, Speakers): " AUDIO_SPEAKERS
    read -p  "  Nombre del MICRÓFONO DEDICADO (ej: SoloCast, Yeti): " MIC_DEDICATED
    read -p "  Nombre del MICRÓFONO de los cascos (ej: SteelSeries, Headset): " MIC_HEADSET

    if [ -n "$AUDIO_HEADSET" ] || [ -n "$AUDIO_SPEAKERS" ]; then
        cat > "$AUDIO_CONF" <<-EOF
AUDIO_HEADSET=$AUDIO_HEADSET
AUDIO_SPEAKERS=$AUDIO_SPEAKERS
MIC_DEDICATED=$MIC_DEDICATED
MIC_HEADSET=$MIC_HEADSET
EOF
        echo -e "${GREEN}✅ Configuración de audio guardada en $AUDIO_CONF${NC}"
    fi
fi

# Cargar configuración si existe
if [ -f "$AUDIO_CONF" ]; then
    source "$AUDIO_CONF"
fi

# Generar scripts desde templates si tenemos datos
if [ -n "$AUDIO_HEADSET" ] && [ -n "$AUDIO_SPEAKERS" ]; then
    # cambiar_audio.sh
    if [ ! -f "$HOME/scripts/cambiar_audio.sh" ] && [ -f "$TEMPLATES_DIR/cambiar_audio.sh.template" ]; then
        sed -e "s/{{AUDIO_HEADSET}}/$AUDIO_HEADSET/g" \
            -e "s/{{AUDIO_SPEAKERS}}/$AUDIO_SPEAKERS/g" \
            -e "s/{{AUDIO_LABEL_CASCOS}}/Cascos/g" \
            -e "s/{{AUDIO_LABEL_ALTAVOCES}}/Altavoces/g" \
            "$TEMPLATES_DIR/cambiar_audio.sh.template" > "$HOME/scripts/cambiar_audio.sh"
        chmod +x "$HOME/scripts/cambiar_audio.sh"
        echo -e "${GREEN}✅ Generado: ~/scripts/cambiar_audio.sh${NC}"
    fi
fi

if [ -n "$MIC_DEDICATED" ] && [ -n "$MIC_HEADSET" ]; then
    # cambiar_micro.sh
    if [ ! -f "$HOME/scripts/cambiar_micro.sh" ] && [ -f "$TEMPLATES_DIR/cambiar_micro.sh.template" ]; then
        sed -e "s/{{MIC_DEDICATED}}/$MIC_DEDICATED/g" \
            -e "s/{{MIC_HEADSET}}/$MIC_HEADSET/g" \
            "$TEMPLATES_DIR/cambiar_micro.sh.template" > "$HOME/scripts/cambiar_micro.sh"
        chmod +x "$HOME/scripts/cambiar_micro.sh"
        echo -e "${GREEN}✅ Generado: ~/scripts/cambiar_micro.sh${NC}"
    fi
fi
