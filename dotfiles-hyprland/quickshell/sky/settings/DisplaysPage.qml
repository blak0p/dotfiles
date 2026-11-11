import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs

// Displays: a layout stage with every monitor (click to select), and for the
// selected one resolution, refresh rate and scale. Apply goes live through
// `hyprctl eval`, then asks "Keep these settings?" for 15 s and reverts on its
// own; only a confirmation rewrites hypr/monitors.lua (scripts/sky_monitors.py,
// which keeps a .bak and every field it does not change).
Page {
    id: page
    title: I18n.t("Displays")

    property var monitors: []
    property string selected: ""
    // Draft of the selected monitor: "WxH", rate (Hz) and scale.
    property string dRes: ""
    property real dRate: 0
    property real dScale: 1
    // Live state before an unconfirmed apply (null when nothing is pending).
    property var pending: null
    property int countdown: 0
    // True once the applied mode was confirmed live (the 15 s prompt is shown).
    property bool confirming: false
    // Requested mode/scale being verified after hyprctl eval; null otherwise.
    property var verify: null
    property string error: ""
    property bool identifying: false

    readonly property string script: Qt.resolvedUrl("../scripts/sky_monitors.py").toString().replace("file://", "")
    readonly property string file: Quickshell.env("HOME") + "/.config/hypr/monitors.lua"
    readonly property var scales: [1, 1.25, 1.5, 2]
    readonly property var cur: monitors.find(m => m.name === selected) || null
    readonly property var groups: cur ? groupModes(cur.availableModes) : []
    readonly property var rates: {
        const g = groups.find(x => x.res === dRes);
        return g ? g.rates : [];
    }
    readonly property bool dirty: cur !== null && (dRes !== curRes(cur) || Math.abs(dRate - curRate(cur)) > 0.005 || Math.abs(dScale - cur.scale) > 0.001)

    function groupModes(modes) {
        const seen = {};
        for (const m of modes || []) {
            const g = /^(\d+)x(\d+)@([\d.]+)Hz$/.exec(m);
            if (!g) continue;
            const res = g[1] + "x" + g[2], rate = Math.round(parseFloat(g[3]) * 100) / 100;
            (seen[res] = seen[res] || []);
            if (!seen[res].includes(rate)) seen[res].push(rate);
        }
        return Object.keys(seen)
            .sort((a, b) => parseInt(b) - parseInt(a) || parseInt(b.split("x")[1]) - parseInt(a.split("x")[1]))
            .map(res => ({ res: res, rates: seen[res].sort((a, b) => b - a) }));
    }
    function curRes(m) { return m.width + "x" + m.height; }
    function curRate(m) { return Math.round(m.refreshRate * 100) / 100; }
    function fmtRate(r) { return String(Math.round(r * 100) / 100); }
    function modeStr(res, rate) { return res + "@" + fmtRate(rate); }

    function load() { list.running = true; }
    function resetDraft() {
        if (!cur) return;
        dRes = curRes(cur); dRate = curRate(cur); dScale = cur.scale;
    }
    function select(name) {
        if (pending) return;
        error = "";
        selected = name;
        resetDraft();
    }
    function pickRes(res) {
        dRes = res;
        const g = groups.find(x => x.res === res);
        if (g && !g.rates.some(r => Math.abs(r - dRate) < 0.005)) dRate = g.rates[0];
    }

    Component.onCompleted: load()
    Component.onDestruction: if (pending && confirming) {
        const p = pending;
        Quickshell.execDetached(liveCmd(p.name, p.mode, p.scale, p.pos));
    }

    Process {
        id: list
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let arr = [];
                try { arr = JSON.parse(text).filter(m => !m.disabled); } catch (e) {}
                arr.sort((a, b) => a.x - b.x);
                page.monitors = arr;
                if (!arr.some(m => m.name === page.selected))
                    page.selected = (arr.find(m => m.name === Config.screen) || arr[0] || { name: "" }).name;
                if (!page.pending) page.resetDraft();
                page.checkVerify();
            }
        }
    }

    // Live apply: the script builds the hl.monitor call (keeping bitdepth etc.
    // from monitors.lua) and hyprctl eval runs it; hyprctl prints "ok" on success.
    function liveCmd(output, mode, scale, position) {
        return ["sh", "-c",
            "lua=$(python3 \"$1\" eval \"$2\" \"$3\" \"$4\" \"$5\" \"$6\") || exit 2; " +
            "out=$(hyprctl eval \"$lua\") || exit 3; [ \"$out\" = ok ] || exit 4",
            "sh", script, file, output, mode, String(scale), position];
    }
    Process {
        id: applier
        property bool isRevert: false
        onExited: code => {
            if (code !== 0) {
                if (!applier.isRevert) { page.clearPending(); }
                page.error = I18n.t(applier.isRevert ? "Couldn't restore the previous mode" : "Couldn't apply this mode");
                page.load();
            } else {
                reload.restart();
            }
        }
    }
    function live(output, mode, scale, position, isRevert) {
        applier.isRevert = !!isRevert;
        applier.command = liveCmd(output, mode, scale, position);
        applier.running = true;
    }
    Timer { id: reload; interval: 900; onTriggered: page.load() }

    function clearPending() {
        tick.stop();
        verify = null;
        confirming = false;
        pending = null;
        resetDraft();
    }
    // Called after every monitor reload: shows the prompt only if the compositor
    // really runs the requested mode and scale.
    function checkVerify() {
        const v = verify;
        if (!v) return;
        verify = null;
        const m = monitors.find(x => x.name === v.name);
        if (m && curRes(m) === v.res && Math.abs(curRate(m) - v.rate) < 0.02 && Math.abs(m.scale - v.scale) < 0.01) {
            confirming = true;
            countdown = 15;
            tick.restart();
        } else {
            clearPending();
            error = I18n.t("Couldn't apply this mode");
        }
    }

    function apply() {
        const m = cur;
        error = "";
        pending = { name: m.name, mode: modeStr(curRes(m), curRate(m)), scale: m.scale, pos: m.x + "x" + m.y };
        verify = { name: m.name, res: dRes, rate: dRate, scale: dScale };
        live(m.name, modeStr(dRes, dRate), dScale, pending.pos, false);
    }
    Process {
        id: saver
        onExited: code => {
            if (code !== 0) page.error = I18n.t("Couldn't save the settings");
            reload.restart();
        }
    }
    function keep() {
        tick.stop();
        const p = pending;
        confirming = false;
        pending = null;
        saver.command = ["python3", script, "save", file, p.name, modeStr(dRes, dRate), String(dScale), p.pos];
        saver.running = true;
    }
    function revert() {
        tick.stop();
        const p = pending;
        confirming = false;
        verify = null;
        pending = null;
        if (p) live(p.name, p.mode, p.scale, p.pos, true);
        resetDraft();
    }
    Timer {
        id: tick
        interval: 1000
        repeat: true
        onTriggered: { page.countdown--; if (page.countdown <= 0) page.revert(); }
    }

    // Name of every monitor, big on its own screen for a moment.
    Timer { id: idTimer; interval: 2500; onTriggered: page.identifying = false }
    Loader {
        active: page.identifying
        sourceComponent: Variants {
            model: Quickshell.screens
            PanelWindow {
                required property var modelData
                screen: modelData
                color: "transparent"
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "sky-identify"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                anchors { top: true; left: true }
                margins { top: 60; left: 60 }
                implicitWidth: tag.width
                implicitHeight: tag.height
                Rectangle {
                    id: tag
                    width: lbl.implicitWidth + 64
                    height: lbl.implicitHeight + 40
                    radius: 28
                    color: Theme.accent
                    Text {
                        id: lbl
                        anchors.centerIn: parent
                        text: modelData.name
                        color: Theme.accentText
                        font.family: "Google Sans Flex"; font.pixelSize: 48; font.weight: Font.Bold
                    }
                }
            }
        }
    }

    headerRight: [
        Btn {
            icon: "badge"
            text: I18n.t("Identify")
            onClicked: { page.identifying = true; idTimer.restart(); }
        }
    ]

    // ---- Layout ----
    Section { text: I18n.t("Layout") }
    Card {
        Item {
            id: stage
            width: parent.width
            height: 200
            readonly property real minX: Math.min(...page.monitors.map(m => m.x), 0)
            readonly property real minY: Math.min(...page.monitors.map(m => m.y), 0)
            readonly property real maxX: Math.max(...page.monitors.map(m => m.x + m.width / m.scale), 1)
            readonly property real maxY: Math.max(...page.monitors.map(m => m.y + m.height / m.scale), 1)
            readonly property real k: Math.min((width - 48) / Math.max(1, maxX - minX), (height - 40) / Math.max(1, maxY - minY))
            readonly property real offX: (width - (maxX - minX) * k) / 2
            readonly property real offY: (height - (maxY - minY) * k) / 2

            Repeater {
                model: page.monitors
                Rectangle {
                    id: mon
                    required property var modelData
                    readonly property bool on: modelData.name === page.selected
                    x: stage.offX + (modelData.x - stage.minX) * stage.k
                    y: stage.offY + (modelData.y - stage.minY) * stage.k
                    width: modelData.width / modelData.scale * stage.k - 4
                    height: modelData.height / modelData.scale * stage.k - 4
                    radius: 12
                    color: on ? Qt.alpha(Theme.accent, 0.18) : Theme.surface2
                    border.width: on || activeFocus ? 2 : 1
                    border.color: on ? Theme.accent : Theme.outline
                    activeFocusOnTab: true
                    Accessible.role: Accessible.RadioButton
                    Accessible.name: modelData.name
                    Accessible.checked: on
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Keys.onReturnPressed: page.select(modelData.name)
                    Keys.onSpacePressed: page.select(modelData.name)
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.select(mon.modelData.name) }
                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: mon.modelData.name
                            color: Theme.fg
                            font.family: "Google Sans Flex"; font.pixelSize: 14; font.weight: Font.DemiBold
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: page.curRes(mon.modelData).replace("x", "×") + " · " + Math.round(page.curRate(mon.modelData)) + " Hz"
                            color: Theme.muted
                            font.family: "Google Sans Flex"; font.pixelSize: 11
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: mon.modelData.name === Config.screen
                            text: I18n.t("Primary")
                            color: Theme.accent
                            font.family: "Google Sans Flex"; font.pixelSize: 11; font.weight: Font.DemiBold
                        }
                    }
                }
            }
        }
        SettingRow {
            visible: page.monitors.length === 0
            icon: "desktop_windows"
            title: I18n.t("No displays found")
        }
    }

    // ---- Selected monitor ----
    Section {
        visible: page.cur !== null
        text: page.cur ? page.cur.name + (page.cur.name === Config.screen ? " · " + I18n.t("Primary") : "") : ""
    }
    Card {
        visible: page.cur !== null
        SettingRow {
            title: I18n.t("Resolution")
            sub: page.cur ? [page.cur.make, page.cur.model].filter(x => x).join(" ") : ""
            Select {
                enabled: !page.pending
                model: page.groups.map(g => g.res.replace("x", "×"))
                currentIndex: page.groups.findIndex(g => g.res === page.dRes)
                onActivated: i => page.pickRes(page.groups[i].res)
            }
        }
        SettingRow {
            divider: true
            title: I18n.t("Refresh rate")
            Select {
                enabled: !page.pending
                model: page.rates.map(r => page.fmtRate(r) + " Hz")
                currentIndex: page.rates.findIndex(r => Math.abs(r - page.dRate) < 0.005)
                onActivated: i => page.dRate = page.rates[i]
            }
        }
        SettingRow {
            divider: true
            title: I18n.t("Scale")
            Select {
                enabled: !page.pending
                model: page.scales.map(s => Math.round(s * 100) + " %")
                currentIndex: page.scales.findIndex(s => Math.abs(s - page.dScale) < 0.001)
                placeholder: Math.round(page.dScale * 100) + " %"
                onActivated: i => page.dScale = page.scales[i]
            }
        }
    }

    // ---- Apply / confirm ----
    Card {
        visible: page.error !== ""
        SettingRow {
            icon: "error"
            title: page.error
        }
    }
    Section { visible: page.confirming; text: I18n.t("Confirm") }
    Card {
        visible: page.confirming
        SettingRow {
            current: true
            icon: "timer"
            title: I18n.t("Keep these settings?")
            sub: I18n.t("Reverting in %1 s", page.countdown)
            Btn { text: I18n.t("Revert"); onClicked: page.revert() }
            Btn { primary: true; text: I18n.t("Keep"); onClicked: page.keep() }
        }
    }
    Row {
        visible: page.pending === null && page.cur !== null
        anchors.right: parent ? parent.right : undefined
        topPadding: 18
        spacing: 10
        Btn { text: I18n.t("Revert"); enabled: page.dirty; onClicked: page.resetDraft() }
        Btn { primary: true; text: I18n.t("Apply"); enabled: page.dirty; onClicked: page.apply() }
    }
}
