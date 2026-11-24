pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

QtObject {
    id: root

    property var _rawNotifs: ({})
    property var _dismissedIds: ({})
    property bool _replayingReload: true

    property PersistentProperties persist: PersistentProperties {
        id: notifPersist
        reloadableId: "qsNotificationServiceState"
        property var expiredIds: ({})
        property var dismissedIds: ({})
    }

    property Timer _replayTimer: Timer {
        interval: 500
        running: true
        repeat: false
        onTriggered: root._replayingReload = false
    }

    property NotificationServer server: NotificationServer {
        id: notifServer

        // telling dbus we are not living in the stone age
        actionsSupported: true
        actionIconsSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: (notification) => root.handleIncomingNotification(notification)
    }

    function handleIncomingNotification(notification): void {
        if (!notification) return;
        const nid = notification.id;
        const hasId = nid !== undefined && nid !== null;
        const wasExpired = hasId && Boolean(notifPersist.expiredIds && notifPersist.expiredIds[nid]);
        const wasDismissed = hasId && Boolean(notifPersist.dismissedIds && notifPersist.dismissedIds[nid]);
        const isReloadReplay = Boolean(notification.lastGeneration) || root._replayingReload;

        // when quickshell hot-reloads, NotificationServer replays trackedNotifications;
        // keep previously expired ones in bell history without re-popping toasts, and purge dismissed ones
        if (isReloadReplay && (wasExpired || wasDismissed)) {
            if (wasDismissed) {
                if (typeof notification.dismiss === "function") {
                    try { notification.dismiss(); } catch (e) {}
                }
                return;
            }
            notification.tracked = true;
            if (hasId) {
                root._rawNotifs[nid] = notification;
            }
            return;
        }

        // track so our notification center widget doesn't have amnesia
        notification.tracked = true;
        if (hasId) {
            delete root._dismissedIds[nid];
            if (notifPersist.expiredIds && notifPersist.expiredIds[nid]) {
                let nextExp = Object.assign({}, notifPersist.expiredIds);
                delete nextExp[nid];
                notifPersist.expiredIds = nextExp;
            }
            if (notifPersist.dismissedIds && notifPersist.dismissedIds[nid]) {
                let nextDis = Object.assign({}, notifPersist.dismissedIds);
                delete nextDis[nid];
                notifPersist.dismissedIds = nextDis;
            }
            root._rawNotifs[nid] = notification;
        }
        const safeNotif = root.sanitize(notification);
        root.notificationReceived(safeNotif);
    }

    signal notificationReceived(var notification)
    signal notificationDismissed(var id)
    signal allCleared()
    signal toggleRequested()
    signal openRequested()
    signal closeRequested()

    function normalizeImageUri(img: string): string {
        if (!img || typeof img !== "string") return "";
        if (img.startsWith("image://") || img.startsWith("file://")) return img;
        if (img.startsWith("/")) return "file://" + img;
        return "";
    }

    function sanitize(notification): var {
        if (!notification) return null;

        let safeActions = [];
        try {
            if (notification.actions) {
                for (let i = 0; i < notification.actions.length; ++i) {
                    const act = notification.actions[i];
                    if (act) {
                        safeActions.push({
                            id: act.id ?? "",
                            text: act.text ?? "",
                            invoke: function() {
                                try {
                                    if (typeof act.invoke === "function") act.invoke();
                                } catch (e) {}
                            }
                        });
                    }
                }
            }
        } catch (e) {}

        const notifId = notification.id ?? Date.now();

        return {
            __sanitized: true,
            id: notifId,
            summary: String(notification.summary ?? ""),
            body: String(notification.body ?? ""),
            appName: String(notification.appName ?? "system"),
            desktopEntry: String(notification.desktopEntry ?? ""),
            appIcon: String(notification.appIcon ?? ""),
            urgency: Number(notification.urgency ?? 1),
            expireTimeout: Number(notification.expireTimeout ?? -1),
            resident: Boolean(notification.resident ?? false),
            image: root.normalizeImageUri(String(notification.image ?? "")),
            actions: safeActions,
            _entered: false,
            _elapsedMs: 0,
            dismiss: function() {
                root.dismiss(notifId);
            }
        };
    }

    function markExpired(id): void {
        if (id === undefined || id === null) return;
        let next = Object.assign({}, notifPersist.expiredIds || {});
        next[id] = true;
        notifPersist.expiredIds = next;
    }

    function dismiss(id): void {
        if (id === undefined || id === null) return;
        if (root._dismissedIds[id]) return;
        root._dismissedIds[id] = true;
        let nextDis = Object.assign({}, notifPersist.dismissedIds || {});
        nextDis[id] = true;
        notifPersist.dismissedIds = nextDis;
        if (notifPersist.expiredIds && notifPersist.expiredIds[id]) {
            let nextExp = Object.assign({}, notifPersist.expiredIds);
            delete nextExp[id];
            notifPersist.expiredIds = nextExp;
        }

        let dismissed = false;
        try {
            const notifs = notifServer.trackedNotifications?.values
                ? [...notifServer.trackedNotifications.values]
                : (Array.isArray(notifServer.trackedNotifications) ? notifServer.trackedNotifications : []);
            const targets = notifs.filter(n => {
                try { return n && n.id === id; } catch (e) { return false; }
            });
            for (const n of targets) {
                if (typeof n.dismiss === "function") {
                    try {
                        n.dismiss();
                        dismissed = true;
                    } catch (e) {}
                }
            }
        } catch (e) {}

        if (!dismissed && root._rawNotifs && root._rawNotifs[id]) {
            const raw = root._rawNotifs[id];
            if (raw && typeof raw.dismiss === "function") {
                try { raw.dismiss(); } catch (e) {}
            }
        }

        if (root._rawNotifs && root._rawNotifs[id]) {
            delete root._rawNotifs[id];
        }

        root.notificationDismissed(id);
    }

    function toggle() {
        root.toggleRequested();
    }

    function open() {
        root.openRequested();
    }

    function close() {
        root.closeRequested();
    }

    readonly property var trackedNotifications: notifServer.trackedNotifications

    // nuking every active notification from orbit
    function clearAll() {
        let nextDis = Object.assign({}, notifPersist.dismissedIds || {});
        try {
            const notifs = notifServer.trackedNotifications?.values ? [...notifServer.trackedNotifications.values] : [];
            for (const n of notifs) {
                if (n) {
                    if (n.id !== undefined && n.id !== null) {
                        root._dismissedIds[n.id] = true;
                        nextDis[n.id] = true;
                    }
                    if (typeof n.dismiss === "function") {
                        try { n.dismiss(); } catch (e) {}
                    }
                }
            }
            for (const key of Object.keys(root._rawNotifs)) {
                const raw = root._rawNotifs[key];
                if (raw) {
                    root._dismissedIds[key] = true;
                    nextDis[key] = true;
                    if (typeof raw.dismiss === "function") {
                        try { raw.dismiss(); } catch (e) {}
                    }
                }
            }
        } catch (e) {}
        notifPersist.dismissedIds = nextDis;
        notifPersist.expiredIds = {};
        root._rawNotifs = {};
        root.allCleared();
    }
}