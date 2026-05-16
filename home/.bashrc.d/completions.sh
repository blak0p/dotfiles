[ -n "$AXIOM_BUNKER" ] && return
# Cargar autocompletado estándar de Linux
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# Hacer que el Tab sea más inteligente (insensible a mayúsculas)
bind "set completion-ignore-case on"
# Mostrar todas las opciones al primer Tab si hay varias
bind "set show-all-if-ambiguous on"
