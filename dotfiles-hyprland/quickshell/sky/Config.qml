pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Per-user choices live in the user layer, outside the repo:
    // $XDG_CONFIG_HOME/sky/settings.json, e.g. { "screen": "DP-1", "language": "es" }.
    // Missing file or keys -> the defaults below.
    readonly property string userFile: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/sky/settings.json"
    property var user: ({})

    FileView {
        path: root.userFile
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const o = JSON.parse(text());
                root.user = (o && typeof o === "object") ? o : {};
            } catch (e) {
                console.warn("sky: bad settings.json:", e);
                root.user = {};
            }
        }
        onLoadFailed: root.user = {}
    }

    // Monitor that hosts the shell; empty -> every screen (shell.qml) or the
    // first one (dialogs).
    readonly property string screen: typeof user.screen === "string" ? user.screen : ""

    // UI language (I18n.qml): "auto" follows LANG, or force "en" / "es".
    readonly property string language: typeof user.language === "string" && user.language ? user.language : "auto"

    readonly property real barHeight: 38

    // Dynamic Island (island/): its own overlay window. Idle it is a pill of
    // islandH centred in the bar; other views grow it wider and downward.
    readonly property real islandH: 30
    readonly property real islandRadius: 26
    readonly property real pillGap: 8          // between the island and the side pills
    readonly property real clockW: 96
    readonly property real notchMusicW: 220     // idle with music: cover + title + clock
    readonly property real volumeW: 340
    readonly property real volumeH: 44
    readonly property real notifW: 440
    readonly property real notifPad: 14
    readonly property real centerW: 460
    readonly property real centerMaxH: 560
    readonly property real islandMaxW: 480
    readonly property int morphMs: 520
    readonly property int osdMs: 1600
    // "Clip saved" pop of the instant replay.
    readonly property real clipW: 360
    readonly property real clipH: 48
    readonly property int clipMs: 2600
    // Pop with a saved clip: thumbnail, name and actions.
    readonly property real clipCardW: 440
    readonly property real clipCardH: 104
    readonly property int clipActionsMs: 6000
    readonly property int notifMs: 5000
    // Fullscreen toast (island/MiniToast.qml).
    readonly property real toastW: 400
    readonly property real toastH: 66
    readonly property real toastMargin: 14
    readonly property int toastMs: 3500

    // Launcher (launcher/Launcher.qml): compact dropdown that grows out of the
    // island pill. Search + result rows + an inline calculator.
    readonly property real launcherW: 520
    readonly property real launcherMaxH: 372     // list is capped and scrolls past this
    readonly property real launcherPad: 10
    readonly property real launcherInputH: 42
    readonly property real launcherRowH: 38
    readonly property int launcherGap: 8

    // Wallpapers (wallpaper/WallpaperView.qml): a horizontal strip of pictures
    // that grows out of the clock pill and slides with the arrow keys. It is
    // only there to pick a wallpaper, so it is allowed to be wide.
    readonly property real wallpaperMaxW: 1400
    readonly property real wallpaperH: 260
    readonly property real wallpaperPad: 16
    readonly property real cardW: 368
    readonly property real cardH: 207
    readonly property int cardGap: 16

    // System tray panel (island/TrayPanel.qml), opened from the status pill.
    readonly property real trayItem: 28
    readonly property real trayGap: 6
    readonly property real trayPad: 12
    readonly property real trayMinW: 168
    readonly property int trayCols: 6            // cells per row before wrapping
    readonly property int trayInline: 3          // tray apps shown in the pill; the rest go behind the chevron
    // StatusNotifierItem ids never shown in the tray. The app keeps running
    // (e.g. blueman-applet still handles pairing prompts and notifications);
    // only its icon is dropped. Bluetooth already lives in the system pill.
    readonly property var trayHidden: ["blueman"]
    function trayVisible(items) {
        return items.filter(it => !trayHidden.includes(it.id));
    }

    // AI plan usage (UsageService.qml, needs the `codexbar` CLI): providers in
    // display order, background refresh, and refresh while the page is open.
    readonly property var usageProviders: ["claude", "codex", "antigravity"]
    readonly property int usageIdleMs: 600000
    readonly property int usageOpenMs: 60000

    readonly property int animMs: 450
    readonly property list<real> bezier: [0.2, 0.9, 0.25, 1.0, 1, 1]
}
