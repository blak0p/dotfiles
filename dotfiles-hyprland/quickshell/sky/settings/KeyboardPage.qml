import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Keyboard and language: layouts of the main keyboard (switchable when there
// are several), key repeat (read-only) and the shell language.
Page {
    id: page
    title: I18n.t("Keyboard and language")

    property var layouts: []
    property int active: 0
    property string keymap: ""
    property string rate: ""
    property string delay: ""

    Component.onCompleted: refresh()
    function refresh() { dev.running = true; rateProc.running = true; delayProc.running = true; }

    Process {
        id: dev
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const ks = JSON.parse(text).keyboards;
                    const k = ks.find(x => x.main) || ks[0];
                    const l = (k.layout || "").split(",");
                    const v = (k.variant || "").split(",");
                    page.layouts = l.map((x, i) => v[i] ? x + " (" + v[i] + ")" : x);
                    page.active = k.active_layout_index || 0;
                    page.keymap = k.active_keymap || "";
                } catch (e) { page.layouts = []; }
            }
        }
    }
    Process {
        id: rateProc
        command: ["hyprctl", "getoption", "input:repeat_rate", "-j"]
        stdout: StdioCollector { onStreamFinished: { try { page.rate = String(JSON.parse(text).int); } catch (e) {} } }
    }
    Process {
        id: delayProc
        command: ["hyprctl", "getoption", "input:repeat_delay", "-j"]
        stdout: StdioCollector { onStreamFinished: { try { page.delay = String(JSON.parse(text).int); } catch (e) {} } }
    }
    Process { id: sw; onExited: page.refresh() }
    function switchTo(i) { sw.command = ["hyprctl", "switchxkblayout", "all", String(i)]; sw.running = true; }

    Section { text: I18n.t("Keyboard layout") }
    Card {
        SettingRow {
            icon: "keyboard"
            title: I18n.t("Current layout")
            sub: page.keymap || "—"
            Select {
                visible: page.layouts.length > 1
                model: page.layouts
                currentIndex: page.active
                onActivated: i => page.switchTo(i)
            }
        }
        SettingRow {
            visible: page.layouts.length <= 1
            divider: true
            icon: "info"
            title: I18n.t("Only one layout configured")
            sub: page.layouts[0] || ""
        }
    }

    Section { text: I18n.t("Key repeat") }
    Card {
        SettingRow {
            icon: "speed"
            title: I18n.t("Repeat rate")
            sub: page.rate ? I18n.t("%1 keys per second", page.rate) : "—"
        }
        SettingRow {
            divider: true
            icon: "timer"
            title: I18n.t("Repeat delay")
            sub: page.delay ? I18n.t("%1 ms", page.delay) : "—"
        }
    }

    Section { text: I18n.t("Language") }
    Card {
        SettingRow {
            icon: "language"
            title: I18n.t("Interface language")
            sub: I18n.t("Follows the system language (LANG)")
            Text {
                text: I18n.lang
                color: Theme.fg
                font.family: "Google Sans Flex"; font.pixelSize: 14; font.weight: Font.DemiBold
            }
        }
    }
}
