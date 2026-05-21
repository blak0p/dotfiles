[ -f /etc/bashrc ] && source /etc/bashrc

for f in ~/.bashrc.d/*.sh; do
  [ -f "$f" ] && source "$f"
done

if [ -z "$AXIOM_BUNKER" ]; then
  command -v fastfetch &>/dev/null && fastfetch
  [ -f ~/.local/share/blesh/ble.sh ] && source ~/.local/share/blesh/ble.sh
fi

[ -f ~/.axiom-env.sh ] && source ~/.axiom-env.sh
export OLLAMA_HOST=127.0.0.1:11434

# OpenClaw Completion
[ -f "/home/alejandro/.openclaw/completions/openclaw.bash" ] && source "/home/alejandro/.openclaw/completions/openclaw.bash"
alias claw-on='systemctl --user start openclaw-gateway openclaw-node && echo "OpenClaw ENCENDIDO"'
alias claw-off='systemctl --user stop openclaw-gateway openclaw-node && echo "OpenClaw APAGADO (RAM liberada)"'

# --- OpenClaw Aliases ---
alias claw-on='systemctl --user start openclaw-gateway openclaw-node && echo "OpenClaw ENCENDIDO"'
alias claw-off='systemctl --user stop openclaw-gateway openclaw-node && echo "OpenClaw APAGADO (RAM liberada)"'
alias claw-fix='systemctl --user stop openclaw-gateway openclaw-node; openclaw devices approve --all --token 856f529bb5cf01a9d351158674042d9e190ddb9b2d1afa24; systemctl --user start openclaw-gateway openclaw-node && echo "OpenClaw RESETEADO Y APROBADO"'
alias claw-status='openclaw status --deep'
# ------------------------
alias claw-help='echo "--- COMANDOS OPENCLAW ---
claw-on     : Enciende el motor y el cerebro.
claw-off    : Apaga todo y libera RAM.
claw-fix    : Resetea permisos y reinicia servicios.
claw-status : Verifica salud y conexión WhatsApp.
claw-help   : Muestra esta ayuda.
------------------------- "'
source ~/.bashrc_openclaw

# Added by Antigravity CLI installer
export PATH="/home/alejandro/.local/bin:$PATH"
