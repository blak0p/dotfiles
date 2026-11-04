import QtQuick
import qs

// Volume OSD: icon, animated level bar, percentage. Click/drag the bar to set it.
Item {
    id: root
    readonly property real v: IslandState.volume
    readonly property bool muted: IslandState.muted

    Icon {
        id: icon
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: root.muted ? "volume_off" : (root.v < 0.01 ? "volume_mute" : (root.v < 0.5 ? "volume_down" : "volume_up"))
        color: root.muted ? Theme.muted : Theme.accent
        font.pixelSize: 20
        fill: 1
        // Small pop on every change.
        scale: 1
        Behavior on text {
            SequentialAnimation {
                NumberAnimation { target: icon; property: "scale"; to: 1.25; duration: 90; easing.type: Easing.OutCubic }
                PropertyAction {}
                NumberAnimation { target: icon; property: "scale"; to: 1; duration: 220; easing.type: Easing.OutBack }
            }
        }
        MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: IslandState.toggleMute() }
    }

    Rectangle {
        id: track
        anchors.left: icon.right
        anchors.leftMargin: 12
        anchors.right: pct.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        height: 6
        radius: 3
        color: Qt.alpha(Theme.fg, 0.14)

        Rectangle {
            id: fill
            height: parent.height
            radius: parent.radius
            width: parent.width * (root.muted ? 0 : Math.min(root.v, 1))
            color: root.muted ? Theme.muted : Theme.accent
            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 180 } }
        }
        // Glowing knob at the end of the fill.
        Rectangle {
            width: 12; height: 12; radius: 6
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, fill.width - width / 2)
            color: Theme.fg
            opacity: root.muted ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -10
            cursorShape: Qt.PointingHandCursor
            function apply(x) { IslandState.setVolume((x - 10) / track.width); IslandState.showOsd(); }
            onPressed: m => apply(m.x)
            onPositionChanged: m => { if (pressed) apply(m.x); }
        }
    }

    Text {
        id: pct
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        width: 34
        horizontalAlignment: Text.AlignRight
        text: root.muted ? "0" : Math.round(root.v * 100)
        color: Theme.fg
        font.family: "Google Sans Flex"; font.pixelSize: 13; font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
    }
}
