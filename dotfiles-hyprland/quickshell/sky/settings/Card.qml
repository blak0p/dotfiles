import QtQuick
import qs

// Rounded group of SettingRows.
Rectangle {
    default property alias content: col.data
    property alias spacing: col.spacing

    width: parent ? parent.width : 0
    implicitHeight: col.implicitHeight + 12
    height: implicitHeight
    radius: 22
    color: Theme.widget
    border.width: 1
    border.color: Qt.alpha(Theme.outline, 0.35)

    Column {
        id: col
        x: 6; y: 6
        width: parent.width - 12
    }
}
