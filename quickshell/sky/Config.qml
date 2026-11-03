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

    readonly property real dockMargin: 8
    readonly property real dockH: 48          // dock height when revealed (items + padding)
    readonly property real dockPadX: 14
    readonly property real dockOpenW: 700
    readonly property real launcherH: 452     // extra height when the launcher is open
    readonly property real itemSize: 36

    // System tray panel (island/TrayPanel.qml), opened from the status pill.
    readonly property real trayItem: 28
    readonly property real trayGap: 6
    readonly property real trayPad: 12
    readonly property real trayMinW: 168
    readonly property int trayCols: 6            // cells per row before wrapping
    readonly property int trayInline: 3          // tray apps shown in the pill; the rest go behind the chevron
    readonly property real dockHotZone: 6     // hover strip at the bottom edge that reveals the dock
    readonly property int dockHideMs: 400

    // AI plan usage (UsageService.qml, needs the `codexbar` CLI): providers in
    // display order, background refresh, and refresh while the page is open.
    readonly property var usageProviders: ["claude", "codex", "antigravity"]
    readonly property int usageIdleMs: 600000
    readonly property int usageOpenMs: 60000

    readonly property int animMs: 450
    readonly property list<real> bezier: [0.2, 0.9, 0.25, 1.0, 1, 1]

    // Desktop-entry ids pinned in the dock, in order. This is only the seed used
    // when no persisted list exists yet; runtime edits live in DockPins.
    readonly property var defaultPinned: ["org.kde.dolphin", "kitty", "zen", "firefox", "steam", "vesktop", "spotify", "obsidian"]
}
