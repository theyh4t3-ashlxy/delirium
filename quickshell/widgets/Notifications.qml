import QtQuick
import QtQuick.Layouts
import ".."
import "../controls"
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland
import Quickshell.Services.Notifications

BarPill {
    id: root

    readonly property int notifCount: NotificationService?.trackedNotifications?.values?.length ?? NotificationService?.trackedNotifications?.count ?? 0
    readonly property bool isDnd: Settings?.dnd ?? false
    readonly property int dndSec: NotificationService?.dndRemainingSec ?? 0

    property string searchQuery: ""
    property string activeAppFilter: ""
    property bool showDndTimers: false

    readonly property var rawNotifs: NotificationService?.trackedNotifications?.values ? [...NotificationService.trackedNotifications.values] : []
    readonly property var uniqueApps: {
        let seen = {};
        let apps = [];
        for (let i = 0; i < rawNotifs.length; i++) {
            let n = rawNotifs[i];
            if (!n) continue;
            let app = String(n.appName || n.desktopEntry || "system").toLowerCase().trim();
            if (app && !seen[app]) {
                seen[app] = true;
                apps.push(app);
            }
        }
        return apps;
    }

    readonly property var filteredNotifs: {
        let q = root.searchQuery.trim().toLowerCase();
        let appF = root.activeAppFilter.trim().toLowerCase();
        let out = [];
        for (let i = 0; i < rawNotifs.length; i++) {
            let n = rawNotifs[i];
            if (!n) continue;
            let app = String(n.appName || n.desktopEntry || "system").toLowerCase().trim();
            if (appF !== "" && app !== appF) continue;
            if (q !== "") {
                let sum = String(n.summary || "").toLowerCase();
                let body = String(n.body || "").toLowerCase();
                if (!sum.includes(q) && !body.includes(q) && !app.includes(q)) continue;
            }
            out.push(n);
        }
        return out;
    }

    active: popup.open
    hovered: notifMouse.containsMouse
    pressed: notifMouse.pressed
    activeBg: Theme.widgetActive
    activeBorder: Theme.alpha(Theme.primary, 0.55)
    normalBorder: root.isDnd ? Theme.alpha(Theme.tertiary, 0.7) : Theme.barPillBorder
    hoverBorder: normalBorder

    implicitWidth: {
        if (Theme.isVertical) return root.pillSize;
        if (root.notifCount === 0 && !Theme.isTextIconSet) return root.pillSize;
        return Math.max(root.pillSize, notifRow.implicitWidth + 20);
    }

    Behavior on implicitWidth { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.animEasing } }

    function resolveNotifIcon(notif): string {
        if (!notif) return "";
        let candidates = [notif.image, notif.appIcon];
        for (let i = 0; i < candidates.length; i++) {
            let img = candidates[i];
            if (!img || typeof img !== "string") continue;
            if (img.startsWith("image://") || img.startsWith("file://")) return img;
            if (img.startsWith("/")) return "file://" + img;
            if (Quickshell?.hasThemeIcon && Quickshell.hasThemeIcon(img)) {
                return Quickshell.iconPath(img) || "";
            }
            let lower = img.toLowerCase();
            if (Quickshell?.hasThemeIcon && Quickshell.hasThemeIcon(lower)) {
                return Quickshell.iconPath(lower) || "";
            }
        }

        if (Theme?.resolveAppIcon) {
            let fallback = Theme.resolveAppIcon(notif.desktopEntry || notif.appIcon || notif.appName || "");
            if (fallback) return fallback;
        }
        return "";
    }

    function formatDndRemaining(sec) {
        let s = Math.max(0, Math.round(sec || 0));
        let m = Math.ceil(s / 60);
        if (m >= 60) {
            let h = Math.floor(m / 60);
            let rm = m % 60;
            return rm > 0 ? (h + "h " + rm + "m") : (h + "h");
        }
        return m + "m";
    }

    Row {
        id: notifRow
        anchors.centerIn: parent
        spacing: 5

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.isDnd
                ? Theme.iconBellOff
                : (root.notifCount > 0 ? Theme.iconBell : Theme.iconBellOutline)
            font.family: Theme.fontIcon
            font.variableAxes: Theme.iconAxes
            font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeXs : Theme.fontSizeSm
            font.weight: Theme.isTextIconSet ? Theme.fontWeightBold : Theme.fontWeightRegular
            color: root.isDnd
                ? Theme.tertiary
                : (root.notifCount > 0 ? Theme.primary : Theme.textSecondary)

            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.notifCount > 0 && !Theme.isVertical
            text: root.notifCount.toString()
            font.family: Theme.fontMono
            font.variableAxes: Theme.monoAxes
            font.pixelSize: Theme.fontSizeXs
            font.weight: Theme.monoWeightBold
            color: root.isDnd ? Theme.tertiary : Theme.primary
        }
    }

    function syncAnchor() {
        if (!root.visible || (root.width <= 0 && root.height <= 0)) {
            popup.targetRelativeX = 0;
            popup.targetRelativeY = 0;
            return;
        }
        let pt = root.mapToItem(null, 0, 0);
        if (Theme.isVertical) {
            popup.targetRelativeY = pt ? (pt.y + (root.height / 2)) : ((popup.screen?.height ?? 1080) / 2);
        } else {
            popup.targetRelativeX = pt ? (pt.x + (root.width / 2)) : ((popup.screen?.width ?? 1920) / 2);
        }
    }

    function togglePopup() {
        root.syncAnchor();
        if (!popup.open) {
            popup.pinned = true;
            popup.open = true;
        } else if (!popup.pinned) {
            popup.pinned = true;
        } else {
            popup.pinned = false;
            popup.open = false;
        }
    }

    function openPopup() {
        root.syncAnchor();
        popup.open = true;
    }

    function closePopup() {
        popup.pinned = false;
        popup.open = false;
    }

    Connections {
        target: NotificationService ?? null
        ignoreUnknownSignals: true

        function onToggleRequested() {
            let myScreen = root.barScreen ?? root.QsWindow?.window?.screen;
            let focusedScreenName = Hyprland?.focusedMonitor?.name;
            if (popup.open) {
                root.closePopup();
            } else if (!focusedScreenName || !myScreen || myScreen.name === focusedScreenName) {
                popup.pinned = true;
                root.openPopup();
            }
        }

        function onOpenRequested() {
            let myScreen = root.barScreen ?? root.QsWindow?.window?.screen;
            let focusedScreenName = Hyprland?.focusedMonitor?.name;
            if (!focusedScreenName || !myScreen || myScreen.name === focusedScreenName) {
                popup.pinned = true;
                root.openPopup();
            }
        }

        function onCloseRequested() { root.closePopup(); }
    }

    HoverFlyoutHandler {
        popup: popup
        mouseArea: notifMouse
        updatePos: () => root.syncAnchor()
    }

    MouseArea {
        id: notifMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                root.togglePopup();
            } else if (mouse.button === Qt.RightButton || mouse.button === Qt.MiddleButton) {
                NotificationService?.setDndForMinutes(root.isDnd ? 0 : 0);
                if (typeof Settings !== "undefined" && Settings) {
                    Settings.dnd = !Settings.dnd;
                }
            }
        }
    }

    PopupPanel {
        id: popup
        wantsFocus: true
        screen: root.barScreen
        cardWidth: 410
        cardHeight: 510

        onOpenChanged: {
            if (!open) {
                root.showDndTimers = false;
            }
        }

        content: ColumnLayout {
            anchors.fill: parent
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    width: 36
                    height: 36
                    radius: Theme.radiusMd
                    color: root.isDnd ? Theme.tertiary_overlay : Theme.primary_overlay
                    border.color: Theme.alpha(root.isDnd ? Theme.tertiary : Theme.primary, 0.45)
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                    Text {
                        anchors.centerIn: parent
                        text: root.isDnd ? Theme.iconBellOff : Theme.iconBell
                        font.family: Theme.fontIcon
                        font.variableAxes: Theme.iconAxes
                        font.pixelSize: Theme.fontSizeMd
                        color: root.isDnd ? Theme.tertiary : Theme.primary
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: "notifications"
                        font.family: Theme.fontDisplay
                        font.variableAxes: Theme.displayAxes
                        font.pixelSize: Theme.fontSizeMd
                        font.weight: Theme.fontWeightBold
                        color: Theme.textPrimary
                    }

                    Text {
                        text: {
                            if (root.isDnd && root.dndSec > 0) return "dnd active • " + root.formatDndRemaining(root.dndSec) + " left";
                            if (root.isDnd) return "do not disturb active";
                            return root.notifCount > 0 ? (root.notifCount + " unread") : "inbox zero";
                        }
                        font.family: Theme.fontMono
                        font.variableAxes: Theme.monoAxes
                        font.weight: Theme.monoWeightRegular
                        font.pixelSize: Theme.fontSizeXs
                        color: root.isDnd ? Theme.tertiary : Theme.textSecondary
                    }
                }

                IconButton {
                    icon: Theme.iconClock
                    iconSize: Theme.fontSizeSm
                    highlighted: root.showDndTimers || root.dndSec > 0
                    tooltip: "timed do not disturb"
                    onClicked: root.showDndTimers = !root.showDndTimers
                }

                Rectangle {
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: dndChipRow.implicitWidth + 16
                    radius: root.isDnd ? Theme.radiusMd : Theme.radiusPill
                    color: root.isDnd
                        ? Theme.tertiary_overlay
                        : (dndMouse.containsMouse ? Theme.pillHover : Theme.pillBg)
                    border.color: root.isDnd
                        ? Theme.alpha(Theme.tertiary, 0.65)
                        : (dndMouse.containsMouse ? Theme.alpha(Theme.primary, 0.4) : Theme.pillBorder)
                    border.width: (root.isDnd || dndMouse.containsMouse || Theme.pillBorder.a > 0) ? 1 : 0

                    Behavior on radius { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                    RowLayout {
                        id: dndChipRow
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            text: root.isDnd ? Theme.iconBellOff : Theme.iconBell
                            font.family: Theme.fontIcon
                            font.variableAxes: Theme.iconAxes
                            font.pixelSize: Theme.fontSizeXs
                            color: root.isDnd ? Theme.tertiary : Theme.textSecondary
                        }

                        Text {
                            text: root.isDnd ? "dnd on" : "dnd off"
                            font.family: Theme.fontFamily
                            font.variableAxes: Theme.sansAxes
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: root.isDnd ? Theme.fontWeightBold : Theme.fontWeightMedium
                            color: root.isDnd ? Theme.tertiary : Theme.textSecondary
                        }
                    }

                    MouseArea {
                        id: dndMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (NotificationService) NotificationService.dndRemainingSec = 0;
                            if (Settings) Settings.dnd = !Settings.dnd;
                        }
                    }
                }

                IconButton {
                    icon: Theme.iconTrash
                    iconSize: Theme.fontSizeSm
                    tooltip: "clear all"
                    visible: root.notifCount > 0
                    onClicked: {
                        root.activeAppFilter = "";
                        root.searchQuery = "";
                        if (NotificationService?.clearAll) NotificationService.clearAll();
                    }
                }

                IconButton {
                    icon: Theme.iconClose
                    iconSize: Theme.fontSizeXs
                    tooltip: "close panel"
                    onClicked: root.closePopup()
                }
            }

            // timed DND selector bar
            RowLayout {
                visible: root.showDndTimers
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: "silence for:"
                    font.family: Theme.fontMono
                    font.variableAxes: Theme.monoAxes
                    font.pixelSize: 10
                    color: Theme.on_surface_variant
                }

                Repeater {
                    model: [
                        { label: "30m", mins: 30 },
                        { label: "1h", mins: 60 },
                        { label: "2h", mins: 120 },
                        { label: "off", mins: 0 }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool isCur: modelData.mins === 0
                            ? (!root.isDnd)
                            : (root.isDnd && Math.abs((root.dndSec / 60) - modelData.mins) < 2)
                        Layout.fillWidth: true
                        height: 24
                        radius: Theme.radiusPill
                        color: isCur ? Theme.tertiary_overlay : (dtMouse.containsMouse ? Theme.widgetHover : Theme.cardBg)
                        border.color: isCur ? Theme.tertiary : Theme.cardBorder
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            font.family: Theme.fontMono
                            font.variableAxes: Theme.monoAxes
                            font.pixelSize: 10
                            font.weight: isCur ? Theme.monoWeightBold : Theme.monoWeightRegular
                            color: isCur ? Theme.tertiary : Theme.on_surface
                        }

                        MouseArea {
                            id: dtMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NotificationService?.setDndForMinutes(modelData.mins)
                        }
                    }
                }
            }

            // search & app filter strip (shown whenever notifications exist)
            ColumnLayout {
                visible: root.notifCount > 0 || root.searchQuery !== ""
                Layout.fillWidth: true
                spacing: 6

                Rectangle {
                    Layout.fillWidth: true
                    height: 30
                    radius: Theme.radiusSm
                    color: Theme.surface_container_highest
                    border.color: notifSearchIn.activeFocus ? Theme.primary : Theme.widgetBorder
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 6
                        spacing: 6

                        Text {
                            text: Theme.iconSearch
                            font.family: Theme.fontIcon
                            font.variableAxes: Theme.iconAxes
                            font.pixelSize: Theme.fontSizeXs
                            color: notifSearchIn.activeFocus ? Theme.primary : Theme.on_surface_variant
                        }

                        TextInput {
                            id: notifSearchIn
                            Layout.fillWidth: true
                            verticalAlignment: TextInput.AlignVCenter
                            font.family: Theme.fontFamily
                            font.variableAxes: Theme.sansAxes
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.on_surface
                            selectByMouse: true
                            onTextChanged: root.searchQuery = text

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: "filter notifications or app..."
                                font: parent.font
                                color: Theme.on_surface_disabled
                                visible: parent.text === ""
                            }
                        }

                        IconButton {
                            visible: notifSearchIn.text !== ""
                            icon: Theme.iconClose
                            iconSize: 10
                            implicitWidth: 20
                            implicitHeight: 20
                            onClicked: notifSearchIn.text = ""
                        }
                    }
                }

                Flickable {
                    visible: root.uniqueApps.length > 1
                    Layout.fillWidth: true
                    Layout.preferredHeight: 24
                    contentWidth: appChipRow.implicitWidth
                    contentHeight: 24
                    flickableDirection: Flickable.HorizontalFlick
                    clip: true

                    Row {
                        id: appChipRow
                        height: 24
                        spacing: 5

                        Repeater {
                            model: [""].concat(root.uniqueApps)

                            delegate: Rectangle {
                                required property string modelData
                                readonly property bool isSel: root.activeAppFilter === modelData
                                height: 22
                                implicitWidth: appTxt.implicitWidth + 14
                                radius: Theme.radiusPill
                                color: isSel ? Theme.primary_overlay : Theme.cardBg
                                border.color: isSel ? Theme.primary : Theme.cardBorder
                                border.width: 1

                                Text {
                                    id: appTxt
                                    anchors.centerIn: parent
                                    text: modelData === "" ? ("all (" + root.rawNotifs.length + ")") : modelData
                                    font.family: Theme.fontMono
                                    font.variableAxes: Theme.monoAxes
                                    font.pixelSize: 9
                                    font.weight: isSel ? Theme.monoWeightBold : Theme.monoWeightRegular
                                    color: isSel ? Theme.primary : Theme.on_surface_variant
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.activeAppFilter = modelData
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.popupDividerHeight
                color: Theme.cardBorder
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: notifListView
                    anchors.fill: parent
                    anchors.rightMargin: 6
                    clip: true
                    spacing: 8
                    boundsBehavior: Flickable.StopAtBounds
                    visible: root.filteredNotifs.length > 0
                    model: root.filteredNotifs

                    delegate: Rectangle {
                        id: notifCard
                        required property var modelData
                        readonly property bool isCritical: modelData?.urgency === NotificationUrgency.Critical
                        readonly property color cardAccent: isCritical ? Theme.error : Theme.primary
                        readonly property string resolvedIcon: root.resolveNotifIcon(modelData)
                        readonly property string previewImageUri: {
                            let img = modelData?.image;
                            if (!img || typeof img !== "string") return "";
                            if (img.startsWith("image://") || img.startsWith("file://")) return img;
                            if (img.startsWith("/")) return "file://" + img;
                            return "";
                        }

                        width: notifListView.width
                        implicitHeight: col.implicitHeight + 22
                        radius: Theme.radiusLg
                        color: isCritical
                            ? Theme.blend(Theme.cardBg, Theme.error, 0.14)
                            : (cardMouse.containsMouse ? Theme.blend(Theme.cardBg, Theme.primary, 0.06) : Theme.cardBg)
                        border.color: isCritical
                            ? Theme.alpha(Theme.error, 0.55)
                            : (cardMouse.containsMouse ? Theme.alpha(Theme.primary, 0.38) : Theme.cardBorder)
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
                        Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                        MouseArea {
                            id: cardMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.MiddleButton
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.MiddleButton) {
                                    if (NotificationService?.dismiss && notifCard.modelData?.id !== undefined) {
                                        NotificationService.dismiss(notifCard.modelData.id);
                                    } else if (notifCard.modelData?.dismiss) {
                                        notifCard.modelData.dismiss();
                                    }
                                }
                            }
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.leftMargin: 4
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.topMargin: 12
                            anchors.bottomMargin: 12
                            width: 3
                            radius: Theme.radiusPill
                            color: notifCard.cardAccent
                            opacity: notifCard.isCritical || cardMouse.containsMouse ? 1.0 : 0.55
                        }

                        ColumnLayout {
                            id: col
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.leftMargin: 14
                            anchors.rightMargin: 10
                            anchors.topMargin: 11
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                ClippingRectangle {
                                    Layout.preferredWidth: 24
                                    Layout.preferredHeight: 24
                                    radius: Theme.radiusSm
                                    color: Theme.widgetBg
                                    border.color: Theme.widgetBorder
                                    border.width: 1

                                    Loader {
                                        anchors.centerIn: parent
                                        active: notifCard.resolvedIcon !== ""
                                        sourceComponent: IconImage {
                                            width: 16
                                            height: 16
                                            implicitSize: 16
                                            source: notifCard.resolvedIcon
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: notifCard.resolvedIcon === ""
                                        text: notifCard.isCritical ? Theme.iconFlame : Theme.iconBell
                                        font.family: Theme.fontIcon
                                        font.variableAxes: Theme.iconAxes
                                        font.pixelSize: Theme.fontSizeXs
                                        color: notifCard.cardAccent
                                    }
                                }

                                Text {
                                    text: (notifCard.modelData?.appName || notifCard.modelData?.desktopEntry || "system").toLowerCase()
                                    font.family: Theme.fontMono
                                    font.variableAxes: Theme.monoAxes
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: Theme.monoWeightBold
                                    color: notifCard.cardAccent
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Rectangle {
                                    visible: notifCard.isCritical
                                    height: 18
                                    implicitWidth: critTxt.implicitWidth + 10
                                    radius: Theme.radiusPill
                                    color: Theme.error_overlay
                                    border.color: Theme.error
                                    border.width: 1

                                    Text {
                                        id: critTxt
                                        anchors.centerIn: parent
                                        text: "urgent"
                                        font.family: Theme.fontMono
                                        font.variableAxes: Theme.monoAxes
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.monoWeightBold
                                        color: Theme.error
                                    }
                                }

                                IconButton {
                                    icon: Theme.iconClose
                                    iconSize: Theme.fontSizeXs
                                    tooltip: "dismiss"
                                    onClicked: {
                                        if (NotificationService?.dismiss && notifCard.modelData?.id !== undefined) {
                                            NotificationService.dismiss(notifCard.modelData.id);
                                        } else if (notifCard.modelData?.dismiss) {
                                            notifCard.modelData.dismiss();
                                        }
                                    }
                                }
                            }

                            Text {
                                text: (notifCard.modelData?.summary ?? "").toLowerCase()
                                font.family: Theme.fontDisplay
                                font.variableAxes: Theme.displayAxes
                                font.pixelSize: Theme.fontSizeSm
                                font.weight: Theme.fontWeightBold
                                color: Theme.textPrimary
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                visible: text !== ""
                            }

                            Text {
                                text: (notifCard.modelData?.body ?? "").replace(/<[^>]*>/g, "").toLowerCase()
                                font.family: Theme.fontFamily
                                font.variableAxes: Theme.sansAxes
                                font.weight: Theme.fontWeightRegular
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.textSecondary
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                visible: text !== ""
                            }

                            ClippingRectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 112
                                radius: Theme.radiusSm
                                color: Theme.widgetBg
                                border.color: Theme.widgetBorder
                                border.width: 1
                                visible: notifCard.previewImageUri !== "" && notifPreviewImg.status !== Image.Error

                                Image {
                                    id: notifPreviewImg
                                    anchors.fill: parent
                                    source: notifCard.previewImageUri
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: 2
                                visible: (notifCard.modelData?.actions?.length ?? 0) > 0
                                spacing: 6

                                Repeater {
                                    model: notifCard.modelData?.actions ?? []

                                    delegate: Rectangle {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 1
                                        Layout.preferredHeight: 28
                                        radius: actMouse.pressed ? Theme.radiusPill : Theme.radiusMd
                                        color: actMouse.pressed
                                            ? notifCard.cardAccent
                                            : (actMouse.containsMouse
                                                ? (notifCard.isCritical ? Theme.error_overlay : Theme.primary_overlay)
                                                : Theme.widgetBg)
                                        border.color: actMouse.containsMouse ? Theme.alpha(notifCard.cardAccent, 0.55) : Theme.widgetBorder
                                        border.width: 1

                                        Behavior on radius { NumberAnimation { duration: Theme.animFast } }
                                        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                        Text {
                                            anchors.fill: parent
                                            anchors.margins: 4
                                            text: (modelData?.text ?? "action").toLowerCase()
                                            font.family: Theme.fontFamily
                                            font.variableAxes: Theme.sansAxes
                                            font.pixelSize: Theme.fontSizeXs
                                            font.weight: Theme.fontWeightBold
                                            color: actMouse.pressed
                                                ? (notifCard.isCritical ? Theme.on_error : Theme.on_primary)
                                                : (actMouse.containsMouse ? notifCard.cardAccent : Theme.textPrimary)
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            elide: Text.ElideRight
                                        }

                                        MouseArea {
                                            id: actMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (modelData?.invoke) modelData.invoke();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 3
                    radius: 2
                    color: "transparent"
                    visible: notifListView.visible && notifListView.visibleArea.heightRatio < 1.0

                    Rectangle {
                        width: parent.width
                        readonly property real trackH: parent.height
                        readonly property real thumbH: Math.max(24, Math.min(trackH, notifListView.visibleArea.heightRatio * trackH))
                        height: thumbH
                        y: Math.max(0, Math.min(trackH - thumbH, notifListView.visibleArea.yPosition * trackH))
                        radius: 2
                        color: Theme.primary
                        opacity: 0.7
                    }
                }

                // empty state
                Rectangle {
                    anchors.fill: parent
                    visible: root.filteredNotifs.length === 0
                    radius: Theme.radiusLg
                    color: Theme.cardBg
                    border.color: Theme.cardBorder
                    border.width: 1

                    ColumnLayout {
                        anchors.centerIn: parent
                        width: parent.width - 36
                        spacing: 10

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            width: 52
                            height: 52
                            radius: Theme.radiusPill
                            color: root.isDnd ? Theme.tertiary_overlay : Theme.widgetBg
                            border.color: root.isDnd ? Theme.alpha(Theme.tertiary, 0.45) : Theme.widgetBorder
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: root.isDnd
                                    ? Theme.iconBellOff
                                    : (Theme.iconSet === "kaomoji" ? Theme.kaoSleepy : Theme.iconBellOutline)
                                font.family: Theme.fontIcon
                                font.variableAxes: Theme.iconAxes
                                font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeMd : Theme.fontSizeTitle
                                color: root.isDnd ? Theme.tertiary : Theme.primary
                            }
                        }

                        Text {
                            text: root.notifCount > 0 ? "no matching notifications" : (root.isDnd ? "do not disturb enabled" : "all caught up")
                            font.family: Theme.fontDisplay
                            font.variableAxes: Theme.displayAxes
                            font.pixelSize: Theme.fontSizeSm
                            font.weight: Theme.fontWeightBold
                            color: Theme.textPrimary
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: root.notifCount > 0
                                ? "clear search or app filter to view unread items"
                                : (root.isDnd
                                    ? Theme.getFlavor("dnd_on", "notifications are silenced right now")
                                    : Theme.getFlavor("notifs_empty", "zero unread notifications in the queue"))
                            font.family: Theme.fontFamily
                            font.variableAxes: Theme.sansAxes
                            font.weight: Theme.fontWeightRegular
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textSecondary
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: root.isDnd ? Theme.iconBellOff : Theme.iconCheck
                    font.family: Theme.fontIcon
                    font.variableAxes: Theme.iconAxes
                    font.pixelSize: Theme.fontSizeXs
                    color: root.isDnd ? Theme.tertiary : Theme.primary
                }

                Text {
                    text: "right-click bar icon to toggle dnd"
                    font.family: Theme.fontFamily
                    font.variableAxes: Theme.sansAxes
                    font.weight: Theme.fontWeightRegular
                    font.pixelSize: Theme.fontSizeXs
                    color: Theme.textSecondary
                    Layout.fillWidth: true
                }

                Text {
                    visible: root.notifCount > 0
                    text: "mid-click card to dismiss"
                    font.family: Theme.fontMono
                    font.variableAxes: Theme.monoAxes
                    font.weight: Theme.monoWeightRegular
                    font.pixelSize: Theme.fontSizeXs
                    color: Theme.textSecondary
                    opacity: 0.75
                }
            }
        }
    }
}
