import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs

Row {
    id: root
    required property var screen
    readonly property var mon: Hyprland.monitorFor(screen)
    readonly property int activeId: mon && mon.activeWorkspace ? mon.activeWorkspace.id : -1
    readonly property var used: {
        const s = new Set();
        for (const w of Hyprland.workspaces.values)
            s.add(w.id);
        return s;
    }
    readonly property var ids: {
        const s = new Set([1, 2, 3, 4, 5]);
        if (activeId > 0) s.add(activeId);
        for (const id of used) if (id > 0) s.add(id);
        return [...s].sort((a, b) => a - b);
    }
    spacing: 6

    Repeater {
        model: root.ids
        delegate: Rectangle {
            required property int modelData
            readonly property bool active: modelData === root.activeId
            readonly property bool isUsed: root.used.has(modelData)
            width: active ? 32 : 18
            height: 18
            radius: 9
            color: active ? Theme.accent : (isUsed ? Theme.surface2 : "transparent")
            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            Text {
                anchors.centerIn: parent
                text: parent.modelData
                font.family: "Google Sans Flex"
                font.pixelSize: 10
                font.weight: Font.DemiBold
                color: parent.active ? Theme.accentText : (parent.isUsed ? Theme.fg : Theme.muted)
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + parent.modelData + " })")  // Hyprland 0.57 Lua dispatcher
            }
        }
    }
}
