# --- DEPENDENCIAS ---
# Detect package manager y auto-instala lo que falta

BREW_PACKAGES=(
    kitty         # terminal emulator
    lazygit       # git TUI
    starship      # prompt (alternativa a oh-my-posh)
    oh-my-posh    # prompt
    btop          # system monitor
    bat           # file preview
    eza           # ls replacement
    fzf           # fuzzy finder
    zoxide        # cd replacement
    glow          # markdown preview
    ripgrep       # file search
)

# Solo en macOS: node, python3 suelen venir con brew
EXTRA_MACOS=(
    node
    python@3.14
)

if command -v brew &>/dev/null; then
    echo -e "\n🍺 Homebrew detectado — verificando dependencias..."

    for pkg in "${BREW_PACKAGES[@]}"; do
        if brew list "$pkg" &>/dev/null 2>&1; then
            echo -e "  ✅ $pkg"
        else
            echo -e "  📦 Instalando $pkg..."
            brew install "$pkg"
        fi
    done

    # En macOS instalar cosas extra que suelen faltar
    if [[ "$(uname)" == "Darwin" ]]; then
        for pkg in "${EXTRA_MACOS[@]}"; do
            if ! brew list "$pkg" &>/dev/null 2>&1; then
                echo -e "  📦 Instalando $pkg..."
                brew install "$pkg"
            fi
        done
    fi
else
    echo -e "\n⚠️  Homebrew no está instalado."
    echo -e "   Instalalo desde https://brew.sh o instalá manualmente:"
    echo -e "   ${BREW_PACKAGES[*]}"
fi
