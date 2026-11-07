import QtQuick
import QtQuick.Layouts
import ".."
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland

Rectangle {
    id: windowTitleRoot

    property var barScreen: null
    property var barMonitor: null

    readonly property var activeTop: Hyprland?.activeToplevel
    readonly property string rawTitle: (activeTop?.title ?? activeTop?.wayland?.title ?? "").trim()
    readonly property string rawClass: {
        if (!activeTop) return "";
        let ipc = activeTop.lastIpcObject;
        let c = ipc ? (ipc["class"] || ipc.initialClass || "") : "";
        if (!c && activeTop.wayland) c = activeTop.wayland.appId;
        if (!c && activeTop.handle) c = activeTop.handle.appId;
        return (c || "").trim();
    }
    readonly property bool isDesktop: !activeTop || rawTitle.length === 0
    readonly property string fallbackText: Theme?.getFlavor
        ? Theme.getFlavor("system", (Theme?.getVibe ? Theme.getVibe(Theme?.kaoEmpty, Theme?.iconDistro ?? Theme?.iconArch ?? "desktop", "desktop") : "desktop"))
        : "desktop"
    readonly property string displayTitle: (!isDesktop ? rawTitle : fallbackText).toLowerCase()

    // let Theme.qml do the heavy lifting instead of duplicating the desktop entry crawl here
    readonly property string resolvedIcon: (!isDesktop && rawClass && Theme?.resolveAppIcon)
        ? Theme.resolveAppIcon(rawClass)
        : ""
    readonly property bool showAppIcon: (Settings?.windowTitleShowIcon ?? true)
    readonly property bool hasAppIcon: showAppIcon && resolvedIcon !== ""
    readonly property string iconName: resolvedIcon

    // invisible ghost text just to figure out how wide this pill wants to be
    Text {
        id: titleMeasure
        visible: false
        text: windowTitleRoot.displayTitle
        font.family: Theme?.fontFamily ?? "sans-serif"
        font.pixelSize: Theme?.fontSizeSm ?? 12
    }

    readonly property real iconTotalWidth: showAppIcon ? 22 : 0
    readonly property real naturalWidth: titleMeasure.implicitWidth + iconTotalWidth + 24
    readonly property real desiredWidth: {
        if (Theme?.isVertical ?? false) return 0;
        let mode = Settings?.windowTitleMode ?? "auto";
        let maxW = Settings?.windowTitleMaxWidth ?? 760;
        if (mode === "compact") {
            return Math.max(50, Math.min(naturalWidth, 260));
        }
        return Math.max(50, Math.min(naturalWidth, maxW));
    }

    visible: !(Theme?.isVertical ?? false) && (Settings?.showWindowTitle ?? true)
    implicitWidth: (Theme?.isVertical ?? false) ? 0 : desiredWidth
    implicitHeight: (Theme?.isVertical ?? false) ? 0 : ((Theme?.barHeight ?? 48) - 8)
    width: parent ? parent.width : implicitWidth
    radius: Theme?.radiusPill ?? 999
    clip: true
    color: wtMouse.containsMouse ? (Theme?.pillHover ?? "#33ffffff") : (Theme?.pillBg ?? "#1a000000")
    border.color: Theme?.pillBorder ?? "transparent"
    border.width: (Theme?.pillBorder ?? "transparent") === "transparent" ? 0 : 1

    Behavior on color { ColorAnimation { duration: Theme?.animFast ?? 150; easing.type: Theme?.animColorEasing ?? Easing.OutQuad } }
    Behavior on border.color { ColorAnimation { duration: Theme?.animFast ?? 150; easing.type: Theme?.animColorEasing ?? Easing.OutQuad } }
    Behavior on implicitWidth { NumberAnimation { duration: Theme?.animFast ?? 150; easing.type: Theme?.animEasing ?? Easing.OutQuad } }

    WindowTitlePopup {
        id: winPopup
        screen: windowTitleRoot.barScreen
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 6

        IconImage {
            id: appIcon
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
            width: 16
            height: 16
            Layout.alignment: Qt.AlignVCenter
            source: windowTitleRoot.resolvedIcon
            visible: windowTitleRoot.hasAppIcon
        }

        Text {
            id: fallbackIcon
            Layout.alignment: Qt.AlignVCenter
            text: windowTitleRoot.isDesktop ? (Theme.iconDistro ?? Theme.iconArch ?? "") : (Theme.iconTerminal ?? "")
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontSizeSm
            color: Theme.primary
            visible: windowTitleRoot.showAppIcon && (!appIcon.visible || appIcon.status === Image.Error)
        }

        Text {
            id: titleText
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            text: windowTitleRoot.displayTitle
            font.family: Theme?.fontFamily ?? "sans-serif"
            font.pixelSize: Theme?.fontSizeSm ?? 12
            color: Theme?.on_surface ?? "#ffffff"
            elide: Text.ElideRight
            maximumLineCount: 1
            opacity: (!windowTitleRoot.isDesktop) ? 1.0 : 0.6

            Behavior on opacity { NumberAnimation { duration: Theme?.animFast ?? 150; easing.type: Theme?.animEasing ?? Easing.OutQuad } }
        }
    }

    function updatePopupPos() {
        let pt = windowTitleRoot.mapToItem(null, 0, 0);
        winPopup.targetRelativeX = pt ? (pt.x + (windowTitleRoot.width / 2)) : 0;
    }

    HoverFlyoutHandler {
        popup: winPopup
        mouseArea: wtMouse
        updatePos: () => windowTitleRoot.updatePopupPos()
    }

    MouseArea {
        id: wtMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        z: 10
        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                windowTitleRoot.updatePopupPos();
                if (!winPopup.open) {
                    winPopup.pinned = true;
                    winPopup.open = true;
                } else if (!winPopup.pinned) {
                    winPopup.pinned = true;
                } else {
                    winPopup.pinned = false;
                    winPopup.open = false;
                }
            } else if (mouse.button === Qt.RightButton) {
                winPopup.dispatchWindowAction("close");
            } else if (mouse.button === Qt.MiddleButton) {
                winPopup.dispatchWindowAction("float");
            }
        }
    }

    Connections {
        target: Settings
        function onRequestWindowTitleToggle() {
            if (!windowTitleRoot.barScreen || Quickshell.screens.length <= 1 || (windowTitleRoot.barMonitor && Hyprland.focusedMonitor && windowTitleRoot.barMonitor.id === Hyprland.focusedMonitor.id)) {
                windowTitleRoot.updatePopupPos();
                winPopup.pinned = !winPopup.open;
                winPopup.open = !winPopup.open;
            }
        }
        function onRequestWindowTitleOpen() {
            if (!windowTitleRoot.barScreen || Quickshell.screens.length <= 1 || (windowTitleRoot.barMonitor && Hyprland.focusedMonitor && windowTitleRoot.barMonitor.id === Hyprland.focusedMonitor.id)) {
                windowTitleRoot.updatePopupPos();
                winPopup.pinned = true;
                winPopup.open = true;
            }
        }
        function onRequestWindowTitleClose() {
            winPopup.pinned = false;
            winPopup.open = false;
        }
    }
}
