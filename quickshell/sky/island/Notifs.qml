pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs

// sky is the notification daemon (org.freedesktop.Notifications).
// New notifications queue up as island popups; every tracked one stays in
// `list` (the notification center) until dismissed.
Singleton {
    id: root

    property var queue: []
    readonly property var current: queue.length ? queue[0] : null
    property int unread: 0
    property bool dnd: false
    property bool hovered: false            // pauses the popup timer
    property var times: ({})                // notification id -> arrival Date

    // A normal notification arrived during fullscreen (MiniToast shows it).
    signal quiet(var n)

    readonly property var list: server.trackedNotifications.values.slice().reverse()

    NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: true

        onNotification: n => {
            n.tracked = true;
            const t = root.times;
            t[n.id] = new Date();
            root.times = t;
            if (IslandState.centerOpen) return;
            root.unread++;
            // Critical ones always use the island. Silent mode: history only.
            // Fullscreen: history + a discreet top-right toast.
            if (n.urgency !== NotificationUrgency.Critical) {
                if (root.dnd) return;
                if (IslandState.fullscreen) { root.quiet(n); return; }
            }
            // A replacement (same id) refreshes the popup in place.
            root.queue = root.queue.filter(x => x && x.id !== n.id).concat([n]);
        }
    }

    // Drop popups whose notification was closed (dismissed, expired, by the app).
    Connections {
        target: server.trackedNotifications
        function onValuesChanged() {
            const alive = server.trackedNotifications.values;
            root.queue = root.queue.filter(x => x && alive.indexOf(x) >= 0);
        }
    }

    function timeoutFor(n) {
        if (!n || n.urgency === NotificationUrgency.Critical) return 0;   // stays until dismissed
        const t = n.expireTimeout > 0 ? n.expireTimeout : Config.notifMs;
        return Math.max(3000, Math.min(t, 10000));
    }

    function next() {
        const n = current;
        queue = queue.slice(1);
        if (n && n.transient) n.expire();
    }

    function dismiss(n) { if (n) n.dismiss(); }
    function clearAll() {
        for (const n of server.trackedNotifications.values.slice()) n.dismiss();
        queue = [];
        unread = 0;
    }
    function markRead() { unread = 0; queue = []; }

    // Click on a notification: run its default action if it has one.
    function activate(n) {
        if (!n) return;
        const a = n.actions.find(x => x.identifier === "default");
        if (a) a.invoke();
        else n.dismiss();
    }

    function iconFor(n) {
        if (!n) return "";
        if (n.image) return n.image;
        const i = n.appIcon || "";
        if (i.startsWith("/") || i.includes("://")) return i;
        // Theme icon name, else the icon of the app's desktop entry; "" falls
        // back to the glyph in NotifCard (never Qt's missing-icon texture).
        const entry = DesktopEntries.heuristicLookup(n.desktopEntry || n.appName || i);
        for (const name of [i, entry ? entry.icon : "", n.desktopEntry || ""]) {
            if (!name) continue;
            if (name.startsWith("/")) return name;
            if (Quickshell.hasThemeIcon(name)) return Quickshell.iconPath(name);
        }
        return "";
    }

    function ago(n) {
        const d = n ? times[n.id] : null;
        if (!d) return "";
        const s = Math.floor((clock.date - d) / 1000);
        if (s < 60) return "now";
        if (s < 3600) return Math.floor(s / 60) + "m";
        if (s < 86400) return Math.floor(s / 3600) + "h";
        return Qt.formatDate(d, "dd/MM");
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Timer {
        id: popupTimer
        interval: Math.max(1, root.timeoutFor(root.current))
        running: root.current !== null && root.timeoutFor(root.current) > 0 && !root.hovered
            && IslandState.mode === "notif"
        onTriggered: root.next()
    }
    // A new popup restarts the countdown.
    onCurrentChanged: if (popupTimer.running) popupTimer.restart()
}
