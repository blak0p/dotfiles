import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs

// Sound mixer page: output devices (pick the default), every app playing
// audio, microphones (pick the default) and apps recording, each with its own
// volume, mute and live level.
Flickable {
    id: root

    readonly property real wanted: col.implicitHeight
    contentHeight: col.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    readonly property var nodes: Pipewire.nodes.values
    // Node type is constant; media.class/audio may not be populated yet when
    // the list is first evaluated, so filter on it alone.
    readonly property var outputs: nodes.filter(n => n.type === PwNodeType.AudioSink)
    readonly property var inputs: nodes.filter(n => n.type === PwNodeType.AudioSource)
    readonly property var playing: nodes.filter(n => n.type === PwNodeType.AudioOutStream)
    // Skips Quickshell's own capture streams (the level meters below).
    readonly property var recording: nodes.filter(n => n.type === PwNodeType.AudioInStream
        && !String(n.properties["application.name"] || n.name || "").toLowerCase().startsWith("quickshell"))

    // Volume/mute of a node are only live while it is tracked.
    PwObjectTracker { objects: root.visible ? root.outputs.concat(root.inputs, root.playing, root.recording) : [] }

    function devName(n) { return n.nickname || n.description || n.name; }
    function devGlyph(n) {
        const s = ((n.name || "") + " " + (n.description || "")).toLowerCase();
        if (s.includes("hdmi") || s.includes("displayport")) return "tv";
        if (s.includes("head") || s.includes("hyperx") || s.includes("usb") || s.includes("bluez")) return "headphones";
        return "speaker";
    }
    function appName(n) {
        const p = n.properties;
        return p["application.name"] || p["application.process.binary"] || n.description || n.name;
    }
    function appIcon(n) {
        const p = n.properties;
        return p["application.icon-name"] || (p["application.process.binary"] || "").toLowerCase();
    }
    function appMedia(n) {
        const m = n.properties["media.name"] || "";
        return m === appName(n) ? "" : m;
    }

    Column {
        id: col
        width: root.width
        spacing: 6

        Section { label: I18n.t("Output") }
        Repeater {
            model: root.outputs
            delegate: MixerRow {
                required property var modelData
                width: col.width
                node: modelData
                glyph: root.devGlyph(modelData)
                title: root.devName(modelData)
                selectable: true
                selected: Pipewire.defaultAudioSink === modelData
                onPicked: Pipewire.preferredDefaultAudioSink = modelData
            }
        }

        Section { label: I18n.t("Apps"); visible: root.playing.length > 0 }
        Repeater {
            model: root.playing
            delegate: MixerRow {
                required property var modelData
                width: col.width
                node: modelData
                appIcon: root.appIcon(modelData)
                glyph: "graphic_eq"
                title: root.appName(modelData)
                subtitle: root.appMedia(modelData)
            }
        }
        Empty { visible: root.playing.length === 0; text: I18n.t("No apps playing audio") }

        Section { label: I18n.t("Microphone"); visible: root.inputs.length > 0 }
        Repeater {
            model: root.inputs
            delegate: MixerRow {
                required property var modelData
                width: col.width
                node: modelData
                glyph: "mic"
                title: root.devName(modelData)
                selectable: true
                selected: Pipewire.defaultAudioSource === modelData
                onPicked: Pipewire.preferredDefaultAudioSource = modelData
            }
        }

        Section { label: I18n.t("Recording"); visible: root.recording.length > 0 }
        Repeater {
            model: root.recording
            delegate: MixerRow {
                required property var modelData
                width: col.width
                node: modelData
                appIcon: root.appIcon(modelData)
                glyph: "mic"
                title: root.appName(modelData)
                subtitle: root.appMedia(modelData)
            }
        }
    }

    component Section: Text {
        property string label
        text: label.toUpperCase()
        topPadding: 6
        leftPadding: 4
        color: Theme.muted
        font.family: "Google Sans Flex"; font.pixelSize: 10; font.weight: Font.Bold
        font.letterSpacing: 0.8
    }
    component Empty: Text {
        width: col.width
        height: 32
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: Theme.muted
        font.family: "Google Sans Flex"; font.pixelSize: 11
    }
}
