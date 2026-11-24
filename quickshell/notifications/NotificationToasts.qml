import QtQuick
import QtQuick.Layouts
import ".."
import "../corners"
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    readonly property string rawPos: Settings?.barPosition ?? "top"
    readonly property string pos: (rawPos === "up" || rawPos === "top") ? "top" : ((rawPos === "down" || rawPos === "bottom") ? "bottom" : rawPos)
    readonly property bool isTop: pos === "top"
    readonly property bool isBottom: pos === "bottom"
    readonly property bool isLeft: pos === "left"
    readonly property bool isRight: pos === "right"
    readonly property bool isVertical: isLeft || isRight

    readonly property bool isConcave: (Settings?.notificationCornerStyle ?? "concave") === "concave"
    readonly property real cardScoopR: Math.min(18, Math.max(8, Theme?.scoopRadiusX ?? Settings?.scoopRadius ?? 14))
    readonly property real scoopW: Math.max(16, Theme?.scoopRadiusX ?? 16)
    readonly property real scoopH: Math.max(16, Theme?.scoopRadiusY ?? 16)
    readonly property bool barFloating: Settings?.barFloating ?? false
    readonly property int barMarginOffset: barFloating ? ((Settings?.barMargin ?? 0) > 0 ? Settings.barMargin : 8) : 0
    readonly property int barOffset: Theme.barHeight + barMarginOffset + (barFloating ? 6 : 0)

    color: "transparent"
    focusable: false
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.namespace: "quickshell:notifications"
    WlrLayershell.layer: WlrLayer.Overlay

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    property var toastList: []

    visible: toastList.length > 0

    mask: Region {
        item: toastBox
    }

    function normalizeImageUri(img: string): string {
        if (!img || typeof img !== "string") return "";
        if (img.startsWith("image://") || img.startsWith("file://")) return img;
        if (img.startsWith("/")) return "file://" + img;
        return "";
    }

    /*
    clone notification properties into a per-window plain js object so multi-monitor
    Variants never mutate shared _entered/_elapsedMs state and dangling c++ pointers
    never segfault the shell
    */
    function sanitize(notif): var {
        if (!notif) return null;

        let safeActions = [];
        try {
            if (notif.actions) {
                for (let i = 0; i < notif.actions.length; ++i) {
                    const act = notif.actions[i];
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

        const notifId = notif.id ?? Date.now();
        return {
            __sanitized: true,
            id: notifId,
            summary: String(notif.summary ?? ""),
            body: String(notif.body ?? ""),
            appName: String(notif.appName ?? "system"),
            desktopEntry: String(notif.desktopEntry ?? ""),
            appIcon: String(notif.appIcon ?? ""),
            urgency: Number(notif.urgency ?? 1),
            expireTimeout: Number(notif.expireTimeout ?? -1),
            resident: Boolean(notif.resident ?? false),
            image: root.normalizeImageUri(String(notif.image ?? "")),
            actions: safeActions,
            _entered: false,
            _elapsedMs: 0,
            dismiss: function() {
                if (NotificationService?.dismiss) {
                    NotificationService.dismiss(notifId);
                } else if (typeof notif.dismiss === "function") {
                    try { notif.dismiss(); } catch (e) {}
                }
            }
        };
    }

    Connections {
        target: NotificationService

        function onNotificationReceived(notif) {
            if (Settings?.dnd) return;
            if (!notif) return;

            const safe = root.sanitize(notif);
            if (!safe) return;

            const existing = root.toastList.find(n => n && n.id === safe.id);
            if (existing && existing._entered) {
                safe._entered = true;
            }

            let updated = root.toastList.filter(n => n && n.id !== safe.id);
            // evict oldest toast from screen without deleting it from notification history
            while (updated.length >= 5) {
                updated.shift();
            }
            updated.push(safe);
            root.toastList = updated;
        }

        function onNotificationDismissed(id) {
            if (id === undefined || id === null) return;
            root.toastList = root.toastList.filter(n => n && n.id !== id);
        }

        function onAllCleared() {
            root.toastList = [];
        }
    }

    // remove from screen only (used when the 5s timer runs out so history stays in the bell popup)
    function expireToast(notif) {
        if (!notif) return;
        let id = (typeof notif === "object") ? notif.id : notif;
        if (id !== undefined && id !== null) {
            if (NotificationService?.markExpired) NotificationService.markExpired(id);
            root.toastList = root.toastList.filter(n => n && n.id !== id);
        } else {
            root.toastList = root.toastList.filter(n => n && n !== notif);
        }
    }

    // nuke from both screen and notification center history (when user clicks X)
    function dismissToastPermanently(notif) {
        if (!notif) return;
        let id = (typeof notif === "object") ? notif.id : notif;
        root.expireToast(notif);
        if (id !== undefined && id !== null && NotificationService?.dismiss) {
            NotificationService.dismiss(id);
        } else if (typeof notif?.dismiss === "function") {
            try { notif.dismiss(); } catch (e) {}
        }
    }

    readonly property string notifEdge: Settings?.notificationEdge ?? "right"
    readonly property bool isEdgeRight: notifEdge === "right"
    readonly property bool isEdgeLeft: notifEdge === "left"
    readonly property bool isEdgeTop: notifEdge === "top"
    readonly property bool isEdgeBottom: notifEdge === "bottom"
    readonly property int screenBorder: Settings?.screenBorderWidth ?? 0
    readonly property int cornerOffset: (Settings?.screenCornerRadius ?? 16) + (root.isConcave ? (Math.round(root.cardScoopR) + 6) : 8)

    ScriptModel {
        id: toastModel
        objectProp: "id"
        values: root.toastList
    }

    // account for left/right/floating bars too so toasts don't park on top of the bar
    Item {
        id: toastBox
        width: 360
        height: Math.max(1, toastCol.implicitHeight)

        x: isEdgeLeft ? ((root.isLeft ? root.barOffset : 0) + root.screenBorder)
         : isEdgeRight ? (root.width - width - (root.isRight ? root.barOffset : 0) - root.screenBorder)
         : Math.round((root.width - width) / 2)

        y: isEdgeTop ? ((root.isTop ? root.barOffset : 0) + root.screenBorder)
         : isEdgeBottom ? (root.height - height - (root.isBottom ? root.barOffset : 0) - root.screenBorder)
         : ((root.isTop ? root.barOffset : 0) + root.screenBorder + root.cornerOffset)

        Behavior on x { NumberAnimation { duration: Theme?.animFast ?? 120; easing.type: Theme?.animEasing ?? Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: Theme?.animFast ?? 120; easing.type: Theme?.animEasing ?? Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: Theme?.animFast ?? 120; easing.type: Theme?.animEasing ?? Easing.OutCubic } }

        ColumnLayout {
            id: toastCol
            width: parent.width
            spacing: root.isConcave ? (Math.round(root.cardScoopR * 2) + 8) : 10

            Repeater {
                model: toastModel

                delegate: NotificationCard {
                    required property var modelData
                    required property int index
                    notificationItem: modelData
                    dockTop: root.isTop
                    dockBottom: root.isBottom
                    dockLeft: root.isLeft
                    dockRight: root.isRight
                    Layout.fillWidth: true

                    onExpired: {
                        root.expireToast(modelData);
                    }
                    onDismissed: {
                        root.dismissToastPermanently(modelData);
                    }
                }
            }
        }
    }
}
