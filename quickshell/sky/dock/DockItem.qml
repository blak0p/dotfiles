import QtQuick
import Quickshell
import Quickshell.Widgets
import qs

Item {
    id: root
    required property var modelData
    required property int index
    readonly property bool running: modelData.toplevels.length > 0
    readonly property bool pinned: DockPins.has(root.modelData.key)

    signal contextRequested()

    width: Config.itemSize
    height: Config.itemSize

    property bool dragging: false
    property int dragFrom: -1
    property var dockRoot: null

    Rectangle {
        id: tile
        width: parent.width; height: parent.height
        radius: 11
        y: root.dragging ? 0 : (hover.hovered ? -3 : 0)
        color: Theme.surface2
        Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        IconImage {
            anchors.centerIn: parent
            implicitSize: 26
            source: AppModel.iconSource(root.modelData.icon)
        }
        Rectangle {
            visible: root.running
            width: 4; height: 4; radius: 2
            color: Theme.accent
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height + 1 + (hover.hovered ? 3 : 0)
        }
        opacity: root.dragging ? 0.85 : 1.0
    }

    property real dragX: 0

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        drag.target: root.pinned ? root : null
        drag.axis: Drag.XAxis
        drag.minimumX: -2000
        drag.maximumX: 2000

        onPressed: (mouse) => {
            root.dragX = 0;
            root.dragging = false;
            if (mouse.button === Qt.LeftButton && root.pinned) {
                root.dragFrom = DockPins.ids.indexOf(root.modelData.key);
            }
        }
        onPositionChanged: (mouse) => {
            if (pressedButtons & Qt.LeftButton && root.pinned) {
                if (Math.abs(root.x) > 4) root.dragging = true;
            }
        }
        onReleased: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                root.contextRequested();
                return;
            }
            if (root.dragging) {
                const step = Config.itemSize + 6;
                const steps = Math.round(root.x / step);
                if (steps !== 0 && root.dragFrom >= 0) {
                    const target = Math.max(0, Math.min(DockPins.ids.length - 1, root.dragFrom + steps));
                    if (target !== root.dragFrom) {
                        DockPins.moveTo(root.modelData.key, target);
                    }
                }
                // Unpin if dropped far outside the dock vertically.
                if (root.dockRoot) {
                    const g = root.mapToGlobal(root.x, root.y);
                    const dr = root.dockRoot.mapToGlobal(0, 0);
                    const outY = Math.abs(g.y - (dr.y + root.dockRoot.height / 2)) > 90;
                    const outX = g.x < dr.x - 20 || g.x > dr.x + root.dockRoot.width + 20;
                    if (outY || outX) {
                        DockPins.remove(root.modelData.key);
                    }
                }
                root.dragging = false;
                root.dragX = 0;
                root.x = 0;
                return;
            }
            // Plain click.
            const tl = root.modelData.toplevels;
            if (tl.length > 0) tl[0].activate();
            else if (root.modelData.entry) root.modelData.entry.execute();
        }
    }
}