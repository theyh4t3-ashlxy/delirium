import QtQuick
import QtQuick.Layouts
import ".."
import "../services"

ColumnLayout {
    id: slRoot
    property string title: ""
    property real from: 0
    property real to: 100
    property real value: 0
    property real stepSize: 1
    property string suffix: "px"
    property var formatter: null
    property bool autoSave: true
    signal moved(real val)

    width: parent ? parent.width : 0
    implicitWidth: width
    Layout.fillWidth: true
    spacing: 5

    readonly property string displayText: slRoot.formatter
        ? slRoot.formatter(slRoot.value)
        : ((Math.round(slRoot.value * 100) / 100) + slRoot.suffix)

    readonly property real ratio: slRoot.to > slRoot.from
        ? Math.max(0.0, Math.min(1.0, (slRoot.value - slRoot.from) / (slRoot.to - slRoot.from)))
        : 0.0

    function commitRatio(r) {
        const t = Math.max(0.0, Math.min(1.0, r));
        let raw = slRoot.from + t * (slRoot.to - slRoot.from);
        if (slRoot.stepSize > 0) raw = Math.round(raw / slRoot.stepSize) * slRoot.stepSize;
        raw = Math.max(slRoot.from, Math.min(slRoot.to, raw));
        if (Math.abs(raw - slRoot.value) > 1e-6) {
            slRoot.moved(raw);
            if (slRoot.autoSave && typeof Settings !== "undefined" && Settings?.save) {
                Settings.save();
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Text {
            visible: slRoot.title !== ""
            text: slRoot.title
            font.family: Theme.fontFamily
            font.variableAxes: Theme.sansAxes
            font.pixelSize: Theme.fontSizeXs
            font.weight: Theme.fontWeightDemiBold
            color: Theme.textSecondary
            Layout.fillWidth: true
        }

        Rectangle {
            height: 18
            implicitWidth: valBadge.implicitWidth + 10
            radius: Theme.radiusPill
            color: dragArea.pressed ? Theme.primary_overlay : Theme.widgetBg
            border.color: dragArea.pressed ? Theme.alpha(Theme.primary, 0.5) : Theme.widgetBorder
            border.width: 1

            Text {
                id: valBadge
                anchors.centerIn: parent
                text: slRoot.displayText
                font.family: Theme.fontMono
                font.variableAxes: Theme.monoAxes
                font.pixelSize: Theme.fontSizeXs
                font.weight: Theme.monoWeightBold
                color: Theme.primary
            }
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 20

        Rectangle {
            id: track
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: dragArea.pressed ? 14 : (dragArea.containsMouse ? 11 : 8)
            radius: Theme.radiusPill
            color: Theme.widgetBg
            border.color: dragArea.containsMouse ? Theme.alpha(Theme.primary, 0.35) : Theme.widgetBorder
            border.width: 1

            Behavior on height { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
            Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Math.max(parent.height, parent.width * slRoot.ratio)
                radius: Theme.radiusPill
                color: dragArea.pressed
                    ? Theme.statePress(Theme.primary, Theme.on_primary)
                    : (dragArea.containsMouse ? Theme.stateHover(Theme.primary, Theme.on_primary) : Theme.primary)

                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }
        }

        Rectangle {
            width: dragArea.pressed ? 6 : 4
            height: dragArea.pressed ? 20 : (dragArea.containsMouse ? 17 : 14)
            radius: Theme.radiusPill
            color: Theme.on_surface
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(parent.width - width, (parent.width * slRoot.ratio) - (width / 2)))

            Behavior on width { NumberAnimation { duration: Theme.animFast } }
            Behavior on height { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animExpressiveEasing } }
        }

        MouseArea {
            id: dragArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            preventStealing: true

            onPressed: (mouse) => slRoot.commitRatio(mouse.x / width)
            onPositionChanged: (mouse) => {
                if (pressed) slRoot.commitRatio(mouse.x / width);
            }
            onWheel: (wheel) => {
                let dir = wheel.angleDelta.y > 0 ? 1 : -1;
                let step = slRoot.stepSize > 0 ? slRoot.stepSize : ((slRoot.to - slRoot.from) * 0.05);
                let next = Math.max(slRoot.from, Math.min(slRoot.to, slRoot.value + dir * step));
                if (Math.abs(next - slRoot.value) > 1e-6) {
                    slRoot.moved(next);
                    if (slRoot.autoSave && typeof Settings !== "undefined" && Settings?.save) {
                        Settings.save();
                    }
                }
            }
        }
    }
}
