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
        command: ["sh", "-c", "gsettings get org.gnome.desktop.interface gtk-theme; gsettings get org.gnome.desktop.interface icon-theme"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n").map(x => x.replace(/'/g, "").trim());
                page.gtkTheme = l[0] || "";
                page.iconTheme = l[1] || "";
            }
        }
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
            icon: "dark_mode"
            title: I18n.t("Dark theme")
            sub: I18n.t("Colors follow the wallpaper")
        }
    }

    Section { text: I18n.t("Themes") }
    Card {
        SettingRow { icon: "style"; title: I18n.t("GTK theme"); sub: page.gtkTheme || "—" }
        SettingRow { divider: true; icon: "category"; title: I18n.t("Icon theme"); sub: page.iconTheme || "—" }
    }
}
