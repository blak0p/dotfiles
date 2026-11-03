pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Pinned dock entries. Persisted to a plain JSON file that is also watched, so
// it can be edited by hand and the dock reacts live.
Singleton {
    id: root

    readonly property string stateHome: {
        const xdg = Quickshell.env("XDG_STATE_HOME");
        return (xdg && xdg.length) ? xdg : (Quickshell.env("HOME") + "/.local/state");
    }
    readonly property string filePath: stateHome + "/quickshell/sky-dock.json"

    property bool ready: false

    // Source of truth: the adapter's pinned array.
    property alias ids: json.pinned

    function has(id) { return ids.indexOf(id) !== -1; }

    function add(id) {
        if (!id || has(id)) return;
        ids = ids.concat([id]);
    }

    function remove(id) {
        if (!has(id)) return;
        ids = ids.filter(x => x !== id);
    }

    function toggle(id) { has(id) ? remove(id) : add(id); }

    function moveTo(id, target) {
        const from = ids.indexOf(id);
        if (from < 0) return;
        target = Math.max(0, Math.min(ids.length - 1, target));
        if (target === from) return;
        const next = ids.slice();
        next.splice(from, 1);
        next.splice(target, 0, id);
        ids = next;
    }

    function move(id, delta) {
        const from = ids.indexOf(id);
        if (from < 0) return;
        moveTo(id, from + delta);
    }

    // Debounced reload / write, matching the ii shell's Persistent pattern.
    Timer { id: reloadTimer; interval: 100; repeat: false; onTriggered: file.reload() }
    Timer { id: writeTimer; interval: 100; repeat: false; onTriggered: file.writeAdapter() }

    FileView {
        id: file
        path: root.filePath
        watchChanges: true
        onFileChanged: reloadTimer.restart()
        onAdapterUpdated: writeTimer.restart()
        onLoaded: root.ready = true
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) writeTimer.restart();
        }

        JsonAdapter {
            id: json
            property var pinned: Config.defaultPinned.slice()
        }
    }
}