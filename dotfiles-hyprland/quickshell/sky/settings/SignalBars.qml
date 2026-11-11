import QtQuick
import qs

// Four rising bars for a 0..1 signal strength.
Row {
    id: bars
    property real strength: 0
    readonly property int lit: strength > 0.75 ? 4 : strength > 0.5 ? 3 : strength > 0.25 ? 2 : strength > 0 ? 1 : 0
    spacing: 2
    height: 16
    Accessible.role: Accessible.Indicator
    Accessible.name: Math.round(strength * 100) + "%"
    Repeater {
        model: 4
        Rectangle {
            required property int index
            anchors.bottom: parent.bottom
            width: 4
            height: 5 + index * 3.7
            radius: 2
            color: index < bars.lit ? Theme.accent : Theme.surface2
            border.width: 1
            border.color: index < bars.lit ? Theme.accent : Theme.outline
        }
    }
}
