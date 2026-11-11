import QtQuick
import Quickshell.Bluetooth
import qs
import qs.island

// Bluetooth settings: on/off, paired devices (connect, trust, forget) and
// nearby devices to pair. Discovery runs only while the page is open.
Page {
    id: page
    title: I18n.t("Bluetooth")

    property string selected: ""

    readonly property var paired: Net.btDevices.filter(d => d.paired || d.bonded)
    readonly property var nearby: Net.btDevices.filter(d => !(d.paired || d.bonded))

    Component.onCompleted: Net.btScan(true)
    Component.onDestruction: Net.btScan(false)
    Connections {
        target: Net
        function onBtOnChanged() { Net.btScan(true); }
    }

    headerRight: [
        Toggle {
            visible: Net.adapter !== null
            checked: Net.btOn
            label: I18n.t("Bluetooth")
            onToggled: on => Net.setBt(on)
        }
    ]

    Card {
        visible: !Net.adapter || !Net.btOn
        SettingRow {
            icon: Net.adapter ? "bluetooth_disabled" : "bluetooth_disabled"
            title: !Net.adapter ? I18n.t("No Bluetooth adapter") : I18n.t("Bluetooth is off")
            sub: !Net.adapter ? I18n.t("Connect a Bluetooth adapter") : I18n.t("Turn it on to see devices")
        }
    }

    Section { visible: Net.btOn; text: I18n.t("My devices") }
    Card {
        visible: Net.btOn
        SettingRow {
            visible: page.paired.length === 0
            icon: "devices"
            title: I18n.t("No paired devices")
        }
        Repeater {
            model: page.paired
            BtRow {
                required property var modelData
                required property int index
                device: modelData
                divider: index > 0
                open: page.selected === modelData.address
                onToggleOpen: page.selected = open ? "" : modelData.address
                onGone: page.selected = ""
            }
        }
    }

    Section { visible: Net.btOn; text: I18n.t("Nearby devices") }
    Card {
        visible: Net.btOn
        SettingRow {
            visible: page.nearby.length === 0
            icon: "bluetooth_searching"
            title: I18n.t("Searching…")
        }
        Repeater {
            model: page.nearby
            BtRow {
                required property var modelData
                required property int index
                device: modelData
                paired: false
                divider: index > 0
            }
        }
    }
}
