import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs

// One StatusNotifierItem: icon, click behaviour and its own context menu,
// rendered by the platform menu (needs `//@ pragma UseQApplication`).
Item {
    id: root
    required property SystemTrayItem modelData
    implicitWidth: 16
    implicitHeight: 16

    // An SNI item reports a theme icon name ("nm-signal-50"), not a URL, so it
    // has to be resolved before IconImage can paint it.
    readonly property string iconSource: {
        const icon = root.modelData.icon;
        if (!icon) return Quickshell.iconPath("image-missing");
        if (icon.startsWith("/") || icon.includes("://")) return icon;
        return Quickshell.iconPath(icon, "image-missing");
    }

    readonly property string label: root.modelData.tooltipTitle || root.modelData.title || root.modelData.id

    IconImage {
        anchors.fill: parent
        source: root.iconSource
        asynchronous: true
    }

    QsMenuAnchor {
        id: menu
        menu: root.modelData.menu
        anchor.item: root
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            const item = root.modelData;
            if (mouse.button === Qt.LeftButton) {
                if (item.onlyMenu) menu.open();
                else { item.activate(); IslandState.closeTray(); }
            } else if (mouse.button === Qt.MiddleButton) {
                item.secondaryActivate();
            } else if (item.hasMenu) {
                menu.open();
            }
        }
    }
}
