[ -n "$AXIOM_BUNKER" ] && return
# Inicializar zoxide para Bash
if command -v zoxide &> /dev/null; then
  eval "$(zoxide init bash)"
fi
