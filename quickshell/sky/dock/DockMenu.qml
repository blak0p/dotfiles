import QtQuick
import qs

// Context menu for a dock item. Stays inside the (masked) screen scene because
// the dock itself clips its children.
Rectangle {
    id: root
    property var item: null
    property real anchorX: 0
    readonly property bool opened: item !== null

    signal closed()

    function open(entry) { item = entry; }
    function close() { item = null; root.closed(); }

    width: opened ? 190 : 0
    height: opened ? col.implicitHeight + 12 : 0
    clip: true
    visible: opened
    radius: 14
    color: "#000000"
    border.width: 1
    border.color: Qt.alpha(Theme.accent, 0.25)

    HoverHandler { id: hover }
    readonly property bool hovered: hover.hovered

    readonly property bool pinned: item ? DockPins.has(item.key) : false
    readonly property int pinnedIndex: item && pinned ? DockPins.ids.indexOf(item.key) : -1
    readonly property bool canLeft: pinned && pinnedIndex > 0
    readonly property bool canRight: pinned && pinnedIndex < DockPins.ids.length - 1

    // Centered on anchorX, clamped to the parent's width.
    x: Math.max(4, Math.min(parent ? parent.width - width - 4 : anchorX, anchorX - width / 2))
    y: 0

    Column {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 6
        spacing: 2

        // Open
        Rectangle {
            width: parent.width; height: 32; radius: 10
            color: oMa.containsMouse ? Theme.surface2 : "transparent"
            Text { anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                text: "Open"; color: Theme.fg; font.family: "Google Sans Flex"; font.pixelSize: 13 }
            MouseArea { id: oMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: { const tl = root.item.toplevels; if (tl.length > 0) tl[0].activate(); else if (root.item.entry) root.item.entry.execute(); root.close(); } }
        }

        // Pin / Unpin
        Rectangle {
            width: parent.width; height: 32; radius: 10
            color: pMa.containsMouse ? Theme.surface2 : "transparent"
            Text { anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                text: root.pinned ? "Remove from dock" : "Pin to dock"; color: Theme.fg; font.family: "Google Sans Flex"; font.pixelSize: 13 }
            MouseArea { id: pMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: { DockPins.toggle(root.item.key); root.close(); } }
        }

        // Move left
        Rectangle {
            width: parent.width; height: 32; radius: 10
            color: root.canLeft && mlMa.containsMouse ? Theme.surface2 : "transparent"
            opacity: root.canLeft ? 1 : 0.4
            Text { anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                text: "Move left"; color: root.canLeft ? Theme.fg : Theme.muted; font.family: "Google Sans Flex"; font.pixelSize: 13 }
            MouseArea { id: mlMa; anchors.fill: parent; hoverEnabled: true; cursorShape: root.canLeft ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: { if (root.canLeft) DockPins.move(root.item.key, -1); } }
        }

        // Move right
        Rectangle {
            width: parent.width; height: 32; radius: 10
            color: root.canRight && mrMa.containsMouse ? Theme.surface2 : "transparent"
            opacity: root.canRight ? 1 : 0.4
            Text { anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                text: "Move right"; color: root.canRight ? Theme.fg : Theme.muted; font.family: "Google Sans Flex"; font.pixelSize: 13 }
            MouseArea { id: mrMa; anchors.fill: parent; hoverEnabled: true; cursorShape: root.canRight ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: { if (root.canRight) DockPins.move(root.item.key, 1); } }
        }

        // Close window (only when running)
        Rectangle {
            visible: root.item && root.item.toplevels && root.item.toplevels.length > 0
            width: parent.width; height: 32; radius: 10
            color: cMa.containsMouse ? Theme.surface2 : "transparent"
            Text { anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                text: "Close window"; color: Theme.fg; font.family: "Google Sans Flex"; font.pixelSize: 13 }
            MouseArea { id: cMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: { const tl = root.item.toplevels; if (tl.length > 0) tl[0].close(); root.close(); } }
        }
    }
}