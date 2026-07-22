import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

MouseArea {
    id: root
    implicitWidth: rowLayout.implicitWidth + 10 * 2
    implicitHeight: Appearance.sizes.barHeight

    hoverEnabled: false
    property bool _open: false

    onClicked: root._open = !root._open

    RowLayout {
        id: rowLayout
        anchors.centerIn: parent

        StyledText {
            text: "codex"
            color: Appearance.colors.colOnLayer1
            font.pixelSize: Appearance.font.pixelSize.large
        }

        StyledText {
            text: CodexBar.compactText
            color: Appearance.colors.colOnLayer1
            font.pixelSize: Appearance.font.pixelSize.small
        }
    }

    HyprlandFocusGrab {
        id: grab
        windows: [popupLoader.item]
        active: root._open
        onActiveChanged: if (!active) root._open = false
    }

    LazyLoader {
        id: popupLoader
        active: root._open
        component: CodexBarPopup {
            hoverTarget: fakeHover
        }
    }

    Item {
        id: fakeHover
        property bool containsMouse: true
    }
}