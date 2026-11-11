import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs
import qs.island

// Sound settings: output and input devices (pick the default, set volume,
// mute) and the apps playing audio, all through Pipewire. Rows are the
// island's MixerRow.
Page {
    id: page
    title: I18n.t("Sound")

    readonly property var nodes: Pipewire.nodes.values
    readonly property var outputs: nodes.filter(n => n.type === PwNodeType.AudioSink)
    readonly property var inputs: nodes.filter(n => n.type === PwNodeType.AudioSource)
    readonly property var playing: nodes.filter(n => n.type === PwNodeType.AudioOutStream)
    // Quickshell's own capture streams (level meters) are not apps.
    readonly property var recording: nodes.filter(n => n.type === PwNodeType.AudioInStream
        && !String(n.properties["application.name"] || n.name || "").toLowerCase().startsWith("quickshell"))

    PwObjectTracker { objects: page.outputs.concat(page.inputs, page.playing, page.recording) }

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

    Section { text: I18n.t("Output") }
    Card {
        spacing: 4
        SettingRow { visible: page.outputs.length === 0; icon: "volume_off"; title: I18n.t("No output devices") }
        Repeater {
            model: page.outputs
            MixerRow {
                required property var modelData
                width: parent ? parent.width : 0
                node: modelData
                glyph: page.devGlyph(modelData)
                title: page.devName(modelData)
                selectable: true
                selected: Pipewire.defaultAudioSink === modelData
                onPicked: Pipewire.preferredDefaultAudioSink = modelData
            }
        }
    }

    Section { text: I18n.t("Input") }
    Card {
        spacing: 4
        SettingRow { visible: page.inputs.length === 0; icon: "mic_off"; title: I18n.t("No input devices") }
        Repeater {
            model: page.inputs
            MixerRow {
                required property var modelData
                width: parent ? parent.width : 0
                node: modelData
                glyph: "mic"
                title: page.devName(modelData)
                selectable: true
                selected: Pipewire.defaultAudioSource === modelData
                onPicked: Pipewire.preferredDefaultAudioSource = modelData
            }
        }
    }

    Section { text: I18n.t("Applications") }
    Card {
        spacing: 4
        SettingRow { visible: page.playing.length + page.recording.length === 0; icon: "graphic_eq"; title: I18n.t("No apps using audio") }
        Repeater {
            model: page.playing
            MixerRow {
                required property var modelData
                width: parent ? parent.width : 0
                node: modelData
                appIcon: page.appIcon(modelData)
                glyph: "graphic_eq"
                title: page.appName(modelData)
                subtitle: page.appMedia(modelData)
            }
        }
        Repeater {
            model: page.recording
            MixerRow {
                required property var modelData
                width: parent ? parent.width : 0
                node: modelData
                appIcon: page.appIcon(modelData)
                glyph: "mic"
                title: page.appName(modelData)
                subtitle: page.appMedia(modelData)
            }
        }
    }
}
