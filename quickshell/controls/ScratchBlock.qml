// ScratchBlock.qml - Material You studio widget card styled to match Theme.qml
import QtQuick
import QtQuick.Layouts
import ".."
import "../services"

Item {
    id: root

    required property string blockId
    property string zoneId: "left"
    property int index: 0
    property bool isDragged: false
    property bool isVisibleInBar: true

    signal dragStarted(real mouseX, real mouseY)
    signal dragUpdated(real globalX, real globalY)
    signal dragFinished()
    signal dragCanceled()
    signal shiftZoneRequested(string targetZone)
    signal moveStepRequested(int delta)
    signal visibilityToggled()
    signal removeRequested()

    readonly property var blockInfo: PresetService?.getBlockInfo(root.blockId)
    readonly property color blockColor: root.blockInfo?.color ?? Theme.primary
    readonly property string blockName: root.blockInfo?.name ?? root.blockId
    readonly property string blockIcon: root.blockInfo?.icon ?? (Theme?.iconGrid ?? "view-grid")
    readonly property string blockCategory: root.blockInfo?.category ?? "tools"

    implicitWidth: 320
    implicitHeight: 44
    height: 44

    // Surface Container Card matching Theme.qml
    Rectangle {
        id: cardBg
        anchors.fill: parent
        radius: Theme?.radiusSm ?? 6
        color: {
            if (root.isDragged) return Qt.rgba(Theme?.surface_container_highest?.r ?? 0.2, Theme?.surface_container_highest?.g ?? 0.2, Theme?.surface_container_highest?.b ?? 0.2, 0.45);
            if (blockMouse.containsMouse) return Theme.surface_container_high;
            return Theme.surface_container;
        }
        border.width: 1
        border.color: {
            if (root.isDragged) return Theme.primary;
            if (blockMouse.containsMouse) return Qt.rgba(root.blockColor.r, root.blockColor.g, root.blockColor.b, 0.6);
            return Theme?.outline_variant ?? Qt.rgba(1, 1, 1, 0.08);
        }

        // Left accent indicator strip matching category color
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 4
            width: 3
            radius: 1.5
            color: root.blockColor
            opacity: root.isVisibleInBar ? 1.0 : 0.35
        }
    }

    MouseArea {
        id: blockMouse
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: pressedLocal || root.isDragged
        cursorShape: root.isDragged ? Qt.ClosedHandCursor : Qt.OpenHandCursor

        property real pressX: 0
        property real pressY: 0
        property bool pressedLocal: false

        onPressed: (mouse) => {
            if (mouse.button !== Qt.LeftButton) return;
            pressX = mouse.x;
            pressY = mouse.y;
            pressedLocal = true;
        }

        onPositionChanged: (mouse) => {
            if (!pressedLocal) return;
            if (!root.isDragged) {
                if (Math.hypot(mouse.x - pressX, mouse.y - pressY) > 5) {
                    root.dragStarted(mouse.x, mouse.y);
                }
            } else {
                let p = root.mapToItem(null, mouse.x, mouse.y);
                root.dragUpdated(p.x, p.y);
            }
        }

        onReleased: {
            if (root.isDragged) root.dragFinished();
            pressedLocal = false;
        }

        onCanceled: {
            if (root.isDragged) root.dragCanceled();
            pressedLocal = false;
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 8
        spacing: 8

        // Drag grip handle
        Text {
            text: "⠿"
            font.family: Theme?.fontFamily
            font.pixelSize: 13
            color: Theme.on_surface_variant
        }

        // Category icon badge
        Rectangle {
            Layout.preferredWidth: 26
            Layout.preferredHeight: 26
            radius: Theme?.radiusSm ?? 6
            color: Qt.rgba(root.blockColor.r, root.blockColor.g, root.blockColor.b, 0.15)
            border.color: Qt.rgba(root.blockColor.r, root.blockColor.g, root.blockColor.b, 0.35)
            border.width: 1

            Icon {
                anchors.centerIn: parent
                source: root.blockIcon
                size: 14
                color: root.blockColor
            }
        }

        // Title and category subtitle
        ColumnLayout {
            spacing: 1
            Layout.fillWidth: true

            Text {
                text: root.blockName
                font.family: Theme?.fontFamily
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: root.isVisibleInBar ? Theme.on_surface : Theme.on_surface_variant
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: root.blockCategory
                font.family: Theme?.fontFamily
                font.pixelSize: 9
                color: Theme.on_surface_variant
            }
        }

        // Action controls
        RowLayout {
            spacing: 3
            opacity: blockMouse.containsMouse ? 1.0 : 0.75

            // Shift Left
            Rectangle {
                visible: root.zoneId === "center" || root.zoneId === "right"
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                radius: Theme?.radiusSm ?? 4
                color: shiftLMouse.containsMouse ? Theme.surface_container_highest : Theme.surface_container_low
                border.width: 1
                border.color: shiftLMouse.containsMouse ? Theme.outline_variant : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "◀"
                    font.pixelSize: 8
                    color: Theme.on_surface
                }

                MouseArea {
                    id: shiftLMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.shiftZoneRequested(root.zoneId === "right" ? "center" : "left")
                }
            }

            // Move Up
            Rectangle {
                visible: root.index > 0
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                radius: Theme?.radiusSm ?? 4
                color: upMouse.containsMouse ? Theme.surface_container_highest : Theme.surface_container_low
                border.width: 1
                border.color: upMouse.containsMouse ? Theme.outline_variant : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "▲"
                    font.pixelSize: 8
                    color: Theme.on_surface
                }

                MouseArea {
                    id: upMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.moveStepRequested(-1)
                }
            }

            // Move Down
            Rectangle {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                radius: Theme?.radiusSm ?? 4
                color: downMouse.containsMouse ? Theme.surface_container_highest : Theme.surface_container_low
                border.width: 1
                border.color: downMouse.containsMouse ? Theme.outline_variant : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "▼"
                    font.pixelSize: 8
                    color: Theme.on_surface
                }

                MouseArea {
                    id: downMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.moveStepRequested(1)
                }
            }

            // Shift Right
            Rectangle {
                visible: root.zoneId === "left" || root.zoneId === "center"
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                radius: Theme?.radiusSm ?? 4
                color: shiftRMouse.containsMouse ? Theme.surface_container_highest : Theme.surface_container_low
                border.width: 1
                border.color: shiftRMouse.containsMouse ? Theme.outline_variant : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "▶"
                    font.pixelSize: 8
                    color: Theme.on_surface
                }

                MouseArea {
                    id: shiftRMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.shiftZoneRequested(root.zoneId === "left" ? "center" : "right")
                }
            }

            // Eye visibility toggle
            Rectangle {
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                radius: Theme?.radiusSm ?? 4
                color: eyeMouse.containsMouse ? Theme.surface_container_highest : (root.isVisibleInBar ? Theme.surface_container_low : Theme.error_overlay)
                border.width: 1
                border.color: root.isVisibleInBar ? (eyeMouse.containsMouse ? Theme.outline_variant : "transparent") : Theme.error

                Icon {
                    anchors.centerIn: parent
                    source: root.isVisibleInBar ? (Theme?.iconEye ?? "view-visible") : (Theme?.iconEyeOff ?? "view-hidden")
                    size: 12
                    color: root.isVisibleInBar ? Theme.on_surface : Theme.error
                }

                MouseArea {
                    id: eyeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.visibilityToggled()
                }
            }

            // Remove / detach
            Rectangle {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                radius: Theme?.radiusSm ?? 4
                color: rmMouse.containsMouse ? Theme.error_container : Theme.surface_container_low
                border.width: 1
                border.color: rmMouse.containsMouse ? Theme.error : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    color: rmMouse.containsMouse ? Theme.on_error_container : Theme.on_surface_variant
                }

                MouseArea {
                    id: rmMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.removeRequested()
                }
            }
        }
    }
}
