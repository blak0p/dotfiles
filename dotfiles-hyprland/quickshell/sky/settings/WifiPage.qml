import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs
import qs.island

// Wi-Fi settings: on/off, the current network with its details, the
// available networks (click to expand: password, connect, forget), DNS and
// VPN connections. Live state comes from Quickshell.Networking (Net.qml);
// details, DNS and VPN go through nmcli.
Page {
    id: page
    title: I18n.t("Wi-Fi")

    property string selected: ""
    property var details: ({ ip: "", gateway: "", dns: "", freq: "", rate: "", conn: "" })
    property var vpns: []
    property string dnsMode: "auto"

    readonly property var others: Net.networks.filter(n => !n.connected)
    readonly property string iface: Net.wifi ? Net.wifi.name : ""
    readonly property var dnsChoices: [
        { label: I18n.t("Automatic"), value: "auto", servers: "" },
        { label: "Cloudflare · 1.1.1.1", value: "cloudflare", servers: "1.1.1.1 1.0.0.1" },
        { label: "Google · 8.8.8.8", value: "google", servers: "8.8.8.8 8.8.4.4" },
        { label: "Quad9 · 9.9.9.9", value: "quad9", servers: "9.9.9.9 149.112.112.112" }
    ]

    Component.onCompleted: { Net.scan(true); refresh(); }
    Component.onDestruction: Net.scan(false)

    function refresh() {
        if (iface) detailsProc.running = true;
        vpnProc.running = true;
    }
    Connections {
        target: Net
        function onActiveChanged() { page.refresh(); }
    }
    Timer { interval: 10000; running: true; repeat: true; onTriggered: page.refresh() }

    // IP4.ADDRESS[1]:192.168.1.42/24 ... then the active network's frequency.
    Process {
        id: detailsProc
        command: ["sh", "-c",
            "nmcli -t -f IP4.ADDRESS,IP4.GATEWAY,IP4.DNS device show \"$1\"; " +
            "c=$(nmcli -g GENERAL.CONNECTION device show \"$1\"); " +
            "echo \"CONN:$c\"; nmcli -g ipv4.ignore-auto-dns,ipv4.dns connection show \"$c\" 2>/dev/null | sed 's/^/CFG:/'; " +
            "nmcli -t -f IN-USE,FREQ,RATE device wifi list ifname \"$1\" --rescan no | sed -n 's/^\\*:/FREQ:/p'",
            "sh", page.iface]
        stdout: StdioCollector {
            onStreamFinished: {
                const d = { ip: "", gateway: "", dns: [], freq: "", rate: "", conn: "", cfg: [] };
                for (const line of text.split("\n")) {
                    const i = line.indexOf(":");
                    if (i < 0) continue;
                    const k = line.slice(0, i), v = line.slice(i + 1).trim();
                    if (k.startsWith("IP4.ADDRESS") && !d.ip) d.ip = v.split("/")[0];
                    else if (k === "IP4.GATEWAY") d.gateway = v;
                    else if (k.startsWith("IP4.DNS") && v) d.dns.push(v);
                    else if (k === "CONN") d.conn = v;
                    else if (k === "CFG") d.cfg.push(v);
                    else if (k === "FREQ" && !d.freq) { const fr = v.split(":"); d.freq = fr[0]; d.rate = (fr[1] || "").replace("Mbit/s", "Mbps"); }
                }
                const ignoreAuto = d.cfg[0] === "yes";
                const servers = (d.cfg[1] || "").replace(/,/g, " ").trim();
                const match = page.dnsChoices.find(c => c.servers && c.servers === servers);
                page.dnsMode = !ignoreAuto ? "auto" : match ? match.value : "custom";
                page.details = { ip: d.ip, gateway: d.gateway, dns: d.dns.join(", "), freq: d.freq, rate: d.rate, conn: d.conn };
            }
        }
    }

    // NAME:TYPE:ACTIVE for VPN and WireGuard profiles.
    Process {
        id: vpnProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE,ACTIVE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                page.vpns = text.split("\n").filter(l => l).map(l => {
                    const p = l.replace(/\\:/g, "\u0001").split(":").map(x => x.replace(/\u0001/g, ":"));
                    return { name: p[0], type: p[1], active: p[2] === "yes" };
                }).filter(c => c.type === "vpn" || c.type === "wireguard");
            }
        }
    }

    Process {
        id: action
        onExited: page.refresh()
    }
    function run(cmd) { action.command = cmd; action.running = true; }

    function setDns(choice) {
        const c = details.conn;
        if (!c) return;
        if (choice.value === "auto")
            run(["sh", "-c", "nmcli connection modify \"$1\" ipv4.ignore-auto-dns no ipv4.dns '' && nmcli connection up \"$1\"", "sh", c]);
        else
            run(["sh", "-c", "nmcli connection modify \"$1\" ipv4.ignore-auto-dns yes ipv4.dns \"$2\" && nmcli connection up \"$1\"", "sh", c, choice.servers]);
    }

    function band(freq) {
        const mhz = parseInt(freq);
        if (!mhz) return "";
        return mhz >= 5900 ? "6 GHz" : mhz >= 4900 ? "5 GHz" : "2,4 GHz";
    }
    function strength(s) {
        return s > 0.75 ? I18n.t("Strong signal") : s > 0.45 ? I18n.t("Good signal") : I18n.t("Weak signal");
    }

    headerRight: [
        Toggle {
            checked: Net.wifiOn
            label: I18n.t("Wi-Fi")
            onToggled: on => Net.setWifi(on)
        }
    ]

    // ---- Off ----
    Card {
        visible: !Net.wifiOn
        SettingRow { icon: "wifi_off"; title: I18n.t("Wi-Fi is off"); sub: I18n.t("Turn it on to see networks") }
    }

    // ---- Current network ----
    Section { visible: Net.wifiOn && Net.active !== null; text: I18n.t("Current network") }
    Card {
        visible: Net.wifiOn && Net.active !== null
        SettingRow {
            current: true
            icon: Net.active ? Net.signalIcon(Net.active.signalStrength) : "wifi"
            title: Net.active ? Net.active.name : ""
            sub: !Net.active ? "" : [I18n.t("Connected"), page.band(page.details.freq), page.strength(Net.active.signalStrength)].filter(x => x).join(" · ")
            SignalBars { strength: Net.active ? Net.active.signalStrength : 0; anchors.verticalCenter: parent.verticalCenter }
            Btn { text: I18n.t("Disconnect"); onClicked: Net.active.disconnect() }
            Btn { danger: true; text: I18n.t("Forget network"); onClicked: Net.active.forget() }
        }
        Grid {
            x: 68
            width: parent.width - 84
            columns: 4
            columnSpacing: 8
            bottomPadding: 12
            Repeater {
                model: [
                    [I18n.t("IP address"), page.details.ip],
                    [I18n.t("Gateway"), page.details.gateway],
                    ["DNS", page.details.dns],
                    [I18n.t("Link speed"), page.details.rate]
                ]
                Column {
                    required property var modelData
                    width: (parent.width - 24) / 4
                    Text { text: modelData[0]; color: Theme.muted; font.family: "Google Sans Flex"; font.pixelSize: 12 }
                    Text {
                        width: parent.width
                        text: modelData[1] || "—"
                        elide: Text.ElideRight
                        color: Theme.fg
                        font.family: "Google Sans Flex"; font.pixelSize: 14; font.weight: Font.DemiBold
                    }
                }
            }
        }
    }

    // ---- Available networks ----
    Section { visible: Net.wifiOn; text: I18n.t("Available networks") }
    Card {
        visible: Net.wifiOn
        SettingRow {
            visible: page.others.length === 0
            icon: "wifi_find"
            title: I18n.t("Searching…")
        }
        Repeater {
            model: page.others
            WifiRow {
                required property var modelData
                required property int index
                network: modelData
                divider: index > 0
                open: page.selected === modelData.name
                onToggleOpen: page.selected = open ? "" : modelData.name
                onDone: page.selected = ""
            }
        }
    }

    // ---- Advanced ----
    Section { visible: Net.wifiOn && Net.active !== null; text: I18n.t("Advanced") }
    Card {
        visible: Net.wifiOn && Net.active !== null
        SettingRow {
            title: I18n.t("DNS servers")
            sub: page.dnsMode === "custom" ? I18n.t("Custom: %1", page.details.dns) : I18n.t("Applies to %1", page.details.conn || "")
            Select {
                model: page.dnsChoices
                currentIndex: page.dnsChoices.findIndex(c => c.value === page.dnsMode)
                placeholder: I18n.t("Custom")
                onActivated: i => page.setDns(page.dnsChoices[i])
            }
        }
        Repeater {
            model: page.vpns
            SettingRow {
                required property var modelData
                divider: true
                icon: "vpn_lock"
                current: modelData.active
                title: "VPN · " + modelData.name
                sub: modelData.active ? I18n.t("Connected") : I18n.t("Disconnected")
                Btn {
                    primary: !modelData.active
                    text: modelData.active ? I18n.t("Disconnect") : I18n.t("Connect")
                    onClicked: page.run(["nmcli", "connection", modelData.active ? "down" : "up", modelData.name])
                }
            }
        }
    }
}
