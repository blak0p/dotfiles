import QtQuick
import qs

// Small accent heading above a settings card.
Text {
    width: parent ? parent.width : implicitWidth
    topPadding: 22
    bottomPadding: 10
    leftPadding: 6
    color: Theme.accent
    font.family: "Google Sans Flex"
    font.pixelSize: 12
    font.weight: Font.DemiBold
    font.letterSpacing: 0.3
}
