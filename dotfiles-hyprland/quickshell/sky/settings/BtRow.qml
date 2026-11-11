import QtQuick
import Quickshell.Bluetooth
import qs
import qs.island

// A Bluetooth device row. Paired devices expand for Trust / Forget; nearby
// ones just show a Pair button.
Column {
    id: w

    required property var device
    property bool paired: true
    property bool open: false
    property bool divider: false
    signal toggleOpen()
    signal gone()

    readonly property var d: device
    readonly property string kind: d.icon || ""
    readonly property bool busy: d.pairing || d.state === BluetoothDeviceState.Connecting
        || d.state === BluetoothDeviceState.Disconnecting
    readonly property string batt: d.connected && d.batteryAvailable ? Math.round(d.battery * 100) + " %" : ""

    width: parent ? parent.width : 0

    SettingRow {
        clickable: paired
        divider: w.divider
        highlighted: w.open
        current: w.d.connected
        icon: w.kind.includes("audio") || w.kind.includes("headset") || w.kind.includes("headphone") ? "headphones"
            : w.kind.includes("phone") ? "smartphone"
            : w.kind.includes("mouse") ? "mouse"
            : w.kind.includes("keyboard") ? "keyboard"
            : w.kind.includes("joystick") || w.kind.includes("gaming") ? "sports_esports"
            : w.kind.includes("computer") || w.kind.includes("laptop") ? "computer"
            : "bluetooth"
        title: w.d.name || w.d.deviceName || w.d.address
        sub: w.d.pairing ? I18n.t("Pairing…")
            : w.d.state === BluetoothDeviceState.Connecting ? I18n.t("Connecting…")
            : !w.paired ? I18n.t("Ready to pair")
            : w.d.connected ? (w.batt ? I18n.t("Connected") + " · " + I18n.t("Battery %1", w.batt) : I18n.t("Connected"))
            : I18n.t("Paired") + " · " + I18n.t("Not connected")
        onClicked: w.toggleOpen()

        Rectangle {
            visible: w.batt !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: bt.implicitWidth + 20; height: 26; radius: 13
            color: Theme.surface2
            Text {
                id: bt
                anchors.centerIn: parent
                text: w.batt
                color: Theme.accent
                font.family: "Google Sans Flex"; font.pixelSize: 12; font.weight: Font.DemiBold
            }
        }
        Btn {
            visible: !w.d.connected && !w.d.pairing
            primary: !w.paired
            enabled: !w.busy
            text: w.paired ? I18n.t("Connect") : I18n.t("Pair")
            onClicked: w.paired ? w.d.connect() : w.d.pair()
        }
        Btn {
            visible: w.d.connected
            enabled: !w.busy
            text: I18n.t("Disconnect")
            onClicked: w.d.disconnect()
        }
        Btn {
            visible: w.d.pairing
            danger: true
            text: I18n.t("Cancel")
            onClicked: w.d.cancelPair()
        }
        Icon {
            visible: w.paired
            anchors.verticalCenter: parent.verticalCenter
            text: "expand_more"
            color: Theme.muted
            font.pixelSize: 20
            rotation: w.open ? 180 : 0
            Behavior on rotation { NumberAnimation { duration: 180 } }
        }
    }

    Row {
        visible: w.open && w.paired
        x: 68
        spacing: 10
        bottomPadding: 12
        topPadding: 2
        Btn {
            icon: w.d.trusted ? "verified" : "shield"
            text: w.d.trusted ? I18n.t("Trusted") : I18n.t("Trust")
            onClicked: w.d.trusted = !w.d.trusted
        }
        Btn {
            danger: true
            text: I18n.t("Forget")
            onClicked: { w.d.forget(); w.gone(); }
        }
    }
}
