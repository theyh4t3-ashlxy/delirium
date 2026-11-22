import QtQuick
import Quickshell
import Quickshell.Widgets
import ".."

Item {
    id: root

    property string source: ""
    property int size: Theme.fontSizeMd
    property bool active: true
    property color color: Theme.on_surface
    property string fallbackSource: ""

    implicitWidth: root.size
    implicitHeight: root.size
    width: root.size
    height: root.size

    readonly property string resolvedSource: {
        let s = root.source;
        if (!s || s === "") return "";
        if (s.startsWith("/") || s.startsWith("file://") || s.startsWith("image://") || s.startsWith("qrc:/")) return s;
        if (Theme?.resolveIconSource) return Theme.resolveIconSource(s);
        return Quickshell.iconPath(s);
    }

    readonly property string effectiveSource: {
        if (iconImg.status === Image.Error && root.fallbackSource !== "") {
            let fb = root.fallbackSource;
            if (fb.startsWith("/") || fb.startsWith("file://") || fb.startsWith("image://") || fb.startsWith("qrc:/")) return fb;
            if (Theme?.resolveIconSource) return Theme.resolveIconSource(fb);
            return Quickshell.iconPath(fb);
        }
        return root.resolvedSource;
    }

    readonly property alias status: iconImg.status
    readonly property bool hasError: iconImg.status === Image.Error
    readonly property bool ready: iconImg.status === Image.Ready

    IconImage {
        id: iconImg
        anchors.fill: parent
        source: root.effectiveSource
        visible: root.active && root.effectiveSource !== "" && status !== Image.Error
    }
}
