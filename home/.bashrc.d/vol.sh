vol() {
    if [ $# -eq 0 ]; then
        ~/dev/dotfiles/scripts/fix-audio-volume.sh
        return
    fi
    wpctl set-volume "$@"
    ~/dev/dotfiles/scripts/fix-audio-volume.sh
}
