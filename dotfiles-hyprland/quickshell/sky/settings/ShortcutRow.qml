import QtQuick
import qs

// One shortcut: title, keycaps, "Custom" badge, Change / Reset. While `capturing`
// it also shows the combo being recorded, the collision warning and Save/Cancel.
// The page owns the state; this row only reports pressed keys and clicks.
Item {
    id: r

    property var info: ({})
    property bool divider: false
    property bool capturing: false
    property var capKeys: []
    property var collision: null
    property string error: ""
    property bool busy: false
    signal change()
    signal reset()
    signal save()
    signal cancel()
    signal pressed(var ev)

    width: parent ? parent.width : 0
    height: top.height + (capturing ? extra.height : 0)

    onCapturingChanged: if (capturing) scope.forceActiveFocus()

    SettingRow {
        id: top
        divider: r.divider
        highlighted: r.capturing
        title: r.info.title
        sub: r.info.note ? I18n.t(r.info.note)
            : r.info.custom ? I18n.t("Default: %1", (r.info.original || []).join(" + ")) : ""
        Rectangle {
            visible: r.info.custom && !r.capturing
            height: 22; width: badge.implicitWidth + 16; radius: 11
            anchors.verticalCenter: parent.verticalCenter
            color: Qt.alpha(Theme.accent, 0.22)
            Text {
                id: badge
                anchors.centerIn: parent
                text: I18n.t("Custom")
                color: Theme.accent
                font.family: "Google Sans Flex"; font.pixelSize: 11; font.weight: Font.DemiBold
            }
        }
        ShortcutKeys { keys: r.info.keys || []; dim: r.capturing; anchors.verticalCenter: parent.verticalCenter }
        Btn {
            visible: r.info.custom && !r.capturing
            text: I18n.t("Reset")
            enabled: !r.busy
            onClicked: r.reset()
        }
        Btn {
            visible: r.info.editable && !r.capturing
            text: I18n.t("Change")
            enabled: !r.busy
            onClicked: r.change()
        }
    }

    // Key capture: only active while this row is recording.
    FocusScope {
        id: scope
        anchors.fill: parent
        focus: r.capturing
        Keys.onPressed: ev => { if (r.capturing) r.pressed(ev); }
    }

    Item {
        id: extra
        visible: r.capturing
        y: top.height
        width: parent.width
        height: ecol.implicitHeight + 16
        Column {
            id: ecol
            x: 16; width: parent.width - 32
            spacing: 10
            Row {
                spacing: 12
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: r.capKeys.length ? I18n.t("New shortcut") : I18n.t("Press the new shortcut… (Esc cancels)")
                    color: Theme.muted
                    font.family: "Google Sans Flex"; font.pixelSize: 13
                }
                ShortcutKeys { visible: r.capKeys.length > 0; keys: r.capKeys; anchors.verticalCenter: parent.verticalCenter }
            }
            Text {
                visible: r.collision !== null
                width: parent.width
                wrapMode: Text.WordWrap
                text: r.collision ? I18n.t("“%1” already uses this shortcut. Saving replaces it.", r.collision.title) : ""
                color: "#ffb4ab"
                font.family: "Google Sans Flex"; font.pixelSize: 13
            }
            Text {
                visible: r.error !== ""
                width: parent.width
                wrapMode: Text.WordWrap
                text: r.error
                color: "#ffb4ab"
                font.family: "Google Sans Flex"; font.pixelSize: 13
            }
            Row {
                spacing: 10
                Btn {
                    primary: true
                    visible: r.capKeys.length > 0
                    enabled: !r.busy && r.error === ""
                    text: r.collision ? I18n.t("Replace and save") : I18n.t("Save")
                    onClicked: r.save()
                }
                Btn { text: I18n.t("Cancel"); onClicked: r.cancel() }
            }
        }
    }
}
