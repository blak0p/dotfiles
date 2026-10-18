// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   N O T E S   D E C K                                                    │
// │   grid of sticky notes · card 0 creates new note · keyboard navigable    │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import qs.Core
import qs.services

FocusScope {
    id: root

    property bool showArchived: false

    readonly property var noteItems: {
        const base = root.showArchived ? NotesService.notes : NotesService.live;
        return (base || []).slice().sort((a, b) => (b.edited || 0) - (a.edited || 0));
    }

    readonly property var deckModel: {
        const items = [{ isNew: true, tint: "yellow", title: "New Note", key: "" }];
        const currentNotes = root.noteItems;
        for (let i = 0; i < currentNotes.length; i++) {
            items.push(currentNotes[i]);
        }
        return items;
    }

    function openCurrent() {
        openIndex(gridView.currentIndex);
    }

    function openIndex(idx) {
        if (idx < 0 || idx >= deckModel.length) return;
        const item = deckModel[idx];
        if (item.isNew) {
            NotesService.create("yellow", true);
        } else if (item.key) {
            NotesService.open(item.key, true);
        }
    }

    function archiveCurrent() {
        archiveIndex(gridView.currentIndex);
    }

    function archiveIndex(idx) {
        if (idx <= 0 || idx >= deckModel.length) return;
        const item = deckModel[idx];
        if (!item.isNew && item.key) {
            NotesService.archive(item.key, !item.archived);
        }
    }

    Keys.onReturnPressed: event => {
        root.openCurrent();
        event.accepted = true;
    }

    Keys.onEnterPressed: event => {
        root.openCurrent();
        event.accepted = true;
    }

    Keys.onDeletePressed: event => {
        root.archiveCurrent();
        event.accepted = true;
    }

    // Header bar
    RowLayout {
        id: headerBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 12
        height: 24

        Text {
            text: "Notas"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeMedium
            font.bold: true
            color: Theme.fg
        }

        Item { Layout.fillWidth: true }

        Text {
            text: "󰌑 Abrir   󰅏 Archivar"
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeLabel
            color: Theme.muted
        }
    }

    // Note Cards Grid
    GridView {
        id: gridView
        anchors.top: headerBar.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: footerBar.top
        anchors.bottomMargin: 8
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        clip: true
        focus: true
        boundsBehavior: Flickable.StopAtBounds

        cellWidth: Math.floor(width / 3)
        cellHeight: 136

        model: root.deckModel
        currentIndex: 0

        Keys.onReturnPressed: event => {
            root.openCurrent();
            event.accepted = true;
        }

        Keys.onEnterPressed: event => {
            root.openCurrent();
            event.accepted = true;
        }

        Keys.onDeletePressed: event => {
            root.archiveCurrent();
            event.accepted = true;
        }

        delegate: Item {
            id: cardDelegate
            width: gridView.cellWidth
            height: gridView.cellHeight

            readonly property bool isCurrent: gridView.currentIndex === index && gridView.activeFocus
            readonly property bool isNewCard: modelData.isNew === true

            Rectangle {
                id: cardShape
                anchors.fill: parent
                anchors.margins: 4
                radius: Theme.paperRadius
                color: isNewCard ? Qt.rgba(1, 1, 1, 0.05) : NotesService.paperOf(modelData.tint || "yellow")
                border.width: isCurrent ? 2 : 1
                border.color: isCurrent ? Theme.accent : (isNewCard ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.1))

                scale: cardMouse.pressed ? 0.97 : (cardMouse.containsMouse ? 1.02 : 1.0)
                Behavior on scale { NumberAnimation { duration: 100 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                // Card 0: "New Note"
                ColumnLayout {
                    anchors.centerIn: parent
                    visible: isNewCard
                    spacing: 6

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "󰐕"
                        font.family: Theme.fontMono
                        font.pixelSize: 26
                        color: isCurrent || cardMouse.containsMouse ? Theme.accent : Theme.muted
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Nueva nota"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                        color: isCurrent || cardMouse.containsMouse ? Theme.fg : Theme.muted
                    }
                }

                // Existing Note cards
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    visible: !isNewCard
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            id: titleField
                            Layout.fillWidth: true
                            text: modelData.title && modelData.title.trim() !== "" ? modelData.title.trim() : NotesService.titleOf(modelData)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Bold
                            font.bold: true
                            color: Theme.paperInk
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        Text {
                            visible: modelData.archived === true
                            text: "󰅏"
                            font.family: Theme.fontMono
                            font.pixelSize: 11
                            color: Theme.paperInkMuted
                        }
                    }

                    Text {
                        id: snippetField
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        text: NotesService.display(modelData.text || "")
                        font.family: Theme.fontHand
                        font.pixelSize: 13
                        lineHeight: 1.1
                        color: Theme.paperInk
                        wrapMode: Text.Wrap
                        elide: Text.ElideRight
                        maximumLineCount: 3
                    }

                    Text {
                        id: ageField
                        Layout.alignment: Qt.AlignRight
                        text: modelData.edited ? NotesService.ageOf(modelData.edited) : ""
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeLabel
                        color: Theme.paperInkMuted
                    }
                }

                MouseArea {
                    id: cardMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        gridView.currentIndex = index;
                        root.openIndex(index);
                    }
                }
            }
        }
    }

    // Footer with total notes count, archived count, and toggle button
    Rectangle {
        id: footerBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 38
        color: "transparent"

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Qt.rgba(1, 1, 1, 0.08)
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 12

            Text {
                text: NotesService.count + (NotesService.count === 1 ? " nota" : " notas")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.muted
            }

            Text {
                text: "•"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Qt.rgba(1, 1, 1, 0.2)
            }

            Text {
                text: NotesService.archived.length + " archivadas"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.muted
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                id: toggleArchivedButton
                implicitHeight: 24
                implicitWidth: toggleContent.implicitWidth + 16
                radius: 12
                color: root.showArchived ? Theme.accent : (toggleMouse.containsMouse ? Theme.islandSurfaceHover : Theme.islandSurface)
                border.width: 1
                border.color: root.showArchived ? Theme.accent : Theme.islandBorder

                RowLayout {
                    id: toggleContent
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: "󰅏"
                        font.family: Theme.fontMono
                        font.pixelSize: 11
                        color: root.showArchived ? Theme.accentText : Theme.muted
                    }

                    Text {
                        text: root.showArchived ? "Ocultar archivadas" : "Ver archivadas"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel
                        color: root.showArchived ? Theme.accentText : Theme.fg
                    }
                }

                MouseArea {
                    id: toggleMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.showArchived = !root.showArchived
                }
            }
        }
    }
}
