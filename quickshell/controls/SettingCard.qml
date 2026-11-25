import QtQuick
import QtQuick.Layouts
import ".."

Rectangle {
    default property alias content: cardCol.data
    Layout.fillWidth: true
    width: parent ? parent.width : undefined
    implicitHeight: cardCol.implicitHeight + (Theme.widgetPaddingV * 2) + 12
    radius: Theme.radiusMd
    color: Theme.cardBg
    border.color: Theme.cardBorder
    border.width: Theme.popupBorderWidth
    clip: true

    Rectangle {
        visible: Theme.isGlass
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Theme.glassHighlight
    }

    Column {
        id: cardCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Theme.widgetPaddingH + 2
        anchors.rightMargin: Theme.widgetPaddingH + 2
        anchors.topMargin: Theme.widgetPaddingV + 6
        spacing: 6
    }
}
