pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs

// What the island shows. Priority: launcher > center (user opened) > clip
// saved > volume > notification > idle.
Singleton {
    id: root

    property bool launcherOpen: false
    property bool centerOpen: false
    property bool wallpaperOpen: false
    property bool trayOpen: false
    property bool osdVisible: false
    // "Clip saved" pop (ReplayService): clipPath is the saved file, or "" for
    // a status message such as "Replay is off".
    property bool clipVisible: false
    property string clipPath: ""
    property string clipText: ""
    // The shell's monitor shows a fullscreen window (set by Island.qml):
    // the top pills hide and only critical notifications / volume pop up.
    property bool fullscreen: false

    readonly property string mode: launcherOpen ? "launcher"
        : wallpaperOpen ? "wallpaper"
        : centerOpen ? "center"
        : clipVisible ? "clip"
        : osdVisible ? "volume"
        : Notifs.current ? "notif"
        : "idle"

    // ---- Launcher ----
    // Keyboard-only: Super+Space (Hyprland global shortcut) or the `launcher`
    // IPC call. The island pill keeps opening the control center.
    function toggleLauncher() { launcherOpen ? closeLauncher() : openLauncher(); }
    function openLauncher() {
        launcherOpen = true;
        centerOpen = false;
        wallpaperOpen = false;
        trayOpen = false;
        osdVisible = false;
    }
    function closeLauncher() { launcherOpen = false; }

    // ---- Wallpapers ----
    // The picker is another island view: it grows out of the clock pill
    // (Island.qml), so it has no window of its own and no chrome.
    function toggleWallpaper() { wallpaperOpen ? closeWallpaper() : openWallpaper(); }
    function openWallpaper() {
        wallpaperOpen = true;
        centerOpen = false;
        launcherOpen = false;
        trayOpen = false;
        osdVisible = false;
    }
    function closeWallpaper() { wallpaperOpen = false; }

    // Center page. Tabbed modules: "notifs" (quick settings), "perf", "music";
    // single pages: "wifi" | "bluetooth" | "sound" | "power" | "usage".
    property string page: "notifs"

    function toggleCenter() { centerOpen ? closeCenter() : openCenter("notifs"); }
    function openCenter(p) {
        page = p || "notifs";
        centerOpen = true;
        launcherOpen = false;
        wallpaperOpen = false;
        trayOpen = false;
        osdVisible = false;
        if (page === "notifs") Notifs.markRead();
    }
    function closeCenter() { centerOpen = false; }
    // Bar buttons: open that page, or close if it is already showing.
    function togglePage(p) { centerOpen && page === p ? closeCenter() : openCenter(p); }

    // ---- System tray ----
    // One chevron in the status pill; the panel lists every tray app.
    function toggleTray() { trayOpen ? closeTray() : openTray(); }
    function openTray() {
        trayOpen = true;
        centerOpen = false;
        launcherOpen = false;
        wallpaperOpen = false;
        osdVisible = false;
    }
    function closeTray() { trayOpen = false; }

    // ---- Volume ----
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: sink && sink.audio ? sink.audio : null
    readonly property real volume: audio ? audio.volume : 0
    readonly property bool muted: audio ? audio.muted : true

    PwObjectTracker { objects: root.sink ? [root.sink] : [] }

    function setVolume(v) {
        if (!audio) return;
        audio.muted = false;
        audio.volume = Math.max(0, Math.min(1.0, v));
    }
    function stepVolume(delta) { setVolume(volume + delta); }
    function toggleMute() { if (audio) audio.muted = !audio.muted; }

    function showOsd() {
        if (!armed.done || centerOpen || launcherOpen || wallpaperOpen) return;
        trayOpen = false;
        osdVisible = true;
        osdTimer.restart();
    }

    // ---- Replay clips ----
    function showClip(path, text) {
        if (launcherOpen || wallpaperOpen || centerOpen) return;
        trayOpen = false;
        osdVisible = false;
        clipPath = path || "";
        clipText = text || "";
        clipVisible = true;
        clipTimer.restart();
    }
    Timer { id: clipTimer; interval: Config.clipMs; onTriggered: root.clipVisible = false }

    Timer { id: osdTimer; interval: Config.osdMs; onTriggered: root.osdVisible = false }

    // Ignore the initial volume/mute values Pipewire reports at startup or
    // when the default sink changes; only real changes open the OSD.
    Timer {
        id: armed
        property bool done: false
        interval: 1500
        running: true
        onTriggered: done = true
    }
    onSinkChanged: { armed.done = false; armed.restart(); }

    Connections {
        target: root.audio
        function onVolumeChanged() { root.showOsd(); }
        function onMutedChanged() { root.showOsd(); }
    }
}
