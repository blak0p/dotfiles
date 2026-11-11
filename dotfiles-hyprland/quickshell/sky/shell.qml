//@ pragma UseQApplication
// QApplication mode is required for the tray's QsMenuAnchor (native menus).
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs
import qs.island
import qs.wallpaper
import qs.settings

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
            // Top space reserve for the pills; the launcher and the dock-free
            // frame live in the island overlay.
            Reserve { screen: perScreen.modelData; edge: "top"; zone: Config.barHeight }
            Island { screen: perScreen.modelData }
            MiniToast { screen: perScreen.modelData }
        }
    }

    // Our polkit agent (admin password dialog).
    PolkitDialog {}

    // Settings window (Super+I), replaces KDE System Settings.
    SettingsWindow {}

    // qs -c sky ipc call settings toggle|close, or: settings open wifi
    IpcHandler {
        target: "settings"
        function toggle(): void { SettingsState.toggle(""); }
        // wifi | bluetooth | displays | sound | appearance | keyboard | shortcuts | replay | time | apps
        function open(page: string): void { SettingsState.open(page); }
        function close(): void { SettingsState.close(); }
    }

    // Bound in Hyprland as hl.dsp.global("quickshell:settingsToggle").
    GlobalShortcut {
        name: "settingsToggle"
        description: "Toggle the sky settings window"
        onPressed: SettingsState.toggle("")
    }

    // qs -c sky ipc call launcher toggle|open|close
    IpcHandler {
        target: "launcher"
        function toggle(): void { IslandState.toggleLauncher(); }
        function open(): void { IslandState.openLauncher(); }
        function close(): void { IslandState.closeLauncher(); }
    }

    // Bound in Hyprland as hl.dsp.global("quickshell:launcherToggle").
    GlobalShortcut {
        name: "launcherToggle"
        description: "Toggle the sky launcher"
        onPressed: IslandState.toggleLauncher()
    }

    // Bound in Hyprland as hl.dsp.global("quickshell:wallpaperToggle").
    GlobalShortcut {
        name: "wallpaperToggle"
        description: "Toggle the sky wallpaper picker"
        onPressed: IslandState.toggleWallpaper()
    }

    // While the strip is open the shell enters the Hyprland submap
    // "wallpapers" (hypr/custom/keybinds.lua), so these are what the arrow
    // keys reach: the movement between wallpapers belongs to hl.
    GlobalShortcut {
        name: "wallpaperPrev"
        description: "Previous wallpaper"
        onPressed: WallpaperService.move(-1)
    }
    GlobalShortcut {
        name: "wallpaperNext"
        description: "Next wallpaper"
        onPressed: WallpaperService.move(1)
    }
    GlobalShortcut {
        name: "wallpaperApply"
        description: "Apply the selected wallpaper"
        onPressed: WallpaperService.apply(WallpaperService.selected)
    }
    GlobalShortcut {
        name: "wallpaperClose"
        description: "Close the wallpaper picker"
        onPressed: IslandState.closeWallpaper()
    }

    // Instant replay. qs -c sky ipc call replay save|toggle|enable|disable|gallery|state
    IpcHandler {
        target: "replay"
        function save(): void { ReplayService.save(); }
        function toggle(): void { ReplayService.toggle(); }
        function enable(): void { ReplayService.setEnabled(true); }
        function disable(): void { ReplayService.setEnabled(false); }
        function gallery(): void { SettingsState.open("replay"); }
        function state(): string {
            return JSON.stringify({ enabled: ReplayService.enabled, available: ReplayService.available,
                active: ReplayService.active, lastClip: ReplayService.lastClip, error: ReplayService.error });
        }
    }

    // Bound in Hyprland (hypr/custom/keybinds.lua) as hl.dsp.global("quickshell:replay…").
    GlobalShortcut {
        name: "replaySave"
        description: "Save the instant replay as a clip"
        onPressed: ReplayService.save()
    }
    GlobalShortcut {
        name: "replayToggle"
        description: "Turn the instant replay on or off"
        onPressed: ReplayService.toggle()
    }
    GlobalShortcut {
        name: "replayGallery"
        description: "Open the clips gallery"
        onPressed: SettingsState.open("replay")
    }

    // qs -c sky ipc call island toggle|open|close|clear|dnd|update|state, or: island page wifi
    IpcHandler {
        target: "island"
        function toggle(): void { IslandState.toggleCenter(); }
        function open(): void { IslandState.openCenter("notifs"); }
        // notifs | perf | music | wifi | bluetooth | sound | power | usage
        function page(name: string): void { IslandState.togglePage(name); }
        function close(): void { IslandState.closeCenter(); }
        function tray(): void { IslandState.toggleTray(); }
        function wallpapers(): void { IslandState.toggleWallpaper(); }
        function clear(): void { Notifs.clearAll(); }
        function dnd(): void { Notifs.dnd = !Notifs.dnd; }
        function update(): void { UpdateService.applyAll(); }
        function state(): string {
            return JSON.stringify({ mode: IslandState.mode, queue: Notifs.queue.length, unread: Notifs.unread,
                history: Notifs.list.length, hovered: Notifs.hovered, dnd: Notifs.dnd, osd: IslandState.osdVisible, fullscreen: IslandState.fullscreen });
        }
    }
}
