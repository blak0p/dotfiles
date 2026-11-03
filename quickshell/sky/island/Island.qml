import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.launcher

// Top of the screen: [workspaces] [Dynamic Island] [status] as three black
// pills. The island morphs wider and downward (notifications, volume, center,
// launcher) over windows only while shown; the side pills slide aside to
// follow it. It reserves no space (Reserve.qml does), so windows never resize.
PanelWindow {
    id: win

    anchors { top: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "sky-island"
    // Focus is needed while the center or the launcher is open so the focus
    // grab holds and the search field can take the keyboard.
    WlrLayershell.keyboardFocus: (IslandState.centerOpen || IslandState.launcherOpen)
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    implicitHeight: pillTop + Config.centerMaxH + shadowPad
    color: "transparent"

    readonly property real shadowPad: 32
    readonly property real pillTop: (Config.barHeight - Config.islandH) / 2
    readonly property string mode: IslandState.mode

    // Fullscreen window on this monitor: hide everything while idle; the island
    // still pops up for volume, critical notifications or an explicit open,
    // and the window goes away once it has shrunk back.
    readonly property var mon: Hyprland.monitorFor(screen)
    readonly property bool fullscreen: mon && mon.activeWorkspace ? mon.activeWorkspace.hasFullscreen : false
    onFullscreenChanged: {
        IslandState.fullscreen = fullscreen;
        if (fullscreen) IslandState.closeTray();
    }
    Component.onCompleted: IslandState.fullscreen = fullscreen
    visible: !fullscreen || mode !== "idle" || pill.height > Config.islandH + 0.5

    // Only the pills take input; the rest of the window is click-through.
    // Panels are sized to zero while closed: Quickshell mask regions follow an
    // item's geometry, not its visibility, so an invisible panel would otherwise
    // leave a dead click zone over the windows below.
    mask: Region {
        Region { item: pill }
        Region { item: left }
        Region { item: rightRow }
        Region {
            x: upd.shown ? updPill.x : 0
            y: upd.shown ? updPill.y : 0
            width: upd.shown ? updPill.width : 0
            height: upd.shown ? updPill.height : 0
        }
        Region {
            x: IslandState.trayOpen ? tray.x : 0
            y: IslandState.trayOpen ? tray.y : 0
            width: IslandState.trayOpen ? tray.width : 0
            height: IslandState.trayOpen ? tray.height : 0
        }
    }

    // Last popup stays rendered while the island shrinks back.
    property var shownNotif: null
    Connections {
        target: Notifs
        function onCurrentChanged() { if (Notifs.current) win.shownNotif = Notifs.current; }
    }

    readonly property size target: {
        switch (mode) {
        case "launcher": return Qt.size(Config.launcherW, launcher.wantedH);
        case "center": return Qt.size(Config.centerW, center.wantedHeight);
        case "volume": return Qt.size(Config.volumeW, Config.volumeH);
        case "notif": return Qt.size(Config.notifW, popup.implicitHeight + 2 * Config.notifPad);
        default: return Qt.size((Media.playing ? Config.notchClosedW : Config.clockW) + (Notifs.unread > 0 ? 18 : 0) + win.stretch,
                                Config.islandH);
        }
    }

    // Click outside the expanded island closes whatever is open.
    HyprlandFocusGrab {
        id: grab
        windows: [win]
        onCleared: { IslandState.closeCenter(); IslandState.closeLauncher(); }
    }
    Connections {
        target: IslandState
        function onCenterOpenChanged() { grab.active = IslandState.centerOpen || IslandState.launcherOpen; }
        function onLauncherOpenChanged() { grab.active = IslandState.centerOpen || IslandState.launcherOpen; }
    }

    RectangularShadow {
        anchors.fill: pill
        radius: pill.radius
        blur: 24
        spread: 0
        offset.y: 6
        color: Qt.rgba(0, 0, 0, win.mode === "idle" ? 0 : 0.55)
        Behavior on color { ColorAnimation { duration: 250 } }
    }

    SidePill {
        id: left
        y: win.pillTop
        visible: !win.fullscreen
        x: pill.x - Config.pillGap - width
        Workspaces { id: ws; anchors.centerIn: parent; screen: win.screen }
        contentW: ws.implicitWidth
    }
    // Pending updates: a circle that the island squeezes out. The island first
    // stretches (`stretch` widens it), then the circle pops out from under its
    // edge (declared before the island, so the island covers it) while the
    // island snaps back. Going away, the island swallows it the same way.
    property real stretch: 0
    Item {
        id: updPill
        // 0 = tucked under the island, 1 = out.
        property real p: 0
        width: upd.width
        height: upd.height
        y: win.pillTop
        x: pill.x + pill.width + Config.pillGap - (1 - p) * (width + Config.pillGap + 6)
        visible: !win.fullscreen && p > 0.01
        opacity: Math.min(1, p * 2)
        scale: 0.4 + 0.6 * Math.min(1, p)
        Updates { id: upd }

        Component.onCompleted: p = upd.shown ? 1 : 0
        Connections {
            target: upd
            function onShownChanged() {
                if (upd.shown) { swallow.stop(); popOut.restart(); }
                else { popOut.stop(); swallow.restart(); }
            }
        }
        SequentialAnimation {
            id: popOut
            NumberAnimation { target: win; property: "stretch"; to: 18; duration: 220; easing.type: Easing.OutCubic }
            ParallelAnimation {
                NumberAnimation { target: updPill; property: "p"; to: 1; duration: 560; easing.type: Easing.OutBack; easing.overshoot: 1.8 }
                NumberAnimation { target: win; property: "stretch"; to: 0; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
            }
        }
        SequentialAnimation {
            id: swallow
            ParallelAnimation {
                NumberAnimation { target: updPill; property: "p"; to: 0; duration: 340; easing.type: Easing.InCubic }
                NumberAnimation { target: win; property: "stretch"; to: 14; duration: 340; easing.type: Easing.InCubic }
            }
            NumberAnimation { target: win; property: "stretch"; to: 0; duration: 380; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
        }
    }

    // Right of the island, one pill per concern: tray apps, network/
    // bluetooth/volume, AI usage and power. Empty pills (no tray apps, no
    // codexbar) are hidden and the rest slide over to close the gap.
    Row {
        id: rightRow
        y: win.pillTop
        x: pill.x + pill.width + Config.pillGap + Math.max(0, updPill.p) * (updPill.width + Config.pillGap)
        visible: !win.fullscreen
        spacing: Config.pillGap
        move: Transition { NumberAnimation { properties: "x"; duration: 250; easing.type: Easing.OutCubic } }

        SidePill {
            id: trayPill
            visible: trayS.hasContent
            Status { id: trayS; section: "tray"; anchors.centerIn: parent }
            contentW: trayS.implicitWidth
        }
        SidePill {
            id: sysPill
            Status { id: sysS; section: "system"; anchors.centerIn: parent }
            contentW: sysS.implicitWidth
        }
        SidePill {
            id: usagePill
            visible: usageS.hasContent
            Status { id: usageS; section: "usage"; anchors.centerIn: parent }
            contentW: usageS.implicitWidth
        }
        SidePill {
            id: powerPill
            Status { id: powerS; section: "power"; anchors.centerIn: parent }
            contentW: powerS.implicitWidth
        }
    }

    // Tray panel, under the tray pill and aligned to its right edge.
    TrayPanel {
        id: tray
        y: win.pillTop + Config.islandH + 10
        x: Math.max(8, Math.min(rightRow.x + trayPill.x + trayPill.width - width, win.width - width - Config.pillGap))
    }
    Connections {
        target: IslandState
        function onTrayOpenChanged() { if (!IslandState.trayOpen) tray.hovered = ""; }
    }

    Rectangle {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        y: win.pillTop
        width: win.target.width
        height: win.target.height
        radius: Math.min(height / 2, Config.islandRadius)
        color: "#000000"
        border.width: 1
        border.color: Qt.alpha(Theme.accent, win.mode === "idle" ? 0.35 : 0.18)
        clip: true

        Behavior on width { enabled: !popOut.running && !swallow.running; NumberAnimation { duration: Config.morphMs; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
        Behavior on height {
            NumberAnimation {
                // The launcher resizes while typing: keep it calm instead of
                // the island's overshooting morph.
                duration: win.mode === "launcher" ? 220 : Config.morphMs
                easing.type: win.mode === "launcher" ? Easing.OutCubic : Easing.OutBack
                easing.overshoot: 0.9
            }
        }

        HoverHandler { onHoveredChanged: Notifs.hovered = hovered }

        // Click opens the control center (wifi, bluetooth, volume, …) as
        // before. The launcher is keyboard-only: Super+Space or its IPC call.
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (IslandState.launcherOpen) IslandState.closeLauncher();
                else if (win.mode !== "center") IslandState.openCenter("notifs");
            }
        }

        // Each view is laid out at its final size and centred at the top of the
        // pill, so the content never reflows while the shape morphs (clip does the reveal).
        View {
            shown: win.mode === "idle"
            width: pill.width; height: Config.islandH
            IdleView { id: idleView; anchors.fill: parent }
        }
        View {
            shown: win.mode === "volume"
            width: Config.volumeW; height: Config.volumeH
            VolumeView { anchors.fill: parent }
        }
        View {
            shown: win.mode === "notif"
            width: Config.notifW; height: popup.implicitHeight + 2 * Config.notifPad
            NotifCard {
                id: popup
                anchors.fill: parent
                anchors.margins: Config.notifPad
                anchors.leftMargin: Config.notifPad + 2
                notif: win.shownNotif
            }
        }
        View {
            shown: win.mode === "launcher"
            width: Config.launcherW; height: launcher.wantedH
            Launcher { id: launcher; anchors.fill: parent; open: win.mode === "launcher" }
        }
        View {
            shown: win.mode === "center"
            width: Config.centerW; height: center.wantedHeight
            CenterView { id: center; anchors.fill: parent }
        }
    }

    component View: Item {
        property bool shown: false
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        visible: opacity > 0
        opacity: shown ? 1 : 0
        scale: shown ? 1 : 0.92
        transformOrigin: Item.Top
        Behavior on opacity { NumberAnimation { duration: shown ? 260 : 120; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    }
}
