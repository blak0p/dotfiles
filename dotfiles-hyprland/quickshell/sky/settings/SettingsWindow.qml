import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

// The sky settings window (Super+I): a sidebar of categories with search and
// the selected page on the right. Replaces KDE System Settings. Pages are
// loaded only while the window is open, so their scanners stop on close.
Scope {
    id: root

    property string query: ""
    readonly property var matches: SettingsState.pages.filter(p => {
        const q = root.query.trim().toLowerCase();
        if (!q) return true;
        return (I18n.t(p.label) + " " + p.label + " " + p.keys).toLowerCase().includes(q);
    })

    Connections {
        target: SettingsState
        function onShownChanged() {
            if (SettingsState.shown) { root.query = ""; search.forceActiveFocus(); }
        }
    }

    PanelWindow {
        id: win

        screen: {
            const main = Quickshell.screens.filter(s => s.name === Config.screen);
            return main.length ? main[0] : Quickshell.screens[0];
        }
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        // Top, not Overlay: the polkit dialog (Overlay) must stay above it.
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell:settings"
        WlrLayershell.keyboardFocus: SettingsState.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: "transparent"
        visible: SettingsState.shown || card.opacity > 0

        Shortcut {
            sequence: "Escape"
            enabled: SettingsState.shown
            onActivated: {
                if (root.query !== "") root.query = "";
                else SettingsState.close();
            }
        }

        // Scrim: a click outside the window closes it.
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.35)
            opacity: SettingsState.shown ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180 } }
            MouseArea { anchors.fill: parent; onClicked: SettingsState.close() }
        }

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: Math.min(1100, parent.width - 80)
            height: Math.min(720, parent.height - 120)
            radius: 26
            clip: true
            color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.9)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.1)
            opacity: SettingsState.shown ? 1 : 0
            scale: SettingsState.shown ? 1 : 0.96
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

            // Swallow clicks so they do not reach the scrim.
            MouseArea { anchors.fill: parent }

            // ---- Sidebar ----
            Rectangle {
                id: side
                width: 280
                height: parent.height
                color: Qt.rgba(0, 0, 0, 0.22)
                Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Qt.alpha(Theme.outline, 0.35) }

                Column {
                    x: 14; y: 20
                    width: parent.width - 28
                    spacing: 14

                    Row {
                        leftPadding: 10
                        spacing: 8
                        Icon { text: "settings"; color: Theme.accent; font.pixelSize: 22; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            text: I18n.t("Settings")
                            color: Theme.fg
                            font.family: "Google Sans Flex"; font.pixelSize: 18; font.weight: Font.DemiBold
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 38
                        radius: 19
                        color: Theme.surface2
                        border.width: search.activeFocus ? 2 : 0
                        border.color: Theme.accent
                        Icon {
                            id: lens
                            x: 14
                            anchors.verticalCenter: parent.verticalCenter
                            text: "search"
                            color: Theme.muted
                        }
                        TextInput {
                            id: search
                            anchors.left: lens.right; anchors.leftMargin: 8
                            anchors.right: parent.right; anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.query
                            onTextEdited: root.query = text
                            color: Theme.fg
                            clip: true
                            font.family: "Google Sans Flex"; font.pixelSize: 14
                            Accessible.name: I18n.t("Search settings")
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !search.text
                                text: I18n.t("Search settings")
                                color: Theme.muted
                                font: search.font
                            }
                            // Enter opens the first match; Down moves into the list.
                            onAccepted: if (root.matches.length) SettingsState.page = root.matches[0].id
                            Keys.onDownPressed: nav.forceActiveFocus()
                        }
                    }

                    ListView {
                        id: nav
                        width: parent.width
                        height: contentHeight
                        spacing: 3
                        interactive: false
                        model: root.matches
                        currentIndex: root.matches.findIndex(p => p.id === SettingsState.page)
                        keyNavigationEnabled: true
                        Keys.onReturnPressed: if (currentItem) SettingsState.page = currentItem.modelData.id
                        Keys.onUpPressed: { if (currentIndex <= 0) search.forceActiveFocus(); else decrementCurrentIndex(); }
                        delegate: Rectangle {
                            id: item
                            required property var modelData
                            required property int index
                            readonly property bool on: SettingsState.page === modelData.id
                            width: nav.width
                            height: 42
                            radius: 21
                            color: on ? Theme.accent
                                : (ima.containsMouse || (nav.activeFocus && ListView.isCurrentItem)) ? Theme.surface2 : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Accessible.role: Accessible.PageTab
                            Accessible.name: I18n.t(modelData.label)

                            Icon {
                                id: nicon
                                x: 14
                                anchors.verticalCenter: parent.verticalCenter
                                text: item.modelData.icon
                                fill: item.on ? 1 : 0
                                font.pixelSize: 19
                                color: item.on ? Theme.accentText : Theme.secondary
                            }
                            Text {
                                anchors.left: nicon.right; anchors.leftMargin: 12
                                anchors.right: parent.right; anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: I18n.t(item.modelData.label)
                                elide: Text.ElideRight
                                color: item.on ? Theme.accentText : Theme.fg
                                font.family: "Google Sans Flex"; font.pixelSize: 14
                                font.weight: item.on ? Font.DemiBold : Font.Normal
                            }
                            MouseArea {
                                id: ima
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: SettingsState.page = item.modelData.id
                            }
                        }
                    }

                    Text {
                        visible: root.matches.length === 0
                        leftPadding: 14
                        text: I18n.t("No settings match")
                        color: Theme.muted
                        font.family: "Google Sans Flex"; font.pixelSize: 13
                    }
                }
            }

            // ---- Page ----
            Loader {
                id: pageLoader
                anchors.left: side.right
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.leftMargin: 32
                anchors.rightMargin: 18
                anchors.topMargin: 26
                anchors.bottomMargin: 8
                active: SettingsState.shown
                source: Qt.resolvedUrl(SettingsState.pageInfo(SettingsState.page).file)
            }
        }
    }
}
