import QtQuick
import qs
import qs.settings

// "Clip saved" pop of the instant replay (IslandState.showClip). With a saved
// clip, a click opens the clips gallery in the settings window.
Item {
    id: root
    readonly property bool hasClip: IslandState.clipPath !== ""
    readonly property string fileName: hasClip ? IslandState.clipPath.split("/").pop() : ""

    Icon {
        id: icon
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        text: root.hasClip ? "movie" : "videocam_off"
        color: root.hasClip ? Theme.accent : Theme.muted
        font.pixelSize: 20
        fill: 1
    }

    Column {
        anchors.left: icon.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0
        Text {
            width: parent.width
            text: IslandState.clipText
            elide: Text.ElideRight
            color: Theme.fg
            font.family: "Google Sans Flex"; font.pixelSize: 13; font.weight: Font.DemiBold
        }
        Text {
            visible: root.hasClip
            width: parent.width
            text: root.fileName
            elide: Text.ElideMiddle
            color: Theme.muted
            font.family: "Google Sans Flex"; font.pixelSize: 11
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.hasClip
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            IslandState.clipVisible = false;
            SettingsState.open("replay");
        }
    }
}
