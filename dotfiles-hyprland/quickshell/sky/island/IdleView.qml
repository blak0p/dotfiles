import QtQuick
import Quickshell
import qs

// Idle island: the clock. While music plays the pill widens (Island.qml) and
// shows the round cover and title on the left; clicks there open Music.
Item {
    id: idle

    readonly property bool music: Media.playing && !!Media.player
    // Right edge of the cover + title, for click routing in Island.qml.
    readonly property real musicZoneW: music ? track.x + track.width + 6 : 0

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Rectangle {
        id: cover
        visible: idle.music
        x: 4
        anchors.verticalCenter: parent.verticalCenter
        width: 22; height: 22; radius: 11
        color: Theme.accent
        clip: true
        Image {
            anchors.fill: parent
            source: Media.player && Media.player.trackArtUrl ? Media.player.trackArtUrl : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }

    Text {
        id: track
        visible: idle.music
        anchors.left: cover.right; anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, Math.max(0, right.x - x - 10))
        text: Media.player ? (Media.player.trackTitle || I18n.t("Unknown")) : ""
        elide: Text.ElideRight
        color: Theme.fg
        font.family: "Google Sans Flex"; font.pixelSize: 13; font.weight: Font.DemiBold
    }

    Row {
        id: right
        spacing: 10
        anchors.verticalCenter: parent.verticalCenter
        x: idle.music ? parent.width - width - 14 : (parent.width - width) / 2

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
            font.pixelSize: idle.music ? 16 : 15
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

        // Instant replay buffer is recording (ReplayService); click saves a clip.
        Rectangle {
            visible: ReplayService.active
            anchors.verticalCenter: parent.verticalCenter
            width: 8; height: 8; radius: 4
            color: "#ff5a5f"
            border.width: 2
            border.color: Qt.alpha("#ff5a5f", 0.35)
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: ReplayService.save()
            }
        }
    }
}
