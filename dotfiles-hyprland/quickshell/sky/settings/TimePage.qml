import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Date and time through timedatectl. Changes ask for admin rights via the
// sky polkit agent.
Page {
    id: page
    title: I18n.t("Date and time")

    property string timezone: ""
    property bool ntp: false
    property bool synced: false
    property bool localRtc: false
    property var zones: []
    property date now: new Date()

    Component.onCompleted: { refresh(); zonesProc.running = true; }
    function refresh() { show.running = true; }

    Timer { interval: 1000; running: true; repeat: true; onTriggered: page.now = new Date() }

    Process {
        id: show
        command: ["timedatectl", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.split("\n")) {
                    const i = line.indexOf("=");
                    if (i < 0) continue;
                    const k = line.slice(0, i), v = line.slice(i + 1);
                    if (k === "Timezone") page.timezone = v;
                    else if (k === "NTP") page.ntp = v === "yes";
                    else if (k === "NTPSynchronized") page.synced = v === "yes";
                    else if (k === "LocalRTC") page.localRtc = v === "yes";
                }
            }
        }
    }
    Process {
        id: zonesProc
        command: ["timedatectl", "list-timezones"]
        stdout: StdioCollector { onStreamFinished: page.zones = text.split("\n").filter(z => z) }
    }
    Process { id: act; onExited: page.refresh() }
    function run(cmd) { if (act.running) return; act.command = cmd; act.running = true; }

    Section { text: I18n.t("Current time") }
    Card {
        Item {
            width: parent.width; height: 96
            Column {
                anchors.centerIn: parent
                spacing: 2
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatTime(page.now, "HH:mm:ss")
                    color: Theme.fg
                    font.family: "Google Sans Flex"; font.pixelSize: 38; font.weight: Font.DemiBold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: page.now.toLocaleDateString(Qt.locale(), Locale.LongFormat)
                    color: Theme.muted
                    font.family: "Google Sans Flex"; font.pixelSize: 13
                }
            }
        }
    }

    Section { text: I18n.t("Synchronization") }
    Card {
        SettingRow {
            icon: "sync"
            current: page.ntp
            title: I18n.t("Set time automatically")
            sub: !page.ntp ? I18n.t("Off") : page.synced ? I18n.t("Synchronized") : I18n.t("Not synchronized yet")
            Toggle {
                checked: page.ntp
                label: I18n.t("Set time automatically")
                onToggled: on => page.run(["timedatectl", "set-ntp", on ? "true" : "false"])
            }
        }
        SettingRow {
            divider: true
            icon: "memory"
            title: I18n.t("Hardware clock")
            sub: page.localRtc ? I18n.t("Local time") : "UTC"
        }
    }

    Section { text: I18n.t("Time zone") }
    Card {
        SettingRow {
            icon: "public"
            title: I18n.t("Time zone")
            sub: page.timezone || "—"
            Select {
                model: page.zones
                currentIndex: page.zones.indexOf(page.timezone)
                placeholder: page.timezone
                onActivated: i => page.run(["timedatectl", "set-timezone", page.zones[i]])
            }
        }
    }
}
