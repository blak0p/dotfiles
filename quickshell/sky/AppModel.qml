pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

// Desktop entries + running toplevels, shared by the dock and the launcher.
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

    function matches(appId, entry) {
        if (!entry || !appId) return false;
        const a = appId.toLowerCase(), id = entry.id.toLowerCase();
        const sc = (entry.startupClass || "").toLowerCase();
        return a === id || (sc && a === sc) || id.endsWith("." + a) || a.endsWith("." + id);
    }

    // Dock model: pinned entries first, then running apps that are not pinned.
    readonly property var dockItems: {
        // byId() is not reactive: depend on the entry list so pinned apps
        // resolve once DesktopEntries finishes scanning at startup.
        void DesktopEntries.applications.values;
        const tl = ToplevelManager.toplevels.values;
        const used = new Set();
        const out = [];
        for (const id of DockPins.ids) {
            const entry = DesktopEntries.byId(id) || DesktopEntries.heuristicLookup(id);
            if (!entry) continue;
            const mine = tl.filter(t => matches(t.appId, entry));
            mine.forEach(t => used.add(t));
            out.push({ key: entry.id, entry, name: entry.name, icon: entry.icon, toplevels: mine });
        }
        for (const t of tl) {
            if (used.has(t) || !t.appId) continue;
            const same = out.find(o => !o.pinnedFlag && o.appId === t.appId);
            if (same) { same.toplevels.push(t); continue; }
            const entry = DesktopEntries.byId(t.appId) || DesktopEntries.heuristicLookup(t.appId);
            out.push({ key: "run:" + t.appId, appId: t.appId, entry, name: entry ? entry.name : t.title,
                       icon: entry ? entry.icon : t.appId.toLowerCase(), toplevels: [t] });
        }
        return out;
    }

    function iconSource(name) {
        const p = Quickshell.iconPath(name || "", true);
        return p || Quickshell.iconPath("application-x-executable", true);
    }
}
