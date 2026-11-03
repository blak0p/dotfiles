import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.dock

// Per screen: the top reserve and the auto-hiding dock (+ launcher).
// The top pills and the Dynamic Island live in island/Island.qml.
Scope {
    id: root
    required property var modelData
    readonly property var screen: modelData
    readonly property bool launcherHere: ShellState.launcherOpen && ShellState.launcherScreen === screen.name

    // Invisible window that only reserves space for the top pills.
    Reserve { screen: root.screen; edge: "top"; zone: Config.barHeight }

    // Dock reveal: hover the bottom strip (or the dock itself), or open the launcher.
    readonly property bool dockWanted: launcherHere || dockHot.hovered || dock.hovered || dockMenu.opened || dockMenu.hovered
    property bool dockShown: false
    onLauncherHereChanged: if (launcherHere) dockMenu.close()
    onDockWantedChanged: {
        if (dockWanted) { hideTimer.stop(); dockShown = true; }
        else hideTimer.restart();
    }
    Timer { id: hideTimer; interval: Config.dockHideMs; onTriggered: { root.dockShown = false; dockMenu.close(); } }

    PanelWindow {
        id: win
        screen: root.screen
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "sky-dock"
        WlrLayershell.keyboardFocus: root.launcherHere ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: "transparent"

        // Only the dock and its hot strip take input; while the launcher is
        // open the whole screen is ours (click outside closes).
        mask: (root.launcherHere || dockMenu.opened) ? fullMask : partsMask
        Region { id: fullMask; item: scene }
        Region {
            id: partsMask
            Region { item: dock }
            Region { item: hotZone }
            Region { item: dockMenu }
        }

        Item {
            id: scene
            anchors.fill: parent

            MouseArea {
                anchors.fill: parent
                enabled: root.launcherHere || dockMenu.opened
                onClicked: {
                    if (root.launcherHere) ShellState.closeLauncher();
                    if (dockMenu.opened) dockMenu.close();
                }
            }

            Item {
                id: hotZone
                width: Math.max(dock.closedW, 200)
                height: Config.dockHotZone
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                HoverHandler { id: dockHot }
            }

            Dock {
                id: dock
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Config.dockMargin
                open: root.launcherHere
                shown: root.dockShown
                onItemContextRequested: (delegateItem, item) => {
                    const p = delegateItem.mapToItem(scene, delegateItem.width / 2, 0);
                    dockMenu.anchorX = p.x;
                    dockMenu.open(item);
                }
            }

            DockMenu {
                id: dockMenu
                z: 10
                anchors.bottom: dock.top
                anchors.bottomMargin: 8
                onClosed: { }
            }
        }
    }
}
