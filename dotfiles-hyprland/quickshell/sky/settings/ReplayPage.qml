import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Instant replay (ReplayService.qml): on/off, buffer length, FPS, quality,
// audio and clips folder, plus the gallery of saved clips (play, copy to the
// clipboard, delete). Options are written by scripts/sky_replay.py into the
// "replay" object of ~/.config/sky/settings.json, which Config.qml watches.
Page {
    id: page
    title: I18n.t("Instant replay")

    readonly property string script: ReplayService.script
    // Effective options (defaults filled in by the script).
    property var opts: ({ enabled: false, seconds: 30, fps: 60, quality: "very_high", audio: "desktop", dir: "", monitor: "auto" })
    property var clips: []
    property string busyPath: ""

    readonly property var secondsModel: [15, 30, 60, 120, 300].map(s => ({ label: s < 60 ? I18n.t("%1 seconds", [s]) : I18n.t("%1 min", [s / 60]), value: s }))
    readonly property var screenModel: [{ label: I18n.t("Main screen (%1)", [ReplayService.monitor || Config.screen || "auto"]), value: "auto" }]
        .concat(Quickshell.screens.map(sc => ({ label: sc.name, value: sc.name })))
    readonly property var fpsModel: [30, 60, 120, 144].map(f => ({ label: f + " FPS", value: f }))
    readonly property var qualityModel: [
        { label: I18n.t("Medium"), value: "medium" },
        { label: I18n.t("High"), value: "high" },
        { label: I18n.t("Very high"), value: "very_high" },
        { label: I18n.t("Ultra"), value: "ultra" }
    ]
    readonly property var audioModel: [
        { label: I18n.t("No audio"), value: "none" },
        { label: I18n.t("Desktop audio"), value: "desktop" },
        { label: I18n.t("Desktop and microphone"), value: "desktop_mic" }
    ]

    Component.onCompleted: reload()
    function reload() { optsProc.running = true; }
    function rescan() { if (page.opts.dir) { scanProc.command = ["python3", page.script, "scan", page.opts.dir]; scanProc.running = true; } }
    function set(key, value) {
        setProc.command = ["python3", page.script, "set", Config.userFile, key, String(value)];
        setProc.running = true;
    }
    function run(cmd) { act.command = cmd; act.running = true; }
    function sizeText(b) { return b >= 1048576 ? (b / 1048576).toFixed(1) + " MB" : Math.max(1, Math.round(b / 1024)) + " KB"; }

    Connections {
        target: Config
        function onUserChanged() { page.reload(); }
    }
    Connections {
        target: ReplayService
        function onSavedCountChanged() { page.rescan(); }
    }

    Process {
        id: optsProc
        command: ["python3", page.script, "options", Config.userFile]
        stdout: StdioCollector {
            onStreamFinished: {
                try { page.opts = JSON.parse(text); page.rescan(); } catch (e) {}
            }
        }
    }
    Process {
        id: scanProc
        stdout: StdioCollector {
            onStreamFinished: { try { page.clips = JSON.parse(text); } catch (e) { page.clips = []; } }
        }
    }
    Process { id: setProc }
    Process { id: act; onExited: { page.busyPath = ""; page.rescan(); } }

    Section { text: I18n.t("Replay buffer") }
    Card {
        SettingRow {
            icon: "fiber_manual_record"
            current: ReplayService.active
            title: I18n.t("Instant replay")
            sub: !ReplayService.available ? I18n.t("gpu-screen-recorder is not installed")
                : ReplayService.active ? I18n.t("Recording the last %1 seconds · Super+Alt+S saves a clip", [page.opts.seconds])
                : ReplayService.enabled && ReplayService.error ? ReplayService.error
                : ReplayService.enabled ? I18n.t("Starting…") : I18n.t("Off")
            Toggle {
                checked: ReplayService.enabled
                label: I18n.t("Instant replay")
                onToggled: on => ReplayService.setEnabled(on)
            }
        }
        SettingRow {
            divider: true
            icon: "desktop_windows"
            title: I18n.t("Screen")
            Select {
                model: page.screenModel
                currentIndex: Math.max(0, page.screenModel.findIndex(x => x.value === (page.opts.monitor || "auto")))
                onActivated: i => page.set("monitor", page.screenModel[i].value)
            }
        }
        SettingRow {
            divider: true
            icon: "timer"
            title: I18n.t("Clip length")
            sub: I18n.t("Seconds kept in memory")
            Select {
                model: page.secondsModel
                currentIndex: page.secondsModel.findIndex(x => x.value === page.opts.seconds)
                placeholder: I18n.t("%1 seconds", [page.opts.seconds])
                onActivated: i => page.set("seconds", page.secondsModel[i].value)
            }
        }
        SettingRow {
            divider: true
            icon: "speed"
            title: I18n.t("Frame rate")
            Select {
                model: page.fpsModel
                currentIndex: page.fpsModel.findIndex(x => x.value === page.opts.fps)
                onActivated: i => page.set("fps", page.fpsModel[i].value)
            }
        }
        SettingRow {
            divider: true
            icon: "high_quality"
            title: I18n.t("Quality")
            sub: I18n.t("Compression, not resolution: lower is lighter but blurrier in motion")
            Select {
                model: page.qualityModel
                currentIndex: page.qualityModel.findIndex(x => x.value === page.opts.quality)
                onActivated: i => page.set("quality", page.qualityModel[i].value)
            }
        }
        SettingRow {
            divider: true
            icon: "graphic_eq"
            title: I18n.t("Audio")
            Select {
                model: page.audioModel
                currentIndex: page.audioModel.findIndex(x => x.value === page.opts.audio)
                onActivated: i => page.set("audio", page.audioModel[i].value)
            }
        }
        SettingRow {
            divider: true
            icon: "folder"
            title: I18n.t("Clips folder")
            sub: I18n.t("Type a path and press Enter")
            Rectangle {
                width: 260; height: 34; radius: 17
                color: Theme.surface2
                border.width: dirInput.activeFocus ? 1 : 0
                border.color: Theme.accent
                TextInput {
                    id: dirInput
                    anchors.fill: parent
                    anchors.leftMargin: 14; anchors.rightMargin: 14
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    text: page.opts.dir
                    color: Theme.fg
                    selectByMouse: true
                    font.family: "Google Sans Flex"; font.pixelSize: 13
                    onAccepted: if (text.trim() && text.trim() !== page.opts.dir) page.set("dir", text.trim())
                }
            }
            Btn {
                icon: "open_in_new"
                text: I18n.t("Open folder")
                onClicked: page.run(["xdg-open", page.opts.dir])
            }
        }
    }

    Section { text: I18n.t("Clips") }
    Card {
        Item {
            width: parent.width
            height: page.clips.length ? grid.height + 24 : 72
            Text {
                visible: !page.clips.length
                anchors.centerIn: parent
                text: I18n.t("No clips yet")
                color: Theme.muted
                font.family: "Google Sans Flex"; font.pixelSize: 13
            }
            Flow {
                id: grid
                x: 12; y: 12
                width: parent.width - 24
                spacing: 12
                Repeater {
                    model: page.clips
                    delegate: Rectangle {
                        id: card
                        required property var modelData
                        readonly property real w: (grid.width - 2 * grid.spacing) / 3
                        width: w
                        height: w * 9 / 16 + 54
                        radius: 14
                        color: Theme.widget
                        opacity: page.busyPath === modelData.path ? 0.4 : 1

                        Rectangle {
                            id: shot
                            width: parent.width; height: parent.width * 9 / 16
                            radius: 14
                            color: Qt.alpha(Theme.fg, 0.06)
                            clip: true
                            Image {
                                anchors.fill: parent
                                visible: !!card.modelData.thumb
                                source: card.modelData.thumb ? "file://" + card.modelData.thumb : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize.width: 480
                            }
                            Icon {
                                anchors.centerIn: parent
                                text: "play_circle"
                                fill: 1
                                font.pixelSize: 40
                                color: "white"
                                opacity: playArea.containsMouse ? 0.95 : 0.6
                            }
                            MouseArea {
                                id: playArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.run(["xdg-open", card.modelData.path])
                            }
                        }
                        Column {
                            anchors.left: parent.left; anchors.leftMargin: 10
                            anchors.right: actions.left; anchors.rightMargin: 6
                            anchors.top: shot.bottom; anchors.topMargin: 8
                            Text {
                                width: parent.width
                                text: card.modelData.name
                                elide: Text.ElideMiddle
                                color: Theme.fg
                                font.family: "Google Sans Flex"; font.pixelSize: 12; font.weight: Font.DemiBold
                            }
                            Text {
                                width: parent.width
                                text: new Date(card.modelData.mtime * 1000).toLocaleString(Qt.locale(), Locale.ShortFormat) + " · " + page.sizeText(card.modelData.size)
                                elide: Text.ElideRight
                                color: Theme.muted
                                font.family: "Google Sans Flex"; font.pixelSize: 11
                            }
                        }
                        Row {
                            id: actions
                            anchors.right: parent.right; anchors.rightMargin: 6
                            anchors.top: shot.bottom; anchors.topMargin: 8
                            spacing: 2
                            ClipAction {
                                icon: "content_copy"
                                tip: I18n.t("Copy to clipboard")
                                onClicked: page.run(["sh", "-c", 'python3 "$1" uri "$2" | wl-copy --type text/uri-list', "sh", page.script, card.modelData.path])
                            }
                            ClipAction {
                                icon: "delete"
                                danger: true
                                tip: I18n.t("Delete")
                                onClicked: {
                                    page.busyPath = card.modelData.path;
                                    page.run(["python3", page.script, "delete", page.opts.dir, card.modelData.path]);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
