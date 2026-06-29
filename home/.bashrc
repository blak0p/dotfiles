[ -f /etc/bashrc ] && source /etc/bashrc
[ -f ~/.axiom-env.sh ] && source ~/.axiom-env.sh

export PATH="$HOME/.local/bin:/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH"

# bashrc.d — source all fragments
for f in "$HOME/.bashrc.d/"*.sh; do
    [ -f "$f" ] && source "$f"
done
