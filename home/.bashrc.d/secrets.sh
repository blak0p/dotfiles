[ -f ~/.secrets/ssh.sh ] && source ~/.secrets/ssh.sh
[ -n "$AXIOM_BUNKER" ] && return
for f in ~/.secrets/*.sh; do
  [ -f "$f" ] && source "$f"
done
