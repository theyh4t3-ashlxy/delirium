import QtQuick
import ".."

Rectangle {
    id: stRoot
    required property Flickable target
    anchors.right: target ? target.right : undefined
    anchors.top: target ? target.top : undefined
    anchors.bottom: target ? target.bottom : undefined
    anchors.margins: 2
    width: 4
    radius: 2
    color: "transparent"
    visible: target ? (target.visible && target.visibleArea.heightRatio < 1.0) : false

    Rectangle {
        width: parent.width
        readonly property real trackH: stRoot.height
        readonly property real thumbH: Math.max(20, Math.min(trackH, (stRoot.target ? stRoot.target.visibleArea.heightRatio : 1) * trackH))
        height: thumbH
        y: Math.max(0, Math.min(trackH - thumbH, (stRoot.target ? stRoot.target.visibleArea.yPosition : 0) * trackH))
        radius: 2
        color: Theme.primary
        opacity: 0.75
    }
}
