import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import ".."
import "../controls"

PanelWindow {
    id: pinRoot

    required property var modelData
    readonly property var pinData: modelData

    screen: {
        let screens = Quickshell.screens || [];
        for (let i = 0; i < screens.length; i++) {
            if (screens[i].name === pinData.screenName) return screens[i];
        }
        return ScreenshotService.getFocusedScreen ? (ScreenshotService.getFocusedScreen() || screens[0]) : screens[0];
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    focusable: false
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell:screenshot"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region {
        item: pinCard
    }

    readonly property real cardScale: Math.max(0.35, Math.min(3.0, Number(pinData.scale ?? 1.0)))
    readonly property real baseW: Math.max(120, Number(pinData.width ?? 420))
    readonly property real baseH: Math.max(80, Number(pinData.height ?? 280))
    readonly property real targetW: Math.max(120, Math.min(pinRoot.width - 24, Math.round(baseW * cardScale)))
    readonly property real targetH: Math.max(80, Math.min(pinRoot.height - 24, Math.round(baseH * cardScale)))

    property real cardX: pinData.x >= 0
        ? pinData.x
        : Math.max(20, Math.round((pinRoot.width - targetW) / 2))
    property real cardY: pinData.y >= 0
        ? pinData.y
        : Math.max(48, Math.round((pinRoot.height - targetH) / 2))

    property bool justCopied: false

    Timer {
        id: copyTimer
        interval: 1000
        onTriggered: pinRoot.justCopied = false
    }

    component PinCtrlBtn: Rectangle {
        id: ctrl
        property string icon: ""
        property string label: ""
        property bool danger: false
        signal clicked()

        height: 22
        implicitWidth: row.implicitWidth + (label !== "" ? 10 : 8)
        radius: Theme.radiusPill
        color: {
            if (m.pressed) return danger ? Theme.error : Theme.primary;
            if (m.containsMouse) return danger ? Theme.error_overlay : Theme.primary_overlay;
            return Theme.alpha(Theme.surface_container_highest, 0.88);
        }
        border.width: 1
        border.color: m.containsMouse ? (danger ? Theme.error : Theme.primary) : Theme.outline_variant

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 3

            Text {
                visible: ctrl.icon !== ""
                text: ctrl.icon
                font.family: Theme.fontIcon
                font.variableAxes: Theme.iconAxes
                font.pixelSize: 11
                color: m.pressed ? (ctrl.danger ? Theme.on_error : Theme.on_primary) : (ctrl.danger ? Theme.error : Theme.on_surface)
            }

            Text {
                visible: ctrl.label !== ""
                text: ctrl.label
                font.family: Theme.fontMono
                font.variableAxes: Theme.monoAxes
                font.pixelSize: 9
                font.weight: Theme.monoWeightBold
                color: m.pressed ? (ctrl.danger ? Theme.on_error : Theme.on_primary) : Theme.on_surface
            }
        }

        MouseArea {
            id: m
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ctrl.clicked()
        }
    }

    Rectangle {
        id: pinCard
        x: Math.max(4, Math.min(pinRoot.width - width - 4, pinRoot.cardX))
        y: Math.max(4, Math.min(pinRoot.height - height - 4, pinRoot.cardY))
        width: pinRoot.targetW
        height: pinRoot.targetH
        radius: Theme.radiusMd
        color: Theme.surface_container_lowest
        border.width: dragMouse.containsMouse || dragMouse.pressed ? 2 : 1
        border.color: dragMouse.containsMouse || dragMouse.pressed ? Theme.primary : Theme.outline_variant
        opacity: Number(pinData.opacity ?? 1.0)
        clip: true

        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

        Image {
            anchors.fill: parent
            anchors.margins: 1
            source: pinData.path ? ("file://" + pinData.path) : ""
            fillMode: Image.PreserveAspectFit
            smooth: true
            cache: false
        }

        // full-card drag + scroll-to-zoom + middle-click close
        MouseArea {
            id: dragMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

            property real pressOriginX: 0
            property real pressOriginY: 0
            property real startCardX: 0
            property real startCardY: 0

            onPressed: (mouse) => {
                if (mouse.button === Qt.MiddleButton) {
                    ScreenshotService.unpin(pinData.id);
                    return;
                }
                if (mouse.button === Qt.RightButton) {
                    let cur = Number(pinData.opacity ?? 1.0);
                    let nxt = cur > 0.85 ? 0.72 : (cur > 0.55 ? 0.42 : 1.0);
                    ScreenshotService.updatePin(pinData.id, { opacity: nxt });
                    return;
                }
                pressOriginX = pinCard.x + mouse.x;
                pressOriginY = pinCard.y + mouse.y;
                startCardX = pinCard.x;
                startCardY = pinCard.y;
            }

            onPositionChanged: (mouse) => {
                if (!(mouse.buttons & Qt.LeftButton)) return;
                let gx = pinCard.x + mouse.x;
                let gy = pinCard.y + mouse.y;
                let nx = startCardX + (gx - pressOriginX);
                let ny = startCardY + (gy - pressOriginY);
                pinRoot.cardX = Math.max(4, Math.min(pinRoot.width - pinCard.width - 4, nx));
                pinRoot.cardY = Math.max(4, Math.min(pinRoot.height - pinCard.height - 4, ny));
            }

            onReleased: (mouse) => {
                if (mouse.button === Qt.LeftButton) {
                    ScreenshotService.updatePin(pinData.id, { x: pinRoot.cardX, y: pinRoot.cardY });
                }
            }

            onWheel: (wheel) => {
                let delta = wheel.angleDelta.y > 0 ? 0.1 : -0.1;
                let nxt = Math.max(0.35, Math.min(3.0, Math.round((pinRoot.cardScale + delta) * 100) / 100));
                ScreenshotService.updatePin(pinData.id, { scale: nxt, x: pinCard.x, y: pinCard.y });
            }
        }

        // floating hover toolbar
        Rectangle {
            visible: dragMouse.containsMouse || toolbarHover.containsMouse
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 6
            height: 28
            implicitWidth: ctrlRow.implicitWidth + 8
            radius: Theme.radiusPill
            color: Theme.alpha(Theme.surface_container_highest, 0.92)
            border.color: Theme.outline_variant
            border.width: 1
            z: 5

            MouseArea {
                id: toolbarHover
                anchors.fill: parent
                hoverEnabled: true
                z: -1
            }

            RowLayout {
                id: ctrlRow
                anchors.centerIn: parent
                spacing: 4

                PinCtrlBtn {
                    label: Math.round(pinRoot.cardScale * 100) + "%"
                    onClicked: ScreenshotService.updatePin(pinData.id, { scale: 1.0 })
                }

                PinCtrlBtn {
                    icon: Theme.iconEye
                    label: Math.round(Number(pinData.opacity ?? 1.0) * 100) + "%"
                    onClicked: {
                        let cur = Number(pinData.opacity ?? 1.0);
                        let nxt = cur > 0.85 ? 0.72 : (cur > 0.55 ? 0.42 : 1.0);
                        ScreenshotService.updatePin(pinData.id, { opacity: nxt });
                    }
                }

                PinCtrlBtn {
                    icon: Theme.iconCopy
                    label: pinRoot.justCopied ? "ok" : ""
                    onClicked: {
                        Quickshell.execDetached(["python3", ScreenshotService.scriptPath, "copy", pinData.path]);
                        pinRoot.justCopied = true;
                        copyTimer.restart();
                    }
                }

                PinCtrlBtn {
                    icon: Theme.iconEdit
                    onClicked: ScreenshotService.editFile(pinData.path)
                }

                PinCtrlBtn {
                    icon: Theme.iconFrame
                    onClicked: ScreenshotService.runQuickPrettify(pinData.path)
                }

                PinCtrlBtn {
                    icon: Theme.iconClose
                    danger: true
                    onClicked: ScreenshotService.unpin(pinData.id)
                }
            }
        }
    }
}
