[ -n "$AXIOM_BUNKER" ] && return
# Inicializar zoxide
eval "$(zoxide init bash)"
alias cd='z'
alias zi='z -i'

# Cargar la integración de fzf correctamente
[ -f ~/.fzf.bash ] && source ~/.fzf.bash

# Buscador de archivos con vista previa
alias fp='fzf --preview "bat --style=numbers --color=always --line-range :500 {}"'
