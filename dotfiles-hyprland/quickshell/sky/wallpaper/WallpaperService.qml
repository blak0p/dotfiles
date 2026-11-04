pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.island

// Wallpaper library for the shell. The scan, the thumbnails and the backend
// commands belong to scripts/sky_wallpaper.py; this singleton only keeps the
// list, the selection and the applied one.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (root.home + "/.config")
    readonly property string script: Quickshell.shellDir + "/scripts/sky_wallpaper.py"

    // [{ path, kind, title, thumb }], as printed by `sky_wallpaper.py scan`.
    property var entries: []
    property int selected: 0
    property string applied: ""

    readonly property string currentPath: root.entries.length > root.selected && root.selected >= 0
        ? root.entries[root.selected].path : ""

    function refresh() {
        if (!scan.running) scan.running = true
        state.reload();
    }

    function move(delta) {
        if (!root.entries.length) return;
        root.selected = Math.max(0, Math.min(root.entries.length - 1, root.selected + delta));
    }

    function apply(index) {
        const entry = root.entries[index];
        if (!entry || applyProc.running) return;
        root.selected = index;
        applyProc.command = ["python3", root.script, "apply", entry.path, entry.kind];
        applyProc.running = true;
    }

    // A null thumbnail (no ffmpeg for a video, unreadable preview) leaves the
    // card flat instead of failing the whole scan.
    function thumbOf(entry) {
        return entry && entry.thumb ? "file://" + entry.thumb : "";
    }

    Process {
        id: scan
        command: ["python3", root.script, "scan"]
        stdout: StdioCollector {
            id: scanOut
            onStreamFinished: {
                try {
                    root.entries = JSON.parse(scanOut.text) || [];
                } catch (e) {
                    console.warn("sky: bad wallpaper scan:", e);
                    root.entries = [];
                }
                if (root.selected >= root.entries.length) root.selected = Math.max(0, root.entries.length - 1);
            }
        }
    }

    Process {
        id: applyProc
        onExited: (code) => {
            if (code === 0) IslandState.closeWallpaper();
        }
    }

    // The applied wallpaper lives in ~/.config/sky/wallpaper.json; Theme.qml
    // watches the same file to regenerate the palette.
    FileView {
        id: state
        path: root.configHome + "/sky/wallpaper.json"
        watchChanges: true
        onFileChanged: state.reload()
        onLoaded: root.syncApplied()
    }

    function syncApplied() {
        try {
            root.applied = JSON.parse(state.text()).path || "";
        } catch (e) {
            root.applied = "";
        }
    }

    Component.onCompleted: root.refresh()
}
