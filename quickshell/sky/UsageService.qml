pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs

// AI plan usage (Claude, Codex, Antigravity, ...) through the CodexBar CLI.
// scripts/fetch_usage.py queries every provider in Config.usageProviders and
// returns normalized windows; a failing provider keeps its row with an error.
// Refreshes every Config.usageIdleMs, and every Config.usageOpenMs while the
// usage page of the island is open.
Singleton {
    id: root

    // False when the `codexbar` CLI is not installed.
    property bool available: true
    property bool loading: false
    property bool loaded: false
    property var providers: []
    property real updatedAt: 0
    // Ticks every minute so "resets in" texts stay current between fetches.
    property real now: Date.now()

    // Set by island/CenterView.qml while its usage page is showing.
    property bool pageOpen: false
    onPageOpenChanged: if (pageOpen) refresh()

    // Lowest remaining percentage across every healthy window (-1 = no data).
    readonly property real lowestLeft: {
        let low = -1;
        for (const p of providers)
            for (const w of p.windows || []) {
                const left = 100 - w.usedPercent;
                if (low < 0 || left < low) low = left;
            }
        return low;
    }

    function refresh() {
        if (fetchProc.running) return;
        root.loading = true;
        fetchProc.running = true;
    }

    function resetsIn(iso) {
        if (!iso) return "";
        const ms = new Date(iso).getTime() - root.now;
        if (isNaN(ms)) return "";
        if (ms <= 0) return "resetting";
        const mins = Math.floor(ms / 60000);
        const d = Math.floor(mins / 1440), h = Math.floor((mins % 1440) / 60), m = mins % 60;
        if (d > 0) return d + "d " + h + "h";
        if (h > 0) return h + "h " + m + "m";
        return m + "m";
    }

    function agoText() {
        if (!root.updatedAt) return "";
        const mins = Math.floor((root.now - root.updatedAt) / 60000);
        return mins < 1 ? "just now" : mins + "m ago";
    }

    Process {
        id: fetchProc
        command: ["python3", Quickshell.shellDir + "/scripts/fetch_usage.py"].concat(Config.usageProviders)
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                try {
                    const data = JSON.parse(text);
                    root.available = data.available !== false;
                    root.providers = data.providers || [];
                    root.updatedAt = Date.now();
                    root.now = root.updatedAt;
                    root.loaded = true;
                } catch (e) {
                    console.warn("sky/UsageService: bad fetch_usage output:", e);
                }
            }
        }
        onExited: root.loading = false
    }

    // Watchdog: providers time out after 25 s each, in parallel.
    Timer {
        interval: 40000
        running: fetchProc.running
        onTriggered: fetchProc.running = false
    }

    Timer {
        interval: root.pageOpen ? Config.usageOpenMs : Config.usageIdleMs
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.now = Date.now()
    }
}
