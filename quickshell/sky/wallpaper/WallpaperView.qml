import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.island
import qs.wallpaper

// The island's wallpaper view: a horizontal strip of pictures that grows out of
// the clock pill and slides with the arrow keys. No chrome at all — no title
// bar, no tabs, no filters, no search, no close button. Esc or a click outside
// closes it; Enter applies. Wallpaper Engine scenes and plain images/videos
// share the strip.
Item {
    id: root
    property bool open: false

    onOpenChanged: {
        // The arrow keys belong to Hyprland while the strip is open: the
        // "wallpapers" submap (hypr/custom/keybinds.lua) maps them to the
        // wallpaperPrev/Next globals, so they never leak to the window below.
        submap.run(open ? "wallpapers" : "reset");
        if (!open) return;
        WallpaperService.refresh();
    }
    Component.onDestruction: submap.run("reset")

    Process {
        id: submap
        // Hyprland 0.57 routes dispatchers through Lua, so a bare
        // `submap <name>` does not parse: it has to be hl.dsp.submap("name").
        function run(name) {
            command = ["hyprctl", "dispatch", "hl.dsp.submap(\"" + name + "\")"];
            running = true;
        }
    }

    Item {
        anchors.fill: parent
        anchors.margins: Config.wallpaperPad

        ListView {
            id: strip
            anchors.fill: parent
            orientation: ListView.Horizontal
            spacing: Config.cardGap
            clip: true
            model: WallpaperService.entries
            currentIndex: WallpaperService.selected
            // Keep the selected card centred and always animate the slide, so
            // the arrow keys feel like moving the strip instead of jumping.
            highlightRangeMode: ListView.StrictlyEnforceRange
            highlightMoveDuration: 220
            preferredHighlightBegin: (width - Config.cardW) / 2
            preferredHighlightEnd: (width + Config.cardW) / 2
            boundsBehavior: Flickable.StopAtBounds

            onCurrentIndexChanged: if (currentIndex !== WallpaperService.selected) WallpaperService.selected = currentIndex

            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                width: Config.cardW
                height: Config.cardH
                anchors.verticalCenter: parent ? parent.verticalCenter : undefined

                readonly property bool selected: ListView.isCurrentItem
                readonly property bool applied: WallpaperService.applied === modelData.path

                scale: selected ? 1.0 : 0.86
                opacity: selected ? 1.0 : 0.62
                Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    clip: true
                    color: Theme.surface2
                    border.width: cell.selected || cell.applied ? 2 : 1
                    border.color: cell.selected ? Theme.accent
                        : (cell.applied ? Qt.alpha(Theme.accent, 0.55) : Qt.alpha(Theme.outline, 0.25))
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    Image {
                        anchors.fill: parent
                        visible: !!modelData.thumb
                        source: WallpaperService.thumbOf(modelData)
                        sourceSize.width: 640
                        sourceSize.height: 360
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                    }
                    Icon {
                        visible: !modelData.thumb
                        anchors.centerIn: parent
                        text: modelData.kind === "video" ? "movie" : "image"
                        color: Theme.muted
                        font.pixelSize: 26
                    }
                    // The name is the only text, and only while selected or
                    // hovered: the strip itself stays picture-only.
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 34
                        opacity: hover.hovered || cell.selected ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 140 } }
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.75) }
                        }
                        Text {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            anchors.bottomMargin: 6
                            elide: Text.ElideRight
                            text: modelData.title
                            color: "#ffffff"
                            font.family: "Google Sans Flex"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                    }
                }

                // A dot marks the applied wallpaper without adding a label.
                Rectangle {
                    visible: cell.applied
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 8
                    width: 7; height: 7; radius: 4
                    color: Theme.accent
                }

                HoverHandler {
                    id: hover
                    onHoveredChanged: if (hovered) WallpaperService.selected = cell.index
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: WallpaperService.apply(cell.index)
                }
            }
        }
    }

    Text {
        visible: WallpaperService.entries.length === 0
        anchors.centerIn: parent
        text: "No wallpapers found"
        color: Theme.muted
        font.family: "Google Sans Flex"
        font.pixelSize: 13
    }

    // Clicks inside the strip never fall through to the pill (which would close
    // the view again).
    MouseArea { anchors.fill: parent; onClicked: {} }
}
