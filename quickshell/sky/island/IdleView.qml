import QtQuick
import Quickshell
import qs

Item {
    id: idle

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Row {
        anchors.centerIn: parent
        spacing: 10

        Row {
            id: eq
            visible: Media.playing
            spacing: 2
            height: 12
            anchors.verticalCenter: parent.verticalCenter
            Repeater {
                model: [6, 11, 8, 4]
                delegate: Rectangle {
                    required property int modelData
                    required property int index
                    width: 3
                    radius: 2
                    color: Theme.accent
                    anchors.bottom: parent.bottom
                    height: modelData
                    SequentialAnimation on height {
                        running: eq.visible
                        loops: Animation.Infinite
                        NumberAnimation { to: 12; duration: 380 + index * 70; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 3; duration: 380 + index * 70; easing.type: Easing.InOutSine }
                    }
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatTime(clock.date, "HH:mm")
            color: Theme.fg
            font.family: "Google Sans Flex"
            font.pixelSize: 15
            font.weight: Font.Bold
        }

        // Unread notifications.
        Rectangle {
            visible: Notifs.unread > 0
            anchors.verticalCenter: parent.verticalCenter
            width: 8; height: 8; radius: 4
            color: Theme.accent
            SequentialAnimation on opacity {
                running: parent.visible
                loops: Animation.Infinite
                NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
            }
        }
    }
}
