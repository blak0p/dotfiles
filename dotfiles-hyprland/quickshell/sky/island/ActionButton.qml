import QtQuick
import qs

// Small rounded action button used in the expanded wifi/bluetooth rows.
Rectangle {
    id: b
    property string icon
    property string label
    property bool primary: false
    property bool danger: false
    signal clicked()

    readonly property color tone: danger ? "#ff8a80" : Theme.accent
    height: 28
    width: row.implicitWidth + 22
    radius: 14
    color: primary ? (ma.containsMouse ? Qt.lighter(tone, 1.1) : tone)
        : (ma.containsMouse ? Qt.alpha(tone, 0.28) : Qt.alpha(tone, 0.14))
    Behavior on color { ColorAnimation { duration: 120 } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5
        Icon {
            visible: b.icon !== ""
            text: b.icon
            font.pixelSize: 15
            color: b.primary ? Theme.accentText : b.tone
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: b.label
            color: b.primary ? Theme.accentText : b.tone
            font.family: "Google Sans Flex"; font.pixelSize: 12; font.weight: Font.DemiBold
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
}
