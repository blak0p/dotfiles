import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs

// Content of one of the pills right of the island, picked by `section`:
//   "tray"   - the first tray apps inline and a chevron with the rest
//   "system" - network, bluetooth and volume
//   "usage"  - AI plan usage (codexbar)
//   "power"  - power menu
// Network/bluetooth/usage/power open their page of the island center.
Row {
    id: root
    spacing: 12

    property string section: "system"
    // Whether this section has anything to show; empty sections hide their pill.
    readonly property bool hasContent: section === "tray" ? trayItems.length > 0
        : section === "usage" ? UsageService.available
        : true

    readonly property var trayItems: Config.trayVisible(SystemTray.items.values)
    readonly property int inlineCount: Math.min(trayItems.length, Config.trayInline)
    readonly property int hiddenCount: Math.max(0, trayItems.length - Config.trayInline)

    // The first few tray apps sit inline, like every other bar; anything past
    // that is behind the chevron so the pill keeps a bounded width.
    Row {
        visible: root.section === "tray"
        spacing: 6
        anchors.verticalCenter: parent.verticalCenter
        Repeater {
            model: root.trayItems.slice(0, root.inlineCount)
            delegate: Item {
                required property int index
                width: 16; height: 16
                TrayIcon {
                    anchors.fill: parent
                    modelData: root.trayItems[index]
                }
            }
        }
    }

    BarButton {
        icon: "keyboard_arrow_down"
        visible: root.section === "tray" && root.hiddenCount > 0
        active: IslandState.trayOpen
        rotation: IslandState.trayOpen ? 180 : 0
        Behavior on rotation { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        onClicked: IslandState.toggleTray()
    }

    BarButton { icon: Net.netIcon; visible: root.section === "system"; active: IslandState.centerOpen && IslandState.page === "wifi"; onClicked: IslandState.togglePage("wifi") }
    BarButton {
        icon: Net.btIcon
        visible: root.section === "system"
        tint: Net.btConnected.length > 0
        active: IslandState.centerOpen && IslandState.page === "bluetooth"
        onClicked: IslandState.togglePage("bluetooth")
    }
    BarButton {
        visible: root.section === "system"
        icon: IslandState.muted ? "volume_off" : (IslandState.volume < 0.01 ? "volume_mute" : (IslandState.volume < 0.5 ? "volume_down" : "volume_up"))
        active: IslandState.centerOpen && IslandState.page === "sound"
        onClicked: IslandState.togglePage("sound")
    }
    // AI usage page; tinted when any plan window is below 20% left.
    BarButton {
        icon: "data_usage"
        visible: root.section === "usage" && UsageService.available
        tint: UsageService.lowestLeft >= 0 && UsageService.lowestLeft < 20
        active: IslandState.centerOpen && IslandState.page === "usage"
        onClicked: IslandState.togglePage("usage")
    }
    BarButton { icon: "power_settings_new"; visible: root.section === "power"; active: IslandState.centerOpen && IslandState.page === "power"; onClicked: IslandState.togglePage("power") }

    component BarButton: Icon {
        id: b
        property string icon
        property bool active: false
        property bool tint: false
        signal clicked()
        anchors.verticalCenter: parent.verticalCenter
        text: icon
        color: active || tint ? Theme.accent : (ma.containsMouse ? Theme.fg : Qt.alpha(Theme.fg, 0.85))
        fill: active ? 1 : 0
        Behavior on color { ColorAnimation { duration: 120 } }
        MouseArea {
            id: ma
            anchors.fill: parent
            anchors.margins: -5
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: b.clicked()
        }
    }
}
