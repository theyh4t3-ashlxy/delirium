import QtQuick
import Quickshell
import Quickshell.Widgets
import ".."

Rectangle {
    id: root

    property string icon: ""
    property int iconSize: Theme.fontSizeMd
    property color iconColor: Theme.on_surface
    property string tooltip: ""
    property bool highlighted: false

    signal clicked()

    implicitWidth: iconSize + Theme.widgetPaddingH * 2
    implicitHeight: Theme.barHeight - 8

    radius: Theme.widgetRadius
    color: mouseArea.pressed
        ? Theme.widgetActive
        : mouseArea.containsMouse
            ? Theme.widgetHover
            : highlighted
                ? Theme.primary_overlay
                : "transparent"

    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    readonly property string resolvedIcon: {
        let s = root.icon;
        if (!s || s === "") return "";
        if (s.startsWith("/") || s.startsWith("file://") || s.startsWith("image://") || s.startsWith("qrc:/")) return s;
        if (Theme?.resolveIconSource) return Theme.resolveIconSource(s);
        return Quickshell.iconPath(s);
    }

    IconImage {
        id: iconImg
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        source: root.resolvedIcon
        visible: root.resolvedIcon !== "" && status !== Image.Error
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
