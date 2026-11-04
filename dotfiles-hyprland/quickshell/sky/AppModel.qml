pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

// Desktop entries, shared by the launcher.
Singleton {
    readonly property var allApps: DesktopEntries.applications.values
        .filter(e => !e.noDisplay)
        .sort((a, b) => a.name.localeCompare(b.name))

    function filter(query) {
        const q = (query || "").trim().toLowerCase();
        if (!q) return allApps;
        const score = e => {
            const n = e.name.toLowerCase();
            if (n.startsWith(q)) return 0;
            if (n.includes(q)) return 1;
            if ((e.genericName || "").toLowerCase().includes(q) || (e.keywords || []).some(k => k.toLowerCase().includes(q))) return 2;
            return -1;
        };
        return allApps.map(e => ({ e, s: score(e) })).filter(x => x.s >= 0)
            .sort((a, b) => a.s - b.s || a.e.name.localeCompare(b.e.name)).map(x => x.e);
    }

    function iconSource(name) {
        const p = Quickshell.iconPath(name || "", true);
        return p || Quickshell.iconPath("application-x-executable", true);
    }
}
