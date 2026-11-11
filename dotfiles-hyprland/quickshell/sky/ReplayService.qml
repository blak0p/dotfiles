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

    // gpu-screen-recorder is installed (checked at startup, and again on enable
    // or save while it was missing).
    property bool available: false
    // The buffer is recording right now.
    readonly property bool active: rec.running
    property string lastClip: ""
    property string error: ""
    // Clips saved during this session; the gallery rescans when it changes.
    property int savedCount: 0

    signal saved(string path)

    function save() {
        if (!root.available) probe.running = true;
        if (!rec.running || !rec.processId) {
            IslandState.showClip("", !root.available ? I18n.t("gpu-screen-recorder is not installed")
                : root.enabled ? I18n.t("Replay is starting") : I18n.t("Replay is off"));
            return;
        }
        signaller.command = ["kill", "-USR1", String(rec.processId)];
        signaller.running = true;
    }
    function setEnabled(on) {
        // Installed after the shell started? Probe again so it starts now.
        if (!root.available) probe.running = true;
        IslandState.showClip("", on ? I18n.t("Instant replay on") : I18n.t("Instant replay off"),
            on ? "fiber_manual_record" : "videocam_off");
        setter.command = ["python3", root.script, "set", Config.userFile, "enabled", on ? "true" : "false"];
        setter.running = true;
    }
    function toggle() { setEnabled(!root.enabled); }

    // Clip actions (island pop and gallery).
    function play(path) { run(["xdg-open", path]); }
    function openFolder(path) { run(["xdg-open", path ? path.substring(0, path.lastIndexOf("/")) : (root.opts.dir || "")]); }
    function copy(path) {
        run(["sh", "-c", 'python3 "$1" uri "$2" | wl-copy --type text/uri-list', "sh", root.script, path]);
        IslandState.showClip(path, I18n.t("Copied to clipboard"), "content_copy");
    }
    function remove(path) {
        remover.command = ["python3", root.script, "delete", root.opts.dir || "~/Videos/Clips", path];
        remover.running = true;
        if (root.lastClip === path) root.lastClip = "";
        IslandState.showClip("", I18n.t("Clip deleted"), "delete");
    }
    function run(cmd) { Quickshell.execDetached(cmd); }

    function restart() {
        failures = 0;
        stopping = rec.running;
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
                    root.error = I18n.t("Could not build the recorder command");
                }
            }
        }
    }

    // Quick crashes (no permission for KMS capture, bad monitor...) retry a
    // few times, then give up and show the last stderr line on the page.
    property int failures: 0
    // An intentional stop (option change, disable) is not a crash.
    property bool stopping: false
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
                IslandState.showClip(p, I18n.t("Clip saved"), "check_circle");
                thumber.clip = p;
                thumber.command = ["python3", root.script, "thumb", p];
                thumber.running = true;
            }
        }
        stderr: SplitParser { onRead: (line) => { if (line.trim()) root.lastErr = line.trim(); } }
        onRunningChanged: running ? stable.restart() : stable.stop()
        onExited: (code) => {
            if (root.stopping) { root.stopping = false; return; }
            if (!root.enabled || !root.available || code === 0) return;
            root.failures++;
            root.error = root.lastErr || ("gpu-screen-recorder exited with code " + code);
            if (root.failures < 3) startDelay.restart();
        }
    }

    // A recorder that ran for a minute is healthy: forget older crashes.
    Timer { id: stable; interval: 60000; onTriggered: { root.failures = 0; root.error = ""; } }

    // Still of the last clip for the island pop.
    Process {
        id: thumber
        property string clip: ""
        stdout: StdioCollector {
            onStreamFinished: if (IslandState.clipPath === thumber.clip) IslandState.clipThumb = text.trim()
        }
    }

    Process { id: signaller }
    Process { id: remover; onExited: root.savedCount++ }
    Process { id: setter }
}
