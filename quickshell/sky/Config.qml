pragma Singleton
import Quickshell

Singleton {
    // Monitor that hosts the shell; falls back to every screen if it is absent.
    readonly property string screen: "DP-2"

    readonly property real barHeight: 38

    // Dynamic Island (island/): its own overlay window. Idle it is a pill of
    // islandH centred in the bar; other views grow it wider and downward.
    readonly property real islandH: 30
    readonly property real islandRadius: 26
    readonly property real pillGap: 8          // between the island and the side pills
    readonly property real clockW: 96
    readonly property real notchClosedW: 140
    readonly property real volumeW: 340
    readonly property real volumeH: 44
    readonly property real notifW: 440
    readonly property real notifPad: 14
    readonly property real centerW: 460
    readonly property real centerMaxH: 560
    readonly property real islandMaxW: 480
    readonly property int morphMs: 520
    readonly property int osdMs: 1600
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

    // System tray panel (island/TrayPanel.qml), opened from the status pill.
    readonly property real trayItem: 28
    readonly property real trayGap: 6
    readonly property real trayPad: 12
    readonly property real trayMinW: 168
    readonly property int trayCols: 6            // cells per row before wrapping
    readonly property int trayInline: 3          // tray apps shown in the pill; the rest go behind the chevron

    // AI plan usage (UsageService.qml, needs the `codexbar` CLI): providers in
    // display order, background refresh, and refresh while the page is open.
    readonly property var usageProviders: ["claude", "codex", "antigravity"]
    readonly property int usageIdleMs: 600000
    readonly property int usageOpenMs: 60000

    readonly property int animMs: 450
    readonly property list<real> bezier: [0.2, 0.9, 0.25, 1.0, 1, 1]
}
