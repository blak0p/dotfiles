import QtQuick
import Quickshell
import qs

// One-line media strip that fits inside the bar.
Item {
    id: root
    readonly property var p: Media.player

    Row {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 12
        spacing: 10

        Rectangle {
            id: art
            width: 20; height: 20; radius: 6
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.accent
            clip: true
            Image {
                anchors.fill: parent
                source: root.p && root.p.trackArtUrl ? root.p.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }

        Text {
            width: parent.width - art.width - ctrl.width - parent.spacing * 2
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            textFormat: Text.StyledText
            text: !root.p ? "Nothing playing"
                : "<b>" + (root.p.trackTitle || "Unknown") + "</b>"
                  + ((root.p.trackArtist || root.p.identity) ? "<font color=\"" + Theme.muted + "\">  " + (root.p.trackArtist || root.p.identity) + "</font>" : "")
            color: Theme.fg
            font.family: "Google Sans Flex"; font.pixelSize: 13
        }

        Row {
            id: ctrl
            spacing: 6
            anchors.verticalCenter: parent.verticalCenter
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                text: "skip_previous"; fill: 1
                MouseArea { anchors.fill: parent; onClicked: if (root.p) root.p.previous() }
            }
            Rectangle {
                width: 22; height: 22; radius: 11
                color: Theme.accent
                Icon {
                    anchors.centerIn: parent
                    text: Media.playing ? "pause" : "play_arrow"; fill: 1
                    color: Theme.accentText
                }
                MouseArea { anchors.fill: parent; onClicked: if (root.p) root.p.togglePlaying() }
            }
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                text: "skip_next"; fill: 1
                MouseArea { anchors.fill: parent; onClicked: if (root.p) root.p.next() }
            }
        }
    }
}
