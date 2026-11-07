// ScreenCapture.qml
import QtQuick
import QtQuick.Layouts
import ".."
import "../controls"
import Quickshell
import Quickshell.Hyprland

Rectangle {
    id: root

    property var barScreen: null
    property var barMonitor: null
    property bool isRecording: typeof ScreenRecService !== "undefined" ? (ScreenRecService?.isRecording ?? false) : false
    property string activeAudio: typeof ScreenRecService !== "undefined" ? (ScreenRecService?.activeAudio ?? "both") : "both"
    property int captureDelaySec: 0
    property int countdownRemaining: 0
    property string pendingTarget: ""

    readonly property bool isFloatingBar: (Settings?.barFloating ?? false) || Theme.isBento
    readonly property int effectiveBarMargin: isFloatingBar ? ((Settings?.barMargin > 0) ? Settings.barMargin : 8) : 0

    readonly property var targetScreen: {
        if (root.barScreen) return root.barScreen;
        if (Quickshell?.screens && Quickshell.screens.length > 0) {
            if (root.barMonitor) {
                for (let i = 0; i < Quickshell.screens.length; i++) {
                    if (Quickshell.screens[i].name === root.barMonitor.name) {
                        return Quickshell.screens[i];
                    }
                }
            }
            return Quickshell.screens[0];
        }
        return null;
    }

    implicitWidth: {
        if (Theme.isVertical) return Theme.barHeight - 8;
        if (root.isRecording || countdownTimer.running) return recRow.implicitWidth + 20;
        return (cMouse.containsMouse || popup.open) ? (iconRow.implicitWidth + 22) : (Theme.barHeight - 8);
    }
    implicitHeight: Theme.barHeight - 8
    radius: Theme.radiusPill

    color: {
        if (cMouse.pressed) return Theme.widgetActive;
        if (root.isRecording) return Theme.error_overlay;
        if (countdownTimer.running) return Theme.warn_overlay;
        if (popup.open) return Theme.primary_overlay;
        if (cMouse.containsMouse) return Theme.pillHover;
        return Theme.pillBg;
    }
    border.color: {
        if (root.isRecording) return Theme.error;
        if (countdownTimer.running) return Theme.warn;
        return Theme.pillBorder;
    }
    border.width: (border.color === "transparent" || border.color.a === 0) ? 0 : 1
    clip: true

    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
    Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
    Behavior on implicitWidth { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }

    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        onTriggered: {
            if (root.countdownRemaining > 1) {
                root.countdownRemaining -= 1;
            } else {
                stop();
                root.countdownRemaining = 0;
                root.executeScreenshot(root.pendingTarget);
            }
        }
    }

    // let the popup close first so it doesn't photobomb the screenshot
    Timer {
        id: immediateShotTimer
        interval: 140
        repeat: false
        onTriggered: root.executeScreenshot(root.pendingTarget)
    }

    function triggerScreenshot(mode) {
        let wasOpen = popup.open;
        popup.open = false;
        root.pendingTarget = mode;

        if (root.captureDelaySec > 0) {
            root.countdownRemaining = root.captureDelaySec;
            countdownTimer.restart();
        } else if (wasOpen) {
            immediateShotTimer.restart();
        } else {
            root.executeScreenshot(mode);
        }
    }

    function executeScreenshot(mode) {
        if (typeof ScreenshotService === "undefined" || !ScreenshotService) return;
        let action = Settings?.screenshotDefaultAction || "both";
        if (mode === "fullscreen") {
            ScreenshotService.captureFullscreen(root.targetScreen, action);
        } else if (ScreenshotService.open) {
            ScreenshotService.open(mode);
        }
    }

    function syncAnchor() {
        const pt = root.mapToItem(null, 0, 0);
        if (pt && root.visible) {
            if (Theme.isVertical) {
                popup.targetRelativeX = 0;
                popup.targetRelativeY = pt.y + (root.implicitHeight / 2) + root.effectiveBarMargin;
            } else {
                popup.targetRelativeX = pt.x + (root.implicitWidth / 2) + root.effectiveBarMargin;
                popup.targetRelativeY = 0;
            }
        } else {
            popup.targetRelativeX = 0;
            popup.targetRelativeY = 0;
        }
    }

    function isTargetMonitorActive() {
        return !root.barScreen
            || Quickshell.screens.length <= 1
            || (root.barMonitor && Hyprland.focusedMonitor && root.barMonitor.id === Hyprland.focusedMonitor.id);
    }

    component CaptureTile: Rectangle {
        id: tileRoot
        property string icon: ""
        property string label: ""
        property string sublabel: ""
        property bool accentRed: false
        signal clicked()

        Layout.fillWidth: true
        Layout.preferredHeight: 54
        radius: Theme.radiusMd
        // using widgetBg/widgetHover/widgetBorder so pure-black and glass modes don't turn into opaque grey bricks
        color: {
            if (tileMouse.pressed) return tileRoot.accentRed ? Theme.error : Theme.primary;
            if (tileMouse.containsMouse) return tileRoot.accentRed ? Theme.error_overlay : Theme.widgetHover;
            return Theme.widgetBg;
        }
        border.color: {
            if (tileMouse.containsMouse) return tileRoot.accentRed ? Theme.error : Theme.primary;
            return Theme.widgetBorder;
        }
        border.width: 1

        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
        Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 3

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: tileRoot.icon
                font.family: Theme.fontIcon
                font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeSm : Theme.fontSizeMd
                color: {
                    if (tileMouse.pressed) return tileRoot.accentRed ? Theme.on_error : Theme.on_primary;
                    return tileRoot.accentRed ? Theme.error : Theme.primary;
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: tileRoot.label
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXs
                font.weight: Font.DemiBold
                color: tileMouse.pressed ? (tileRoot.accentRed ? Theme.on_error : Theme.on_primary) : Theme.on_surface
            }
        }

        MouseArea {
            id: tileMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tileRoot.clicked()
        }
    }

    component MiniChip: Rectangle {
        id: chipRoot
        property string label: ""
        property string icon: ""
        property bool selected: false
        property bool fillWidth: false
        signal clicked()

        Layout.fillWidth: fillWidth
        Layout.preferredHeight: 24
        Layout.preferredWidth: fillWidth ? -1 : (chipRow.implicitWidth + 16)
        radius: Theme.radiusPill
        color: selected ? Theme.primary_overlay : (chipMouse.containsMouse ? Theme.widgetHover : "transparent")
        border.color: selected ? Theme.primary : Theme.widgetBorder
        border.width: 1

        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
        Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

        RowLayout {
            id: chipRow
            anchors.centerIn: parent
            spacing: 4

            // hide prefix icon in text mode so we don't end up with "mic mic" or "clip clipboard"
            Text {
                visible: chipRoot.icon !== "" && !Theme.isTextIconSet
                text: chipRoot.icon
                font.family: Theme.fontIcon
                font.pixelSize: Theme.fontSizeXs
                color: chipRoot.selected ? Theme.primary : Theme.on_surface_variant
            }

            Text {
                text: chipRoot.label
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXs
                font.weight: chipRoot.selected ? Font.Bold : Font.Normal
                color: chipRoot.selected ? Theme.primary : Theme.on_surface_variant
            }
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chipRoot.clicked()
        }
    }

    // idle bar content
    Row {
        id: iconRow
        anchors.centerIn: parent
        spacing: 6
        visible: !root.isRecording && !countdownTimer.running

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Theme.iconCamera
            font.family: Theme.fontIcon
            font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeXs : Theme.fontSizeSm
            color: popup.open || cMouse.containsMouse ? Theme.primary : Theme.on_surface

            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "capture"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSm
            font.weight: Font.Medium
            color: Theme.on_surface
            visible: !Theme.isVertical && (cMouse.containsMouse || popup.open)
        }
    }

    // active recording or countdown pill content
    RowLayout {
        id: recRow
        anchors.centerIn: parent
        spacing: 6
        visible: root.isRecording || countdownTimer.running

        Rectangle {
            id: pulseDot
            width: 8
            height: 8
            radius: 4
            color: root.isRecording ? Theme.error : Theme.warn

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: root.isRecording || countdownTimer.running
                NumberAnimation { from: 1.0; to: 0.20; duration: 650; easing.type: Easing.InOutQuad }
                NumberAnimation { from: 0.20; to: 1.0; duration: 650; easing.type: Easing.InOutQuad }
            }
        }

        Text {
            visible: !Theme.isVertical
            text: root.isRecording
                ? ("REC " + (ScreenRecService?.elapsedTimeString ?? "00:00"))
                : (root.countdownRemaining + "s")
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeXs
            font.weight: Font.Bold
            color: root.isRecording ? Theme.error : Theme.warn
        }
    }

    MouseArea {
        id: cMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            if (countdownTimer.running) {
                countdownTimer.stop();
                root.countdownRemaining = 0;
                return;
            }
            if (mouse.button === Qt.RightButton) {
                if (root.isRecording) {
                    ScreenRecService?.stopRecording();
                } else {
                    root.triggerScreenshot("region");
                }
                return;
            }
            if (mouse.button === Qt.MiddleButton) {
                root.triggerScreenshot("fullscreen");
                return;
            }
            if (root.isRecording) {
                ScreenRecService?.stopRecording();
            } else {
                root.syncAnchor();
                popup.open = !popup.open;
            }
        }
    }

    Connections {
        target: Settings
        function onRequestCaptureToggle() {
            if (root.isTargetMonitorActive()) {
                root.syncAnchor();
                popup.open = !popup.open;
            }
        }
        function onRequestCaptureOpen() {
            if (root.isTargetMonitorActive()) {
                root.syncAnchor();
                popup.open = true;
            }
        }
        function onRequestCaptureClose() {
            popup.open = false;
        }
    }

    PopupPanel {
        id: popup
        screen: root.targetScreen
        cardWidth: 390
        cardHeight: Math.round(captureLayout.implicitHeight + (Theme.popupPadding * 2))
        targetRelativeX: 0
        targetRelativeY: 0

        content: ColumnLayout {
            id: captureLayout
            anchors.fill: parent
            spacing: Theme.popupSpacing

            // header with icon badge, rotating flavor quote, and status pill
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    width: 34
                    height: 34
                    radius: Theme.radiusMd
                    color: root.isRecording ? Theme.error_overlay : Theme.primary_overlay
                    border.color: root.isRecording ? Theme.error : Theme.alpha(Theme.primary, 0.35)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: Theme.iconCamera
                        font.family: Theme.fontIcon
                        font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeSm : Theme.fontSizeLg
                        color: root.isRecording ? Theme.error : Theme.primary
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: "screen capture & recorder"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMd
                        font.weight: Font.Bold
                        color: Theme.on_surface
                    }

                    Text {
                        text: Theme.getFlavor("screenshot", "gpu accelerated • native wayland")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXs
                        color: Theme.on_surface_variant
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    height: 22
                    implicitWidth: statusText.implicitWidth + 14
                    radius: Theme.radiusPill
                    color: root.isRecording ? Theme.error_overlay : (countdownTimer.running ? Theme.warn_overlay : Theme.primary_overlay)
                    border.color: root.isRecording ? Theme.error : (countdownTimer.running ? Theme.warn : Theme.primary)
                    border.width: 1

                    Text {
                        id: statusText
                        anchors.centerIn: parent
                        text: root.isRecording ? ("REC " + (ScreenRecService?.elapsedTimeString ?? "00:00")) : (countdownTimer.running ? (root.countdownRemaining + "s") : "ready")
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeXs
                        font.weight: Font.Bold
                        color: root.isRecording ? Theme.error : (countdownTimer.running ? Theme.warn : Theme.primary)
                    }
                }
            }

            // screenshot card
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: shotCol.implicitHeight + 20
                radius: Theme.radiusMd
                color: Theme.cardBg
                border.color: Theme.cardBorder
                border.width: 1
                clip: true

                Rectangle {
                    visible: Theme.isGlass
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: Theme.glassHighlight
                }

                ColumnLayout {
                    id: shotCol
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: Theme.iconScreenshot
                            font.family: Theme.fontIcon
                            font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeXs : Theme.fontSizeSm
                            color: Theme.primary
                        }

                        Text {
                            text: "screenshot"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                            font.weight: Font.Bold
                            color: Theme.on_surface
                        }

                        Item { Layout.fillWidth: true }

                        Repeater {
                            model: [
                                { label: "now", sec: 0 },
                                { label: "3s", sec: 3 },
                                { label: "5s", sec: 5 }
                            ]

                            delegate: MiniChip {
                                required property var modelData
                                label: modelData.label
                                selected: root.captureDelaySec === modelData.sec
                                onClicked: root.captureDelaySec = modelData.sec
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        CaptureTile {
                            icon: Theme.iconCrop
                            label: "region"
                            onClicked: root.triggerScreenshot("region")
                        }

                        CaptureTile {
                            icon: Theme.iconWorkspaces
                            label: "window"
                            onClicked: root.triggerScreenshot("window")
                        }

                        CaptureTile {
                            icon: Theme.iconExpand
                            label: "display"
                            onClicked: root.triggerScreenshot("fullscreen")
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: "output:"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.on_surface_variant
                        }

                        Repeater {
                            model: [
                                { id: "both", label: "copy + save", icon: Theme.iconCheck },
                                { id: "copy", label: "clipboard", icon: Theme.iconClipboard },
                                { id: "save", label: "file only", icon: Theme.iconSave }
                            ]

                            delegate: MiniChip {
                                required property var modelData
                                readonly property string curAction: Settings?.screenshotDefaultAction || "both"
                                label: modelData.label
                                icon: modelData.icon
                                fillWidth: true
                                selected: curAction === modelData.id
                                onClicked: {
                                    if (Settings) {
                                        Settings.screenshotDefaultAction = modelData.id;
                                        if (Settings.save) Settings.save();
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // screen recording card
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: recCol.implicitHeight + 20
                radius: Theme.radiusMd
                color: Theme.cardBg
                border.color: root.isRecording ? Theme.error : Theme.cardBorder
                border.width: 1
                clip: true

                Rectangle {
                    visible: Theme.isGlass
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: Theme.glassHighlight
                }

                ColumnLayout {
                    id: recCol
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: Theme.iconPlay
                            font.family: Theme.fontIcon
                            font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeXs : Theme.fontSizeSm
                            color: root.isRecording ? Theme.error : Theme.primary
                        }

                        Text {
                            text: "screen recording"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                            font.weight: Font.Bold
                            color: Theme.on_surface
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: "60 fps • gpu-screen-recorder"
                            font.family: Theme.fontMono
                            font.pixelSize: Math.max(8, Theme.fontSizeXs - 1)
                            color: Theme.on_surface_variant
                        }
                    }

                    // active recording controls
                    Rectangle {
                        visible: root.isRecording
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        radius: Theme.radiusSm
                        color: Theme.error_overlay
                        border.color: Theme.error
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

                            Rectangle {
                                width: 8
                                height: 8
                                radius: 4
                                color: Theme.error

                                SequentialAnimation on opacity {
                                    loops: Animation.Infinite
                                    running: root.isRecording
                                    NumberAnimation { from: 1.0; to: 0.20; duration: 650; easing.type: Easing.InOutQuad }
                                    NumberAnimation { from: 0.20; to: 1.0; duration: 650; easing.type: Easing.InOutQuad }
                                }
                            }

                            Text {
                                text: "recording " + (ScreenRecService?.elapsedTimeString ?? "00:00")
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeSm
                                font.weight: Font.Bold
                                color: Theme.error
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                height: 30
                                implicitWidth: stopTxt.implicitWidth + 18
                                radius: Theme.radiusSm
                                color: stopMouse.containsMouse ? Theme.alpha(Theme.error, 0.85) : Theme.error

                                Text {
                                    id: stopTxt
                                    anchors.centerIn: parent
                                    text: "save & stop"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: Font.Bold
                                    // using on_error instead of #ffffff so it doesn't blind you on pastel M3 error colors
                                    color: Theme.on_error
                                }

                                MouseArea {
                                    id: stopMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ScreenRecService?.stopRecording()
                                }
                            }

                            Rectangle {
                                height: 30
                                implicitWidth: discTxt.implicitWidth + 16
                                radius: Theme.radiusSm
                                color: discMouse.containsMouse ? Theme.error_overlay : "transparent"
                                border.color: Theme.error
                                border.width: 1

                                Text {
                                    id: discTxt
                                    anchors.centerIn: parent
                                    text: "discard"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: Font.Medium
                                    color: Theme.error
                                }

                                MouseArea {
                                    id: discMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ScreenRecService?.discardRecording()
                                }
                            }
                        }
                    }

                    // idle recording triggers
                    RowLayout {
                        visible: !root.isRecording
                        Layout.fillWidth: true
                        spacing: 8

                        CaptureTile {
                            icon: Theme.iconCrop
                            label: "region"
                            accentRed: true
                            onClicked: {
                                popup.open = false;
                                ScreenRecService?.startRecording("region");
                            }
                        }

                        CaptureTile {
                            icon: Theme.iconWorkspaces
                            label: "window"
                            accentRed: true
                            onClicked: {
                                popup.open = false;
                                ScreenRecService?.startRecording("window");
                            }
                        }

                        CaptureTile {
                            icon: Theme.iconExpand
                            label: "display"
                            accentRed: true
                            onClicked: {
                                popup.open = false;
                                ScreenRecService?.startRecording("screen");
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: "audio:"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.on_surface_variant
                        }

                        Repeater {
                            model: [
                                { id: "both", label: "desktop + mic", icon: Theme.iconMic },
                                { id: "desktop", label: "desktop", icon: Theme.iconVolHigh },
                                { id: "mic", label: "mic", icon: Theme.iconMic },
                                { id: "none", label: "muted", icon: Theme.iconVolMute }
                            ]

                            delegate: MiniChip {
                                required property var modelData
                                label: modelData.label
                                icon: modelData.icon
                                fillWidth: true
                                selected: root.activeAudio === modelData.id
                                onClicked: {
                                    if (typeof ScreenRecService !== "undefined" && ScreenRecService) {
                                        ScreenRecService.activeAudio = modelData.id;
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // quick folder footer actions
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MiniChip {
                    icon: Theme.iconFolder
                    label: "open screenshots"
                    fillWidth: true
                    Layout.preferredHeight: 30
                    onClicked: {
                        popup.open = false;
                        let dir = Settings?.screenshotDir || ((Quickshell.env("HOME") || "") + "/Pictures/Screenshots");
                        Quickshell.execDetached(["xdg-open", dir]);
                    }
                }

                MiniChip {
                    icon: Theme.iconFolder
                    label: "open recordings"
                    fillWidth: true
                    Layout.preferredHeight: 30
                    onClicked: {
                        popup.open = false;
                        let dir = ScreenRecService?.outputDirectory || ((Quickshell.env("HOME") || "") + "/Videos");
                        Quickshell.execDetached(["xdg-open", dir]);
                    }
                }
            }
        }
    }
}
