import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth
import qs

// Expanded island. Opened from the island itself it shows three modules behind
// tabs: quick settings ("notifs": tiles, volume and notifications), performance
// ("perf") and music ("music"). Opened from a side-pill button it shows only
// that button's page (wifi, bluetooth, sound, power or AI usage), so each one
// has its own panel.
Item {
    id: root

    readonly property string page: IslandState.page
    readonly property bool full: page === "notifs"
    readonly property bool tabbed: full || page === "perf" || page === "music"
    readonly property bool showVol: full
    readonly property real pageWanted: page === "wifi" ? wifiPage.wanted
        : page === "bluetooth" ? btPage.wanted
        : page === "power" ? powerPage.wanted
        : page === "usage" ? usagePage.wanted
        : page === "sound" ? soundPage.wanted
        : page === "perf" ? perfPage.wanted
        : page === "music" ? musicPage.wanted
        : notifPage.wanted
    // Island height needed to show everything (lists scroll past the cap).
    readonly property real wantedHeight: Math.min(Config.centerMaxH,
        (tabbed ? tabs.height + col.spacing : 0)
        + (full ? tiles.height + col.spacing : 0)
        + (media.visible ? media.height + col.spacing : 0)
        + (showVol ? vol.height + col.spacing : 0)
        + (tabbed && !full ? 0 : pageHeader.height + col.spacing) + pageWanted + 2 * col.anchors.margins)

    // Scan only while the matching page is visible.
    readonly property bool shown: IslandState.centerOpen
    // Faster usage polling only while its page is on screen.
    Binding { target: UsageService; property: "pageOpen"; value: root.shown && root.page === "usage" }
    // Sensors are sampled only while the Performance tab is on screen.
    Binding { target: PerfService; property: "active"; value: root.shown && root.page === "perf" }
    onShownChanged: syncScan()
    onPageChanged: syncScan()
    function syncScan() {
        Net.scan(shown && page === "wifi");
        Net.btScan(shown && page === "bluetooth");
    }

    Column {
        id: col
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        PageHeader { visible: !root.tabbed }

        // Module tabs: quick settings, performance, music.
        Rectangle {
            id: tabs
            visible: root.tabbed
            width: parent.width
            height: 40
            radius: 16
            color: Qt.alpha(Theme.fg, 0.06)
            Row {
                id: tabRow
                anchors.fill: parent
                anchors.margins: 4
                spacing: 4
                Repeater {
                    model: [
                        { page: "notifs", icon: "tune", label: "Quick settings" },
                        { page: "perf", icon: "monitoring", label: "Performance" },
                        { page: "music", icon: "music_note", label: "Music" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool current: root.page === modelData.page
                        width: (tabRow.width - 2 * tabRow.spacing) / 3
                        height: tabRow.height
                        radius: 12
                        color: current ? Theme.accent : (tabMa.containsMouse ? Qt.alpha(Theme.fg, 0.08) : "transparent")
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.icon
                                fill: parent.parent.current ? 1 : 0
                                color: parent.parent.current ? Theme.accentText : Theme.muted
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: I18n.t(modelData.label)
                                color: parent.parent.current ? Theme.accentText : Theme.muted
                                font.family: "Google Sans Flex"; font.pixelSize: 13; font.weight: Font.DemiBold
                            }
                        }
                        MouseArea {
                            id: tabMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: IslandState.openCenter(modelData.page)
                        }
                    }
                }
            }
        }

        Row {
            id: tiles
            visible: root.full
            width: parent.width
            spacing: 8
            readonly property real tileW: (width - 3 * spacing) / 4
            Tile {
                width: tiles.tileW
                icon: Net.netIcon; label: "Wi-Fi"; sub: Net.netLabel
                on: Net.wifiOn; current: root.page === "wifi"
                onToggled: Net.setWifi(!Net.wifiOn)
                onOpened: IslandState.page = "wifi"
            }
            Tile {
                width: tiles.tileW
                icon: Net.btIcon; label: "Bluetooth"; sub: Net.btLabel
                on: Net.btOn; current: root.page === "bluetooth"
                onToggled: Net.setBt(!Net.btOn)
                onOpened: IslandState.page = "bluetooth"
            }
            Tile {
                width: tiles.tileW
                icon: Notifs.dnd ? "notifications_off" : "notifications"
                label: I18n.t("Silent"); sub: Notifs.list.length ? I18n.t("%1 notifs", Notifs.list.length) : I18n.t("None")
                on: Notifs.dnd; current: root.page === "notifs"
                onToggled: Notifs.dnd = !Notifs.dnd
                onOpened: IslandState.page = "notifs"
            }
            Tile {
                width: tiles.tileW
                icon: "power_settings_new"; label: I18n.t("Power"); sub: I18n.t("Session")
                on: false; current: root.page === "power"
                onToggled: IslandState.page = "power"
                onOpened: IslandState.page = "power"
            }
        }

        Rectangle {
            id: media
            width: parent.width
            height: 40
            visible: !!Media.player && root.page === "sound"
            radius: 20
            color: Qt.alpha(Theme.fg, 0.06)
            MediaView { anchors.fill: parent }
        }

        Rectangle {
            id: vol
            visible: root.showVol
            width: parent.width
            height: 40
            radius: 20
            color: Qt.alpha(Theme.fg, 0.06)
            VolumeView { anchors.fill: parent }
        }

        PageHeader { id: pageHeader; visible: root.full }

        Item {
            id: pages
            width: parent.width
            height: parent.height - y
            clip: true

            // ---- Notifications ----
            Item {
                id: notifPage
                readonly property real wanted: Notifs.list.length ? Math.max(list.contentHeight, 60) : 60
                anchors.fill: parent
                visible: root.page === "notifs"

                Column {
                    anchors.centerIn: parent
                    visible: Notifs.list.length === 0
                    spacing: 4
                    Icon { anchors.horizontalCenter: parent.horizontalCenter; text: "notifications_paused"; color: Theme.muted; font.pixelSize: 22 }
                    Text { text: "No notifications"; color: Theme.muted; font.family: "Google Sans Flex"; font.pixelSize: 12 }
                }

                ListView {
                    id: list
                    anchors.fill: parent
                    clip: true
                    spacing: 8
                    model: Notifs.list
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: Rectangle {
                        required property var modelData
                        width: list.width
                        height: card.implicitHeight + 20
                        radius: 16
                        color: Qt.alpha(Theme.fg, 0.06)
                        NotifCard { id: card; anchors.fill: parent; anchors.margins: 10; notif: modelData }
                    }
                    add: Transition { NumberAnimation { properties: "opacity,scale"; from: 0.6; to: 1; duration: 220; easing.type: Easing.OutCubic } }
                    remove: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 160 } }
                    displaced: Transition { NumberAnimation { property: "y"; duration: 220; easing.type: Easing.OutCubic } }
                }
            }

            // ---- Wi-Fi ----
            // Click a network to expand it: connect / disconnect / forget, and a
            // password field for secured networks that are not saved yet.
            Item {
                id: wifiPage
                readonly property real wanted: !Net.wifiOn || !Net.networks.length ? 60 : Math.max(wifiList.contentHeight, 60)
                anchors.fill: parent
                visible: root.page === "wifi"
                property string selected: ""

                Text {
                    anchors.centerIn: parent
                    visible: !Net.wifiOn || Net.networks.length === 0
                    text: !Net.wifiOn ? I18n.t("Wi-Fi is off") : I18n.t("Searching…")
                    color: Theme.muted
                    font.family: "Google Sans Flex"; font.pixelSize: 12
                }

                ListView {
                    id: wifiList
                    anchors.fill: parent
                    visible: Net.wifiOn
                    clip: true
                    spacing: 4
                    boundsBehavior: Flickable.StopAtBounds
                    model: Net.networks
                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        readonly property var n: modelData
                        readonly property bool open: wifiPage.selected === n.name
                        readonly property bool needsPass: Net.secured(n) && !n.known && !n.connected
                        property string error: ""
                        width: wifiList.width
                        height: 40 + (open ? (needsPass ? 76 : 40) : 0)
                        radius: 14
                        clip: true
                        color: n.connected ? Qt.alpha(Theme.accent, 0.16)
                            : open ? Qt.alpha(Theme.fg, 0.08)
                            : (rowMa.containsMouse ? Qt.alpha(Theme.fg, 0.06) : "transparent")
                        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                        Connections {
                            target: row.n
                            function onConnectionFailed(reason) {
                                row.error = reason === ConnectionFailReason.NoSecrets ? I18n.t("Wrong password") : I18n.t("Could not connect");
                                wifiPage.selected = row.n.name;
                            }
                            function onConnectedChanged() { if (row.n.connected) row.error = ""; }
                        }

                        function join() {
                            error = "";
                            if (needsPass) { if (pass.text) n.connectWithPsk(pass.text); }
                            else n.connect();
                        }

                        MouseArea {
                            id: rowMa
                            width: parent.width; height: 40
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                wifiPage.selected = row.open ? "" : row.n.name;
                                if (row.open && row.needsPass) { pass.text = ""; pass.forceActiveFocus(); }
                            }
                        }

                        Icon {
                            id: sig
                            x: 12; y: 12
                            text: Net.signalIcon(row.n.signalStrength)
                            color: row.n.connected ? Theme.accent : Theme.fg
                            fill: 1
                        }
                        Text {
                            anchors.left: sig.right; anchors.leftMargin: 10
                            anchors.right: state.left; anchors.rightMargin: 8
                            y: 11
                            text: row.n.name
                            elide: Text.ElideRight
                            color: Theme.fg
                            font.family: "Google Sans Flex"; font.pixelSize: 13
                            font.weight: row.n.connected ? Font.DemiBold : Font.Normal
                        }
                        Text {
                            id: state
                            anchors.right: lock.left; anchors.rightMargin: 8
                            y: 12
                            text: row.error !== "" ? row.error
                                : row.n.stateChanging ? I18n.t("Connecting…")
                                : row.n.connected ? I18n.t("Connected")
                                : row.n.known ? I18n.t("Saved") : ""
                            color: row.error !== "" ? "#ff8a80" : Theme.muted
                            font.family: "Google Sans Flex"; font.pixelSize: 11
                        }
                        Icon {
                            id: lock
                            anchors.right: chev.left; anchors.rightMargin: 6
                            y: 12
                            text: Net.secured(row.n) ? "lock" : "lock_open"
                            color: Theme.muted
                            font.pixelSize: 14
                        }
                        Icon {
                            id: chev
                            anchors.right: parent.right; anchors.rightMargin: 10
                            y: 12
                            text: "expand_more"
                            color: Theme.muted
                            rotation: row.open ? 180 : 0
                            Behavior on rotation { NumberAnimation { duration: 200 } }
                        }

                        // Expanded: password (new secured network) + actions.
                        Column {
                            x: 12; y: 44
                            width: parent.width - 24
                            spacing: 8
                            opacity: row.open ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 160 } }

                            Rectangle {
                                visible: row.needsPass
                                width: parent.width; height: 30
                                radius: 15
                                color: Qt.alpha(Theme.fg, 0.08)
                                border.width: 1
                                border.color: pass.activeFocus ? Theme.accent : "transparent"
                                TextInput {
                                    id: pass
                                    anchors.fill: parent
                                    anchors.leftMargin: 12; anchors.rightMargin: 36
                                    verticalAlignment: TextInput.AlignVCenter
                                    echoMode: showPass.shown ? TextInput.Normal : TextInput.Password
                                    color: Theme.fg
                                    font.family: "Google Sans Flex"; font.pixelSize: 12
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: !pass.text
                                        text: I18n.t("Password")
                                        color: Theme.muted
                                        font: pass.font
                                    }
                                    onAccepted: row.join()
                                    Keys.onEscapePressed: wifiPage.selected = ""
                                }
                                Icon {
                                    id: showPass
                                    property bool shown: false
                                    anchors.right: parent.right; anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: shown ? "visibility_off" : "visibility"
                                    color: Theme.muted
                                    font.pixelSize: 16
                                    MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: showPass.shown = !showPass.shown }
                                }
                            }

                            Row {
                                spacing: 6
                                ActionButton {
                                    visible: !row.n.connected
                                    primary: true
                                    icon: "link"; label: I18n.t("Connect")
                                    onClicked: row.join()
                                }
                                ActionButton {
                                    visible: row.n.connected
                                    icon: "link_off"; label: I18n.t("Disconnect")
                                    onClicked: row.n.disconnect()
                                }
                                ActionButton {
                                    visible: row.n.known
                                    danger: true
                                    icon: "delete"; label: I18n.t("Forget")
                                    onClicked: { row.n.forget(); wifiPage.selected = ""; }
                                }
                            }
                        }
                    }
                }
            }

            // ---- Bluetooth ----
            // Click a device to expand it: connect / disconnect / pair, trust, forget.
            Item {
                id: btPage
                readonly property real wanted: !Net.btOn || !Net.btDevices.length ? 60 : Math.max(btList.contentHeight, 60)
                anchors.fill: parent
                visible: root.page === "bluetooth"
                property string selected: ""

                Text {
                    anchors.centerIn: parent
                    visible: !Net.btOn || Net.btDevices.length === 0
                    text: !Net.adapter ? I18n.t("No Bluetooth adapter") : !Net.btOn ? I18n.t("Bluetooth is off") : I18n.t("Searching…")
                    color: Theme.muted
                    font.family: "Google Sans Flex"; font.pixelSize: 12
                }

                ListView {
                    id: btList
                    anchors.fill: parent
                    visible: Net.btOn
                    clip: true
                    spacing: 4
                    boundsBehavior: Flickable.StopAtBounds
                    model: Net.btDevices
                    delegate: Rectangle {
                        id: brow
                        required property var modelData
                        readonly property var d: modelData
                        readonly property bool open: btPage.selected === d.address
                        readonly property string kind: d.icon || ""
                        width: btList.width
                        height: open ? 80 : 40
                        radius: 14
                        clip: true
                        color: d.connected ? Qt.alpha(Theme.accent, 0.16)
                            : open ? Qt.alpha(Theme.fg, 0.08)
                            : (bma.containsMouse ? Qt.alpha(Theme.fg, 0.06) : "transparent")
                        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                        MouseArea {
                            id: bma
                            width: parent.width; height: 40
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: btPage.selected = brow.open ? "" : brow.d.address
                        }
                        Icon {
                            id: bicon
                            x: 12; y: 12
                            text: brow.kind.includes("audio") || brow.kind.includes("headset") ? "headphones"
                                : brow.kind.includes("phone") ? "smartphone"
                                : brow.kind.includes("mouse") ? "mouse"
                                : brow.kind.includes("keyboard") ? "keyboard"
                                : brow.kind.includes("joystick") || brow.kind.includes("gaming") ? "sports_esports"
                                : "bluetooth"
                            color: brow.d.connected ? Theme.accent : Theme.fg
                            fill: 1
                        }
                        Text {
                            anchors.left: bicon.right; anchors.leftMargin: 10
                            anchors.right: bstate.left; anchors.rightMargin: 8
                            y: 11
                            text: brow.d.name || brow.d.deviceName
                            elide: Text.ElideRight
                            color: Theme.fg
                            font.family: "Google Sans Flex"; font.pixelSize: 13
                            font.weight: brow.d.connected ? Font.DemiBold : Font.Normal
                        }
                        Text {
                            id: bstate
                            anchors.right: bchev.left; anchors.rightMargin: 8
                            y: 12
                            text: brow.d.pairing ? I18n.t("Pairing…")
                                : brow.d.state === BluetoothDeviceState.Connecting ? I18n.t("Connecting…")
                                : brow.d.connected ? (brow.d.batteryAvailable ? Math.round(brow.d.battery * 100) + "%" : I18n.t("Connected"))
                                : brow.d.paired ? I18n.t("Paired") : I18n.t("New")
                            color: Theme.muted
                            font.family: "Google Sans Flex"; font.pixelSize: 11
                        }
                        Icon {
                            id: bchev
                            anchors.right: parent.right; anchors.rightMargin: 10
                            y: 12
                            text: "expand_more"
                            color: Theme.muted
                            rotation: brow.open ? 180 : 0
                            Behavior on rotation { NumberAnimation { duration: 200 } }
                        }

                        Row {
                            x: 12; y: 44
                            spacing: 6
                            opacity: brow.open ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 160 } }
                            ActionButton {
                                visible: !brow.d.connected
                                primary: true
                                icon: brow.d.paired ? "link" : "add_link"
                                label: brow.d.paired ? I18n.t("Connect") : I18n.t("Pair")
                                onClicked: brow.d.paired ? brow.d.connect() : brow.d.pair()
                            }
                            ActionButton {
                                visible: brow.d.connected
                                icon: "link_off"; label: I18n.t("Disconnect")
                                onClicked: brow.d.disconnect()
                            }
                            ActionButton {
                                visible: brow.d.paired
                                icon: brow.d.trusted ? "verified" : "shield"
                                label: brow.d.trusted ? I18n.t("Trusted") : I18n.t("Trust")
                                onClicked: brow.d.trusted = !brow.d.trusted
                            }
                            ActionButton {
                                visible: brow.d.paired || brow.d.pairing
                                danger: true
                                icon: brow.d.pairing ? "close" : "delete"
                                label: brow.d.pairing ? I18n.t("Cancel") : I18n.t("Forget")
                                onClicked: { if (brow.d.pairing) brow.d.cancelPair(); else { brow.d.forget(); btPage.selected = ""; } }
                            }
                        }
                    }
                }
            }

            // ---- AI usage (CodexBar) ----
            Item {
                id: usagePage
                readonly property real wanted: UsageService.providers.length ? Math.max(usageList.contentHeight, 60) : 60
                anchors.fill: parent
                visible: root.page === "usage"

                Column {
                    anchors.centerIn: parent
                    visible: !UsageService.providers.length
                    spacing: 4
                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: UsageService.available ? "hourglass_top" : "extension_off"
                        color: Theme.muted; font.pixelSize: 22
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: !UsageService.available ? I18n.t("Install codexbar to see AI usage")
                            : UsageService.loading || !UsageService.loaded ? I18n.t("Loading usage…") : I18n.t("No providers")
                        color: Theme.muted; font.family: "Google Sans Flex"; font.pixelSize: 12
                    }
                }

                ListView {
                    id: usageList
                    anchors.fill: parent
                    clip: true
                    spacing: 8
                    model: UsageService.providers
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: UsageCard {
                        required property var modelData
                        width: usageList.width
                        height: implicitHeight
                        provider: modelData
                    }
                }
            }

            // ---- Performance ----
            PerfPage {
                id: perfPage
                anchors.fill: parent
                visible: root.page === "perf"
            }

            // ---- Music ----
            MusicPage {
                id: musicPage
                anchors.fill: parent
                visible: root.page === "music"
            }

            // ---- Sound mixer ----
            SoundPage {
                id: soundPage
                anchors.fill: parent
                visible: root.page === "sound"
            }

            // ---- Power ----
            Grid {
                id: powerPage
                readonly property real wanted: 72
                visible: root.page === "power"
                width: parent.width
                columns: 6
                spacing: 8
                readonly property real cellW: (width - 5 * spacing) / 6
                Repeater {
                    model: [
                        { icon: "system_update", label: UpdateService.totalCount > 0 ? I18n.t("Update (%1)", UpdateService.totalCount) : I18n.t("Update"), action: () => UpdateService.applyAll() },
                        { icon: "lock", label: I18n.t("Lock"), cmd: ["hyprlock"] },
                        { icon: "bedtime", label: I18n.t("Suspend"), cmd: ["sh", "-c", "systemctl suspend || loginctl suspend"] },
                        { icon: "logout", label: I18n.t("Log out"), cmd: ["sh", "-c", "loginctl terminate-session \"$XDG_SESSION_ID\""] },
                        { icon: "restart_alt", label: I18n.t("Reboot"), cmd: ["sh", "-c", "systemctl reboot || loginctl reboot"] },
                        { icon: "power_settings_new", label: I18n.t("Shut down"), cmd: ["sh", "-c", "systemctl poweroff || loginctl poweroff"] }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        width: powerPage.cellW
                        height: 64
                        radius: 16
                        color: pma.containsMouse ? Qt.alpha(Theme.accent, 0.22) : Qt.alpha(Theme.fg, 0.06)
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Column {
                            anchors.centerIn: parent
                            spacing: 4
                            Icon { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.icon; font.pixelSize: 20; color: pma.containsMouse ? Theme.accent : Theme.fg }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; color: Theme.fg; font.family: "Google Sans Flex"; font.pixelSize: 11 }
                        }
                        MouseArea {
                            id: pma
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                IslandState.closeCenter();
                                if (modelData.action) modelData.action();
                                else if (modelData.cmd) Quickshell.execDetached(modelData.cmd);
                            }
                        }
                    }
                }
            }

        }
    }
    // Page title and its actions. Sits above the page; in the full center it
    // goes below the tiles and volume, on a single page it is the top row.
    component PageHeader: Item {
        width: parent ? parent.width : 0
        height: 24
        // Single pages get a back arrow to the full control center.
        Rectangle {
            id: back
            visible: !root.full
            width: visible ? 24 : 0
            height: 24; radius: 12
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            color: backMa.containsMouse ? Qt.alpha(Theme.fg, 0.14) : Qt.alpha(Theme.fg, 0.08)
            Behavior on color { ColorAnimation { duration: 120 } }
            Icon { anchors.centerIn: parent; text: "arrow_back"; font.pixelSize: 16 }
            MouseArea { id: backMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: IslandState.openCenter("notifs") }
        }
        Text {
            anchors.left: back.right
            anchors.leftMargin: back.visible ? 8 : 4
            anchors.verticalCenter: parent.verticalCenter
            text: I18n.t(({ notifs: "Notifications", wifi: "Wi-Fi", bluetooth: "Bluetooth", power: "Power", usage: "AI usage", sound: "Sound" })[root.page] || "")
            color: Theme.fg
            font.family: "Google Sans Flex"; font.pixelSize: 14; font.weight: Font.Bold
        }
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Pill {
                visible: root.page === "notifs" && Notifs.list.length > 0
                icon: "clear_all"; label: I18n.t("Clear")
                onClicked: Notifs.clearAll()
            }
            Text {
                visible: root.page === "usage" && UsageService.loaded
                anchors.verticalCenter: parent.verticalCenter
                text: UsageService.agoText()
                color: Theme.muted
                font.family: "Google Sans Flex"; font.pixelSize: 10
            }
            Pill {
                visible: root.page === "usage" && UsageService.available
                icon: "refresh"; label: UsageService.loading ? I18n.t("Updating") : I18n.t("Refresh")
                onClicked: UsageService.refresh()
            }
            Pill {
                visible: root.page === "wifi" || root.page === "bluetooth" || root.page === "sound"
                icon: "settings"; label: I18n.t("Settings")
                onClicked: {
                    Quickshell.execDetached(root.page === "wifi" ? ["nm-connection-editor"]
                        : root.page === "sound" ? ["pavucontrol"] : ["blueman-manager"]);
                    IslandState.closeCenter();
                }
            }
        }
    }

    component Pill: Rectangle {
        id: p
        property string icon
        property string label
        signal clicked()
        height: 24
        width: prow.implicitWidth + 18
        radius: 12
        color: ma.containsMouse ? Qt.alpha(Theme.fg, 0.14) : Qt.alpha(Theme.fg, 0.08)
        Row {
            id: prow
            anchors.centerIn: parent
            spacing: 4
            Icon { text: p.icon; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
            Text { text: p.label; color: Theme.fg; font.family: "Google Sans Flex"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
        }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: p.clicked() }
    }
}
