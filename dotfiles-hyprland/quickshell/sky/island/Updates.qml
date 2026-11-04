import QtQuick
import qs

// Updates bubble beside the island: a black pill with a download glyph and the
// pending count *inside* it; a spinner while the updater terminal is open and a
// short check when it is done. Clicking it runs the updaters.
Rectangle {
    id: root

    readonly property bool busy: UpdateService.isUpdating || UpdateService.isVerifying
    readonly property bool done: UpdateService.justFinished && !busy
    readonly property bool showCount: !busy && !done && UpdateService.totalCount > 0
    readonly property bool shown: UpdateService.totalCount > 0 || busy || done
    readonly property bool hovered: ma.containsMouse

    width: Math.max(Config.islandH, row.implicitWidth + 24)
    height: Config.islandH
    radius: height / 2
    color: "#000000"
    border.width: 1
    border.color: Qt.alpha(Theme.accent, hovered ? 0.7 : 0.25)
    Behavior on border.color { ColorAnimation { duration: 140 } }
    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: root.showCount ? 6 : 0

        Icon {
            id: glyph
            anchors.verticalCenter: parent.verticalCenter
            text: root.busy ? "progress_activity" : root.done ? "check_circle" : "download"
            color: root.done ? Theme.tertiary : Theme.accent
            fill: 1
            font.pixelSize: 18

            RotationAnimation on rotation {
                running: root.busy
                loops: Animation.Infinite
                from: 0; to: 360
                duration: 900
                onRunningChanged: if (!running) glyph.rotation = 0
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showCount
            width: visible ? implicitWidth : 0
            text: UpdateService.totalCount
            color: Theme.accent
            font.family: "Google Sans Flex"
            font.pixelSize: 14
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
