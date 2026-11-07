import QtQuick
import QtQuick.Layouts
import ".."
import "../controls"
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland
import Quickshell.Services.Notifications

Rectangle {
    id: root

    property var barScreen: null
    property var barMonitor: null

    readonly property int notifCount: NotificationService?.trackedNotifications?.values?.length ?? NotificationService?.trackedNotifications?.count ?? 0
    readonly property bool isDnd: Settings?.dnd ?? false
    readonly property int pillSize: Theme.barHeight - 8

    implicitWidth: {
        if (Theme.isVertical) return root.pillSize;
        if (root.notifCount === 0 && !Theme.isTextIconSet) return root.pillSize;
        return Math.max(root.pillSize, notifRow.implicitWidth + 20);
    }
    implicitHeight: root.pillSize
    radius: Theme.radiusPill
    color: popup.open
        ? Theme.widgetActive
        : (notifMouse.containsMouse ? Theme.pillHover : Theme.pillBg)
    border.color: root.isDnd
        ? Theme.alpha(Theme.tertiary, 0.7)
        : (popup.open ? Theme.alpha(Theme.primary, 0.55) : Theme.pillBorder)
    border.width: (root.isDnd || popup.open || Theme.pillBorder.a > 0) ? 1 : 0

    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
    Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
    Behavior on implicitWidth { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.animEasing } }

    /*
    try the raw dbus image/icon first (including image://qsimage/ pixmaps),
    then let Theme.resolveAppIcon hunt down the .desktop entry if the app was lazy
    */
    function resolveNotifIcon(notif): string {
        if (!notif) return "";
        let candidates = [notif.image, notif.appIcon];
        for (let i = 0; i < candidates.length; i++) {
            let img = candidates[i];
            if (!img || typeof img !== "string") continue;
            if (img.startsWith("image://") || img.startsWith("file://")) return img;
            if (img.startsWith("/")) return "file://" + img;
            if (Quickshell?.hasThemeIcon && Quickshell.hasThemeIcon(img)) {
                return Quickshell.iconPath(img);
            }
            let lower = img.toLowerCase();
            if (Quickshell?.hasThemeIcon && Quickshell.hasThemeIcon(lower)) {
                return Quickshell.iconPath(lower);
            }
        }

        if (Theme?.resolveAppIcon) {
            let fallback = Theme.resolveAppIcon(notif.desktopEntry || notif.appIcon || notif.appName || "");
            if (fallback) return fallback;
        }
        return "";
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
            font.pixelSize: Theme.fontSizeXs
            font.weight: Theme.fontWeightBold
            color: root.isDnd ? Theme.tertiary : Theme.primary
        }
    }

    // update coordinates without accidentally forcing popup.open = true on hover
    function syncAnchor() {
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

        function onCloseRequested() {
            root.closePopup();
        }
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
                if (typeof Settings !== "undefined" && Settings) {
                    Settings.dnd = !Settings.dnd;
                }
            }
        }
    }

    PopupPanel {
        id: popup
        screen: root.barScreen
        cardWidth: 400
        cardHeight: 480

        content: ColumnLayout {
            anchors.fill: parent
            spacing: Theme.popupSpacing

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
                        font.pixelSize: Theme.fontSizeMd
                        font.weight: Theme.fontWeightBold
                        color: Theme.textPrimary
                    }

                    Text {
                        text: root.isDnd
                            ? "do not disturb active"
                            : (root.notifCount > 0 ? (root.notifCount + " unread") : "inbox zero")
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeXs
                        color: root.isDnd ? Theme.tertiary : Theme.textSecondary
                    }
                }

                // squishy dnd toggle pill
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
                    Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                    RowLayout {
                        id: dndChipRow
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            text: root.isDnd ? Theme.iconBellOff : Theme.iconBell
                            font.family: Theme.fontIcon
                            font.pixelSize: Theme.fontSizeXs
                            color: root.isDnd ? Theme.tertiary : Theme.textSecondary
                        }

                        Text {
                            text: root.isDnd ? "dnd on" : "dnd off"
                            font.family: Theme.fontFamily
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
                    visible: root.notifCount > 0
                    model: NotificationService?.trackedNotifications

                    delegate: Rectangle {
                        id: notifCard
                        required property var modelData
                        readonly property bool isCritical: modelData?.urgency === NotificationUrgency.Critical
                        readonly property color cardAccent: isCritical ? Theme.error : Theme.primary
                        readonly property string resolvedIcon: root.resolveNotifIcon(modelData)

                        width: notifListView.width
                        // avoid anchors.fill on col so wrapped text never causes a QML binding loop
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

                        // middle-click anywhere on the card to yeet it
                        MouseArea {
                            id: cardMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.MiddleButton
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.MiddleButton && notifCard.modelData?.dismiss) {
                                    notifCard.modelData.dismiss();
                                }
                            }
                        }

                        // left urgency/accent bar
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

                            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
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

                                    IconImage {
                                        id: notifIconImg
                                        anchors.centerIn: parent
                                        width: 16
                                        height: 16
                                        source: notifCard.resolvedIcon
                                        visible: source !== "" && status !== Image.Error
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: !notifIconImg.visible
                                        text: notifCard.isCritical ? Theme.iconFlame : Theme.iconBell
                                        font.family: Theme.fontIcon
                                        font.pixelSize: Theme.fontSizeXs
                                        color: notifCard.cardAccent
                                    }
                                }

                                Text {
                                    text: (notifCard.modelData?.appName || notifCard.modelData?.desktopEntry || "system").toLowerCase()
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: Theme.fontWeightBold
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
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightBold
                                        color: Theme.error
                                    }
                                }

                                IconButton {
                                    icon: Theme.iconClose
                                    iconSize: Theme.fontSizeXs
                                    tooltip: "dismiss"
                                    onClicked: {
                                        if (notifCard.modelData?.dismiss) notifCard.modelData.dismiss();
                                    }
                                }
                            }

                            Text {
                                text: (notifCard.modelData?.summary ?? "").toLowerCase()
                                font.family: Theme.fontDisplay
                                font.pixelSize: Theme.fontSizeSm
                                font.weight: Theme.fontWeightBold
                                color: Theme.textPrimary
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                visible: text !== ""
                            }

                            Text {
                                // strip stray html tags that chat apps love shoving into notification bodies
                                text: (notifCard.modelData?.body ?? "").replace(/<[^>]*>/g, "").toLowerCase()
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.textSecondary
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                visible: text !== ""
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

                // tiny scrollbar thumb so you know how many pings you're ignoring
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

                // zen empty state when nobody is bothering you
                Rectangle {
                    anchors.fill: parent
                    visible: root.notifCount === 0
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
                                font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeMd : Theme.fontSizeTitle
                                color: root.isDnd ? Theme.tertiary : Theme.primary
                            }
                        }

                        Text {
                            text: root.isDnd ? "do not disturb enabled" : "all caught up"
                            font.family: Theme.fontDisplay
                            font.pixelSize: Theme.fontSizeSm
                            font.weight: Theme.fontWeightBold
                            color: Theme.textPrimary
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: root.isDnd
                                ? Theme.getFlavor("dnd_on", "notifications are silenced right now")
                                : Theme.getFlavor("notifs_empty", "zero unread notifications in the queue")
                            font.family: Theme.fontFamily
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
                    font.pixelSize: Theme.fontSizeXs
                    color: root.isDnd ? Theme.tertiary : Theme.primary
                }

                Text {
                    text: "right-click bar icon to toggle dnd"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeXs
                    color: Theme.textSecondary
                    Layout.fillWidth: true
                }

                Text {
                    visible: root.notifCount > 0
                    text: "mid-click card to dismiss"
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeXs
                    color: Theme.textSecondary
                    opacity: 0.75
                }
            }
        }
    }
}
