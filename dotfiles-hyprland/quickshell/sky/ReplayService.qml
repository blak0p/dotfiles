pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.island

// Instant replay (Medal-style clips). While enabled, gpu-screen-recorder keeps
// the last N seconds of the shell's monitor in RAM; save() sends it SIGUSR1 and
// it writes a clip to the clips folder, printing the path on stdout.
// Options: the "replay" object of ~/.config/sky/settings.json (Config.user),
// written by scripts/sky_replay.py from the settings page (ReplayPage.qml).
Singleton {
    id: root

    readonly property string script: Quickshell.shellDir + "/scripts/sky_replay.py"
    readonly property var opts: Config.user.replay && typeof Config.user.replay === "object" ? Config.user.replay : ({})
    readonly property bool enabled: opts.enabled === true
    readonly property string optsKey: JSON.stringify(opts) + "|" + Config.screen

    // gpu-screen-recorder is installed (checked once at startup and on enable).
    property bool available: false
    // The buffer is recording right now.
    readonly property bool active: rec.running
    property string lastClip: ""
    property string error: ""
    // Clips saved during this session; the gallery rescans when it changes.
    property int savedCount: 0

    signal saved(string path)

    function save() {
        if (!rec.running || !rec.processId) {
            IslandState.showClip("", !root.available ? I18n.t("gpu-screen-recorder is not installed")
                : root.enabled ? I18n.t("Replay is starting") : I18n.t("Replay is off"));
            return;
        }
        signaller.command = ["kill", "-USR1", String(rec.processId)];
        signaller.running = true;
    }
    function setEnabled(on) {
        setter.command = ["python3", root.script, "set", Config.userFile, "enabled", on ? "true" : "false"];
        setter.running = true;
    }
    function toggle() { setEnabled(!root.enabled); }

    function restart() {
        failures = 0;
        rec.running = false;
        if (root.enabled && root.available) startDelay.restart();
    }

    onEnabledChanged: restart()
    onOptsKeyChanged: restart()
    onAvailableChanged: restart()

    Process {
        id: probe
        running: true
        command: ["sh", "-c", "command -v gpu-screen-recorder"]
        onExited: (code) => root.available = code === 0
    }

    // Small delay so several option writes in a row start the recorder once.
    Timer { id: startDelay; interval: 400; onTriggered: builder.running = true }

    Process {
        id: builder
        command: ["python3", root.script, "cmd", Config.userFile, Config.screen]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    rec.command = JSON.parse(text);
                    root.error = "";
                    rec.running = true;
                } catch (e) {
                    root.error = "bad recorder command";
                }
            }
        }
    }

    // Quick crashes (no permission for KMS capture, bad monitor...) retry a
    // few times, then give up and show the last stderr line on the page.
    property int failures: 0
    property string lastErr: ""
    Process {
        id: rec
        stdout: SplitParser {
            onRead: (line) => {
                const p = line.trim();
                if (!/\.(mp4|mkv|webm|mov)$/i.test(p)) return;
                root.lastClip = p;
                root.savedCount++;
                root.saved(p);
                IslandState.showClip(p, I18n.t("Clip saved"));
            }
        }
        stderr: SplitParser { onRead: (line) => { if (line.trim()) root.lastErr = line.trim(); } }
        onExited: (code) => {
            if (!root.enabled || !root.available || code === 0) return;
            root.failures++;
            root.error = root.lastErr || ("gpu-screen-recorder exited with code " + code);
            if (root.failures < 3) startDelay.restart();
        }
    }

    Process { id: signaller }
    Process { id: setter }
}
