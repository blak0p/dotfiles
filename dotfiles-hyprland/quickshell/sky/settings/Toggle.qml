import QtQuick
import qs

// On/off switch. Emits toggled(on) with the requested state; the owner
// decides whether to apply it (bind `checked` to the real state).
Rectangle {
    id: t

    property bool checked: false
    property string label: ""
    signal toggled(bool on)

    width: 48; height: 28; radius: 14
    color: checked ? Theme.accent : Theme.surface2
    border.width: 2
    border.color: activeFocus ? Theme.fg : checked ? Theme.accent : Theme.outline
    activeFocusOnTab: true
    Accessible.role: Accessible.CheckBox
    Accessible.name: label
    Accessible.checked: checked
    Behavior on color { ColorAnimation { duration: 150 } }

    Rectangle {
        width: t.checked ? 20 : 16
        height: width
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        x: t.checked ? parent.width - width - 4 : 4
        color: t.checked ? Theme.accentText : Theme.outline
        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    }

    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: t.toggled(!t.checked) }
    Keys.onSpacePressed: t.toggled(!t.checked)
    Keys.onReturnPressed: t.toggled(!t.checked)
}
