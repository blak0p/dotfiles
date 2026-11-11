import QtQuick
import Quickshell.Networking
import qs
import qs.island

// An available network. Click to expand: password field for new secured
// networks, and connect / forget actions. Errors show in the subtitle.
Column {
    id: w

    required property var network
    property bool open: false
    property bool divider: false
    property string error: ""
    readonly property bool needsPass: Net.secured(network) && !network.known
    signal toggleOpen()
    signal done()

    width: parent ? parent.width : 0

    Connections {
        target: w.network
        function onConnectionFailed(reason) {
            w.error = reason === ConnectionFailReason.NoSecrets ? I18n.t("Wrong password") : I18n.t("Could not connect");
        }
        function onConnectedChanged() { if (w.network.connected) { w.error = ""; w.done(); } }
    }
    onOpenChanged: if (open && needsPass) { pass.text = ""; pass.forceActiveFocus(); }

    function join() {
        error = "";
        if (needsPass) { if (pass.text) network.connectWithPsk(pass.text); }
        else network.connect();
    }

    SettingRow {
        clickable: true
        divider: w.divider
        highlighted: w.open
        icon: Net.secured(w.network) ? "lock" : "wifi"
        title: w.network.name
        sub: w.error !== "" ? w.error
            : w.network.stateChanging ? I18n.t("Connecting…")
            : [Net.secured(w.network) ? I18n.t("Secured") : I18n.t("Open"), w.network.known ? I18n.t("Saved") : ""].filter(x => x).join(" · ")
        onClicked: w.toggleOpen()
        SignalBars { strength: w.network.signalStrength; anchors.verticalCenter: parent.verticalCenter }
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            text: "expand_more"
            color: Theme.muted
            font.pixelSize: 20
            rotation: w.open ? 180 : 0
            Behavior on rotation { NumberAnimation { duration: 180 } }
        }
    }

    Row {
        visible: w.open
        x: 68
        width: parent.width - 84
        spacing: 10
        bottomPadding: 12
        topPadding: 2

        Rectangle {
            visible: w.needsPass
            width: parent.width - actions.width - 10
            height: 40
            radius: 20
            color: Theme.surface2
            border.width: pass.activeFocus ? 2 : 0
            border.color: Theme.accent
            TextInput {
                id: pass
                anchors.left: parent.left; anchors.leftMargin: 16
                anchors.right: eye.left; anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                echoMode: eye.shown ? TextInput.Normal : TextInput.Password
                inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                color: Theme.fg
                clip: true
                font.family: "Google Sans Flex"; font.pixelSize: 14
                Accessible.name: I18n.t("Password for %1", w.network.name)
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !pass.text
                    text: I18n.t("Password")
                    color: Theme.muted
                    font: pass.font
                }
                onAccepted: w.join()
            }
            Icon {
                id: eye
                property bool shown: false
                anchors.right: parent.right; anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: shown ? "visibility_off" : "visibility"
                color: Theme.muted
                font.pixelSize: 18
                MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: eye.shown = !eye.shown }
            }
        }

        Row {
            id: actions
            spacing: 10
            Btn { visible: w.needsPass; text: I18n.t("Cancel"); onClicked: w.toggleOpen() }
            Btn { visible: w.network.known; danger: true; text: I18n.t("Forget"); onClicked: { w.network.forget(); w.done(); } }
            Btn { primary: true; text: I18n.t("Connect"); enabled: !w.needsPass || pass.text !== ""; onClicked: w.join() }
        }
    }
}
