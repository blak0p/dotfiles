import QtQuick
import qs

// Material Symbols Rounded glyph, addressed by ligature name.
Text {
    property real fill: 0
    color: Theme.fg
    font.family: "Material Symbols Rounded"
    font.pixelSize: 16
    font.variableAxes: ({ "FILL": fill })
    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
}
