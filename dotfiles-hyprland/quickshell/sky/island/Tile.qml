import QtQuick
import qs

// Quick tile: the round icon toggles, the rest of the tile opens its page.
Rectangle {
    id: t
    property string icon
    property string label
    property string sub
    property bool on: false
    property bool current: false
    signal toggled()
    signal opened()
    height: 52
    radius: 18
    color: current ? Qt.alpha(Theme.fg, 0.12) : (tma.containsMouse ? Qt.alpha(Theme.fg, 0.09) : Qt.alpha(Theme.fg, 0.05))
    border.width: current ? 1 : 0
    border.color: Qt.alpha(Theme.accent, 0.5)
    Behavior on color { ColorAnimation { duration: 120 } }
    MouseArea { id: tma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: t.opened() }
    Rectangle {
        id: knob
        x: 8; anchors.verticalCenter: parent.verticalCenter
        width: 32; height: 32; radius: 16
        color: t.on ? Theme.accent : Qt.alpha(Theme.fg, 0.1)
        Behavior on color { ColorAnimation { duration: 180 } }
        Icon { anchors.centerIn: parent; text: t.icon; fill: 1; color: t.on ? Theme.accentText : Theme.fg; font.pixelSize: 17 }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: t.toggled() }
    }
    Column {
        anchors.left: knob.right; anchors.leftMargin: 8
        anchors.right: parent.right; anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        Text { width: parent.width; text: t.label; elide: Text.ElideRight; color: Theme.fg; font.family: "Google Sans Flex"; font.pixelSize: 12; font.weight: Font.DemiBold }
        Text { width: parent.width; text: t.sub; elide: Text.ElideRight; color: Theme.muted; font.family: "Google Sans Flex"; font.pixelSize: 10 }
    }
}
