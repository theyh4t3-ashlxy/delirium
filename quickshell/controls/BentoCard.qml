// BentoCard.qml
import QtQuick
import QtQuick.Layouts
import ".."

Rectangle {
    id: root

    property alias contentItem: contentContainer.data
    property bool hoverLift: Settings?.bentoHoverLift ?? true
    property real elevationProgress: hoverHandler.hovered ? 1.0 : 0.0

    color: Theme.alpha(Theme.cardBg, Theme.cardOpacity * Theme.surfaceOpacity)
    border.color: Theme.isCyberNeon ? Theme.primary : Theme.cardBorder
    border.width: 1
    radius: Theme.radiusMd > 4 ? Theme.radiusMd : 8
    scale: (hoverLift && hoverHandler.hovered) ? 1.015 : 1.0

    Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutQuad } }
    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
    Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

    HoverHandler {
        id: hoverHandler
    }

    // Glass highlight pass
    Rectangle {
        visible: (Theme.glassmorphismLevel ?? 0.85) > 0.1
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Theme.glassHighlight
        opacity: Theme.glassmorphismLevel ?? 0.85
        z: 2
    }

    Item {
        id: contentContainer
        anchors.fill: parent
        anchors.margins: Theme.widgetPaddingH ?? 8
    }
}
