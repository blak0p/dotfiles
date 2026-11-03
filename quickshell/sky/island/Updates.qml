import QtQuick
import qs

// Updates bubble beside the island: a black circle with a download glyph and
// the pending count as a badge; a spinner while the updater terminal is open
// and a short check when it is done. Clicking it runs the updaters.
Rectangle {
    id: root

    readonly property bool busy: UpdateService.isUpdating || UpdateService.isVerifying
    readonly property bool done: UpdateService.justFinished && !busy
    readonly property bool shown: UpdateService.totalCount > 0 || busy || done
    readonly property bool hovered: ma.containsMouse

    width: Config.islandH
    height: Config.islandH
    radius: width / 2
    color: "#000000"
    border.width: 1
    border.color: Qt.alpha(Theme.accent, hovered ? 0.7 : 0.25)
    Behavior on border.color { ColorAnimation { duration: 140 } }

    Icon {
        id: glyph
        anchors.centerIn: parent
        text: root.busy ? "progress_activity" : root.done ? "check_circle" : "download"
        color: root.done ? Theme.tertiary : Theme.accent
        fill: root.hovered ? 1 : 0
        font.pixelSize: 16

        RotationAnimation on rotation {
            running: root.busy
            loops: Animation.Infinite
            from: 0; to: 360
            duration: 900
            onRunningChanged: if (!running) glyph.rotation = 0
        }
    }

    // Pending count, hanging off the bottom-right edge.
    Rectangle {
        visible: !root.busy && !root.done && UpdateService.totalCount > 0
        x: parent.width - width + 4
        y: parent.height - height + 3
        width: Math.max(height, countText.implicitWidth + 6)
        height: 13
        radius: height / 2
        color: Theme.accent
        border.width: 1.5
        border.color: "#000000"
        Text {
            id: countText
            anchors.centerIn: parent
            text: UpdateService.totalCount
            color: Theme.accentText
            font.family: "Google Sans Flex"
            font.pixelSize: 9
            font.weight: Font.Bold
            font.features: { "tnum": 1 }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.busy ? Qt.BusyCursor : Qt.PointingHandCursor
        onClicked: if (!root.busy) UpdateService.applyAll()
    }
}
