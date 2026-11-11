import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Keyboard shortcuts: every live Hyprland bind grouped by its description prefix,
// with search, key capture to change a shortcut and a collision warning. Changes
// are written ONLY to the user layer (~/.config/sky/hypr/keybinds.lua) by
// scripts/sky_keybinds.py and applied with `hyprctl reload`.
Page {
    id: page
    title: I18n.t("Shortcuts")

    readonly property string script: Qt.resolvedUrl("../scripts/sky_keybinds.py").toString().replace("file://", "")

    property var groups: []
    property int hidden: 0
    property string query: ""
    property string error: ""
    property bool busy: false

    // capture state
    property string capId: ""
    property string capCurrent: ""
    property string capCombo: ""
    property var capKeys: []
    property var collision: null
    property string capError: ""

    readonly property var filtered: {
        const q = query.trim().toLowerCase();
        const out = [];
        for (const g of groups) {
            const rows = g.rows.filter(r => !q || (r.title + " " + g.name + " " + r.keys.join(" ")).toLowerCase().includes(q));
            if (rows.length) out.push({ name: g.name, rows: rows });
        }
        return out;
    }

    Component.onCompleted: load()
    Component.onDestruction: endCapture()

    function load() { lister.running = true; }

    Process {
        id: lister
        command: ["python3", page.script, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    if (d.error) { page.error = d.error; return; }
                    page.groups = d.groups;
                    page.hidden = d.hidden;
                    page.error = "";
                } catch (e) { page.error = I18n.t("Couldn't read the shortcuts"); }
            }
        }
    }

    // ---- capture ----
    // While recording, Hyprland would run the bound action instead of handing the
    // pressed key to this window, so switch to a submap with no binds and back.
    function beginCapture(row) {
        capId = row.id;
        capCurrent = row.combo;
        capCombo = ""; capKeys = []; collision = null; capError = "";
        Quickshell.execDetached(["hyprctl", "eval",
            "hl.define_submap(\"skycapture\", function() hl.bind(\"SUPER + CTRL + ALT + SHIFT + F12\", hl.dsp.no_op()) end)"]);
        submapOn.restart();
        giveUp.restart();
    }
    Timer { id: submapOn; interval: 120; onTriggered: if (page.capId) Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.submap(\"skycapture\")"]) }
    Timer { id: giveUp; interval: 30000; onTriggered: page.endCapture() }

    function endCapture() {
        const was = capId !== "";
        capId = ""; capCombo = ""; capKeys = []; collision = null; capError = "";
        submapOn.stop(); giveUp.stop();
        if (was) Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.submap(\"reset\")"]);
    }

    readonly property var named: ({
        [Qt.Key_Return]: "Return", [Qt.Key_Enter]: "KP_Enter", [Qt.Key_Space]: "space", [Qt.Key_Tab]: "Tab",
        [Qt.Key_Backtab]: "Tab", [Qt.Key_Backspace]: "BackSpace", [Qt.Key_Delete]: "Delete", [Qt.Key_Insert]: "Insert",
        [Qt.Key_Home]: "Home", [Qt.Key_End]: "End", [Qt.Key_PageUp]: "Page_Up", [Qt.Key_PageDown]: "Page_Down",
        [Qt.Key_Left]: "Left", [Qt.Key_Right]: "Right", [Qt.Key_Up]: "Up", [Qt.Key_Down]: "Down",
        [Qt.Key_Print]: "Print", [Qt.Key_Minus]: "minus", [Qt.Key_Equal]: "equal", [Qt.Key_Comma]: "comma",
        [Qt.Key_Period]: "period", [Qt.Key_Slash]: "slash", [Qt.Key_Semicolon]: "semicolon",
        [Qt.Key_Apostrophe]: "apostrophe", [Qt.Key_BracketLeft]: "bracketleft", [Qt.Key_BracketRight]: "bracketright",
        [Qt.Key_Backslash]: "backslash", [Qt.Key_QuoteLeft]: "grave",
        // Shift + digit arrives as a symbol (US layout)
        [Qt.Key_Exclam]: "1", [Qt.Key_At]: "2", [Qt.Key_NumberSign]: "3", [Qt.Key_Dollar]: "4", [Qt.Key_Percent]: "5",
        [Qt.Key_AsciiCircum]: "6", [Qt.Key_Ampersand]: "7", [Qt.Key_Asterisk]: "8", [Qt.Key_ParenLeft]: "9",
        [Qt.Key_ParenRight]: "0", [Qt.Key_Underscore]: "minus", [Qt.Key_Plus]: "equal"
    })

    function keyName(k) {
        if (k >= Qt.Key_A && k <= Qt.Key_Z) return String.fromCharCode(k);
        if (k >= Qt.Key_0 && k <= Qt.Key_9) return String.fromCharCode(k);
        if (k >= Qt.Key_F1 && k <= Qt.Key_F12) return "F" + (k - Qt.Key_F1 + 1);
        return named[k] || "";
    }

    // Sets ev.accepted. A bare Enter saves the combo already recorded (Esc cancels);
    // other bare Tab/Space are left to the focus chain, as none is a valid shortcut alone.
    function onPressed(ev) {
        const bare = !(ev.modifiers & ~Qt.KeypadModifier);
        if (bare && (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) && capKeys.length) {
            ev.accepted = true;
            // with a collision only the "Replace and save" button confirms
            if (!capError && !busy && !collision) apply(["set", capId, capCombo]);
            return;
        }
        if (bare && [Qt.Key_Tab, Qt.Key_Backtab, Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space].includes(ev.key)) { ev.accepted = false; return; }
        ev.accepted = true;
        if (ev.key === Qt.Key_Escape && !(ev.modifiers & ~Qt.KeypadModifier)) { endCapture(); return; }
        const k = keyName(ev.key);
        if (!k) return;          // a lone modifier, or a key we cannot name
        const m = ev.modifiers;
        const mods = [];
        if (m & Qt.MetaModifier) mods.push("SUPER");
        if (m & Qt.ControlModifier) mods.push("CTRL");
        if (m & Qt.AltModifier) mods.push("ALT");
        if (m & Qt.ShiftModifier) mods.push("SHIFT");
        capKeys = mods.concat([k]);
        capCombo = capKeys.join("+");
        collision = null; capError = "";
        checker.command = ["python3", script, "check", capCombo, "--current", capCurrent];
        checker.running = false;
        checker.running = true;
    }

    Process {
        id: checker
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    if (d.error) page.capError = I18n.t(d.error);
                    else page.collision = d.collision;
                } catch (e) { page.capError = I18n.t("Couldn't check this shortcut"); }
            }
        }
    }

    // ---- save / reset ----
    function apply(args) {
        busy = true;
        writer.command = ["sh", "-c", "S=$1; shift; python3 \"$S\" \"$@\" && hyprctl reload", "sh", script].concat(args);
        writer.running = true;
    }
    Process {
        id: writer
        stdout: StdioCollector { id: wout }
        onExited: code => {
            page.busy = false;
            if (code !== 0) {
                let msg = "";
                try { msg = JSON.parse(wout.text).error; } catch (e) {}
                page.capError = msg ? I18n.t(msg) : I18n.t("Couldn't save the shortcut");
                if (!page.capId) page.error = page.capError;
                return;
            }
            page.endCapture();
            reloaded.restart();
        }
    }
    // hyprctl reload returns before the new binds are live
    Timer { id: reloaded; interval: 900; onTriggered: page.load() }

    headerRight: [
        Btn { icon: "refresh"; text: I18n.t("Refresh"); onClicked: page.load() }
    ]

    // ---- search ----
    Rectangle {
        width: parent.width
        height: 38
        radius: 19
        color: Theme.surface2
        border.width: find.activeFocus ? 2 : 0
        border.color: Theme.accent
        Icon { id: lens; x: 14; anchors.verticalCenter: parent.verticalCenter; text: "search"; color: Theme.muted }
        TextInput {
            id: find
            anchors.left: lens.right; anchors.leftMargin: 8
            anchors.right: parent.right; anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: page.query
            onTextEdited: page.query = text
            color: Theme.fg
            clip: true
            font.family: "Google Sans Flex"; font.pixelSize: 14
            Accessible.name: I18n.t("Search shortcuts")
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: !find.text
                text: I18n.t("Search shortcuts")
                color: Theme.muted
                font: find.font
            }
        }
    }

    Text {
        visible: page.error !== ""
        width: parent.width
        topPadding: 12
        text: page.error
        color: "#ffb4ab"
        font.family: "Google Sans Flex"; font.pixelSize: 13
    }

    Card {
        visible: page.filtered.length === 0 && page.error === ""
        SettingRow {
            icon: "keyboard_command_key"
            title: page.groups.length ? I18n.t("No shortcut matches your search") : I18n.t("Loading…")
        }
    }

    Repeater {
        model: page.filtered
        Column {
            required property var modelData
            width: parent.width
            Section { text: I18n.t(modelData.name) }
            Card {
                Repeater {
                    model: modelData.rows
                    ShortcutRow {
                        required property var modelData
                        required property int index
                        info: modelData
                        divider: index > 0
                        busy: page.busy
                        capturing: page.capId === modelData.id
                        capKeys: capturing ? page.capKeys : []
                        collision: capturing ? page.collision : null
                        error: capturing ? page.capError : ""
                        onChange: { if (page.capId) page.endCapture(); page.beginCapture(modelData); }
                        onCancel: page.endCapture()
                        onPressed: ev => page.onPressed(ev)
                        onSave: page.apply(["set", modelData.id, page.capCombo])
                        onReset: page.apply(["reset", modelData.id])
                    }
                }
            }
        }
    }

    Text {
        visible: page.hidden > 0 && page.error === ""
        width: parent.width
        topPadding: 16
        text: I18n.t("%1 more shortcuts are not shown (no name, or inside a submap).", page.hidden)
        color: Theme.muted
        font.family: "Google Sans Flex"; font.pixelSize: 12
    }
}
