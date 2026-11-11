import QtQuick
import qs

// Pill button for settings pages: default (surface), primary (accent) or danger.
Rectangle {
    id: b

    property string text: ""
    property string icon: ""
    property bool primary: false
    property bool danger: false
    signal clicked()

    readonly property color ink: primary ? Theme.accentText : danger ? "#ffb4ab" : Theme.fg
    implicitWidth: row.implicitWidth + 36
    width: implicitWidth
    height: 36
    radius: 18
    opacity: enabled ? 1 : 0.45
    color: primary ? (ma.containsMouse ? Qt.lighter(Theme.accent, 1.12) : Theme.accent)
        : (ma.containsMouse ? Qt.alpha(Theme.outline, 0.45) : Theme.surface2)
    border.width: activeFocus ? 2 : 0
    border.color: Theme.fg
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: text
    Behavior on color { ColorAnimation { duration: 120 } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Icon {
            visible: b.icon !== ""
            text: b.icon
            color: b.ink
            font.pixelSize: 17
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: b.text
            color: b.ink
            font.family: "Google Sans Flex"; font.pixelSize: 13; font.weight: Font.DemiBold
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
    Keys.onSpacePressed: b.clicked()
    Keys.onReturnPressed: b.clicked()
}
