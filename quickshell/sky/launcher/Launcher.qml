import QtQuick
import Quickshell.Widgets
import Quickshell
import qs

Item {
    id: root
    property bool open: false

    signal itemContextRequested(var delegateItem, var item)

    property string query: ""
    property int sel: 0
    readonly property var apps: AppModel.filter(query)
    readonly property var commands: [
        { name: "Change wallpaper", hint: "Super W", run: () => Quickshell.execDetached(["python3", Theme.home + "/.config/hypr/wallfliper/main.py"]) },
        { name: "Lock screen", hint: "Super L", run: () => Quickshell.execDetached(["hyprlock"]) },
        { name: "Screenshot region", hint: "Super Shift S", run: () => Quickshell.execDetached(["sh", "-c",
            "d=\"$HOME/Imágenes/Screenshots\"; mkdir -p \"$d\"; sleep 0.3; g=$(slurp) && grim -g \"$g\" \"$d/$(date +%F_%H-%M-%S).png\""]) }
    ].filter(c => c.name.toLowerCase().includes(query.trim().toLowerCase()))
    readonly property int total: apps.length + commands.length

    onOpenChanged: {
        if (open) { query = ""; sel = 0; input.text = ""; focusRetry.restart(); }
    }
    onQueryChanged: sel = 0

    // The layer surface only receives keyboard focus after the compositor
    // applies the new keyboard mode, so retry until the field really has it.
    Timer {
        id: focusRetry
        interval: 30; repeat: true
        property int tries: 0
        onTriggered: {
            input.forceActiveFocus();
            if (input.activeFocus || ++tries > 20) { stop(); tries = 0; }
        }
    }

    function activate(i) {
        ShellState.closeLauncher();
        if (i < apps.length) apps[i].execute();
        else if (i - apps.length < commands.length) commands[i - apps.length].run();
    }
    function move(key) {
        const n = apps.length;
        if (total === 0) return;
        if (key === Qt.Key_Left) sel = Math.max(0, sel - 1);
        else if (key === Qt.Key_Right) sel = Math.min(total - 1, sel + 1);
        else if (key === Qt.Key_Down) {
            if (sel < n) sel = (sel + 5 < n) ? sel + 5 : (commands.length ? n : sel);
            else sel = Math.min(total - 1, sel + 1);
        } else if (key === Qt.Key_Up) {
            if (sel >= n) sel = (sel > n) ? sel - 1 : Math.max(0, n - 1);
            else sel = Math.max(0, sel - 5);
        }
        if (sel < n) grid.positionViewAtIndex(sel, GridView.Contain);
    }

    Column {
        anchors.fill: parent
        anchors.margins: 20
        anchors.topMargin: 12
        anchors.bottomMargin: 16
        spacing: 12

        Rectangle {
            width: parent.width; height: 44; radius: 14
            color: Theme.surface2
            Icon { x: 14; anchors.verticalCenter: parent.verticalCenter; text: "search"; color: Theme.muted; font.pixelSize: 20 }
            TextInput {
                id: input
                x: 46
                width: parent.width - 62
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.fg
                selectionColor: Theme.accent
                selectedTextColor: Theme.accentText
                font.family: "Google Sans Flex"; font.pixelSize: 15
                clip: true
                onTextChanged: root.query = text
                Keys.onEscapePressed: ShellState.closeLauncher()
                Keys.onReturnPressed: root.activate(root.sel)
                Keys.onEnterPressed: root.activate(root.sel)
                Keys.onPressed: e => {
                    if ([Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down].includes(e.key)) {
                        // Left/Right move the cursor only when the field is empty-of-grid-intent.
                        root.move(e.key);
                        e.accepted = true;
                    }
                }
                Text {
                    visible: !input.text
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Search apps, commands…"
                    color: Theme.muted
                    font: input.font
                }
            }
        }

        Text {
            text: "APPS"
            color: Theme.muted
            font.family: "Google Sans Flex"; font.pixelSize: 12; font.weight: Font.DemiBold; font.letterSpacing: 1
        }

        GridView {
            id: grid
            width: parent.width
            height: 2 * 96
            cellWidth: width / 5
            cellHeight: 96
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.apps
            delegate: Rectangle {
                required property var modelData
                required property int index
                readonly property bool selected: root.sel === index
                width: grid.cellWidth - 6; height: grid.cellHeight - 6
                radius: 14
                color: selected ? Qt.alpha(Theme.accent, 0.16) : (ma.containsMouse ? Theme.surface2 : "transparent")
                border.width: selected ? 1 : 0
                border.color: Qt.alpha(Theme.accent, 0.4)
                Column {
                    anchors.centerIn: parent
                    spacing: 6
                    width: parent.width - 8
                    IconImage {
                        anchors.horizontalCenter: parent.horizontalCenter
                        implicitSize: 36
                        source: AppModel.iconSource(modelData.icon)
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: modelData.name
                        color: Theme.fg
                        font.family: "Google Sans Flex"; font.pixelSize: 13; font.weight: Font.DemiBold
                    }
                }
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.RightButton) {
                            root.itemContextRequested(ma, {
                                key: modelData.id,
                                entry: modelData,
                                name: modelData.name,
                                icon: modelData.icon,
                                toplevels: []
                            });
                        } else {
                            root.activate(index);
                        }
                    }
                }
                // Pin badge
                Icon {
                    visible: DockPins.has(modelData.id)
                    anchors.top: parent.top; anchors.right: parent.right
                    anchors.topMargin: 4; anchors.rightMargin: 4
                    text: "push_pin"; fill: 1; color: Theme.muted; font.pixelSize: 12
                    z: 2
                }
            }
        }

        Text {
            text: "COMMANDS"
            visible: root.commands.length > 0
            color: Theme.muted
            font.family: "Google Sans Flex"; font.pixelSize: 12; font.weight: Font.DemiBold; font.letterSpacing: 1
        }

        Column {
            width: parent.width
            spacing: 2
            Repeater {
                model: root.commands
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool selected: root.sel === root.apps.length + index
                    width: parent.width; height: 36; radius: 10
                    color: selected ? Qt.alpha(Theme.accent, 0.16) : (cma.containsMouse ? Theme.surface2 : "transparent")
                    Text {
                        x: 12; anchors.verticalCenter: parent.verticalCenter
                        text: modelData.name
                        color: Theme.fg
                        font.family: "Google Sans Flex"; font.pixelSize: 14
                    }
                    Rectangle {
                        anchors.right: parent.right; anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: kbd.width + 14; height: 20; radius: 6
                        color: Theme.surface2
                        Text {
                            id: kbd
                            anchors.centerIn: parent
                            text: modelData.hint
                            color: Theme.muted
                            font.family: "Google Sans Flex"; font.pixelSize: 11
                        }
                    }
                    MouseArea {
                        id: cma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activate(root.apps.length + index)
                    }
                }
            }
        }
    }
}
