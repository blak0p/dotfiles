pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Shared "current player" selection for notch views. The Music module can pin
// a player with select(); otherwise the playing one wins, then the first.
Singleton {
    id: root
    readonly property var players: Mpris.players.values
    property string chosen: ""

    readonly property var player: {
        const ps = root.players;
        return ps.find(p => p.dbusName === root.chosen) || ps.find(p => p.isPlaying) || ps[0] || null;
    }
    readonly property bool playing: player ? player.isPlaying : false

    function select(p) { root.chosen = p ? p.dbusName : ""; }

    function fmtTime(s) {
        s = Math.max(0, Math.floor(s || 0));
        const m = Math.floor(s / 60), r = s % 60;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }
}
