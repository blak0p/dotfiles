import QtQuick
import QtQuick.Controls
import qs

// Scrollable settings page: a big title, optional header controls on the
// right (headerRight), and a column of Sections and Cards (children).
Flickable {
    id: page

    property string title: ""
    default property alias content: col.data
    property alias headerRight: right.data

    clip: true
    boundsBehavior: Flickable.StopAtBounds
    contentWidth: width
    contentHeight: head.height + col.implicitHeight + 32
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    Item {
        id: head
        width: page.width - 14
        height: 44
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: page.title
            color: Theme.fg
            font.family: "Google Sans Flex"; font.pixelSize: 26; font.weight: Font.DemiBold
        }
        Row {
            id: right
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
        }
    }

    Column {
        id: col
        y: head.height + 4
        width: page.width - 14
    }
}
