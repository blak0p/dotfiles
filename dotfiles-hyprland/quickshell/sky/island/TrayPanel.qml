import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs

// Everything the status pill hides behind its chevron: one cell per
// StatusNotifierItem. The pill keeps a bounded width, so the bar never reflows
// depending on how many apps are running in the background.
Item {
    id: root

    readonly property var items: SystemTray.items.values.slice(Config.trayInline)
    readonly property int cols: Math.min(items.length, Config.trayCols)
    readonly property real contentW: Config.trayPad * 2
        + cols * Config.trayItem + Math.max(0, cols - 1) * Config.trayGap

    property string hovered: ""

    implicitWidth: card.width
    implicitHeight: card.height
    width: implicitWidth
    height: implicitHeight
    opacity: IslandState.trayOpen ? 1 : 0
    scale: IslandState.trayOpen ? 1 : 0.96
    transformOrigin: Item.Top
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: IslandState.trayOpen ? 180 : 100; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    // Nothing left to overflow into: the chevron disappears, so the panel must
    // not stay open on its own.
    Connections {
        target: SystemTray.items
        function onValuesChanged() {
            if (SystemTray.items.values.length <= Config.trayInline) IslandState.closeTray();
        }
    }

    Rectangle {
        id: card
        width: Math.max(Config.trayMinW, root.contentW)
        height: header.height + 8 + grid.height + Config.trayPad * 2
        radius: 16
        color: "#000000"
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.25)

        Text {
            id: header
            x: Config.trayPad
            y: Config.trayPad
            width: card.width - Config.trayPad * 2
            text: root.hovered !== "" ? root.hovered : I18n.t("System tray")
            color: root.hovered !== "" ? Theme.fg : Theme.muted
            font.family: "Google Sans Flex"
            font.pixelSize: 12
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        Flow {
            id: grid
            x: Config.trayPad
            y: header.y + header.height + 8
            width: card.width - Config.trayPad * 2
            spacing: Config.trayGap

            Repeater {
                model: root.items

                delegate: Rectangle {
                    id: cell
                    required property SystemTrayItem modelData
                    width: Config.trayItem
                    height: Config.trayItem
                    radius: 8
                    color: hover.hovered ? Qt.alpha(Theme.fg, 0.12) : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    HoverHandler {
                        id: hover
                        onHoveredChanged: root.hovered = hovered ? cell.modelData.tooltipTitle
                            || cell.modelData.title || cell.modelData.id : ""
                    }

                    TrayIcon {
                        modelData: cell.modelData
                        anchors.fill: parent
                        anchors.margins: 4
                    }
                }
            }
        }
    }
}
