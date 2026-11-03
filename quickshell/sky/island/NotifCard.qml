import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs

// One notification: icon, app + age, summary, body, actions.
// Used by the popup (full body) and by the center list (compact).
Item {
    id: root
    required property var notif
    property bool compact: false

    readonly property bool critical: notif && notif.urgency === NotificationUrgency.Critical
    readonly property var buttons: notif ? notif.actions.filter(a => a.identifier !== "default" && a.text) : []

    implicitHeight: col.implicitHeight

    Rectangle {
        id: icon
        width: root.compact ? 32 : 40
        height: width
        radius: 12
        color: Theme.surface2
        clip: true
        Image {
            id: img
            anchors.fill: parent
            source: Notifs.iconFor(root.notif)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize: Qt.size(80, 80)
        }
        Icon {
            anchors.centerIn: parent
            visible: img.status !== Image.Ready
            text: root.critical ? "priority_high" : "notifications"
            color: root.critical ? "#ff8a80" : Theme.accent
            font.pixelSize: 20
            fill: 1
        }
    }

    Column {
        id: col
        anchors.left: icon.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        spacing: 2

        Row {
            width: parent.width
            spacing: 6
            Text {
                text: root.notif ? (root.notif.appName || "Notification") : ""
                color: Theme.muted
                font.family: "Google Sans Flex"; font.pixelSize: 11
                elide: Text.ElideRight
                width: Math.min(implicitWidth, parent.width - age.width - close.width - 12)
            }
            Text {
                id: age
                text: "· " + Notifs.ago(root.notif)
                color: Theme.muted
                font.family: "Google Sans Flex"; font.pixelSize: 11
            }
        }

        Text {
            width: parent.width - close.width
            text: root.notif ? root.notif.summary : ""
            color: root.critical ? "#ff8a80" : Theme.fg
            font.family: "Google Sans Flex"; font.pixelSize: 14; font.weight: Font.DemiBold
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        Text {
            width: parent.width
            visible: text !== ""
            text: root.notif ? root.notif.body : ""
            textFormat: Text.StyledText
            color: Qt.alpha(Theme.fg, 0.8)
            font.family: "Google Sans Flex"; font.pixelSize: 12
            wrapMode: Text.Wrap
            elide: Text.ElideRight
            maximumLineCount: root.compact ? 1 : 3
            onLinkActivated: link => Qt.openUrlExternally(link)
        }

        Item { width: 1; height: root.buttons.length && !root.compact ? 6 : 0 }

        Row {
            visible: root.buttons.length > 0 && !root.compact
            spacing: 6
            Repeater {
                model: root.buttons
                delegate: Rectangle {
                    required property var modelData
                    height: 26
                    width: label.implicitWidth + 24
                    radius: 13
                    color: ma.containsMouse ? Qt.alpha(Theme.accent, 0.3) : Qt.alpha(Theme.accent, 0.16)
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text {
                        id: label
                        anchors.centerIn: parent
                        text: modelData.text
                        color: Theme.accent
                        font.family: "Google Sans Flex"; font.pixelSize: 12; font.weight: Font.DemiBold
                    }
                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: modelData.invoke()
                    }
                }
            }
        }
    }

    // Whole card runs the default action; z: -1 keeps it under the buttons.
    MouseArea {
        anchors.fill: parent
        z: -1
        cursorShape: Qt.PointingHandCursor
        onClicked: Notifs.activate(root.notif)
    }

    Icon {
        id: close
        anchors.right: parent.right
        anchors.top: parent.top
        text: "close"
        color: closeMa.containsMouse ? Theme.fg : Theme.muted
        font.pixelSize: 16
        MouseArea {
            id: closeMa
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Notifs.dismiss(root.notif)
        }
    }
}
