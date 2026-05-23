# --- SYSTEMD USER SERVICES ---
SERVICES_DIR="$DOTFILES_DIR/home/.config/systemd/user"

if [ -d "$SERVICES_DIR" ]; then
    for svc in "$SERVICES_DIR"/*.service; do
        [ -f "$svc" ] || continue
        link_file "$svc" "$HOME/.config/systemd/user/$(basename "$svc")"
    done

    systemctl --user daemon-reload
    echo -e "${GREEN}✅ systemd daemon recargado${NC}"

    # Habilitar servicios conocidos
    for svc in auto-big-picture ak620-digital tokensave-daemon dotfiles-auto-sync; do
        if systemctl --user enable "$svc" 2>/dev/null; then
            systemctl --user start "$svc" 2>/dev/null
            echo -e "${GREEN}✅ $svc habilitado e iniciado${NC}"
        fi
    done
fi
