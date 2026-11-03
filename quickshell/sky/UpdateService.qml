pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Background update tracking for Pacman, AUR and Homebrew.
Singleton {
    id: root

    property bool isChecking: false
    // Updater terminal is open.
    property bool isUpdating: false
    // Re-checking counts right after the updater terminal closed.
    property bool isVerifying: false
    // Short-lived "all done" flash after a successful update round.
    property bool justFinished: false
    property int pacmanCount: 0
    property int aurCount: 0
    property int brewCount: 0
    property int totalCount: 0
    property int lastChecked: 0

    readonly property string home: Quickshell.env("HOME")

    function applyCache(txt) {
        try {
            const data = JSON.parse(txt);
            if (!data) return;

            if (data.pending) {
                root.totalCount = data.pending.total || 0;
                root.pacmanCount = data.pending.pacman || 0;
                root.aurCount = data.pending.aur || 0;
                root.brewCount = data.pending.brew || 0;
            }

            if (data.checked_at) {
                root.lastChecked = data.checked_at;
            }
        } catch (e) {
            console.warn("sky/UpdateService: error parsing updates.json:", e);
        }
    }

    function checkUpdates() {
        if (root.isChecking) return;
        root.isChecking = true;
        fetchProc.running = false;
        fetchProc.running = true;
    }

    function applyAll() {
        if (root.isUpdating) return;
        root.justFinished = false;
        root.isUpdating = true;
        updateProc.running = true;
    }

    // Runs cachy-update and brew update unmodified in a separate terminal;
    // the process lives as long as that terminal window.
    Process {
        id: updateProc
        command: ["kitty", "--class", "kitty-floating", "-T", "System Update",
                  "bash", Quickshell.shellDir + "/scripts/apply_updates.sh"]
        onExited: {
            root.isUpdating = false;
            root.isVerifying = true;
            root.isChecking = false;
            fetchProc.running = false;
            root.checkUpdates();
        }
    }

    Timer {
        id: finishedTimer
        interval: 3500
        onTriggered: root.justFinished = false
    }

    FileView {
        path: root.home + "/.local/state/sky/updates.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.applyCache(text())
    }

    Process {
        id: fetchProc
        command: ["python3", Quickshell.shellDir + "/scripts/fetch_updates.py"]
        // Apply the fresh result directly so the pill never lags behind the file watcher.
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim()) root.applyCache(text);
                if (root.isVerifying) {
                    root.isVerifying = false;
                    if (root.totalCount === 0) {
                        root.justFinished = true;
                        finishedTimer.restart();
                    }
                }
            }
        }
        onExited: function(code) {
            root.isChecking = false;
        }
    }

    // Periodic check every hour
    Timer {
        id: periodicTimer
        interval: 3600000
        running: true
        repeat: true
        onTriggered: root.checkUpdates()
    }
}
