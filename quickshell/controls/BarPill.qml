// BarPill.qml — shared bar module container with uniform hover/active/alert/pressed states
import QtQuick
import ".."

Rectangle {
    id: pillRoot

    property var barScreen: null
    property var barMonitor: null

    property bool active: false
    property bool alert: false
    property bool hovered: false
    property bool pressed: false
    property bool pressScale: true

    property int pillSize: Math.max(20, (Theme?.barHeight ?? 48) - 8)
    property color normalBg: Theme?.barPillBg ?? "transparent"
    property color hoverBg: Theme?.barPillHover ?? Theme?.widgetHover
    property color pressedBg: Theme?.widgetActive ?? Theme?.primary_overlay
    property color activeBg: Theme?.primary_overlay ?? Theme?.widgetActive
    property color alertBg: Theme?.error_overlay ?? activeBg

    property color normalBorder: Theme?.barPillBorder ?? "transparent"
    property color hoverBorder: normalBorder
    property color activeBorder: Theme?.primary ?? "transparent"
    property color alertBorder: Theme?.error ?? activeBorder

    implicitHeight: pillSize
    implicitWidth: pillSize
    radius: Theme?.barWidgetRadius ?? 999

    color: {
        if (alert) return pressed ? pressedBg : alertBg;
        if (pressed) return pressedBg;
        if (active) return activeBg;
        if (hovered) return hoverBg;
        return normalBg;
    }

    border.color: {
        if (alert) return alertBorder;
        if (active) return activeBorder;
        if (hovered) return hoverBorder;
        return normalBorder;
    }
    border.width: (border.color === "transparent" || border.color.a === 0) ? 0 : 1

    scale: (pressScale && pressed) ? 0.96 : 1.0

    Behavior on color { ColorAnimation { duration: Theme?.animFast ?? 150; easing.type: Theme?.animColorEasing ?? Easing.OutQuad } }
    Behavior on border.color { ColorAnimation { duration: Theme?.animFast ?? 150; easing.type: Theme?.animColorEasing ?? Easing.OutQuad } }
    Behavior on scale { NumberAnimation { duration: Theme?.animFast ?? 150; easing.type: Theme?.animEasing ?? Easing.OutQuad } }

    function anchorToPopup(popup) {
        if (!popup) return;
        let pt = pillRoot.mapToItem(null, 0, 0);
        if (!pt) return;
        popup.targetRelativeX = pt.x + (pillRoot.width / 2);
        popup.targetRelativeY = pt.y + (pillRoot.height / 2);
    }
}
