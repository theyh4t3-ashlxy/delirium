import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import ".."
import "../controls"

BarPill {
    id: trayRoot

    readonly property var rawItems: (SystemTray.items && SystemTray.items.values) ? SystemTray.items.values : []
    readonly property int itemCount: rawItems.length
    readonly property int collapseThreshold: 3
    readonly property int collapsedMax: 2
    property bool trayCollapsed: false
    readonly property bool isCollapsedActive: trayCollapsed && itemCount > collapseThreshold
    readonly property var displayedItems: isCollapsedActive ? rawItems.slice(0, collapsedMax) : rawItems

    property var hoveredItem: null
    property Item hoveredAnchor: null

    visible: Settings?.showSystemTray ?? true
    pressScale: false

    readonly property int activeSlotCount: itemCount === 0
        ? 0
        : (displayedItems.length + (itemCount > collapseThreshold ? 1 : 0))

    readonly property real trayExtent: itemCount > 0
        ? (activeSlotCount * 24 + Math.max(0, activeSlotCount - 1) * 4 + 12)
        : pillSize

    implicitWidth: Theme.isVertical ? pillSize : trayExtent
    implicitHeight: Theme.isVertical ? trayExtent : pillSize

    Behavior on implicitWidth { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
    Behavior on implicitHeight { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }

    function showTooltipFor(itemData, anchorItem) {
        trayRoot.hoveredItem = itemData;
        trayRoot.hoveredAnchor = anchorItem;
    }

    function hideTooltipFor(anchorItem) {
        if (trayRoot.hoveredAnchor === anchorItem) {
            trayRoot.hoveredItem = null;
            trayRoot.hoveredAnchor = null;
        }
    }

    Text {
        anchors.centerIn: parent
        visible: trayRoot.itemCount === 0
        text: Theme.iconTray
        font.family: Theme.isTextIconSet ? Theme.fontFamily : Theme.fontIcon
        font.variableAxes: Theme.iconAxes
        font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeXs : Theme.fontSizeSm
        color: Theme.on_surface_variant
        opacity: 0.65
    }

    component TrayItemButton: Rectangle {
        id: btnRoot
        required property var modelData

        width: 24
        height: 24
        radius: Theme.radiusSm
        color: tMouse.pressed
            ? Theme.widgetActive
            : (menuAnchor.visible
                ? Theme.primary_overlay
                : (tMouse.containsMouse ? Theme.widgetHover : "transparent"))
        border.color: menuAnchor.visible
            ? Theme.primary
            : (tMouse.containsMouse ? Theme.outline_variant : "transparent")
        border.width: 1

        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

        IconImage {
            anchors.centerIn: parent
            width: 16
            height: 16
            source: {
                let ic = btnRoot.modelData?.icon || "";
                if (!ic) return "";
                if (ic.startsWith("/") || ic.startsWith("file://") || ic.startsWith("image://")) return ic;
                return Quickshell.iconPath(ic);
            }
            scale: tMouse.containsMouse ? 1.08 : 1.0
            Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
        }

        QsMenuAnchor {
            id: menuAnchor
            menu: btnRoot.modelData?.menu ?? null
        }

        MouseArea {
            id: tMouse
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onEntered: trayRoot.showTooltipFor(btnRoot.modelData, btnRoot)
            onExited: trayRoot.hideTooltipFor(btnRoot)

            onClicked: (mouse) => {
                if (!btnRoot.modelData) return;
                trayRoot.hideTooltipFor(btnRoot);
                if (mouse.button === Qt.RightButton || btnRoot.modelData.onlyMenu) {
                    menuAnchor.open();
                } else if (mouse.button === Qt.MiddleButton) {
                    btnRoot.modelData.secondaryActivate();
                } else {
                    btnRoot.modelData.activate();
                }
            }

            onWheel: (wheel) => {
                if (!btnRoot.modelData) return;
                if (Math.abs(wheel.angleDelta.y) > 0) {
                    btnRoot.modelData.scroll(Math.round(wheel.angleDelta.y), false);
                } else if (Math.abs(wheel.angleDelta.x) > 0) {
                    btnRoot.modelData.scroll(Math.round(wheel.angleDelta.x), true);
                }
            }
        }
    }

    component TrayCollapseBtn: Rectangle {
        width: 24
        height: 24
        radius: Theme.radiusSm
        visible: trayRoot.itemCount > trayRoot.collapseThreshold
        color: foldMouse.containsMouse
            ? Theme.widgetHover
            : (trayRoot.isCollapsedActive ? Theme.primary_overlay : "transparent")
        border.color: trayRoot.isCollapsedActive ? Theme.alpha(Theme.primary, 0.5) : "transparent"
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: trayRoot.isCollapsedActive
                ? ("+" + (trayRoot.itemCount - trayRoot.collapsedMax))
                : (Theme.isVertical ? Theme.iconChevronUp : Theme.iconChevronLeft)
            font.family: trayRoot.isCollapsedActive ? Theme.fontMono : Theme.fontIcon
            font.variableAxes: Theme.iconAxes
            font.pixelSize: trayRoot.isCollapsedActive ? 10 : 12
            font.weight: Font.Bold
            color: trayRoot.isCollapsedActive ? Theme.primary : Theme.on_surface_variant
        }

        MouseArea {
            id: foldMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: trayRoot.trayCollapsed = !trayRoot.trayCollapsed
        }
    }

    Column {
        id: trayCol
        visible: Theme.isVertical && trayRoot.itemCount > 0
        anchors.centerIn: parent
        spacing: 4

        Repeater {
            model: trayRoot.displayedItems
            TrayItemButton {}
        }

        TrayCollapseBtn {}
    }

    Row {
        id: trayRow
        visible: !Theme.isVertical && trayRoot.itemCount > 0
        anchors.centerIn: parent
        spacing: 4

        Repeater {
            model: trayRoot.displayedItems
            TrayItemButton {}
        }

        TrayCollapseBtn {}
    }

    CustomTooltip {
        anchorItem: trayRoot.hoveredAnchor ?? trayRoot
        active: trayRoot.hoveredItem !== null && trayRoot.hoveredAnchor !== null
        delay: 260
        text: (trayRoot.hoveredItem?.tooltipTitle || trayRoot.hoveredItem?.title || trayRoot.hoveredItem?.id || "").trim()
        subtext: (trayRoot.hoveredItem?.tooltipDescription || "").trim()
    }
}
