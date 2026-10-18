// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   N O T E S   P A N E L                                                  │
// │   dynamic island container · deck view vs editor view · hotkey router    │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import qs.Core
import qs.services

FocusScope {
    id: root

    signal closed()

    implicitWidth: NotesService.panelWidth
    implicitHeight: 420
    width: implicitWidth
    height: implicitHeight
    focus: true

    Keys.onEscapePressed: event => {
        if (NotesService.opened !== "") {
            NotesService.leave();
        } else {
            root.closed();
        }
        event.accepted = true;
    }

    Loader {
        id: viewLoader
        anchors.fill: parent
        focus: true
        sourceComponent: NotesService.opened === "" ? deckComponent : editorComponent

        onLoaded: {
            if (item) {
                item.forceActiveFocus();
            }
        }
    }

    Component {
        id: deckComponent
        NotesDeck {
            focus: true
        }
    }

    Component {
        id: editorComponent
        NotesEditor {
            focus: true
        }
    }
}
