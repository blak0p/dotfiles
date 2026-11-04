import QtQuick
import qs

// Black pill beside the island (workspaces, status).
Rectangle {
    property real contentW: 0
    width: contentW + 2 * 12
    height: Config.islandH
    radius: height / 2
    color: "#000000"
    border.width: 1
    border.color: Qt.alpha(Theme.accent, 0.25)
    Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
}
