import QtQuick
import Quickshell
import qs
import qs.launcher

// Floating dock (black pill like the top ones). Hidden by default; `shown`
// slides it up. When `open`, it widens and grows upward to host the launcher.
Item {
    id: root
    property bool open: false
    property bool shown: false
    readonly property bool hovered: hover.hovered
    property real launcherH: open ? Config.launcherH : 0
    property real reveal: shown || open ? 1 : 0

    signal itemContextRequested(var delegateItem, var item)

    readonly property real closedW: row.implicitWidth + Config.dockPadX * 2
    width: open ? Config.dockOpenW : closedW
    height: Config.dockH * reveal + launcherH
    clip: true

    HoverHandler { id: hover }

    Rectangle {
        anchors.fill: parent
        radius: 22
        color: "#000000"
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.25)
        opacity: root.reveal
        visible: opacity > 0
    }

    Behavior on reveal { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    Behavior on launcherH { NumberAnimation { duration: 500; easing.type: Easing.BezierSpline; easing.bezierCurve: Config.bezier } }
    Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.BezierSpline; easing.bezierCurve: Config.bezier } }

    Item {
        id: lp
        width: parent.width
        height: root.launcherH
        clip: true
        opacity: root.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
        Launcher {
            width: Config.dockOpenW
            height: Config.launcherH
            anchors.horizontalCenter: parent.horizontalCenter
            open: root.open
            onItemContextRequested: (d, it) => root.itemContextRequested(d, it)
        }
    }

    Row {
        id: row
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6 - Config.dockH * (1 - root.reveal)
        spacing: 6

        Rectangle {
            width: Config.itemSize; height: Config.itemSize; radius: 11
            color: root.open ? Theme.accent : Theme.surface2
            Behavior on color { ColorAnimation { duration: 200 } }
            Icon {
                anchors.centerIn: parent
                text: "apps"; fill: 1
                color: root.open ? Theme.accentText : Theme.fg
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ShellState.toggleLauncher() }
        }
        Rectangle {
            width: 1; height: 24
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.outline
            opacity: 0.4
        }
        Repeater {
            model: AppModel.dockItems
            delegate: DockItem {
                dockRoot: row
                onContextRequested: root.itemContextRequested(this, modelData)
            }
        }
    }
}
