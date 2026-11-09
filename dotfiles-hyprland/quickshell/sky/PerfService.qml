pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs

// CPU, RAM, AMD GPU and disk usage for the island Performance module.
// scripts/sys_stats.py prints one JSON sample per second; it only runs while
// `active` (set by island/CenterView.qml while the Performance tab shows).
Singleton {
    id: root

    property bool active: false
    property bool loaded: false

    property var cpu: ({ percent: 0, temp: null, ghz: null })
    property var mem: ({ used: 0, total: 0, percent: 0 })
    property var gpu: null
    property var disks: []
    property real readBps: 0
    property real writeBps: 0

    // Last samples (0..100) for the sparklines.
    readonly property int historyLen: 30
    property var cpuHist: []
    property var gpuHist: []
    property var memHist: []

    function push(list, v) {
        const out = list.concat([v]);
        return out.length > historyLen ? out.slice(out.length - historyLen) : out;
    }

    function gb(bytes) { return (bytes / 1073741824).toLocaleString(Qt.locale(), "f", 1); }
    function mbps(bytes) { return (bytes / 1048576).toLocaleString(Qt.locale(), "f", bytes < 10485760 ? 1 : 0) + " MB/s"; }
    function size(bytes) { return bytes >= 1099511627776 ? (bytes / 1099511627776).toLocaleString(Qt.locale(), "f", 1) + " TB" : Math.round(bytes / 1073741824) + " GB"; }

    function apply(s) {
        root.cpu = s.cpu;
        root.mem = s.mem;
        root.gpu = s.gpu;
        root.disks = s.disks || [];
        root.readBps = s.readBps || 0;
        root.writeBps = s.writeBps || 0;
        root.cpuHist = push(root.cpuHist, s.cpu.percent);
        root.memHist = push(root.memHist, s.mem.percent);
        if (s.gpu) root.gpuHist = push(root.gpuHist, s.gpu.percent);
        root.loaded = true;
    }

    Process {
        id: proc
        running: root.active
        command: ["python3", Quickshell.shellDir + "/scripts/sys_stats.py", "--interval", "1"]
        stdout: SplitParser {
            onRead: line => {
                try { root.apply(JSON.parse(line)); }
                catch (e) { console.warn("sys_stats: bad sample", e); }
            }
        }
    }
}
