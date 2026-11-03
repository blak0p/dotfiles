pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Palette from ~/.local/state/sky/colors.json (written by scripts/sky_theme.py).
// Regenerated automatically when the wallpaper changes.
Singleton {
    id: root

    property color accent: "#8fcff3"
    property color accentText: "#00344e"
    property color secondary: "#b7c9d9"
    property color tertiary: "#8fcff3"
    property color surface: "#0f1417"
    property color surface2: "#262a2e"
    property color widget: "#1c2023"
    property color fg: "#e0e3e8"
    property color muted: "#c1c7ce"
    property color outline: "#8b9198"

    readonly property string home: Quickshell.env("HOME")
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (root.home + "/.config")
    readonly property var keys: ["accent", "secondary", "tertiary", "surface", "surface2", "widget", "muted", "outline"]

    Behavior on accent { ColorAnimation { duration: 600 } }
    Behavior on accentText { ColorAnimation { duration: 600 } }
    Behavior on secondary { ColorAnimation { duration: 600 } }
    Behavior on tertiary { ColorAnimation { duration: 600 } }
    Behavior on surface { ColorAnimation { duration: 600 } }
    Behavior on surface2 { ColorAnimation { duration: 600 } }
    Behavior on widget { ColorAnimation { duration: 600 } }
    Behavior on fg { ColorAnimation { duration: 600 } }
    Behavior on muted { ColorAnimation { duration: 600 } }
    Behavior on outline { ColorAnimation { duration: 600 } }

    function apply(txt) {
        try {
            const o = JSON.parse(txt);
            for (const k of keys)
                if (o[k]) root[k] = o[k];
            if (o.on) root.fg = o.on;
            if (o.onAccent) root.accentText = o.onAccent;
        } catch (e) {
            console.warn("sky: bad colors.json:", e);
        }
    }

    FileView {
        path: root.home + "/.local/state/sky/colors.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.apply(text())
    }

    // The shell's own wallpaper state changed -> regenerate the palette.
    FileView {
        path: root.configHome + "/sky/wallpaper.json"
        watchChanges: true
        onFileChanged: debounce.restart()
    }

    Timer {
        id: debounce
        interval: 800
        onTriggered: regen.running = true
    }

    Process {
        id: regen
        command: ["python3", Quickshell.shellDir + "/scripts/sky_theme.py"]
    }
}
