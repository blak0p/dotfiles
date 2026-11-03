pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    property bool launcherOpen: false
    property string launcherScreen: ""

    function focusedName() {
        const m = Hyprland.focusedMonitor;
        return m ? m.name : (Quickshell.screens.length ? Quickshell.screens[0].name : "");
    }
    // Screen that hosts the shell (Config.screen), or the focused one if it is absent.
    function mainName() {
        const s = Quickshell.screens.find(s => s.name === Config.screen);
        return s ? s.name : focusedName();
    }
    function openLauncher() { launcherScreen = mainName(); launcherOpen = true; }
    function closeLauncher() { launcherOpen = false; }
    function toggleLauncher() { launcherOpen ? closeLauncher() : openLauncher(); }
}
