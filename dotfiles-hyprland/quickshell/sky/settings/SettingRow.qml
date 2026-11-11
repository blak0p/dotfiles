import QtQuick
import qs

// One row of a settings card: optional round icon, title + subtitle, and
// trailing controls (children). `current` tints the icon with the accent,
// `clickable` adds hover and the clicked() signal, `divider` draws a line on top.
Item {
    id: r

    property string icon: ""
    property string title: ""
    property string sub: ""
    property bool current: false
    property bool clickable: false
    property bool divider: false
    property bool highlighted: false
    default property alias trailing: tail.data
    signal clicked()

    width: parent ? parent.width : 0
    implicitHeight: Math.max(56, texts.implicitHeight + 16)
    height: implicitHeight

    Rectangle {
        anchors.fill: parent
        radius: 18
        color: r.highlighted ? Theme.surface
            : r.clickable && ma.containsMouse ? Theme.surface2 : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
    }
    Rectangle {
        visible: r.divider
        x: 16; width: parent.width - 32; height: 1
        color: Qt.alpha(Theme.outline, 0.35)
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: r.clickable
        hoverEnabled: true
        cursorShape: r.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: r.clicked()
    }

    Rectangle {
        id: ico
        visible: r.icon !== ""
        x: 16
        anchors.verticalCenter: parent.verticalCenter
        width: 38; height: 38; radius: 19
        color: r.current ? Theme.accent : Theme.surface2
        Icon {
            anchors.centerIn: parent
            text: r.icon
            fill: r.current ? 1 : 0
            font.pixelSize: 19
            color: r.current ? Theme.accentText : Theme.secondary
        }
    }

    Column {
        id: texts
        anchors.left: ico.visible ? ico.right : parent.left
        anchors.leftMargin: ico.visible ? 14 : 16
        anchors.right: tail.left
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Text {
            width: parent.width
            text: r.title
            elide: Text.ElideRight
            color: Theme.fg
            font.family: "Google Sans Flex"; font.pixelSize: 14
            font.weight: r.current ? Font.DemiBold : Font.Medium
        }
        Text {
            width: parent.width
            visible: r.sub !== ""
            text: r.sub
            elide: Text.ElideRight
            color: Theme.muted
            font.family: "Google Sans Flex"; font.pixelSize: 12
        }
    }

    Row {
        id: tail
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
    }
}
