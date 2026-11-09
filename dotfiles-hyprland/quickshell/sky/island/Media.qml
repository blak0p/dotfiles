pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Shared "current player" selection for notch views: the playing one, then
// the first. The Music module can pick another player with select(); that pick
// only drives the Music page (`current`), never the idle island.
Singleton {
    id: root
    readonly property var players: Mpris.players.values
    property string chosen: ""

    readonly property var player: {
        const ps = root.players;
        return ps.find(p => p.isPlaying) || ps[0] || null;
    }
    readonly property var current: root.players.find(p => p.dbusName === root.chosen) || root.player
    readonly property bool playing: player ? player.isPlaying : false

    function select(p) { root.chosen = p ? p.dbusName : ""; }

    function fmtTime(s) {
        s = Math.max(0, Math.floor(s || 0));
        const m = Math.floor(s / 60), r = s % 60;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }
}
