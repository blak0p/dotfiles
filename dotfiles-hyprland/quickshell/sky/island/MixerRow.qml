import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import qs

// One mixer line for a Pipewire node (device or app stream): icon (click to
// mute), title/subtitle, a volume slider with a live level meter, and the
// percentage. Devices can be picked as the default with `selectable`.
Rectangle {
    id: row

    required property var node
    property string glyph: "volume_up"
    property string appIcon: ""
    property string title: ""
    property string subtitle: ""
    property bool selectable: false
    property bool selected: false
    signal picked()

    readonly property var audio: node && node.audio ? node.audio : null
    readonly property real v: audio ? audio.volume : 0
    readonly property bool muted: audio ? audio.muted : false

    height: 52
    radius: 14
    color: selected ? Qt.alpha(Theme.accent, 0.14)
        : (pickMa.containsMouse && selectable ? Qt.alpha(Theme.fg, 0.07) : Qt.alpha(Theme.fg, 0.04))
    border.width: selected ? 1 : 0
    border.color: Qt.alpha(Theme.accent, 0.45)
    Behavior on color { ColorAnimation { duration: 140 } }

    PwNodePeakMonitor { id: peak; node: row.node; enabled: row.visible && !row.muted }

    // Background tap makes a device the default.
    MouseArea {
        id: pickMa
        anchors.fill: parent
        hoverEnabled: true
        enabled: row.selectable
        cursorShape: row.selectable && !row.selected ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (!row.selected) row.picked()
    }

    // Icon: app icon when there is one, a glyph otherwise. Click toggles mute.
    Rectangle {
        id: knob
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 32; height: 32; radius: 16
        color: row.muted ? Qt.alpha(Theme.fg, 0.08) : (row.selected ? Theme.accent : Qt.alpha(Theme.fg, 0.1))
        Behavior on color { ColorAnimation { duration: 160 } }

        IconImage {
            id: img
            anchors.centerIn: parent
            implicitSize: 20
            visible: row.appIcon !== "" && status === Image.Ready
            source: row.appIcon !== "" ? Quickshell.iconPath(row.appIcon, true) : ""
            opacity: row.muted ? 0.4 : 1
        }
        Icon {
            anchors.centerIn: parent
            visible: !img.visible
            text: row.muted ? (row.glyph === "mic" ? "mic_off" : "volume_off") : row.glyph
            fill: 1
            color: row.muted ? Theme.muted : (row.selected ? Theme.accentText : Theme.fg)
            font.pixelSize: 17
        }
        // Mute badge over app icons.
        Rectangle {
            visible: img.visible && row.muted
            anchors.right: parent.right; anchors.bottom: parent.bottom
            width: 14; height: 14; radius: 7
            color: "#000000"
            Icon { anchors.centerIn: parent; text: "volume_off"; font.pixelSize: 10; color: Theme.muted }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: if (row.audio) row.audio.muted = !row.audio.muted
        }
    }

    Column {
        anchors.left: knob.right; anchors.leftMargin: 10
        anchors.right: pct.left; anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Row {
            width: parent.width
            spacing: 6
            Text {
                id: titleText
                width: Math.min(implicitWidth, parent.width)
                text: row.title
                elide: Text.ElideRight
                color: Theme.fg
                font.family: "Google Sans Flex"; font.pixelSize: 12
                font.weight: row.selected ? Font.Bold : Font.DemiBold
            }
            Text {
                width: Math.max(0, parent.width - titleText.width - parent.spacing)
                visible: row.subtitle !== ""
                anchors.baseline: titleText.baseline
                text: row.subtitle
                elide: Text.ElideRight
                color: Theme.muted
                font.family: "Google Sans Flex"; font.pixelSize: 10
            }
        }

        // Slider: track, live level under the fill, knob.
        Item {
            id: track
            width: parent.width
            height: 12
            // The level animates, not the width, so resizing never lags behind.
            property real lvl: row.muted ? 0 : Math.min(row.v, 1)
            Behavior on lvl { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: 6; radius: 3
                color: Qt.alpha(Theme.fg, 0.12)

                // Set volume (dim) with the live level on top (bright).
                Rectangle {
                    id: fill
                    height: parent.height; radius: parent.radius
                    width: parent.width * track.lvl
                    color: row.muted ? Theme.muted : Theme.accent
                    opacity: 0.4
                }
                Rectangle {
                    height: parent.height; radius: parent.radius
                    width: parent.width * track.lvl * Math.min(1, peak.peak)
                    color: Theme.accent
                }
            }
            Rectangle {
                width: 12; height: 12; radius: 6
                anchors.verticalCenter: parent.verticalCenter
                x: Math.max(0, Math.min(track.width - width, fill.width - width / 2))
                color: Theme.fg
                opacity: row.muted ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: Qt.PointingHandCursor
                function apply(x) {
                    if (!row.audio) return;
                    row.audio.muted = false;
                    row.audio.volume = Math.max(0, Math.min(1, (x - 8) / track.width));
                }
                onPressed: m => apply(m.x)
                onPositionChanged: m => { if (pressed) apply(m.x); }
                onWheel: w => { if (row.audio) row.audio.volume = Math.max(0, Math.min(1, row.v + (w.angleDelta.y > 0 ? 0.05 : -0.05))); }
            }
        }
    }

    Text {
        id: pct
        anchors.right: parent.right; anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 30
        horizontalAlignment: Text.AlignRight
        text: row.muted ? "0" : Math.round(row.v * 100)
        color: row.muted ? Theme.muted : Theme.fg
        font.family: "Google Sans Flex"; font.pixelSize: 12; font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
    }
}
