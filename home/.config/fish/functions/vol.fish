function vol --description "Audio volume control"
    if test (count $argv) -eq 0
        ~/dev/dotfiles/scripts/fix-audio-volume.sh
        return
    end
    wpctl set-volume $argv
    ~/dev/dotfiles/scripts/fix-audio-volume.sh
end
