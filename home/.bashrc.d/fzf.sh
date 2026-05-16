[ -n "$AXIOM_BUNKER" ] && return
# ==========================================================
# CONFIGURACIÓN MAESTRA DE FZF (Versión Compatible con ble.sh)
# ==========================================================

if command -v fzf &> /dev/null; then
  # 1. Inicializar fzf sin cargar las terminaciones de Bash antiguas
  # Esto evita el conflicto con ble.sh
  eval "$(fzf --bash)"

  # 2. Configuración Estética
  export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border --color=16"
  export FZF_CTRL_T_OPTS="--preview 'bat -n --color=always {} 2>/dev/null || cat {}'"
  export FZF_CTRL_R_OPTS="--header '[Historial de comandos]'"

  # 3. Tus funciones de utilidad (fkill y fzd)
  fkill() {
    local pid
    pid=$(ps -u $USER -opid,stat,comm | fzf --height 40% --reverse --header="[Matar Proceso]" | awk '{print $1}')
    [ -n "$pid" ] && kill -9 $pid && echo ">>> Proceso $pid aniquilado."
  }

  fzd() {
    local dir
    dir=$(find ${1:-.} -path '*/.*' -prune -o -type d -print 2>/dev/null | fzf --height 40% --reverse --header="[Ir a carpeta...]")
    [ -n "$dir" ] && cd "$dir"
  }
fi
