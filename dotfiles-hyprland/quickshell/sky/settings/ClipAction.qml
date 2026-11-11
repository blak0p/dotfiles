import QtQuick
import qs

// Small round icon button of a clip card in ReplayPage.qml (copy, delete).
Rectangle {
    id: btn
    property string icon: ""
    property string tip: ""
    property bool danger: false
    signal clicked()
    width: 30; height: 30; radius: 15
    color: area.containsMouse ? Qt.alpha(danger ? "#ffb4ab" : Theme.fg, 0.12) : "transparent"
    Icon {
        anchors.centerIn: parent
        text: btn.icon
        font.pixelSize: 17
        color: btn.danger ? "#ffb4ab" : Theme.muted
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
