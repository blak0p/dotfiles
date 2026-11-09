import QtQuick
import Quickshell.Services.Mpris
import qs

// Music module: cover, track, seekable progress, transport controls, the
// player's own volume and a chip per MPRIS player to switch between them.
Item {
    id: root
    readonly property var p: Media.player
    readonly property real wanted: p ? body.implicitHeight : 60

    // MprisPlayer.position only updates when positionChanged() is emitted.
    Timer {
        running: root.visible && Media.playing
        interval: 1000
        repeat: true
        onTriggered: if (root.p) root.p.positionChanged()
    }

    Column {
        anchors.centerIn: parent
        visible: !root.p
        spacing: 4
        Icon { anchors.horizontalCenter: parent.horizontalCenter; text: "music_off"; color: Theme.muted; font.pixelSize: 22 }
        Text { text: I18n.t("Nothing playing"); color: Theme.muted; font.family: "Google Sans Flex"; font.pixelSize: 12 }
    }

    Column {
        id: body
        visible: !!root.p
        width: parent.width
        spacing: 12

        Row {
            width: parent.width
            spacing: 14
            Rectangle {
                id: art
                width: 84; height: 84; radius: 18
                color: Qt.alpha(Theme.accent, 0.2)
                clip: true
                Icon { anchors.centerIn: parent; text: "music_note"; color: Theme.accent; font.pixelSize: 32; visible: cover.status !== Image.Ready }
                Image {
                    id: cover
                    anchors.fill: parent
                    source: root.p && root.p.trackArtUrl ? root.p.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
            Column {
                width: parent.width - art.width - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Text {
                    width: parent.width
                    text: root.p ? root.p.identity : ""
                    elide: Text.ElideRight
                    color: Theme.muted
                    font.family: "Google Sans Flex"; font.pixelSize: 11
                }
                Text {
                    width: parent.width
                    text: root.p ? (root.p.trackTitle || I18n.t("Unknown")) : ""
                    elide: Text.ElideRight
                    color: Theme.fg
                    font.family: "Google Sans Flex"; font.pixelSize: 17; font.weight: Font.Bold
                }
                Text {
                    width: parent.width
                    text: !root.p ? "" : [root.p.trackArtist, root.p.trackAlbum].filter(s => !!s).join(" — ")
                    elide: Text.ElideRight
                    color: Theme.muted
                    font.family: "Google Sans Flex"; font.pixelSize: 12
                }
            }
        }

        // Progress: click or drag to seek when the player allows it.
        Item {
            width: parent.width
            height: 16
            visible: !!root.p && root.p.lengthSupported && root.p.length > 0
            Text {
                id: posT
                anchors.verticalCenter: parent.verticalCenter
                text: root.p ? Media.fmtTime(seek.dragging ? seek.dragPos : root.p.position) : ""
                color: Theme.muted
                font.family: "Google Sans Flex"; font.pixelSize: 11
                font.features: { "tnum": 1 }
            }
            Text {
                id: lenT
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.p ? Media.fmtTime(root.p.length) : ""
                color: Theme.muted
                font.family: "Google Sans Flex"; font.pixelSize: 11
                font.features: { "tnum": 1 }
            }
            Slider {
                id: seek
                anchors.left: posT.right; anchors.leftMargin: 10
                anchors.right: lenT.left; anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                enabled: !!root.p && root.p.canSeek
                property real dragPos: 0
                value: root.p && root.p.length > 0 ? (dragging ? dragPos : root.p.position) / root.p.length : 0
                onMoved: f => dragPos = f * root.p.length
                onReleased: f => { if (root.p) root.p.position = f * root.p.length; }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 18
            CtrlButton {
                icon: "shuffle"
                visible: !!root.p && root.p.shuffleSupported
                on: !!root.p && root.p.shuffle
                onClicked: root.p.shuffle = !root.p.shuffle
            }
            CtrlButton { icon: "skip_previous"; big: true; enabled: !!root.p && root.p.canGoPrevious; onClicked: root.p.previous() }
            Rectangle {
                width: 44; height: 44; radius: 22
                anchors.verticalCenter: parent.verticalCenter
                color: playMa.containsMouse ? Qt.lighter(Theme.accent, 1.1) : Theme.accent
                Icon { anchors.centerIn: parent; text: Media.playing ? "pause" : "play_arrow"; fill: 1; color: Theme.accentText; font.pixelSize: 24 }
                MouseArea { id: playMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (root.p) root.p.togglePlaying() }
            }
            CtrlButton { icon: "skip_next"; big: true; enabled: !!root.p && root.p.canGoNext; onClicked: root.p.next() }
            CtrlButton {
                visible: !!root.p && root.p.loopSupported
                icon: root.p && root.p.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
                on: !!root.p && root.p.loopState !== MprisLoopState.None
                onClicked: root.p.loopState = root.p.loopState === MprisLoopState.None ? MprisLoopState.Playlist
                    : root.p.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None
            }
        }

        Rectangle {
            width: parent.width
            height: 40; radius: 20
            visible: !!root.p && root.p.volumeSupported
            color: Qt.alpha(Theme.fg, 0.06)
            Icon { id: volI; x: 14; anchors.verticalCenter: parent.verticalCenter; text: "volume_up" }
            Slider {
                anchors.left: volI.right; anchors.leftMargin: 10
                anchors.right: volT.left; anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                value: root.p ? root.p.volume : 0
                onMoved: f => { if (root.p) root.p.volume = f; }
            }
            Text {
                id: volT
                anchors.right: parent.right; anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: root.p ? Math.round(root.p.volume * 100) + "%" : ""
                color: Theme.muted
                font.family: "Google Sans Flex"; font.pixelSize: 11
            }
        }

        Flow {
            width: parent.width
            spacing: 6
            visible: Media.players.length > 1
            Repeater {
                model: Media.players
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool sel: modelData === root.p
                    width: chipT.implicitWidth + 18
                    height: 24; radius: 12
                    color: sel ? Qt.alpha(Theme.accent, 0.2) : (chipMa.containsMouse ? Qt.alpha(Theme.fg, 0.12) : Qt.alpha(Theme.fg, 0.08))
                    Text {
                        id: chipT
                        anchors.centerIn: parent
                        text: modelData.identity
                        color: parent.sel ? Theme.fg : Theme.muted
                        font.family: "Google Sans Flex"; font.pixelSize: 11
                    }
                    MouseArea { id: chipMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Media.select(modelData) }
                }
            }
        }
    }

    component CtrlButton: Icon {
        id: cb
        property string icon
        property bool on: false
        property bool big: false
        signal clicked()
        anchors.verticalCenter: parent.verticalCenter
        text: icon
        fill: 1
        font.pixelSize: big ? 26 : 20
        opacity: enabled ? 1 : 0.35
        color: on ? Theme.accent : (cbMa.containsMouse ? Theme.fg : Qt.alpha(Theme.fg, big ? 1 : 0.7))
        MouseArea { id: cbMa; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (cb.enabled) cb.clicked() }
    }

    // Thin track with a knob; reports 0..1 while dragging and on release.
    component Slider: Item {
        id: s
        property real value: 0
        property bool dragging: sMa.pressed
        signal moved(real f)
        signal released(real f)
        height: 16
        opacity: enabled ? 1 : 0.5
        readonly property real shown: dragging ? sMa.f : Math.max(0, Math.min(1, value))
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width; height: 5; radius: 3
            color: Qt.alpha(Theme.fg, 0.12)
            Rectangle { width: parent.width * s.shown; height: parent.height; radius: 3; color: Theme.accent }
        }
        Rectangle {
            visible: s.enabled && (sMa.containsMouse || s.dragging)
            x: parent.width * s.shown - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 12; height: 12; radius: 6
            color: Theme.fg
        }
        MouseArea {
            id: sMa
            property real f: 0
            anchors.fill: parent
            anchors.margins: -4
            enabled: s.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            function at(x) { return Math.max(0, Math.min(1, (x - 4) / s.width)); }
            onPressed: m => { f = at(m.x); s.moved(f); }
            onPositionChanged: m => { if (pressed) { f = at(m.x); s.moved(f); } }
            onReleased: m => { f = at(m.x); s.released(f); }
        }
    }
}
