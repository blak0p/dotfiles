//@ pragma UseQApplication
// QApplication mode is required for the tray's QsMenuAnchor (native menus).
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs
import qs.island

ShellRoot {
    Variants {
        // Only the configured monitor gets the shell.
        model: {
            const main = Quickshell.screens.filter(s => s.name === Config.screen);
            return main.length ? main : Quickshell.screens;
        }
        Scope {
            id: perScreen
            required property var modelData
            ScreenFrame { modelData: perScreen.modelData }
            Island { screen: perScreen.modelData }
            MiniToast { screen: perScreen.modelData }
        }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { ShellState.toggleLauncher(); }
        function open(): void { ShellState.openLauncher(); }
        function close(): void { ShellState.closeLauncher(); }
    }

    // Bound in Hyprland as hl.dsp.global("quickshell:launcherToggle").
    GlobalShortcut {
        name: "launcherToggle"
        description: "Toggle the sky launcher"
        onPressed: ShellState.toggleLauncher()
    }

    // qs -c sky ipc call island toggle|open|close|clear|dnd|update|state, or: island page wifi
    IpcHandler {
        target: "island"
        function toggle(): void { IslandState.toggleCenter(); }
        function open(): void { IslandState.openCenter("notifs"); }
        // notifs | wifi | bluetooth | sound | power | usage
        function page(name: string): void { IslandState.togglePage(name); }
        function close(): void { IslandState.closeCenter(); }
        function tray(): void { IslandState.toggleTray(); }
        function clear(): void { Notifs.clearAll(); }
        function dnd(): void { Notifs.dnd = !Notifs.dnd; }
        function update(): void { UpdateService.applyAll(); }
        function state(): string {
            return JSON.stringify({ mode: IslandState.mode, queue: Notifs.queue.length, unread: Notifs.unread,
                history: Notifs.list.length, hovered: Notifs.hovered, dnd: Notifs.dnd, osd: IslandState.osdVisible, fullscreen: IslandState.fullscreen });
        }
    }
}
