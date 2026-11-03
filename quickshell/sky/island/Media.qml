pragma Singleton
import Quickshell
import Quickshell.Services.Mpris

// Shared "current player" selection for notch views.
Singleton {
    readonly property var player: {
        const ps = Mpris.players.values;
        return ps.find(p => p.isPlaying) || ps[0] || null;
    }
    readonly property bool playing: player ? player.isPlaying : false
}
