import QtQuick
import qs
import qs.settings

// Instant replay pop (IslandState.showClip). A status message ("Replay is
// off", "Instant replay on"...) is one line; a saved clip is a Medal-style
// card: thumbnail, name and actions (play, copy, folder, gallery, delete).
// Hovering keeps it open (IslandState.clipHold).
Item {
    id: root
    readonly property bool hasClip: IslandState.clipPath !== ""
    readonly property string path: IslandState.clipPath
    readonly property string fileName: hasClip ? path.split("/").pop() : ""
    // Delete takes two clicks: the first one arms it.
    property bool armDelete: false
    // Name of the action under the pointer, shown instead of the file name.
    property string hoverTip: ""
    function hint(a) { if (a.hovered) hoverTip = a.tip; else if (hoverTip === a.tip) hoverTip = ""; }
    onPathChanged: armDelete = false

    HoverHandler { onHoveredChanged: IslandState.clipHold = hovered }

    // ---- status line ----
    Row {
        visible: !root.hasClip
        anchors.centerIn: parent
        spacing: 10
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            text: IslandState.clipIcon || "videocam_off"
            color: IslandState.clipIcon === "fiber_manual_record" ? "#ff5a5f" : Theme.muted
            font.pixelSize: 20
            fill: 1
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: IslandState.clipText
            color: Theme.fg
            font.family: "Google Sans Flex"; font.pixelSize: 13; font.weight: Font.DemiBold
        }
    }

    // ---- saved clip card ----
    Rectangle {
        id: shot
        visible: root.hasClip
        x: 12; y: 12
        width: 142; height: 80
        radius: 14
        color: Qt.alpha(Theme.fg, 0.08)
        clip: true
        Image {
            anchors.fill: parent
            source: IslandState.clipThumb ? "file://" + IslandState.clipThumb : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 300
        }
        Icon {
            anchors.centerIn: parent
            text: "play_circle"
            fill: 1
            font.pixelSize: 30
            color: "white"
            opacity: shotArea.containsMouse ? 0.95 : 0.7
        }
        MouseArea {
            id: shotArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { ReplayService.play(root.path); IslandState.hideClip(); }
        }
    }

    Column {
        visible: root.hasClip
        anchors.left: shot.right; anchors.leftMargin: 14
        anchors.right: parent.right; anchors.rightMargin: 14
        y: 14
        spacing: 2
        Row {
            spacing: 6
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                text: IslandState.clipIcon || "check_circle"
                color: Theme.accent
                font.pixelSize: 16
                fill: 1
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.armDelete ? I18n.t("Click again to delete") : IslandState.clipText
                color: Theme.fg
                font.family: "Google Sans Flex"; font.pixelSize: 13; font.weight: Font.DemiBold
            }
        }
        Text {
            width: parent.width
            text: root.hoverTip || root.fileName
            elide: Text.ElideMiddle
            color: Theme.muted
            font.family: "Google Sans Flex"; font.pixelSize: 11
        }
    }

    Row {
        visible: root.hasClip
        anchors.left: shot.right; anchors.leftMargin: 8
        anchors.bottom: parent.bottom; anchors.bottomMargin: 10
        spacing: 2
        ClipAction { onHoveredChanged: root.hint(this); icon: "play_arrow"; tip: I18n.t("Play"); onClicked: { ReplayService.play(root.path); IslandState.hideClip(); } }
        ClipAction { onHoveredChanged: root.hint(this); icon: "content_copy"; tip: I18n.t("Copy to clipboard"); onClicked: ReplayService.copy(root.path) }
        ClipAction { onHoveredChanged: root.hint(this); icon: "folder_open"; tip: I18n.t("Show in folder"); onClicked: { ReplayService.openFolder(root.path); IslandState.hideClip(); } }
        ClipAction { onHoveredChanged: root.hint(this); icon: "video_library"; tip: I18n.t("All clips"); onClicked: { IslandState.hideClip(); SettingsState.open("replay"); } }
        ClipAction {
            onHoveredChanged: root.hint(this)
            icon: root.armDelete ? "delete_forever" : "delete"
            danger: true
            tip: I18n.t("Delete")
            onClicked: {
                if (!root.armDelete) { root.armDelete = true; return; }
                root.armDelete = false;
                ReplayService.remove(root.path);
            }
        }
    }
}
