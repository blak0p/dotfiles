# Integration with Gentle AI SSOT
# Every time the 'gentle' command is used for common tasks, it syncs the SSOT
gentle() {
    case "${1:-}" in
        sync)
            # Soporta 'gentle sync gemini', 'gentle sync claude', etc.
            "$HOME/dev/dotfiles/scripts/gentleai-config.sh" sync "${2:-opencode}"
            ;;
        backup)
            "$HOME/dev/dotfiles/scripts/gentleai-config.sh" backup
            ;;
        restore|distribute)
            # Shortcut to distribute what's in master
            "$HOME/dev/dotfiles/scripts/gentleai-config.sh" distribute
            ;;
        *)
            echo "Universal Gentle AI Manager (SSOT)"
            echo "Uso: gentle {sync [backend]|backup|restore}"
            echo ""
            echo "  sync [backend]  Colecta de un backend (opencode, gemini, claude) y distribuye."
            echo "                  Default: opencode"
            echo "  backup          Crea backup de seguridad del maestro."
            echo "  restore         Fuerza distribución del maestro a backends."
            ;;
    esac
}

