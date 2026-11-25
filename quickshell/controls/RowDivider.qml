import QtQuick
import ".."

Rectangle {
    width: parent ? parent.width - 12 : 0
    anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
    height: 1
    color: Theme.widgetBorder
}
