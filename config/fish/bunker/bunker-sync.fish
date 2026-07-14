# Sync engram memories → dotfiles repo (backup del container efímero)
alias sync-engram='/home/alejndro/dev/dotfiles/scripts/sync-engram.sh'

# Auto-sync al salir del container (solo en distrobox)
if test -n "$DISTROBOX_HOST_HOME"
    function _sync_engram_on_exit --on-event fish_exit
        /home/alejndro/dev/dotfiles/scripts/sync-engram.sh
    end
end
