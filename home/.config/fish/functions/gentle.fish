function gentle --description "Gentle AI config manager (SSOT)"
    switch $argv[1]
        case sync
            $HOME/dev/dotfiles/scripts/gentleai-config.sh sync $argv[2..-1]
        case backup
            $HOME/dev/dotfiles/scripts/gentleai-config.sh backup
        case restore distribute
            $HOME/dev/dotfiles/scripts/gentleai-config.sh distribute
        case '*'
            echo "Universal Gentle AI Manager (SSOT)"
            echo "Uso: gentle sync [backend]|backup|restore"
            echo ""
            echo "  sync [backend]  Colecta de un backend (opencode, gemini, claude) y distribuye."
            echo "                  Default: opencode"
            echo "  backup          Crea backup de seguridad del maestro."
            echo "  restore         Fuerza distribución del maestro a backends."
    end
end
