import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import ".."
import "../controls"

PanelWindow {
    id: hudRoot

    required property var modelData
    screen: modelData

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
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    readonly property bool isTargetMonitor: {
        let cap = ScreenshotService.lastCapture;
        if (ScreenshotService.hudMode === "capture" && cap && cap.screenName) {
            return cap.screenName === hudRoot.screen.name;
        }
        let focused = ScreenshotService.getFocusedScreen ? ScreenshotService.getFocusedScreen() : null;
        return !focused || focused.name === hudRoot.screen.name;
    }

    readonly property bool activeOnScreen: ScreenshotService.hudVisible && isTargetMonitor
    visible: activeOnScreen || hudCard.opacity > 0.01

    mask: Region {
        item: activeOnScreen ? hudCard : null
    }

    readonly property string barPos: (Settings?.barPosition ?? "top").toLowerCase()
    readonly property bool barBottom: barPos === "bottom" || barPos === "down"
    readonly property int barOffset: Theme.barHeight + ((Settings?.barFloating ?? false) ? ((Settings?.barMargin ?? 0) > 0 ? Settings.barMargin : 8) + 8 : 8)

    property bool justCopied: false
    property int remainingMs: 5200
    readonly property int totalDurationMs: ScreenshotService.hudMode === "capture" ? 5600 : 3200

    Timer {
        id: copiedFlashTimer
        interval: 1200
        onTriggered: hudRoot.justCopied = false
    }

    Timer {
        id: hudTickTimer
        interval: 80
        repeat: true
        running: hudRoot.activeOnScreen && !cardHoverMouse.containsMouse && !btnAreaGuard
        onTriggered: {
            hudRoot.remainingMs -= interval;
            if (hudRoot.remainingMs <= 0) {
                ScreenshotService.dismissHud();
            }
        }
    }

    property bool btnAreaGuard: false

    Connections {
        target: ScreenshotService
        function onHudVisibleChanged() {
            if (ScreenshotService.hudVisible) {
                hudRoot.justCopied = false;
                hudRoot.remainingMs = hudRoot.totalDurationMs;
            }
        }
        function onLastCaptureChanged() {
            hudRoot.justCopied = false;
            hudRoot.remainingMs = hudRoot.totalDurationMs;
        }
        function onPickedColorHexChanged() {
            hudRoot.remainingMs = hudRoot.totalDurationMs;
        }
    }

    component HudActionChip: Rectangle {
        id: chip
        property string icon: ""
        property string label: ""
        property bool accent: false
        property bool danger: false
        signal clicked()

        height: 26
        implicitWidth: chipRow.implicitWidth + (label !== "" ? 14 : 10)
        radius: Theme.radiusPill
        color: {
            if (chipMouse.pressed) return danger ? Theme.error : Theme.primary;
            if (chipMouse.containsMouse) return danger ? Theme.error_overlay : Theme.primary_overlay;
            return accent ? Theme.primary_overlay : Theme.widgetBg;
        }
        border.width: 1
        border.color: {
            if (chipMouse.containsMouse) return danger ? Theme.error : Theme.primary;
            return accent ? Theme.alpha(Theme.primary, 0.5) : Theme.widgetBorder;
        }

        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

        RowLayout {
            id: chipRow
            anchors.centerIn: parent
            spacing: 4

            Text {
                visible: chip.icon !== ""
                text: chip.icon
                font.family: Theme.fontIcon
                font.variableAxes: Theme.iconAxes
                font.pixelSize: Theme.fontSizeXs
                color: chipMouse.pressed
                    ? (chip.danger ? Theme.on_error : Theme.on_primary)
                    : (chip.danger ? Theme.error : (chip.accent || chipMouse.containsMouse ? Theme.primary : Theme.on_surface))
            }

            Text {
                visible: chip.label !== ""
                text: chip.label
                font.family: Theme.fontFamily
                font.variableAxes: Theme.sansAxes
                font.pixelSize: Theme.fontSizeXs
                font.weight: chip.accent ? Theme.fontWeightDemiBold : Theme.fontWeightMedium
                color: chipMouse.pressed
                    ? (chip.danger ? Theme.on_error : Theme.on_primary)
                    : (chip.danger ? Theme.error : (chip.accent || chipMouse.containsMouse ? Theme.primary : Theme.on_surface))
            }
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: hudRoot.btnAreaGuard = true
            onExited: hudRoot.btnAreaGuard = false
            onClicked: chip.clicked()
        }
    }

    Rectangle {
        id: hudCard
        readonly property var cap: ScreenshotService.lastCapture
        readonly property bool isCaptureMode: ScreenshotService.hudMode === "capture" && cap !== null
        readonly property bool isColorMode: ScreenshotService.hudMode === "color"

        width: isCaptureMode ? 364 : 290
        height: contentCol.implicitHeight + 20
        radius: Theme.radiusLg
        color: Theme.popupBg
        border.color: Theme.popupBorderColor
        border.width: Theme.popupBorderWidth
        clip: true

        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 18
        anchors.bottomMargin: hudRoot.barBottom ? (hudRoot.barOffset + 12) : 20

        opacity: hudRoot.activeOnScreen ? 1.0 : 0.0
        scale: hudRoot.activeOnScreen ? 1.0 : 0.94
        transformOrigin: Item.BottomRight

        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.animEasing } }
        Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.animEasingEntrance } }

        MouseArea {
            id: cardHoverMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.MiddleButton | Qt.RightButton
            onClicked: (mouse) => {
                if (mouse.button === Qt.MiddleButton || mouse.button === Qt.RightButton) {
                    ScreenshotService.dismissHud();
                }
            }
        }

        ColumnLayout {
            id: contentCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 10
            spacing: 8

            // capture mode body
            RowLayout {
                visible: hudCard.isCaptureMode
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    width: 84
                    height: 58
                    radius: Theme.radiusMd
                    color: Theme.surface_container_highest
                    border.color: thumbMouse.containsMouse ? Theme.primary : Theme.outline_variant
                    border.width: 1
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: hudCard.cap && (hudCard.cap.previewPath || hudCard.cap.destPath)
                            ? ("file://" + (hudCard.cap.previewPath || hudCard.cap.destPath))
                            : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                        cache: false
                    }

                    MouseArea {
                        id: thumbMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: hudRoot.btnAreaGuard = true
                        onExited: hudRoot.btnAreaGuard = false
                        onClicked: {
                            let target = hudCard.cap?.destPath || hudCard.cap?.previewPath;
                            if (target) Quickshell.execDetached(["xdg-open", target]);
                            ScreenshotService.dismissHud();
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: hudRoot.justCopied
                                ? "copied to clipboard"
                                : (hudCard.cap?.prettified ? "prettified capture" : "screenshot ready")
                            font.family: Theme.fontFamily
                            font.variableAxes: Theme.sansAxes
                            font.pixelSize: Theme.fontSizeSm
                            font.weight: Theme.fontWeightBold
                            color: hudRoot.justCopied ? Theme.primary : Theme.on_surface
                            Layout.fillWidth: true
                        }

                        IconButton {
                            icon: Theme.iconClose
                            iconSize: 12
                            implicitWidth: 20
                            implicitHeight: 20
                            onClicked: ScreenshotService.dismissHud()
                        }
                    }

                    Text {
                        text: {
                            if (!hudCard.cap) return "";
                            let dims = hudCard.cap.width + " × " + hudCard.cap.height;
                            let fmt = String(hudCard.cap.format || "png").toUpperCase();
                            let sz = hudCard.cap.sizeText ? (" • " + hudCard.cap.sizeText) : "";
                            let clipState = hudCard.cap.saved ? "saved + clip" : "clipboard only";
                            return dims + " • " + fmt + sz + " • " + clipState;
                        }
                        font.family: Theme.fontMono
                        font.variableAxes: Theme.monoAxes
                        font.pixelSize: 10
                        color: Theme.on_surface_variant
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }

            RowLayout {
                visible: hudCard.isCaptureMode
                Layout.fillWidth: true
                spacing: 5

                HudActionChip {
                    icon: Theme.iconEdit
                    label: "annotate"
                    accent: true
                    onClicked: {
                        let p = hudCard.cap?.destPath || hudCard.cap?.previewPath;
                        if (p) ScreenshotService.editFile(p);
                    }
                }

                HudActionChip {
                    visible: !(hudCard.cap?.prettified ?? false)
                    icon: Theme.iconFrame
                    label: "prettify"
                    onClicked: {
                        let p = hudCard.cap?.destPath || hudCard.cap?.previewPath;
                        if (p) ScreenshotService.runQuickPrettify(p);
                    }
                }

                HudActionChip {
                    icon: Theme.iconPin
                    label: "pin"
                    onClicked: {
                        ScreenshotService.pinLast();
                        ScreenshotService.dismissHud();
                    }
                }

                HudActionChip {
                    icon: Theme.iconCopy
                    label: hudRoot.justCopied ? "copied" : "copy"
                    onClicked: {
                        let p = hudCard.cap?.previewPath || hudCard.cap?.destPath;
                        if (p) {
                            Quickshell.execDetached(["python3", ScreenshotService.scriptPath, "copy", p]);
                            hudRoot.justCopied = true;
                            copiedFlashTimer.restart();
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                HudActionChip {
                    visible: Boolean(hudCard.cap?.saved && hudCard.cap?.destPath)
                    icon: Theme.iconTrash
                    danger: true
                    onClicked: {
                        let p = hudCard.cap?.destPath;
                        if (p) {
                            Quickshell.execDetached(["rm", "-f", "--", p]);
                            ScreenshotService.captureCompleted({});
                        }
                        ScreenshotService.dismissHud();
                    }
                }
            }

            // picked color mode body
            RowLayout {
                visible: hudCard.isColorMode
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    width: 34
                    height: 34
                    radius: Theme.radiusMd
                    color: ScreenshotService.pickedColorHex || Theme.primary
                    border.color: Theme.outline_variant
                    border.width: 1
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: ScreenshotService.pickedColorHex
                        font.family: Theme.fontMono
                        font.variableAxes: Theme.monoAxes
                        font.pixelSize: Theme.fontSizeMd
                        font.weight: Theme.monoWeightBold
                        color: Theme.primary
                    }

                    Text {
                        text: "color copied to clipboard"
                        font.family: Theme.fontFamily
                        font.variableAxes: Theme.sansAxes
                        font.pixelSize: 10
                        color: Theme.on_surface_variant
                    }
                }

                IconButton {
                    icon: Theme.iconClose
                    iconSize: 12
                    implicitWidth: 22
                    implicitHeight: 22
                    onClicked: ScreenshotService.dismissHud()
                }
            }

            // message fallback mode body
            RowLayout {
                visible: !hudCard.isCaptureMode && !hudCard.isColorMode
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: Theme.iconScreenshot
                    font.family: Theme.fontIcon
                    font.variableAxes: Theme.iconAxes
                    font.pixelSize: Theme.fontSizeMd
                    color: Theme.primary
                }

                Text {
                    text: ScreenshotService.hudMessage
                    font.family: Theme.fontFamily
                    font.variableAxes: Theme.sansAxes
                    font.pixelSize: Theme.fontSizeXs
                    color: Theme.on_surface
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                IconButton {
                    icon: Theme.iconClose
                    iconSize: 12
                    implicitWidth: 22
                    implicitHeight: 22
                    onClicked: ScreenshotService.dismissHud()
                }
            }
        }

        // timeout countdown hairline
        Rectangle {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            height: 2
            width: Math.max(0, Math.min(parent.width, parent.width * (hudRoot.remainingMs / Math.max(1, hudRoot.totalDurationMs))))
            color: Theme.primary
            opacity: 0.75
        }
    }
}
