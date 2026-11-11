import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import "displayLayout.js" as Layout

// Displays: a layout stage with every monitor (click to select), and for the
// selected one resolution, refresh rate and scale. Apply goes live through
// `hyprctl eval`, then asks "Keep these settings?" for 15 s and reverts on its
// own; only a confirmation rewrites the user layer file
// ~/.config/sky/hypr/monitors.lua (scripts/sky_monitors.py, which keeps a .bak
// and every field it does not change). Monitors can be dragged on the stage
// (edges snap, always touching); the new positions go through the same
// Apply / Keep / Revert flow as mode and scale.
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
    // Pending positions {name: {x, y}} in logical px (empty = as live) and the
    // drag in progress ({name, x, y} snapped preview, or null).
    property var layout: ({})
    property var dragging: null

    readonly property string script: Qt.resolvedUrl("../scripts/sky_monitors.py").toString().replace("file://", "")
    readonly property string file: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/sky/hypr/monitors.lua"
    readonly property int snapThreshold: 80
    readonly property var scales: [1, 1.25, 1.5, 2]
    readonly property var cur: monitors.find(m => m.name === selected) || null
    readonly property var groups: cur ? groupModes(cur.availableModes) : []
    readonly property var rates: {
        const g = groups.find(x => x.res === dRes);
        return g ? g.rates : [];
    }
    readonly property bool moved: monitors.some(m => { const p = posOf(m); return p.x !== m.x || p.y !== m.y; })
    readonly property bool dirty: cur !== null && (moved || dRes !== curRes(cur) || Math.abs(dRate - curRate(cur)) > 0.005 || Math.abs(dScale - cur.scale) > 0.001)

    function posOf(m) { return layout[m.name] || { x: m.x, y: m.y }; }
    function sizeOf(m) { return Layout.logicalSize(m); }
    function rectOf(m) { const p = posOf(m), s = sizeOf(m); return { x: p.x, y: p.y, w: s.w, h: s.h }; }
    function othersOf(name) { return monitors.filter(m => m.name !== name).map(m => rectOf(m)); }
    function allPositions() {
        const out = {};
        for (const m of monitors) { const p = posOf(m); out[m.name] = { x: p.x, y: p.y }; }
        return out;
    }
    // Commit a snapped position for NAME, normalised so the top-left is 0x0.
    function setPos(name, x, y) {
        const all = allPositions();
        all[name] = { x: x, y: y };
        layout = Layout.normalize(all);
    }
    function nudge(name, dir) {
        const m = monitors.find(x => x.name === name);
        if (!m || pending) return;
        const p = Layout.nudge(sizeOf(m), othersOf(name), posOf(m), dir, snapThreshold);
        setPos(name, p.x, p.y);
    }
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
        layout = {};
        dragging = null;
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
    Component.onDestruction: if (pending && confirming) Quickshell.execDetached(liveCmd(pending.prev))

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

    // Live apply of ENTRIES [{name, mode, scale, pos}]: the script builds each
    // hl.monitor call (keeping bitdepth etc. from monitors.lua) and hyprctl eval
    // runs it; hyprctl prints "ok" on success. Stops at the first failure.
    function liveCmd(entries) {
        const args = [];
        for (const e of entries) args.push(e.name, e.mode, String(e.scale), e.pos);
        return ["sh", "-c",
            "S=$1; F=$2; shift 2; while [ $# -ge 4 ]; do " +
            "lua=$(python3 \"$S\" eval \"$F\" \"$1\" \"$2\" \"$3\" \"$4\") || exit 2; " +
            "out=$(hyprctl eval \"$lua\") || exit 3; [ \"$out\" = ok ] || exit 4; shift 4; done",
            "sh", script, file].concat(args);
    }
    Process {
        id: applier
        property bool isRevert: false
        onExited: code => {
            if (code !== 0) {
                if (!applier.isRevert) {
                    // a later monitor may have failed after an earlier one applied
                    const p = page.pending;
                    page.clearPending();
                    if (p) Quickshell.execDetached(page.liveCmd(p.prev));
                }
                page.error = I18n.t(applier.isRevert ? "Couldn't restore the previous mode" : "Couldn't apply this mode");
                page.load();
            } else {
                reload.restart();
            }
        }
    }
    function live(entries, isRevert) {
        applier.isRevert = !!isRevert;
        applier.command = liveCmd(entries);
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
    function posStr(p) { return p.x + "x" + p.y; }
    // Called after every monitor reload: shows the prompt only if the compositor
    // really runs every requested mode, scale and position.
    function checkVerify() {
        const v = verify;
        if (!v) return;
        verify = null;
        const ok = v.every(t => {
            const m = monitors.find(x => x.name === t.name);
            return m && curRes(m) === t.res && Math.abs(curRate(m) - t.rate) < 0.02
                && Math.abs(m.scale - t.scale) < 0.01 && m.x === t.x && m.y === t.y;
        });
        if (ok) {
            confirming = true;
            countdown = 15;
            tick.restart();
        } else {
            const p = pending;
            clearPending();
            if (p) live(p.prev, true);
            error = I18n.t("Couldn't apply this mode");
        }
    }

    function apply() {
        error = "";
        // Final sizes: the selected monitor may change resolution/scale, which
        // changes its logical size, so its position is snapped again.
        const sel = cur;
        const mode = modeStr(dRes, dRate);
        const g = /^(\d+)x(\d+)$/.exec(dRes);
        const selSize = Layout.logicalSize({ width: +g[1], height: +g[2], scale: dScale, transform: sel.transform });
        const all = allPositions();
        const others = monitors.filter(m => m.name !== sel.name).map(m => rectOf(m));
        if (selSize.w !== sizeOf(sel).w || selSize.h !== sizeOf(sel).h) {
            const p = Layout.snap(selSize, others, posOf(sel), snapThreshold);
            all[sel.name] = p;
        }
        const final = Layout.normalize(all);
        const prev = [], targets = [], tv = [];
        for (const m of monitors) {
            const isSel = m.name === sel.name;
            const f = final[m.name];
            if (!isSel && f.x === m.x && f.y === m.y) continue;
            prev.push({ name: m.name, mode: modeStr(curRes(m), curRate(m)), scale: m.scale, pos: m.x + "x" + m.y });
            const t = { name: m.name, mode: isSel ? mode : modeStr(curRes(m), curRate(m)), scale: isSel ? dScale : m.scale, pos: posStr(f) };
            targets.push(t);
            tv.push({ name: m.name, res: isSel ? dRes : curRes(m), rate: isSel ? dRate : curRate(m), scale: t.scale, x: f.x, y: f.y });
        }
        pending = { prev: prev, targets: targets };
        verify = tv;
        live(targets, false);
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
        saver.command = ["python3", script, "save", file, "--json", JSON.stringify(p.targets.map(t => ({
            output: t.name, mode: t.mode, scale: t.scale, position: t.pos })))];
        saver.running = true;
    }
    function revert() {
        tick.stop();
        const p = pending;
        confirming = false;
        verify = null;
        pending = null;
        if (p) live(p.prev, true);
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
            height: 280
            // World bounds (with room around to drag into); frozen while dragging
            // so the monitor under the mouse does not move under the cursor.
            readonly property var liveView: {
                const rs = page.monitors.map(m => page.rectOf(m));
                if (!rs.length) return { minX: 0, minY: 0, k: 1, offX: 0, offY: 0 };
                const padX = Math.max(...rs.map(r => r.w)) * 0.3, padY = Math.max(...rs.map(r => r.h)) * 0.3;
                const minX = Math.min(...rs.map(r => r.x)) - padX, minY = Math.min(...rs.map(r => r.y)) - padY;
                const maxX = Math.max(...rs.map(r => r.x + r.w)) + padX, maxY = Math.max(...rs.map(r => r.y + r.h)) + padY;
                const k = Math.min((width - 24) / Math.max(1, maxX - minX), (height - 24) / Math.max(1, maxY - minY));
                return { minX: minX, minY: minY, k: k, offX: (width - (maxX - minX) * k) / 2, offY: (height - (maxY - minY) * k) / 2 };
            }
            property var frozen: null
            readonly property var view: frozen || liveView

            Repeater {
                model: page.monitors
                Rectangle {
                    id: mon
                    required property var modelData
                    readonly property bool on: modelData.name === page.selected
                    readonly property bool isDrag: page.dragging !== null && page.dragging.name === modelData.name
                    readonly property var pos: isDrag ? page.dragging : page.posOf(modelData)
                    readonly property var sz: page.sizeOf(modelData)
                    x: stage.view.offX + (pos.x - stage.view.minX) * stage.view.k
                    y: stage.view.offY + (pos.y - stage.view.minY) * stage.view.k
                    z: isDrag ? 2 : 0
                    width: sz.w * stage.view.k - 4
                    height: sz.h * stage.view.k - 4
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
                    Keys.onLeftPressed: page.nudge(modelData.name, "left")
                    Keys.onRightPressed: page.nudge(modelData.name, "right")
                    Keys.onUpPressed: page.nudge(modelData.name, "up")
                    Keys.onDownPressed: page.nudge(modelData.name, "down")
                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        cursorShape: page.pending ? Qt.ArrowCursor : (drag ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
                        property bool drag: false
                        property real gx: 0   // grab offset inside the monitor, logical px
                        property real gy: 0
                        onPressed: ev => {
                            mon.forceActiveFocus();
                            page.select(mon.modelData.name);
                            if (page.pending) return;
                            const p = mapToItem(stage, ev.x, ev.y);
                            stage.frozen = stage.liveView;
                            gx = (p.x - stage.view.offX) / stage.view.k + stage.view.minX - mon.pos.x;
                            gy = (p.y - stage.view.offY) / stage.view.k + stage.view.minY - mon.pos.y;
                            drag = true;
                            page.dragging = { name: mon.modelData.name, x: mon.pos.x, y: mon.pos.y };
                        }
                        onPositionChanged: ev => {
                            if (!drag) return;
                            const p = mapToItem(stage, ev.x, ev.y);
                            const wx = (p.x - stage.view.offX) / stage.view.k + stage.view.minX - gx;
                            const wy = (p.y - stage.view.offY) / stage.view.k + stage.view.minY - gy;
                            const s = Layout.snap(mon.sz, page.othersOf(mon.modelData.name), { x: wx, y: wy }, page.snapThreshold);
                            page.dragging = { name: mon.modelData.name, x: s.x, y: s.y };
                        }
                        onReleased: finish()
                        onCanceled: finish()
                        function finish() {
                            if (!drag) return;
                            drag = false;
                            const d = page.dragging;
                            page.dragging = null;
                            stage.frozen = null;
                            if (d) page.setPos(d.name, d.x, d.y);
                        }
                    }
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
                            text: mon.pos.x + ", " + mon.pos.y
                            visible: mon.isDrag
                            color: Theme.accent
                            font.family: "Google Sans Flex"; font.pixelSize: 12; font.weight: Font.DemiBold
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
            visible: page.monitors.length > 0
            divider: true
            icon: "open_with"
            title: I18n.t("Position")
            sub: page.cur ? page.posOf(page.cur).x + ", " + page.posOf(page.cur).y + " · " + I18n.t("Drag a monitor to move it, or use the arrow keys") : ""
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
