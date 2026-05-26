[ -f /etc/bashrc ] && source /etc/bashrc

for f in ~/.bashrc.d/*.sh; do
  [ -f "$f" ] && source "$f"
done

if [ -z "$AXIOM_BUNKER" ]; then
  command -v fastfetch &>/dev/null && fastfetch
  [ -f ~/.local/share/blesh/ble.sh ] && source ~/.local/share/blesh/ble.sh
fi

[ -f ~/.axiom-env.sh ] && source ~/.axiom-env.sh

# Added by Antigravity CLI installer
export PATH="/home/alejandro/.local/bin:$PATH"
