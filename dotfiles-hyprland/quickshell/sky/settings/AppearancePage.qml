import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.island
import qs.wallpaper

// Appearance: the applied wallpaper (with a shortcut to the picker), the
// palette derived from it and read-only theme info. Dark only.
Page {
    id: page
    title: I18n.t("Appearance")

    readonly property var entry: WallpaperService.entries.find(e => e.path === WallpaperService.applied) || null
    readonly property string preview: {
        if (entry && entry.thumb) return WallpaperService.thumbOf(entry);
        const p = WallpaperService.applied;
        return /\.(png|jpe?g|webp|bmp|gif)$/i.test(p) ? "file://" + p : "";
    }
    readonly property string wallName: {
        const p = WallpaperService.applied;
        return entry && entry.title ? entry.title : p ? p.split("/").pop() : "";
    }
    property string gtkTheme: ""
    property string iconTheme: ""
    property string cursorTheme: ""
    property int cursorSize: 24
    property var lists: ({ gtk: [], icons: [], cursors: [], sizes: [24, 32, 48], schemes: [] })
    property string scheme: "scheme-tonal-spot"
    property string accent: ""          // "" = from the wallpaper
    property string hexDraft: ""
    property string error: ""
    readonly property string script: Qt.resolvedUrl("../scripts/sky_appearance.py").toString().replace("file://", "")
    readonly property string themeScript: Qt.resolvedUrl("../scripts/sky_theme.py").toString().replace("file://", "")
    readonly property var presets: ["#5cb8f0", "#ff6b6b", "#ffa94d", "#ffd43b", "#69db7c", "#38d9a9", "#9775fa", "#f783ac"]
    readonly property var schemeNames: ({
        "scheme-tonal-spot": I18n.t("Tonal spot"), "scheme-vibrant": I18n.t("Vibrant"),
        "scheme-expressive": I18n.t("Expressive"), "scheme-fidelity": I18n.t("Fidelity"),
        "scheme-content": I18n.t("Content"), "scheme-neutral": I18n.t("Neutral"),
        "scheme-monochrome": I18n.t("Monochrome") })
    function withCurrent(list, cur) { return cur && list.indexOf(cur) < 0 ? [cur].concat(list) : list; }
    function run(args, after) {
        runner.after = after || null;
        runner.command = ["python3", script].concat(args);
        runner.running = true;
    }
    function savePalette(sch, acc) {
        scheme = sch; accent = acc; hexDraft = acc;
        run(["palette", sch, acc || "auto"], () => regen.running = true);
    }
    function validHex(t) { return /^#[0-9a-fA-F]{6}$/.test(t); }
    readonly property var swatches: [
        { name: I18n.t("Accent"), color: Theme.accent },
        { name: I18n.t("Secondary"), color: Theme.secondary },
        { name: I18n.t("Tertiary"), color: Theme.tertiary },
        { name: I18n.t("Surface"), color: Theme.surface },
        { name: I18n.t("Widget"), color: Theme.widget },
        { name: I18n.t("Text"), color: Theme.fg }
    ]

    Process {
        id: gtk
        command: ["sh", "-c", "for k in gtk-theme icon-theme cursor-theme cursor-size; do gsettings get org.gnome.desktop.interface $k; done; cat \"${XDG_CONFIG_HOME:-$HOME/.config}/sky/theme.json\" 2>/dev/null"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n");
                const v = i => (l[i] || "").replace(/'/g, "").trim();
                page.gtkTheme = v(0);
                page.iconTheme = v(1);
                page.cursorTheme = v(2);
                page.cursorSize = parseInt(v(3)) || 24;
                try {
                    const t = JSON.parse(l.slice(4).join("\n"));
                    if (t.scheme) page.scheme = t.scheme;
                    page.accent = t.accent || "";
                    page.hexDraft = page.accent;
                } catch (e) {}
            }
        }
    }
    Process {
        id: scanner
        command: ["python3", page.script, "scan"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { try { page.lists = JSON.parse(text); } catch (e) {} }
        }
    }
    Process {
        id: runner
        property var after: null
        onExited: code => {
            page.error = code === 0 ? "" : I18n.t("Couldn't save the settings");
            if (code === 0 && after) after();
        }
    }
    Process {
        id: regen
        command: ["python3", page.themeScript]
    }

    Section { text: I18n.t("Wallpaper") }
    Card {
        Item {
            width: parent.width; height: 220
            Rectangle {
                x: 10; y: 10
                width: parent.width - 20; height: parent.height - 20
                radius: 16
                color: Theme.surface2
                clip: true
                Image {
                    anchors.fill: parent
                    source: page.preview
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 900
                }
                Icon {
                    visible: page.preview === ""
                    anchors.centerIn: parent
                    text: "wallpaper"; color: Theme.muted; font.pixelSize: 40
                }
            }
        }
        SettingRow {
            icon: "wallpaper"
            title: page.wallName || I18n.t("No wallpaper")
            sub: I18n.t("Colors follow the wallpaper")
            Btn {
                primary: true
                icon: "image"
                text: I18n.t("Change wallpaper")
                onClicked: { SettingsState.close(); IslandState.openWallpaper(); }
            }
        }
    }

    Section { text: I18n.t("Palette") }
    Card {
        Item {
            width: parent.width; height: 92
            Row {
                x: 16; y: 14
                spacing: 12
                Repeater {
                    model: page.swatches
                    Column {
                        required property var modelData
                        spacing: 6
                        Rectangle {
                            width: (page.width - 14 - 44 - 60) / 6; height: 40; radius: 14
                            color: modelData.color
                            border.width: 1; border.color: Qt.alpha(Theme.outline, 0.6)
                        }
                        Text {
                            text: modelData.name
                            color: Theme.muted
                            font.family: "Google Sans Flex"; font.pixelSize: 12
                        }
                    }
                }
            }
        }
        SettingRow {
            divider: true
            icon: "palette"
            title: I18n.t("Palette style")
            sub: I18n.t("Material scheme variant")
            Select {
                model: page.lists.schemes.map(k => page.schemeNames[k] || k)
                currentIndex: page.lists.schemes.indexOf(page.scheme)
                onActivated: i => page.savePalette(page.lists.schemes[i], page.accent)
            }
        }
        SettingRow {
            divider: true
            icon: "colorize"
            title: I18n.t("Accent color")
            sub: page.accent ? page.accent : I18n.t("From the wallpaper")
            Btn {
                icon: "wallpaper"
                text: I18n.t("From the wallpaper")
                primary: page.accent === ""
                onClicked: page.savePalette(page.scheme, "")
            }
        }
        Item {
            width: parent.width; height: 60
            Row {
                x: 16; anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Repeater {
                    model: page.presets
                    Rectangle {
                        required property string modelData
                        width: 32; height: 32; radius: 16
                        color: modelData
                        border.width: page.accent === modelData ? 3 : 1
                        border.color: page.accent === modelData ? Theme.fg : Qt.alpha(Theme.outline, 0.6)
                        Accessible.role: Accessible.Button
                        Accessible.name: modelData
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.savePalette(page.scheme, modelData)
                        }
                    }
                }
                Rectangle {
                    width: 110; height: 36; radius: 18
                    color: Theme.surface2
                    border.width: hex.activeFocus ? 2 : 1
                    border.color: hex.activeFocus ? Theme.accent : (page.hexDraft === "" || page.validHex(page.hexDraft) ? Theme.outline : Theme.secondary)
                    TextInput {
                        id: hex
                        anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                        verticalAlignment: TextInput.AlignVCenter
                        text: page.hexDraft
                        validator: RegularExpressionValidator { regularExpression: /^#?[0-9a-fA-F]{0,6}$/ }
                        color: Theme.fg
                        font.family: "Google Sans Flex"; font.pixelSize: 13
                        onTextEdited: page.hexDraft = text
                        onAccepted: if (page.validHex(text)) page.savePalette(page.scheme, text.toLowerCase())
                        Text {
                            visible: hex.text === ""
                            text: "#rrggbb"; color: Theme.muted
                            font: hex.font
                        }
                    }
                }
            }
        }
        SettingRow {
            divider: true
            icon: "dark_mode"
            title: I18n.t("Dark theme")
            sub: I18n.t("Light mode is not available yet")
        }
        Text {
            visible: page.error !== ""
            x: 16
            text: page.error
            color: Theme.secondary
            font.family: "Google Sans Flex"; font.pixelSize: 12
        }
    }

    Section { text: I18n.t("Themes") }
    Card {
        SettingRow {
            icon: "style"; title: I18n.t("GTK theme"); sub: I18n.t("Applies to GTK apps")
            Select {
                readonly property var items: page.withCurrent(page.lists.gtk, page.gtkTheme)
                model: items
                currentIndex: items.indexOf(page.gtkTheme)
                onActivated: i => { page.gtkTheme = items[i]; page.run(["gtk", items[i]]); }
            }
        }
        SettingRow {
            divider: true
            icon: "category"; title: I18n.t("Icon theme"); sub: I18n.t("Qt apps take theirs from qt6ct")
            Select {
                readonly property var items: page.withCurrent(page.lists.icons, page.iconTheme)
                model: items
                currentIndex: items.indexOf(page.iconTheme)
                onActivated: i => { page.iconTheme = items[i]; page.run(["icons", items[i]]); }
            }
        }
        SettingRow {
            divider: true
            icon: "mouse"; title: I18n.t("Cursor theme"); sub: I18n.t("Applied now and saved for the next session")
            Select {
                readonly property var items: page.withCurrent(page.lists.cursors, page.cursorTheme)
                model: items
                currentIndex: items.indexOf(page.cursorTheme)
                onActivated: i => { page.cursorTheme = items[i]; page.run(["cursor", items[i], String(page.cursorSize)]); }
            }
        }
        SettingRow {
            divider: true
            icon: "open_with"; title: I18n.t("Cursor size")
            Select {
                readonly property var items: page.lists.sizes.indexOf(page.cursorSize) < 0 ? [page.cursorSize].concat(page.lists.sizes) : page.lists.sizes
                implicitWidth: 100
                model: items.map(n => String(n))
                currentIndex: items.indexOf(page.cursorSize)
                onActivated: i => { page.cursorSize = items[i]; if (page.cursorTheme) page.run(["cursor", page.cursorTheme, String(items[i])]); }
            }
        }
    }
}
