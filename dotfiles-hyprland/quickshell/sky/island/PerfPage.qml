import QtQuick
import qs

// Performance module: CPU and GPU side by side, RAM, then disks. Data comes
// from PerfService, which only samples while this page is on screen.
Item {
    id: root
    readonly property real wanted: PerfService.loaded ? body.implicitHeight : 60
    readonly property var gpu: PerfService.gpu

    function pct(v) { return Math.round(v || 0) + "%"; }
    function barColor(v) { return v > 80 ? "#f3c58f" : Theme.accent; }

    Text {
        anchors.centerIn: parent
        visible: !PerfService.loaded
        text: I18n.t("Reading sensors…")
        color: Theme.muted
        font.family: "Google Sans Flex"; font.pixelSize: 12
    }

    Column {
        id: body
        width: parent.width
        spacing: 8
        visible: PerfService.loaded

        Row {
            width: parent.width
            spacing: 8
            Meter {
                id: cpuM
                width: (parent.width - parent.spacing) / 2
                height: Math.max(cpuM.need, gpuM.need)
                icon: "memory"; title: "CPU"
                value: PerfService.cpu.percent
                history: PerfService.cpuHist
                chips: [PerfService.cpu.temp !== null ? Math.round(PerfService.cpu.temp) + " °C" : "",
                        PerfService.cpu.ghz !== null ? PerfService.cpu.ghz.toLocaleString(Qt.locale(), "f", 1) + " GHz" : ""]
            }
            Meter {
                id: gpuM
                width: (parent.width - parent.spacing) / 2
                height: Math.max(cpuM.need, gpuM.need)
                icon: "videogame_asset"; title: "GPU"
                value: root.gpu ? root.gpu.percent : 0
                history: PerfService.gpuHist
                missing: !root.gpu
                chips: !root.gpu ? [] : [
                    root.gpu.temp !== null ? Math.round(root.gpu.temp) + " °C" : "",
                    root.gpu.vramTotal ? "VRAM " + PerfService.gb(root.gpu.vramUsed) + "/" + Math.round(root.gpu.vramTotal / 1073741824) + " GB" : "",
                    root.gpu.watts !== null ? Math.round(root.gpu.watts) + " W" : ""]
            }
        }

        Meter {
            width: parent.width
            icon: "memory_alt"; title: I18n.t("RAM")
            value: PerfService.mem.percent
            history: PerfService.memHist
            chips: [I18n.t("%1 / %2 GB used", PerfService.gb(PerfService.mem.used), PerfService.gb(PerfService.mem.total))]
        }

        Card {
            width: parent.width
            height: disks.implicitHeight + 24
            Column {
                id: disks
                x: 12; y: 12
                width: parent.width - 24
                spacing: 8
                Item {
                    width: parent.width; height: 20
                    Row {
                        spacing: 8
                        anchors.verticalCenter: parent.verticalCenter
                        Icon { text: "hard_drive"; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: I18n.t("Disks"); color: Theme.fg; font.family: "Google Sans Flex"; font.pixelSize: 13; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "R " + PerfService.mbps(PerfService.readBps) + " · W " + PerfService.mbps(PerfService.writeBps)
                        color: Theme.muted
                        font.family: "Google Sans Flex"; font.pixelSize: 11
                    }
                }
                Repeater {
                    model: PerfService.disks
                    delegate: Item {
                        required property var modelData
                        width: disks.width
                        height: 16
                        Text {
                            id: dl
                            width: 56
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            elide: Text.ElideRight
                            color: Theme.fg
                            font.family: "Google Sans Flex"; font.pixelSize: 12
                        }
                        Bar {
                            anchors.left: dl.right; anchors.leftMargin: 8
                            anchors.right: ds.left; anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            value: modelData.percent
                        }
                        Text {
                            id: ds
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: PerfService.size(modelData.used) + " / " + PerfService.size(modelData.total)
                            color: Theme.muted
                            font.family: "Google Sans Flex"; font.pixelSize: 11
                        }
                    }
                }
            }
        }
    }

    component Card: Rectangle {
        radius: 18
        color: Qt.alpha(Theme.fg, 0.06)
    }

    component Bar: Rectangle {
        property real value: 0
        height: 6; radius: 3
        color: Qt.alpha(Theme.fg, 0.1)
        Rectangle {
            width: parent.width * Math.max(0, Math.min(100, parent.value)) / 100
            height: parent.height; radius: 3
            color: root.barColor(parent.value)
            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        }
    }

    component Meter: Card {
        id: m
        property string icon
        property string title
        property real value: 0
        property var history: []
        property var chips: []
        property bool missing: false
        // CPU and GPU share a row: both take the taller card's height.
        readonly property real need: mcol.implicitHeight + 24
        height: need
        Column {
            id: mcol
            x: 12; y: 12
            width: parent.width - 24
            spacing: 8
            Item {
                width: parent.width; height: 28
                Row {
                    spacing: 8
                    anchors.verticalCenter: parent.verticalCenter
                    Icon { text: m.icon; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: m.title; color: Theme.fg; font.family: "Google Sans Flex"; font.pixelSize: 13; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: m.missing ? "—" : root.pct(m.value)
                    color: Theme.fg
                    font.family: "Google Sans Flex"; font.pixelSize: 22; font.weight: Font.Bold
                    font.features: { "tnum": 1 }
                }
            }
            Spark { width: parent.width; height: 34; values: m.history; visible: !m.missing }
            Bar { width: parent.width; value: m.value; visible: !m.missing }
            Text {
                visible: m.missing
                text: I18n.t("No AMD GPU found")
                color: Theme.muted
                font.family: "Google Sans Flex"; font.pixelSize: 11
            }
            Flow {
                width: parent.width
                spacing: 6
                Repeater {
                    model: m.chips.filter(c => c !== "")
                    delegate: Rectangle {
                        required property string modelData
                        width: ct.implicitWidth + 16
                        height: 20; radius: 10
                        color: Qt.alpha(Theme.fg, 0.08)
                        Text {
                            id: ct
                            anchors.centerIn: parent
                            text: modelData
                            color: Theme.muted
                            font.family: "Google Sans Flex"; font.pixelSize: 11
                        }
                    }
                }
            }
        }
    }
}
