import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Default applications per MIME type. Choices come from sky_default_apps.py
// (installed .desktop files that list the type); the current value and the
// change go through xdg-mime.
Page {
    id: page
    title: I18n.t("Default apps")

    readonly property string script: Quickshell.shellDir + "/scripts/sky_default_apps.py"
    readonly property var kinds: [
        { icon: "language", label: I18n.t("Web browser"), mimes: ["x-scheme-handler/http", "x-scheme-handler/https"] },
        { icon: "folder", label: I18n.t("File manager"), mimes: ["inode/directory"] },
        { icon: "description", label: I18n.t("Text editor"), mimes: ["text/plain"] },
        { icon: "image", label: I18n.t("Images"), mimes: ["image/png", "image/jpeg"] },
        { icon: "movie", label: I18n.t("Video"), mimes: ["video/mp4", "video/x-matroska"] },
        { icon: "music_note", label: I18n.t("Music"), mimes: ["audio/mpeg", "audio/flac"] },
        { icon: "picture_as_pdf", label: I18n.t("PDF"), mimes: ["application/pdf"] },
        { icon: "folder_zip", label: I18n.t("Archives"), mimes: ["application/zip"] }
    ]

    Section { text: I18n.t("Applications") }
    Card {
        Repeater {
            model: page.kinds
            SettingRow {
                id: row
                required property var modelData
                required property int index
                property var apps: []
                property string current: ""
                readonly property var choices: {
                    const l = apps.slice();
                    if (current && !l.some(a => a.id === current)) l.push({ id: current, name: current.replace(/\.desktop$/, "") });
                    return l;
                }

                divider: index > 0
                icon: modelData.icon
                title: modelData.label
                sub: {
                    const a = choices.find(c => c.id === current);
                    return a ? a.name : I18n.t("Not set");
                }

                Process {
                    id: list
                    command: ["python3", page.script, "apps", row.modelData.mimes[0]]
                    running: true
                    stdout: StdioCollector {
                        onStreamFinished: { try { row.apps = JSON.parse(text); } catch (e) { row.apps = []; } }
                    }
                }
                Process {
                    id: query
                    command: ["xdg-mime", "query", "default", row.modelData.mimes[0]]
                    running: true
                    stdout: StdioCollector { onStreamFinished: row.current = text.trim() }
                }
                Process {
                    id: setter
                    onExited: query.running = true
                }
                Select {
                    model: row.choices.map(c => c.name)
                    currentIndex: row.choices.findIndex(c => c.id === row.current)
                    placeholder: I18n.t("Not set")
                    onActivated: i => {
                        setter.command = ["xdg-mime", "default", row.choices[i].id].concat(row.modelData.mimes);
                        setter.running = true;
                    }
                }
            }
        }
    }
}
