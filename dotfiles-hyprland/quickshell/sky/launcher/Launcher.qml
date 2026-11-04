import QtQuick
import Quickshell
import Quickshell.Widgets
import qs
import qs.island
import "calc.js" as Calc

// Compact launcher: it is the island's "launcher" view, so the pill itself
// grows into this dropdown (no dock, no separate window). Search apps and
// commands, and type an arithmetic expression to get the result inline.
Item {
    id: root
    property bool open: false

    // Result of evaluating the query as an expression, or null.
    readonly property var calc: Calc.result(input.text)
    readonly property var apps: AppModel.filter(input.text)
    readonly property var commands: [
        { name: I18n.t("Change wallpaper"), hint: "Ctrl+Super+T", icon: "wallpaper", run: () => IslandState.openWallpaper() },
        { name: I18n.t("Lock screen"), hint: "Super L", icon: "lock", run: () => Quickshell.execDetached(["hyprlock"]) },
        { name: "Screenshot region", hint: "Super Shift S", icon: "photo_camera", run: () => Quickshell.execDetached(["sh", "-c",
            "d=\"$HOME/Imágenes/Screenshots\"; mkdir -p \"$d\"; sleep 0.3; g=$(slurp) && grim -g \"$g\" \"$d/$(date +%F_%H-%M-%S).png\""]) }
    ].filter(c => c.name.toLowerCase().indexOf(input.text.trim().toLowerCase()) !== -1)

    readonly property var rows: {
        const out = [];
        if (calc) out.push({ kind: "calc", icon: "calculate", text: calc.text });
        for (const a of apps) out.push({ kind: "app", icon: a.icon, text: a.name, entry: a });
        for (const c of commands) out.push({ kind: "cmd", icon: c.icon, text: c.name, hint: c.hint, run: c.run });
        return out;
    }
    // Rows that fit before the list scrolls.
    readonly property int fit: Math.max(1, Math.floor(
        (Config.launcherMaxH - 2 * Config.launcherPad - Config.launcherInputH - Config.launcherGap) / Config.launcherRowH))
    readonly property int shownRows: Math.max(1, Math.min(rows.length, fit))
    readonly property real wantedH: 2 * Config.launcherPad + Config.launcherInputH + Config.launcherGap
        + shownRows * Config.launcherRowH

    property int sel: 0

    onOpenChanged: {
        if (!open) return;
        input.text = "";
        sel = 0;
        focusRetry.restart();
    }
    onRowsChanged: if (sel >= rows.length) sel = Math.max(0, rows.length - 1)

    // The layer surface only receives keyboard focus after the compositor
    // applies the keyboard mode, so retry until the field really has it.
    Timer {
        id: focusRetry
        interval: 30; repeat: true
        property int tries: 0
        onTriggered: {
            input.forceActiveFocus();
            if (input.activeFocus || ++tries > 20) { stop(); tries = 0; }
        }
    }

    function move(delta) {
        if (!rows.length) return;
        sel = Math.max(0, Math.min(rows.length - 1, sel + delta));
        list.positionViewAtIndex(sel, ListView.Contain);
    }

    function activate(i) {
        const row = rows[i];
        if (!row) return;
        if (row.kind === "calc") {
            Quickshell.clipboardText = row.text;
            IslandState.closeLauncher();
            return;
        }
        IslandState.closeLauncher();
        if (row.kind === "app") row.entry.execute();
        else if (row.run) row.run();
    }

    // Clicks on the dropdown body never fall through to the pill (which would
    // toggle the launcher closed again).
    MouseArea { anchors.fill: parent; onClicked: {} }

    Rectangle {
        id: field
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: Config.launcherPad
        anchors.leftMargin: Config.launcherPad
        anchors.rightMargin: Config.launcherPad
        height: Config.launcherInputH
        radius: 12
        color: Qt.alpha(Theme.fg, 0.08)

        Icon {
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            text: "search"; color: Theme.muted; font.pixelSize: 19
        }
        TextInput {
            id: input
            x: 44
            width: parent.width - 60
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.fg
            selectionColor: Theme.accent
            selectedTextColor: Theme.accentText
            font.family: "Google Sans Flex"; font.pixelSize: 15
            clip: true
            onTextChanged: root.sel = 0
            Keys.onEscapePressed: IslandState.closeLauncher()
            Keys.onReturnPressed: root.activate(root.sel)
            Keys.onEnterPressed: root.activate(root.sel)
            Keys.onUpPressed: root.move(-1)
            Keys.onDownPressed: root.move(1)
            Text {
                visible: !input.text
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.t("Search apps, commands, or 2+2…")
                color: Theme.muted
                font: input.font
            }
        }
    }

    ListView {
        id: list
        anchors.top: field.bottom
        anchors.topMargin: Config.launcherGap
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: Config.launcherPad
        anchors.rightMargin: Config.launcherPad
        anchors.bottomMargin: Config.launcherPad
        clip: true
        model: root.rows
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            required property var modelData
            required property int index
            readonly property bool selected: root.sel === index
            width: list.width
            height: Config.launcherRowH
            radius: 10
            color: selected ? Qt.alpha(Theme.accent, 0.18)
                : (rowMa.containsMouse ? Qt.alpha(Theme.fg, 0.06) : "transparent")
            Behavior on color { ColorAnimation { duration: 120 } }

            Icon {
                visible: modelData.kind !== "app"
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.kind === "calc" ? "calculate" : modelData.icon
                color: modelData.kind === "calc" ? Theme.accent : Theme.fg
                font.pixelSize: 18
            }
            IconImage {
                visible: modelData.kind === "app"
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 22
                source: modelData.kind === "app" ? AppModel.iconSource(modelData.icon) : ""
            }
            Text {
                id: main
                x: 44
                width: parent.width - 44 - (tail.width + 20)
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: modelData.kind === "calc" ? "= " + modelData.text : modelData.text
                color: Theme.fg
                font.family: "Google Sans Flex"
                font.pixelSize: 14
                font.weight: modelData.kind === "calc" ? Font.Bold : Font.Normal
            }
            Text {
                id: tail
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.kind === "calc" ? I18n.t("↵ copy") : (modelData.hint || "")
                color: modelData.kind === "calc" ? Qt.alpha(Theme.accent, 0.9) : Theme.muted
                font.family: "Google Sans Flex"; font.pixelSize: 11
                font.weight: modelData.kind === "calc" ? Font.DemiBold : Font.Normal
            }

            MouseArea {
                id: rowMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.sel = index
                onClicked: root.activate(index)
            }
        }
    }

    // Empty state: still one row tall, so the pill does not collapse.
    Text {
        visible: root.rows.length === 0
        anchors.top: field.bottom
        anchors.topMargin: Config.launcherGap + 10
        anchors.horizontalCenter: parent.horizontalCenter
        text: I18n.t("No results")
        color: Theme.muted
        font.family: "Google Sans Flex"; font.pixelSize: 13
    }
}
