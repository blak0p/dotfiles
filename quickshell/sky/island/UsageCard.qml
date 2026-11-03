import QtQuick
import qs

// One AI provider on the usage page: name, plan, service status and a bar per
// rate window (remaining %, time to reset, pace). Failing providers show why.
Rectangle {
    id: card
    property var provider: ({})
    readonly property var windows: provider.windows || []
    readonly property var status: provider.status || null

    implicitHeight: body.implicitHeight + 24
    radius: 16
    color: Qt.alpha(Theme.fg, 0.06)

    function barColor(left) {
        return left >= 50 ? Theme.accent : left >= 20 ? "#f5c26b" : "#f28b82";
    }

    Column {
        id: body
        x: 12; y: 12
        width: parent.width - 24
        spacing: 10

        Item {
            width: parent.width
            height: 24

            Rectangle {
                id: mark
                width: 24; height: 24; radius: 12
                anchors.verticalCenter: parent.verticalCenter
                color: card.provider.ok ? Theme.accent : Qt.alpha(Theme.fg, 0.12)
                Text {
                    anchors.centerIn: parent
                    text: (card.provider.name || "?").charAt(0)
                    color: card.provider.ok ? Theme.accentText : Theme.muted
                    font.family: "Google Sans Flex"; font.pixelSize: 12; font.weight: Font.Bold
                }
            }
            Text {
                id: nameText
                anchors.left: mark.right; anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: card.provider.name || ""
                color: Theme.fg
                font.family: "Google Sans Flex"; font.pixelSize: 13; font.weight: Font.Bold
            }
            Text {
                anchors.left: nameText.right; anchors.leftMargin: 6
                anchors.right: statusRow.left; anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: card.provider.plan || ""
                elide: Text.ElideRight
                color: Theme.muted
                font.family: "Google Sans Flex"; font.pixelSize: 11
            }
            // Service status from the provider's status page.
            Row {
                id: statusRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                visible: card.status !== null
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 7; height: 7; radius: 3.5
                    color: !card.status || card.status.indicator === "none" ? "#81c995"
                        : card.status.indicator === "minor" ? "#f5c26b" : "#f28b82"
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: !card.status ? "" : card.status.indicator === "none" ? "Operational" : card.status.description
                    color: Theme.muted
                    font.family: "Google Sans Flex"; font.pixelSize: 10
                }
            }
        }

        // Provider error (expired session, timeout, ...).
        Row {
            visible: !card.provider.ok
            spacing: 6
            Icon { text: "error"; fill: 1; color: "#f28b82"; font.pixelSize: 15; anchors.verticalCenter: parent.verticalCenter }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: card.provider.error || ""
                color: Theme.fg
                font.family: "Google Sans Flex"; font.pixelSize: 11
            }
        }

        Repeater {
            model: card.windows
            delegate: Column {
                id: win
                required property var modelData
                readonly property real remaining: Math.max(0, Math.min(100, 100 - modelData.usedPercent))
                width: body.width
                spacing: 5

                Item {
                    width: parent.width
                    height: titleText.implicitHeight
                    Text {
                        id: titleText
                        text: win.modelData.title
                        color: Theme.fg
                        font.family: "Google Sans Flex"; font.pixelSize: 11; font.weight: Font.DemiBold
                    }
                    Text {
                        anchors.right: parent.right
                        readonly property string reset: UsageService.resetsIn(win.modelData.resetsAt)
                        text: Math.round(win.remaining) + "% left" + (reset ? "  ·  " + reset : "")
                        color: Theme.muted
                        font.family: "Google Sans Flex"; font.pixelSize: 11
                        font.features: { "tnum": 1 }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 6
                    radius: 3
                    color: Qt.alpha(Theme.fg, 0.08)
                    Rectangle {
                        height: parent.height
                        radius: 3
                        width: Math.max(parent.height, parent.width * win.remaining / 100)
                        visible: win.remaining > 0
                        color: card.barColor(win.remaining)
                        Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }
                }

                Text {
                    visible: text.length > 0
                    width: parent.width
                    text: (win.modelData.pace || "").split(" | ").join("  ·  ")
                    elide: Text.ElideRight
                    color: Qt.alpha(Theme.muted, 0.8)
                    font.family: "Google Sans Flex"; font.pixelSize: 10
                }
            }
        }
    }
}
