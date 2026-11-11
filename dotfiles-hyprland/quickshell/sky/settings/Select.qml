import QtQuick
import QtQuick.Controls
import qs

// Dropdown. `model` is a list of strings or of { label, value } objects;
// emits activated(index) when the user picks an entry. Bind currentIndex to
// the real state.
Rectangle {
    id: s

    property var model: []
    property int currentIndex: -1
    property string placeholder: ""
    signal activated(int index)

    function labelOf(i) {
        const m = model[i];
        if (m === undefined || m === null) return "";
        return typeof m === "object" ? String(m.label) : String(m);
    }

    implicitWidth: Math.max(170, cur.implicitWidth + 52)
    width: implicitWidth
    height: 36
    radius: 18
    opacity: enabled ? 1 : 0.45
    color: ma.containsMouse ? Qt.alpha(Theme.outline, 0.45) : Theme.surface2
    border.width: activeFocus || popup.visible ? 2 : 1
    border.color: activeFocus || popup.visible ? Theme.accent : Theme.outline
    activeFocusOnTab: true
    Accessible.role: Accessible.ComboBox
    Accessible.name: labelOf(currentIndex)

    Text {
        id: cur
        anchors.left: parent.left; anchors.leftMargin: 14
        anchors.right: chev.left; anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        text: s.currentIndex >= 0 ? s.labelOf(s.currentIndex) : s.placeholder
        elide: Text.ElideRight
        color: s.currentIndex >= 0 ? Theme.fg : Theme.muted
        font.family: "Google Sans Flex"; font.pixelSize: 13
    }
    Icon {
        id: chev
        anchors.right: parent.right; anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: "expand_more"
        color: Theme.muted
        font.pixelSize: 18
        rotation: popup.visible ? 180 : 0
        Behavior on rotation { NumberAnimation { duration: 160 } }
    }

    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: popup.open() }
    Keys.onSpacePressed: popup.open()
    Keys.onReturnPressed: popup.open()

    Popup {
        id: popup
        y: s.height + 4
        width: Math.max(s.width, 200)
        padding: 6
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onOpened: list.currentIndex = Math.max(0, s.currentIndex)
        background: Rectangle {
            radius: 16
            color: Theme.surface
            border.width: 1
            border.color: Qt.alpha(Theme.outline, 0.6)
        }
        contentItem: ListView {
            id: list
            implicitHeight: Math.min(contentHeight, 300)
            clip: true
            focus: true
            boundsBehavior: Flickable.StopAtBounds
            model: s.model
            keyNavigationEnabled: true
            Keys.onReturnPressed: { s.activated(currentIndex); popup.close(); }
            delegate: Rectangle {
                required property int index
                width: ListView.view.width
                height: 34
                radius: 12
                color: index === s.currentIndex ? Qt.alpha(Theme.accent, 0.2)
                    : (dma.containsMouse || ListView.isCurrentItem) ? Theme.surface2 : "transparent"
                Text {
                    anchors.left: parent.left; anchors.leftMargin: 12
                    anchors.right: parent.right; anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: s.labelOf(index)
                    elide: Text.ElideRight
                    color: index === s.currentIndex ? Theme.accent : Theme.fg
                    font.family: "Google Sans Flex"; font.pixelSize: 13
                }
                MouseArea {
                    id: dma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { s.activated(index); popup.close(); }
                }
            }
        }
    }
}
