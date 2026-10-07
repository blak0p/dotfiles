// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   N O T E S   E D I T O R                                                │
// │   direct note writing sheet · paper styling · debounced live persistence │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import qs.Core
import qs.services

FocusScope {
    id: root

    readonly property string noteKey: NotesService.opened
    readonly property var currentNote: NotesService.entry(root.noteKey)
    property bool isSyncing: false

    Keys.onEscapePressed: event => {
        NotesService.leave();
        event.accepted = true;
    }

    function syncFromNote() {
        if (root.currentNote) {
            root.isSyncing = true;
            heading.text = root.currentNote.title || "";
            body.text = root.currentNote.text || "";
            root.isSyncing = false;
        }
    }

    Connections {
        target: NotesService
        function onOpenedChanged() {
            root.syncFromNote();
            if (NotesService.opened !== "") {
                if (heading.text === "") {
                    heading.forceActiveFocus();
                } else {
                    body.forceActiveFocus();
                }
            }
        }
    }

    Component.onCompleted: {
        root.syncFromNote();
        if (heading.text === "") {
            heading.forceActiveFocus();
        } else {
            body.forceActiveFocus();
        }
    }

    // Paper sheet background
    Rectangle {
        id: paperSheet
        anchors.fill: parent
        radius: Theme.paperRadius
        color: NotesService.paperOf(root.currentNote ? root.currentNote.tint : "yellow")
    }

    // Top action bar: tint swatches & edited timestamp
    RowLayout {
        id: topBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 14
        height: 28

        // Circular tint swatches
        Row {
            spacing: 8
            Repeater {
                model: NotesService.tints

                Rectangle {
                    required property string modelData
                    width: 22
                    height: 22
                    radius: 11
                    color: NotesService.tintColor ? NotesService.tintColor(modelData) : NotesService.paperOf(modelData)
                    border.width: root.currentNote && root.currentNote.tint === modelData ? 2 : 1
                    border.color: root.currentNote && root.currentNote.tint === modelData ? Theme.paperInk : Qt.rgba(0, 0, 0, 0.25)
                    scale: swatchMouse.containsMouse ? 1.15 : (root.currentNote && root.currentNote.tint === modelData ? 1.08 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    MouseArea {
                        id: swatchMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.noteKey !== "") {
                                NotesService.setTint(root.noteKey, modelData);
                            }
                        }
                    }
                }
            }
        }

        Item { Layout.fillWidth: true }

        Text {
            id: editedLabel
            visible: root.currentNote !== null && (root.currentNote.edited > 0)
            text: root.currentNote ? NotesService.ageOf(root.currentNote.edited) : ""
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeLabel
            color: Theme.paperInkMuted
        }
    }

    // Title input
    TextInput {
        id: heading
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: topBar.bottom
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 10
        height: 32
        font.family: Theme.fontFamily
        font.pixelSize: 18
        font.bold: true
        font.weight: Font.Bold
        color: Theme.paperInk
        selectByMouse: true
        selectionColor: Theme.paperLine
        clip: true

        property string placeholderText: "Título de la nota..."

        Text {
            anchors.fill: parent
            anchors.verticalCenter: parent.verticalCenter
            text: heading.placeholderText
            font: heading.font
            color: Theme.paperInkMuted
            visible: heading.text === "" && !heading.activeFocus
        }

        onTextChanged: {
            if (!root.isSyncing && root.noteKey !== "") {
                NotesService.update(root.noteKey, { title: heading.text, text: body.text });
            }
        }
    }

    // Title divider line
    Rectangle {
        id: titleDivider
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: heading.bottom
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 6
        height: 1
        color: Theme.paperLine
    }

    // Multiline body editor inside Flickable
    Flickable {
        id: bodyFlickable
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: titleDivider.bottom
        anchors.bottom: bottomBar.top
        anchors.margins: 16
        clip: true
        contentWidth: width
        contentHeight: Math.max(height, body.paintedHeight + 20)
        boundsBehavior: Flickable.StopAtBounds

        TextEdit {
            id: body
            width: bodyFlickable.width
            property string placeholderText: "Escribe una nota rápida... [ ] para checklist"
            font.family: Theme.fontHand
            font.pixelSize: 16
            color: Theme.paperInk
            wrapMode: TextEdit.Wrap
            selectByMouse: true
            selectionColor: Theme.paperLine

            Text {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                text: body.placeholderText
                font: body.font
                color: Theme.paperInkMuted
                wrapMode: Text.Wrap
                visible: body.text === "" && !body.activeFocus
            }

            onTextChanged: {
                if (!root.isSyncing && root.noteKey !== "") {
                    NotesService.update(root.noteKey, { title: heading.text, text: body.text });
                }
            }

            onCursorRectangleChanged: {
                const r = cursorRectangle;
                if (bodyFlickable.contentY >= r.y) {
                    bodyFlickable.contentY = r.y;
                } else if (bodyFlickable.contentY + bodyFlickable.height <= r.y + r.height) {
                    bodyFlickable.contentY = r.y + r.height - bodyFlickable.height;
                }
            }
        }
    }

    // Bottom action bar (Back / Done, Archive, Delete)
    Rectangle {
        id: bottomBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 44
        color: "transparent"

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Theme.paperLine
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 10

            // Done / Back button
            Rectangle {
                id: doneButton
                implicitHeight: 28
                implicitWidth: doneContent.implicitWidth + 18
                radius: 14
                color: doneMouse.containsMouse ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(0, 0, 0, 0.06)
                border.width: 1
                border.color: Theme.paperLine

                RowLayout {
                    id: doneContent
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: "󰌑"
                        font.family: Theme.fontMono
                        font.pixelSize: 12
                        color: Theme.paperInk
                    }

                    Text {
                        text: "Listo"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                        color: Theme.paperInk
                    }
                }

                MouseArea {
                    id: doneMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NotesService.leave()
                }
            }

            Item { Layout.fillWidth: true }

            // Archive button
            Rectangle {
                id: archiveButton
                implicitHeight: 28
                implicitWidth: archiveContent.implicitWidth + 18
                radius: 14
                color: archiveMouse.containsMouse ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(0, 0, 0, 0.06)
                border.width: 1
                border.color: Theme.paperLine

                RowLayout {
                    id: archiveContent
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: "󰅏"
                        font.family: Theme.fontMono
                        font.pixelSize: 12
                        color: Theme.paperInk
                    }

                    Text {
                        text: root.currentNote && root.currentNote.archived ? "Desarchivar" : "Archivar"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.paperInk
                    }
                }

                MouseArea {
                    id: archiveMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.noteKey !== "") {
                            NotesService.archive(root.noteKey, root.currentNote ? !root.currentNote.archived : true);
                        }
                    }
                }
            }

            // Delete button
            Rectangle {
                id: deleteButton
                implicitHeight: 28
                implicitWidth: deleteContent.implicitWidth + 18
                radius: 14
                color: deleteMouse.containsMouse ? Qt.rgba(0.9, 0.1, 0.1, 0.18) : Qt.rgba(0, 0, 0, 0.06)
                border.width: 1
                border.color: Theme.paperLine

                RowLayout {
                    id: deleteContent
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: "󰆴"
                        font.family: Theme.fontMono
                        font.pixelSize: 12
                        color: deleteMouse.containsMouse ? Theme.red : Theme.paperInk
                    }

                    Text {
                        text: "Eliminar"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: deleteMouse.containsMouse ? Theme.red : Theme.paperInk
                    }
                }

                MouseArea {
                    id: deleteMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.noteKey !== "") {
                            NotesService.remove(root.noteKey);
                        }
                    }
                }
            }
        }
    }
}
