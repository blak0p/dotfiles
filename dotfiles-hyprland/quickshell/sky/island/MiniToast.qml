import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

// Discreet top-right toast for notifications that arrive while a fullscreen
// window is up: one line, translucent, gone after Config.toastMs.
// The notification stays in the history (unread) either way.
PanelWindow {
    id: win

    anchors { top: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "sky-toast"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    implicitWidth: Config.toastW + 2 * Config.toastMargin
    implicitHeight: Config.toastH + 2 * Config.toastMargin
    color: "transparent"
    visible: shown || card.opacity > 0

    property var notif: null
    property bool shown: false

    // Click dismisses the toast; nothing else takes input.
    mask: Region { item: shown ? card : null }

    Connections {
        target: Notifs
        function onQuiet(n) {
            win.notif = n;
            win.shown = true;
            hide.restart();
        }
    }
    Connections {
        target: IslandState
        function onFullscreenChanged() { if (!IslandState.fullscreen) win.shown = false; }
    }

    Timer { id: hide; interval: Config.toastMs; onTriggered: win.shown = false }

    Rectangle {
        id: card
        y: Config.toastMargin
        x: Config.toastMargin + (win.shown ? 0 : 40)
        width: Config.toastW
        height: Config.toastH
        radius: 22
        color: Qt.rgba(0, 0, 0, 0.85)
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.35)
        opacity: win.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: win.shown ? 180 : 260 } }
        Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

        Rectangle {
            id: icon
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            width: parent.height - 20; height: width
            radius: 12
            color: Theme.surface2
            clip: true
            Image {
                id: img
                anchors.fill: parent
                source: Notifs.iconFor(win.notif)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize: Qt.size(96, 96)
            }
            Icon {
                anchors.centerIn: parent
                visible: img.status !== Image.Ready
                text: "notifications"
                color: Theme.accent
                font.pixelSize: 20
                fill: 1
            }
        }

        Column {
            anchors.left: icon.right; anchors.leftMargin: 12
            anchors.right: parent.right; anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
                width: parent.width
                elide: Text.ElideRight
                textFormat: Text.StyledText
                text: !win.notif ? ""
                    : "<font color=\"" + Theme.muted + "\">" + (win.notif.appName || "Notification") + " &nbsp;·&nbsp; </font>"
                      + "<b>" + (win.notif.summary || "") + "</b>"
                color: Theme.fg
                font.family: "Google Sans Flex"; font.pixelSize: 14
            }
            Text {
                width: parent.width
                visible: text !== ""
                elide: Text.ElideRight
                maximumLineCount: 1
                textFormat: Text.StyledText
                text: win.notif ? win.notif.body.replace(/\n/g, " ") : ""
                color: Qt.alpha(Theme.fg, 0.8)
                font.family: "Google Sans Flex"; font.pixelSize: 13
            }
        }

        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.shown = false }
    }
}
