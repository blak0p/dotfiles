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

