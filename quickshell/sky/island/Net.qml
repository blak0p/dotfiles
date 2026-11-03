pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth

// Wifi (NetworkManager) and Bluetooth (BlueZ) state for the bar and the center.
Singleton {
    id: root

    // ---- Network ----
    readonly property var devices: Networking.devices.values
    readonly property var wifi: devices.find(d => d.type === DeviceType.Wifi) || null
    readonly property var wired: devices.find(d => d.type === DeviceType.Wired && d.connected) || null
    readonly property bool wifiOn: Networking.wifiEnabled
    readonly property var networks: !wifi ? [] : wifi.networks.values.slice()
        .filter(n => n.name)
        .sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength))
    readonly property var active: networks.find(n => n.connected) || null

    function setWifi(on) { Networking.wifiEnabled = on; }
    function scan(on) { if (wifi) wifi.scannerEnabled = on; }

    function signalIcon(s) {
        if (s > 0.75) return "signal_wifi_4_bar";
        if (s > 0.5) return "network_wifi_3_bar";
        if (s > 0.25) return "network_wifi_2_bar";
        return "network_wifi_1_bar";
    }
    readonly property string netIcon: wired ? "lan"
        : !wifiOn ? "wifi_off"
        : active ? signalIcon(active.signalStrength)
        : "signal_wifi_0_bar"
    readonly property string netLabel: wired ? "Ethernet" : !wifiOn ? "Off" : active ? active.name : "Not connected"

    function secured(n) { return n && n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Unknown; }

    // ---- Bluetooth ----
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool btOn: adapter ? adapter.enabled : false
    readonly property var btDevices: !adapter ? [] : adapter.devices.values.slice()
        // Unpaired devices that only advertise their MAC are noise.
        .filter(d => d.paired || d.connected || !/^([0-9A-F]{2}[-:]){5}[0-9A-F]{2}$/i.test(d.name || d.deviceName || ""))
        .sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || (a.name || "").localeCompare(b.name || ""))
    readonly property var btConnected: btDevices.filter(d => d.connected)

    function setBt(on) { if (adapter) adapter.enabled = on; }
    function btScan(on) { if (adapter && adapter.enabled) adapter.discovering = on; }
    function btToggle(d) {
        if (d.connected) d.disconnect();
        else if (!d.paired) d.pair();
        else d.connect();
    }
    readonly property string btIcon: !btOn ? "bluetooth_disabled" : (btConnected.length ? "bluetooth_connected" : "bluetooth")
    readonly property string btLabel: !adapter ? "No adapter" : !btOn ? "Off"
        : btConnected.length ? (btConnected[0].name || btConnected[0].deviceName) : "On"
}
