import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland
import qs
import qs.services
import qs.Core
import qs.Core.Services
import qs.modules.common

BarButton {
    id: root

    property bool transparentBg: false
    implicitWidth: transparentBg ? hLayout.implicitWidth + 8 : (hLayout.implicitWidth + 24)
    implicitHeight: 32
    color: transparentBg ? "transparent" : Theme.bgSecondary
    radius: height / 2
    border.width: transparentBg ? 0 : 1
    border.color: Qt.rgba(1, 1, 1, 0.08)

    readonly property int activeWorkspaceId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
    readonly property int maxOccupiedWsId: {
        let maxId = 1;
        if (Hyprland.workspaces && Hyprland.workspaces.values) {
            const list = Hyprland.workspaces.values;
            for (let i = 0; i < list.length; i++) {
                const ws = list[i];
                if (!ws || ws.id <= 0)
                    continue;

                let hasWins = false;
                if (ws.toplevels && ws.toplevels.values && ws.toplevels.values.length > 0)
                    hasWins = true;

                if (!hasWins && Hyprland.toplevels && Hyprland.toplevels.values)
                    hasWins = Hyprland.toplevels.values.some((top) => {
                        return top && top.workspace && top.workspace.id === ws.id;
                    });

                if (!hasWins && (ws.windows > 0 || (typeof ws.hasWindows === "boolean" && ws.hasWindows)))
                    hasWins = true;

                if (hasWins && ws.id > maxId)
                    maxId = ws.id;
            }
        }
        if (Hyprland.toplevels && Hyprland.toplevels.values) {
            for (let j = 0; j < Hyprland.toplevels.values.length; j++) {
                const top = Hyprland.toplevels.values[j];
                if (top && top.workspace && top.workspace.id > maxId)
                    maxId = top.workspace.id;
            }
        }
        return maxId;
    }
    readonly property int visibleWorkspaceCount: Math.min(10, Math.max(Math.max(activeWorkspaceId, maxOccupiedWsId) + 1, 5))

    WheelHandler {
        onWheel: (event) => {
            if (event.angleDelta.y < 0)
                Hyprland.dispatch('hl.dsp.focus({workspace = "r+1"})');
            else if (event.angleDelta.y > 0)
                Hyprland.dispatch('hl.dsp.focus({workspace = "r-1"})');
        }
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    }

    Connections {
        function onRawEvent(event) {
            if (!event || !event.name)
                return;
            const ev = event.name;
            if (ev === "openwindow" || ev === "closewindow" || ev === "movewindowv2" || ev === "createworkspacev2" || ev === "destroyworkspacev2")
                refreshDebounce.restart();
        }
        target: Hyprland
    }

    Timer {
        id: refreshDebounce
        interval: 100
        repeat: false
        onTriggered: {
            if (typeof Hyprland.refreshWorkspaces === "function")
                Hyprland.refreshWorkspaces();
        }
    }

    RowLayout {
        id: hLayout

        anchors.centerIn: parent
        spacing: 6

        Repeater {
            model: 10

            Rectangle {
                id: wsItemH

                readonly property int wsId: index + 1
                readonly property bool isVisibleSlot: wsId <= root.visibleWorkspaceCount
                readonly property var workspace: Hyprland.workspaces.values.find((ws) => {
                    return ws.id === wsId;
                })
                readonly property bool isActive: root.activeWorkspaceId === wsId
                readonly property bool hasActualWindows: {
                    if (workspace !== undefined && workspace.windows > 0) return true;
                    if (workspace && workspace.toplevels && workspace.toplevels.values && workspace.toplevels.values.length > 0) return true;
                    if (Hyprland.toplevels && Hyprland.toplevels.values) {
                        return Hyprland.toplevels.values.some((top) => top && top.workspace && top.workspace.id === wsId);
                    }
                    return false;
                }
                readonly property bool hasWindows: hasActualWindows
                readonly property string manualLabel: (Persistent.ready && Persistent.states?.workspaceLabels && (wsId - 1) < Persistent.states.workspaceLabels.length) ? (Persistent.states.workspaceLabels[wsId - 1] || "") : ""
                readonly property var mainWin: HyprlandData.biggestWindowForWorkspace(wsId)
                readonly property string appClass: mainWin?.class || ""
                readonly property string appIconName: appClass !== "" ? AppSearch.guessIcon(appClass) : ""
                readonly property bool hasAutoIcon: manualLabel === "" && appIconName !== ""
                readonly property string label: manualLabel

                visible: opacity > 0.001
                opacity: isVisibleSlot ? 1.0 : 0.0

                implicitWidth: !isVisibleSlot ? 0 : (
                    manualLabel !== ""
                        ? labelText.implicitWidth + (isActive ? 20 : 14)
                        : (hasAutoIcon
                            ? (isActive ? 26 : 20)
                            : (isActive ? 24 : 8))
                )
                implicitHeight: !isVisibleSlot ? 0 : (
                    manualLabel !== ""
                        ? (isActive ? 20 : 16)
                        : (hasAutoIcon
                            ? (isActive ? 20 : 16)
                            : (isActive ? 10 : 8))
                )
                Layout.preferredWidth: implicitWidth
                Layout.preferredHeight: implicitHeight
                radius: implicitHeight / 2

                color: {
                    if (!isVisibleSlot) return "transparent";
                    if (manualLabel !== "" || hasAutoIcon) {
                        return mouseAreaH.containsMouse ? Theme.accent : (isActive ? Theme.accent : Theme.fg);
                    }
                    if (isActive) return Theme.accent;
                    if (hasWindows) {
                        return mouseAreaH.containsMouse
                            ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.95)
                            : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.65);
                    }
                    return mouseAreaH.containsMouse
                        ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.45)
                        : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.22);
                }
                scale: mouseAreaH.pressed ? 0.88 : (mouseAreaH.containsMouse && !isActive ? 1.2 : 1.0)

                Text {
                    id: labelText
                    visible: manualLabel !== ""
                    anchors.centerIn: parent
                    text: manualLabel
                    font.pixelSize: isActive ? 11 : 10
                    font.bold: true
                    color: Theme.bg
                }

                IconImage {
                    id: appIcon
                    visible: manualLabel === "" && hasAutoIcon
                    anchors.centerIn: parent
                    source: hasAutoIcon ? Quickshell.iconPath(appIconName, "image-missing") : ""
                    implicitWidth: isActive ? 14 : 12
                    implicitHeight: isActive ? 14 : 12
                }

                MouseArea {
                    id: mouseAreaH

                    anchors.fill: parent
                    anchors.margins: -8
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch('hl.dsp.focus({workspace=' + wsId + '})')
                }

                Behavior on implicitWidth {
                    NumberAnimation {
                        duration: Constants.animNormal
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on implicitHeight {
                    NumberAnimation {
                        duration: Constants.animNormal
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Constants.animFast
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Constants.animFast
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Constants.animFast
                        easing.type: Easing.OutQuad
                    }
                }
            }
        }
    }
}
