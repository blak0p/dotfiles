[ -n "$AXIOM_BUNKER" ] && return
[ -n "$AXIOM_BUNKER" ] && return
# 1. Definir la ruta de Homebrew
export HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"

# 2. Activar el entorno de Brew (añade bin, man, etc. al sistema)
eval "$($HOMEBREW_PREFIX/bin/brew shellenv)"
