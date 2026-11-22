// BentoBox.qml
import QtQuick
import QtQuick.Layouts
import ".."

Rectangle {
    id: root

    property alias contentItem: contentContainer.data
    property bool active: false

    color: Theme.alpha(Theme.surface_container, Theme.surfaceOpacity)
    opacity: Theme.cardOpacity
    border.color: active ? Theme.primary : Theme.outline_variant
    border.width: 1
    radius: Theme.radiusSm > 2 ? Theme.radiusSm : 4

    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
    Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
    Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutQuad } }

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
        anchors.margins: Theme.widgetSpacing ?? 4
    }
}
