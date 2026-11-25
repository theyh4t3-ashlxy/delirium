// ScreenCapture.qml
import QtQuick
import QtQuick.Layouts
import ".."
import "../controls"
import "../theme/confFormat.mjs" as ConfFmt
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

BarPill {
    id: root

    property bool isRecording: typeof ScreenRecService !== "undefined" ? (ScreenRecService?.isRecording ?? false) : false
    property string activeAudio: typeof ScreenRecService !== "undefined" ? (ScreenRecService?.activeAudio ?? "both") : "both"
    readonly property int captureDelaySec: Settings?.screenshotDelay ?? 0
    readonly property int countdownRemaining: typeof ScreenshotService !== "undefined" ? (ScreenshotService?.countdownRemaining ?? 0) : 0
    readonly property bool isDelayRunning: typeof ScreenshotService !== "undefined" ? (ScreenshotService?.hasPendingDelay ?? false) : false
    property string pendingTarget: ""
    property bool showSettings: false
    property var recentCaptures: []
    property string copiedCapturePath: ""

    Timer {
        id: copiedCaptureTimer
        interval: 1200
        onTriggered: root.copiedCapturePath = ""
    }

    Process {
        id: recentProc
        stdout: StdioCollector {
            onStreamFinished: {
                let recs = ConfFmt.parseRecords(text || "", "cap");
                root.recentCaptures = Array.isArray(recs) ? recs : [];
            }
        }
    }

    function refreshRecentCaptures() {
        let rawShotDir = Settings?.screenshotDir || ((Quickshell.env("HOME") || "") + "/Pictures/Screenshots");
        let shotDir = typeof ScreenshotService !== "undefined" && ScreenshotService?.expandHome ? ScreenshotService.expandHome(rawShotDir) : rawShotDir;
        let recDir = ScreenRecService?.outputDirectory || ((Quickshell.env("HOME") || "") + "/Videos/Recordings");
        let py = "import os, sys\n" +
            "def esc(s): return s.replace('\\\\','\\\\\\\\').replace('\\n','\\\\n').replace('=','\\\\e').replace(',','\\\\c').replace(';','\\\\s').replace('|','\\\\p')\n" +
            "items = []\n" +
            "img_ext = {'.png','.jpg','.jpeg','.webp','.bmp'}\n" +
            "vid_ext = {'.mp4','.mkv','.webm','.mov'}\n" +
            "for d, kind_hint in [(os.path.expanduser(sys.argv[1]), 'img'), (os.path.expanduser(sys.argv[2]), 'vid')]:\n" +
            "  if not d or not os.path.isdir(d): continue\n" +
            "  try:\n" +
            "    for e in os.scandir(d):\n" +
            "      if not e.is_file(): continue\n" +
            "      ext = os.path.splitext(e.name)[1].lower()\n" +
            "      if ext in img_ext: k = 'image'\n" +
            "      elif ext in vid_ext: k = 'video'\n" +
            "      else: continue\n" +
            "      items.append((e.stat().st_mtime, k, e.path, e.name))\n" +
            "  except Exception: pass\n" +
            "items.sort(key=lambda x: x[0], reverse=True)\n" +
            "items = items[:10]\n" +
            "print(f'count={len(items)}')\n" +
            "for i, (_, k, p, n) in enumerate(items):\n" +
            "  print(f'cap.{i}.kind={k}')\n" +
            "  print(f'cap.{i}.path={esc(p)}')\n" +
            "  print(f'cap.{i}.name={esc(n)}')\n";
        recentProc.command = ["python3", "-c", py, shotDir, recDir];
        recentProc.running = false;
        recentProc.running = true;
    }

    Connections {
        target: ScreenRecService
        function onIsRecordingChanged() {
            if (!ScreenRecService.isRecording) root.refreshRecentCaptures();
        }
    }

    Connections {
        target: ScreenshotService
        function onCaptureCompleted(info) {
            root.refreshRecentCaptures();
        }
    }

    readonly property bool isFloatingBar: (Settings?.barFloating ?? false) || Theme.isIslands
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

    active: popup.open
    alert: root.isRecording
    hovered: cMouse.containsMouse
    pressed: cMouse.pressed
    normalBg: root.isDelayRunning ? Theme.warn_overlay : Theme.barPillBg
    normalBorder: root.isDelayRunning ? Theme.warn : Theme.barPillBorder
    clip: true

    implicitWidth: {
        if (Theme.isVertical) return pillSize;
        if (root.isRecording || root.isDelayRunning) return recRow.implicitWidth + 20;
        if (Theme.isTextIconSet) return iconRow.implicitWidth + 20;
        return pillSize;
    }

    Behavior on implicitWidth { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }

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

        if (mode === "clip") {
            ScreenshotService.editClipboard();
            return;
        }
        if (root.captureDelaySec > 0 && mode !== "eyedropper") {
            ScreenshotService.openDelayed(mode, root.captureDelaySec);
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
        } else if (mode === "annotate") {
            ScreenshotService.openAnnotate();
        } else if (mode === "eyedropper") {
            ScreenshotService.openEyedropper();
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
                font.variableAxes: Theme.iconAxes
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
                font.variableAxes: Theme.sansAxes
                font.pixelSize: Theme.fontSizeXs
                font.weight: Theme.fontWeightDemiBold
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
                font.variableAxes: Theme.iconAxes
                font.pixelSize: Theme.fontSizeXs
                color: chipRoot.selected ? Theme.primary : Theme.on_surface_variant
            }

            Text {
                text: chipRoot.label
                font.family: Theme.fontFamily
                font.variableAxes: Theme.sansAxes
                font.pixelSize: Theme.fontSizeXs
                font.weight: chipRoot.selected ? Theme.fontWeightBold : Theme.fontWeightRegular
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
        visible: !root.isRecording && !root.isDelayRunning

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Theme.iconCamera
            font.family: Theme.fontIcon
            font.variableAxes: Theme.iconAxes
            font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeXs : Theme.fontSizeSm
            color: popup.open || cMouse.containsMouse ? Theme.primary : Theme.on_surface

            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "capture"
            font.family: Theme.fontFamily
            font.variableAxes: Theme.sansAxes
            font.pixelSize: Theme.fontSizeSm
            font.weight: Theme.fontWeightMedium
            color: Theme.on_surface
            visible: !Theme.isVertical && Theme.isTextIconSet
        }
    }

    // active recording or countdown pill content
    RowLayout {
        id: recRow
        anchors.centerIn: parent
        spacing: 6
        visible: root.isRecording || root.isDelayRunning

        Rectangle {
            id: pulseDot
            width: 8
            height: 8
            radius: 4
            color: root.isRecording ? Theme.error : Theme.warn

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: root.isRecording || root.isDelayRunning
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
            font.variableAxes: Theme.monoAxes
            font.pixelSize: Theme.fontSizeXs
            font.weight: Theme.monoWeightBold
            color: root.isRecording ? Theme.error : Theme.warn
        }
    }

    HoverFlyoutHandler {
        id: captureHoverHandler
        popup: popup
        mouseArea: cMouse
        updatePos: () => root.syncAnchor()
    }

    MouseArea {
        id: cMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            if (root.isDelayRunning) {
                ScreenshotService.cancelDelay();
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
                captureHoverHandler.handlePillClick();
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
        cardWidth: 426
        cardHeight: Math.min(Theme.popupMaxHeight ?? 680, Math.round(captureLayout.implicitHeight + (Theme.popupPadding * 2)))
        targetRelativeX: 0
        targetRelativeY: 0
        onOpenChanged: {
            if (open) {
                root.showSettings = false;
                root.refreshRecentCaptures();
            }
        }

        content: ColumnLayout {
            id: captureLayout
            anchors.fill: parent
            spacing: Theme.popupSpacing

            // header with icon badge, rotating flavor quote, status pill, and settings toggle
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

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
                        font.variableAxes: Theme.iconAxes
                        font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeSm : Theme.fontSizeLg
                        color: root.isRecording ? Theme.error : Theme.primary
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: root.showSettings ? "capture & overlay settings" : "screen capture & recorder"
                        font.family: Theme.fontFamily
                        font.variableAxes: Theme.sansAxes
                        font.pixelSize: Theme.fontSizeMd
                        font.weight: Theme.fontWeightBold
                        color: Theme.on_surface
                    }

                    Text {
                        text: root.showSettings
                            ? "selection guides, snapping, flash & border styling"
                            : Theme.getFlavor("screenshot", "gpu accelerated • native wayland")
                        font.family: Theme.fontFamily
                        font.variableAxes: Theme.sansAxes
                        font.weight: Theme.fontWeightRegular
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
                    color: root.isRecording ? Theme.error_overlay : (root.isDelayRunning ? Theme.warn_overlay : Theme.primary_overlay)
                    border.color: root.isRecording ? Theme.error : (root.isDelayRunning ? Theme.warn : Theme.primary)
                    border.width: 1

                    Text {
                        id: statusText
                        anchors.centerIn: parent
                        text: root.isRecording ? ("REC " + (ScreenRecService?.elapsedTimeString ?? "00:00")) : (root.isDelayRunning ? (root.countdownRemaining + "s") : "ready")
                        font.family: Theme.fontMono
                        font.variableAxes: Theme.monoAxes
                        font.pixelSize: Theme.fontSizeXs
                        font.weight: Theme.monoWeightBold
                        color: root.isRecording ? Theme.error : (root.isDelayRunning ? Theme.warn : Theme.primary)
                    }
                }

                IconButton {
                    icon: root.showSettings ? Theme.iconClose : Theme.iconSettings
                    iconSize: Theme.fontSizeMd
                    highlighted: root.showSettings
                    tooltip: root.showSettings ? "back to capture" : "overlay & capture settings"
                    onClicked: root.showSettings = !root.showSettings
                }
            }

            // capture & selection overlay settings drawer (moved out of QuickSettings)
            Rectangle {
                visible: root.showSettings
                Layout.fillWidth: true
                implicitHeight: Math.min(430, capSetCol.implicitHeight + 18)
                radius: Theme.radiusMd
                color: Theme.cardBg
                border.color: Theme.cardBorder
                border.width: 1
                clip: true

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 9
                    contentWidth: width
                    contentHeight: capSetCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: capSetCol
                        width: parent.width
                        spacing: 8

                        Repeater {
                            model: [
                                { key: "screenshotWindowSnapping", title: "window snapping", sub: "snap selection box to hovered hyprland windows" },
                                { key: "screenshotFreeze", title: "freeze display frame", sub: "pause screen frame while dragging selection" },
                                { key: "screenshotIncludeCursor", title: "capture cursor", sub: "include mouse pointer inside screenshots" },
                                { key: "screenshotShowLoupe", title: "pixel loupe & hex", sub: "5x zoomed magnifier + live color coordinate readout" },
                                { key: "screenshotPostHud", title: "post-capture preview hud", sub: "floating card for quick edit, pin, prettify & trash" },
                                { key: "screenshotDefaultAnnotate", title: "open in studio annotate mode", sub: "expand pen, arrow, step & redact toolbar on capture" },
                                { key: "screenshotFlash", title: "shutter flash", sub: "visual flash feedback on capture" },
                                { key: "screenshotNotify", title: "desktop notification", sub: "notify with preview thumbnail after saving" },
                                { key: "screenshotShowCrosshair", title: "hairline crosshairs", sub: "alignment crosshair lines tracking cursor" },
                                { key: "screenshotShowBadge", title: "dimension badge", sub: "show [w x h] and hovered class badge" },
                                { key: "screenshotShowHandles", title: "corner accent handles", sub: "draw selection corner markers" }
                            ]

                            delegate: RowLayout {
                                required property var modelData
                                readonly property bool checkedVal: Boolean(Settings ? Settings[modelData.key] : false)
                                Layout.fillWidth: true
                                spacing: 8

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        text: modelData.title
                                        font.family: Theme.fontFamily
                                        font.variableAxes: Theme.sansAxes
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightDemiBold
                                        color: Theme.on_surface
                                    }

                                    Text {
                                        text: modelData.sub
                                        font.family: Theme.fontFamily
                                        font.variableAxes: Theme.sansAxes
                                        font.weight: Theme.fontWeightRegular
                                        font.pixelSize: 10
                                        color: Theme.on_surface_variant
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                ToggleSwitch {
                                    checked: parent.checkedVal
                                    onToggled: {
                                        if (Settings) {
                                            Settings[modelData.key] = !parent.checkedVal;
                                            if (Settings.save) Settings.save();
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Theme.widgetBorder
                        }

                        Slider {
                            Layout.fillWidth: true
                            label: "overlay dim"
                            unit: "%"
                            from: 10
                            to: 90
                            stepSize: 5
                            value: Math.round((Settings?.screenshotDimOpacity ?? 0.5) * 100)
                            onMoved: (val) => {
                                if (Settings) {
                                    Settings.screenshotDimOpacity = val / 100.0;
                                    if (Settings.save) Settings.save();
                                }
                            }
                        }

                        Slider {
                            Layout.fillWidth: true
                            label: "selection border width"
                            unit: "px"
                            from: 1
                            to: 6
                            stepSize: 1
                            value: Settings?.screenshotBorderWidth ?? 2
                            onMoved: (val) => {
                                if (Settings) {
                                    Settings.screenshotBorderWidth = Math.round(val);
                                    if (Settings.save) Settings.save();
                                }
                            }
                        }

                        Slider {
                            Layout.fillWidth: true
                            label: "selection corner radius"
                            unit: "px"
                            from: 0
                            to: 20
                            stepSize: 2
                            value: Settings?.screenshotBorderRadius ?? 8
                            onMoved: (val) => {
                                if (Settings) {
                                    Settings.screenshotBorderRadius = Math.round(val);
                                    if (Settings.save) Settings.save();
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Theme.widgetBorder
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: "format:"
                                font.family: Theme.fontFamily
                                font.variableAxes: Theme.sansAxes
                                font.pixelSize: Theme.fontSizeXs
                                font.weight: Theme.fontWeightDemiBold
                                color: Theme.on_surface
                                Layout.fillWidth: true
                            }

                            Repeater {
                                model: ["png", "jpg", "webp"]
                                delegate: MiniChip {
                                    required property string modelData
                                    label: modelData
                                    selected: (Settings?.screenshotFormat || "png") === modelData
                                    onClicked: {
                                        if (Settings) {
                                            Settings.screenshotFormat = modelData;
                                            if (Settings.save) Settings.save();
                                        }
                                    }
                                }
                            }
                        }

                        Slider {
                            visible: (Settings?.screenshotFormat || "png") !== "png"
                            Layout.fillWidth: true
                            label: "jpg / webp quality"
                            unit: "%"
                            from: 60
                            to: 100
                            stepSize: 2
                            value: Settings?.screenshotQuality ?? 92
                            onMoved: (val) => {
                                if (Settings) {
                                    Settings.screenshotQuality = Math.round(val);
                                    if (Settings.save) Settings.save();
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: "naming:"
                                font.family: Theme.fontFamily
                                font.variableAxes: Theme.sansAxes
                                font.pixelSize: Theme.fontSizeXs
                                font.weight: Theme.fontWeightDemiBold
                                color: Theme.on_surface
                                Layout.fillWidth: true
                            }

                            Repeater {
                                model: [
                                    { id: "timestamp", label: "Screenshot_date" },
                                    { id: "compact", label: "shot_compact" }
                                ]
                                delegate: MiniChip {
                                    required property var modelData
                                    label: modelData.label
                                    selected: (Settings?.screenshotFilenamePattern || "timestamp") === modelData.id
                                    onClicked: {
                                        if (Settings) {
                                            Settings.screenshotFilenamePattern = modelData.id;
                                            if (Settings.save) Settings.save();
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Theme.widgetBorder
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    text: "auto-prettify captures"
                                    font.family: Theme.fontFamily
                                    font.variableAxes: Theme.sansAxes
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: Theme.fontWeightDemiBold
                                    color: Theme.on_surface
                                }

                                Text {
                                    text: "frame saved captures in gradient backdrop & shadow"
                                    font.family: Theme.fontFamily
                                    font.variableAxes: Theme.sansAxes
                                    font.pixelSize: 10
                                    color: Theme.on_surface_variant
                                }
                            }

                            ToggleSwitch {
                                checked: Boolean(Settings?.screenshotPrettifyEnabled ?? false)
                                onToggled: {
                                    if (Settings) {
                                        Settings.screenshotPrettifyEnabled = !Boolean(Settings.screenshotPrettifyEnabled);
                                        if (Settings.save) Settings.save();
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    text: "prettify drop shadow"
                                    font.family: Theme.fontFamily
                                    font.variableAxes: Theme.sansAxes
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: Theme.fontWeightDemiBold
                                    color: Theme.on_surface
                                }

                                Text {
                                    text: "soft elevated window shadow under framed shots"
                                    font.family: Theme.fontFamily
                                    font.variableAxes: Theme.sansAxes
                                    font.pixelSize: 10
                                    color: Theme.on_surface_variant
                                }
                            }

                            ToggleSwitch {
                                checked: Boolean(Settings?.screenshotPrettifyShadow ?? true)
                                onToggled: {
                                    if (Settings) {
                                        Settings.screenshotPrettifyShadow = !Boolean(Settings.screenshotPrettifyShadow);
                                        if (Settings.save) Settings.save();
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: "backdrop:"
                                font.family: Theme.fontFamily
                                font.variableAxes: Theme.sansAxes
                                font.pixelSize: Theme.fontSizeXs
                                font.weight: Theme.fontWeightDemiBold
                                color: Theme.on_surface
                                Layout.fillWidth: true
                            }

                            Repeater {
                                model: ["matugen", "wallpaper", "oled", "glass"]
                                delegate: MiniChip {
                                    required property string modelData
                                    label: modelData
                                    selected: (Settings?.screenshotPrettifyStyle || "matugen") === modelData
                                    onClicked: {
                                        if (Settings) {
                                            Settings.screenshotPrettifyStyle = modelData;
                                            if (Settings.save) Settings.save();
                                        }
                                    }
                                }
                            }
                        }

                        Slider {
                            Layout.fillWidth: true
                            label: "prettify frame padding"
                            unit: "px"
                            from: 16
                            to: 96
                            stepSize: 4
                            value: Settings?.screenshotPrettifyPadding ?? 48
                            onMoved: (val) => {
                                if (Settings) {
                                    Settings.screenshotPrettifyPadding = Math.round(val);
                                    if (Settings.save) Settings.save();
                                }
                            }
                        }

                        Slider {
                            Layout.fillWidth: true
                            label: "prettify inner radius"
                            unit: "px"
                            from: 0
                            to: 32
                            stepSize: 2
                            value: Settings?.screenshotPrettifyRadius ?? 14
                            onMoved: (val) => {
                                if (Settings) {
                                    Settings.screenshotPrettifyRadius = Math.round(val);
                                    if (Settings.save) Settings.save();
                                }
                            }
                        }
                    }
                }
            }

            // screenshot card
            Rectangle {
                visible: !root.showSettings
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
                            font.variableAxes: Theme.iconAxes
                            font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeXs : Theme.fontSizeSm
                            color: Theme.primary
                        }

                        Text {
                            text: "screenshot"
                            font.family: Theme.fontFamily
                            font.variableAxes: Theme.sansAxes
                            font.pixelSize: Theme.fontSizeSm
                            font.weight: Theme.fontWeightBold
                            color: Theme.on_surface
                        }

                        Item { Layout.fillWidth: true }

                        Repeater {
                            model: [
                                { label: "now", sec: 0 },
                                { label: "3s", sec: 3 },
                                { label: "5s", sec: 5 },
                                { label: "10s", sec: 10 }
                            ]

                            delegate: MiniChip {
                                required property var modelData
                                label: modelData.label
                                selected: root.captureDelaySec === modelData.sec
                                onClicked: {
                                    if (Settings) {
                                        Settings.screenshotDelay = modelData.sec;
                                        if (Settings.save) Settings.save();
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

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

                        CaptureTile {
                            icon: Theme.iconEdit
                            label: "studio"
                            onClicked: root.triggerScreenshot("annotate")
                        }

                        CaptureTile {
                            icon: Theme.iconEyedropper
                            label: "pick hex"
                            onClicked: root.triggerScreenshot("eyedropper")
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        MiniChip {
                            icon: Theme.iconFrame
                            label: "prettify"
                            selected: Boolean(Settings?.screenshotPrettifyEnabled ?? false)
                            onClicked: {
                                if (Settings) {
                                    Settings.screenshotPrettifyEnabled = !Boolean(Settings.screenshotPrettifyEnabled);
                                    if (Settings.save) Settings.save();
                                }
                            }
                        }

                        MiniChip {
                            icon: Theme.iconBrush
                            label: "cursor"
                            selected: Boolean(Settings?.screenshotIncludeCursor ?? false)
                            onClicked: {
                                if (Settings) {
                                    Settings.screenshotIncludeCursor = !Boolean(Settings.screenshotIncludeCursor);
                                    if (Settings.save) Settings.save();
                                }
                            }
                        }

                        MiniChip {
                            icon: Theme.iconClipboard
                            label: "edit clip"
                            fillWidth: true
                            onClicked: root.triggerScreenshot("clip")
                        }

                        MiniChip {
                            visible: ScreenshotService.lastCapture !== null
                            icon: Theme.iconPin
                            label: "pin last"
                            onClicked: {
                                popup.open = false;
                                ScreenshotService.pinLast();
                            }
                        }

                        MiniChip {
                            visible: ScreenshotService.pinnedShots.length > 0
                            icon: Theme.iconClose
                            label: "unpin (" + ScreenshotService.pinnedShots.length + ")"
                            selected: true
                            onClicked: ScreenshotService.clearPins()
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        Text {
                            text: "output:"
                            font.family: Theme.fontFamily
                            font.variableAxes: Theme.sansAxes
                            font.weight: Theme.fontWeightRegular
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

                        MiniChip {
                            label: String(Settings?.screenshotFormat || "png").toUpperCase()
                            selected: (Settings?.screenshotFormat || "png") !== "png"
                            onClicked: {
                                if (!Settings) return;
                                let cur = String(Settings.screenshotFormat || "png").toLowerCase();
                                Settings.screenshotFormat = cur === "png" ? "webp" : (cur === "webp" ? "jpg" : "png");
                                if (Settings.save) Settings.save();
                            }
                        }
                    }
                }
            }

            // screen recording card
            Rectangle {
                visible: !root.showSettings
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
                            font.variableAxes: Theme.iconAxes
                            font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeXs : Theme.fontSizeSm
                            color: root.isRecording ? Theme.error : Theme.primary
                        }

                        Text {
                            text: "screen recording"
                            font.family: Theme.fontFamily
                            font.variableAxes: Theme.sansAxes
                            font.pixelSize: Theme.fontSizeSm
                            font.weight: Theme.fontWeightBold
                            color: Theme.on_surface
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: "60 fps • gpu-screen-recorder"
                            font.family: Theme.fontMono
                            font.variableAxes: Theme.monoAxes
                            font.weight: Theme.monoWeightRegular
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
                                font.variableAxes: Theme.monoAxes
                                font.pixelSize: Theme.fontSizeSm
                                font.weight: Theme.monoWeightBold
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
                                    font.variableAxes: Theme.sansAxes
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: Theme.fontWeightBold
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
                                    font.variableAxes: Theme.sansAxes
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: Theme.fontWeightMedium
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
                            font.variableAxes: Theme.sansAxes
                            font.weight: Theme.fontWeightRegular
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

            // recent captures gallery
            Rectangle {
                visible: !root.showSettings
                Layout.fillWidth: true
                implicitHeight: recentCol.implicitHeight + 18
                radius: Theme.radiusMd
                color: Theme.cardBg
                border.color: Theme.cardBorder
                border.width: 1

                ColumnLayout {
                    id: recentCol
                    anchors.fill: parent
                    anchors.margins: 9
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: Theme.iconHistory
                            font.family: Theme.fontIcon
                            font.variableAxes: Theme.iconAxes
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.primary
                        }

                        Text {
                            text: "recent captures (" + root.recentCaptures.length + ")"
                            font.family: Theme.fontFamily
                            font.variableAxes: Theme.sansAxes
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: Theme.fontWeightBold
                            color: Theme.on_surface
                            Layout.fillWidth: true
                        }

                        IconButton {
                            icon: Theme.iconRefresh
                            iconSize: 12
                            implicitWidth: 22
                            implicitHeight: 22
                            tooltip: "refresh gallery"
                            onClicked: root.refreshRecentCaptures()
                        }
                    }

                    Text {
                        visible: root.recentCaptures.length === 0
                        text: "no recent screenshots or recordings found"
                        font.family: Theme.fontFamily
                        font.variableAxes: Theme.sansAxes
                        font.weight: Theme.fontWeightRegular
                        font.pixelSize: 10
                        color: Theme.on_surface_variant
                        Layout.fillWidth: true
                    }

                    Flickable {
                        visible: root.recentCaptures.length > 0
                        Layout.fillWidth: true
                        Layout.preferredHeight: 90
                        contentWidth: recentStrip.implicitWidth
                        contentHeight: 90
                        flickableDirection: Flickable.HorizontalFlick
                        clip: true

                        Row {
                            id: recentStrip
                            height: 90
                            spacing: 6

                            Repeater {
                                model: root.recentCaptures

                                delegate: Rectangle {
                                    id: capTile
                                    required property var modelData
                                    readonly property bool isImg: modelData.kind === "image"
                                    readonly property bool justCopied: root.copiedCapturePath === modelData.path
                                    readonly property bool hoverAny: tileMouse.containsMouse || editBtnMouse.containsMouse || pinBtnMouse.containsMouse || prettyBtnMouse.containsMouse || openBtnMouse.containsMouse || rmBtnMouse.containsMouse

                                    width: 138
                                    height: 86
                                    radius: Theme.radiusSm
                                    color: Theme.surface_container_highest
                                    border.color: justCopied
                                        ? Theme.primary
                                        : (tileMouse.containsMouse ? Theme.alpha(Theme.primary, 0.7) : Theme.widgetBorder)
                                    border.width: 1
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        visible: capTile.isImg
                                        source: capTile.isImg ? ("file://" + capTile.modelData.path) : ""
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        smooth: true
                                    }

                                    Column {
                                        anchors.centerIn: parent
                                        visible: !capTile.isImg
                                        spacing: 2
                                        width: parent.width - 12

                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: Theme.iconPlay
                                            font.family: Theme.fontIcon
                                            font.variableAxes: Theme.iconAxes
                                            font.pixelSize: Theme.fontSizeMd
                                            color: Theme.primary
                                        }

                                        Text {
                                            width: parent.width
                                            text: capTile.modelData.name
                                            font.family: Theme.fontMono
                                            font.variableAxes: Theme.monoAxes
                                            font.weight: Theme.monoWeightRegular
                                            font.pixelSize: 8
                                            color: Theme.on_surface
                                            elide: Text.ElideMiddle
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }

                                    MouseArea {
                                        id: tileMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: (mouse) => {
                                            let p = capTile.modelData.path;
                                            if (!p) return;
                                            if (mouse.button === Qt.MiddleButton || mouse.button === Qt.RightButton || !capTile.isImg) {
                                                Quickshell.execDetached(["xdg-open", p]);
                                            } else {
                                                Quickshell.execDetached(["python3", ScreenshotService.scriptPath, "copy", p]);
                                                root.copiedCapturePath = p;
                                                copiedCaptureTimer.restart();
                                            }
                                        }
                                    }

                                    // bottom overlay label
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        height: 18
                                        color: Theme.alpha(Theme.scrim, 0.72)

                                        Text {
                                            anchors.centerIn: parent
                                            width: parent.width - 8
                                            text: capTile.justCopied
                                                ? "copied!"
                                                : (tileMouse.containsMouse ? (capTile.isImg ? "click: copy" : "click: open") : capTile.modelData.name)
                                            font.family: Theme.fontMono
                                            font.variableAxes: Theme.monoAxes
                                            font.pixelSize: 8
                                            font.weight: capTile.justCopied ? Theme.monoWeightBold : Theme.monoWeightRegular
                                            color: capTile.justCopied ? Theme.primary : Theme.on_surface
                                            elide: Text.ElideMiddle
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }

                                    // top-right studio edit, pin, prettify, open & delete buttons on hover
                                    Row {
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 4
                                        spacing: 3
                                        visible: capTile.hoverAny

                                        Rectangle {
                                            visible: capTile.isImg
                                            width: 19
                                            height: 19
                                            radius: 9.5
                                            color: editBtnMouse.containsMouse ? Theme.primary : Theme.alpha(Theme.scrim, 0.78)

                                            Text {
                                                anchors.centerIn: parent
                                                text: Theme.iconEdit
                                                font.family: Theme.fontIcon
                                                font.variableAxes: Theme.iconAxes
                                                font.pixelSize: 10
                                                color: editBtnMouse.containsMouse ? Theme.on_primary : Theme.on_surface
                                            }

                                            MouseArea {
                                                id: editBtnMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    popup.open = false;
                                                    ScreenshotService.editFile(capTile.modelData.path);
                                                }
                                            }
                                        }

                                        Rectangle {
                                            visible: capTile.isImg
                                            width: 19
                                            height: 19
                                            radius: 9.5
                                            color: pinBtnMouse.containsMouse ? Theme.primary : Theme.alpha(Theme.scrim, 0.78)

                                            Text {
                                                anchors.centerIn: parent
                                                text: Theme.iconPin
                                                font.family: Theme.fontIcon
                                                font.variableAxes: Theme.iconAxes
                                                font.pixelSize: 10
                                                color: pinBtnMouse.containsMouse ? Theme.on_primary : Theme.on_surface
                                            }

                                            MouseArea {
                                                id: pinBtnMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    popup.open = false;
                                                    ScreenshotService.pinFile(capTile.modelData.path, 480, 300, root.targetScreen?.name || "");
                                                }
                                            }
                                        }

                                        Rectangle {
                                            visible: capTile.isImg
                                            width: 19
                                            height: 19
                                            radius: 9.5
                                            color: prettyBtnMouse.containsMouse ? Theme.primary : Theme.alpha(Theme.scrim, 0.78)

                                            Text {
                                                anchors.centerIn: parent
                                                text: Theme.iconFrame
                                                font.family: Theme.fontIcon
                                                font.variableAxes: Theme.iconAxes
                                                font.pixelSize: 10
                                                color: prettyBtnMouse.containsMouse ? Theme.on_primary : Theme.on_surface
                                            }

                                            MouseArea {
                                                id: prettyBtnMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    popup.open = false;
                                                    ScreenshotService.runQuickPrettify(capTile.modelData.path);
                                                }
                                            }
                                        }

                                        Rectangle {
                                            width: 19
                                            height: 19
                                            radius: 9.5
                                            color: openBtnMouse.containsMouse ? Theme.primary : Theme.alpha(Theme.scrim, 0.78)

                                            Text {
                                                anchors.centerIn: parent
                                                text: Theme.iconExternalLink
                                                font.family: Theme.fontIcon
                                                font.variableAxes: Theme.iconAxes
                                                font.pixelSize: 10
                                                color: openBtnMouse.containsMouse ? Theme.on_primary : Theme.on_surface
                                            }

                                            MouseArea {
                                                id: openBtnMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: Quickshell.execDetached(["xdg-open", capTile.modelData.path])
                                            }
                                        }

                                        Rectangle {
                                            width: 19
                                            height: 19
                                            radius: 9.5
                                            color: rmBtnMouse.containsMouse ? Theme.error : Theme.alpha(Theme.scrim, 0.78)

                                            Text {
                                                anchors.centerIn: parent
                                                text: Theme.iconClose
                                                font.family: Theme.fontIcon
                                                font.variableAxes: Theme.iconAxes
                                                font.pixelSize: 10
                                                color: rmBtnMouse.containsMouse ? Theme.on_error : Theme.on_surface
                                            }

                                            MouseArea {
                                                id: rmBtnMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    Quickshell.execDetached(["rm", "-f", "--", capTile.modelData.path]);
                                                    refreshAfterDeleteTimer.restart();
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Timer {
                        id: refreshAfterDeleteTimer
                        interval: 120
                        onTriggered: root.refreshRecentCaptures()
                    }
                }
            }

            // quick folder footer actions
            RowLayout {
                visible: !root.showSettings
                Layout.fillWidth: true
                spacing: 8

                MiniChip {
                    icon: Theme.iconFolder
                    label: "open screenshots"
                    fillWidth: true
                    Layout.preferredHeight: 30
                    onClicked: {
                        popup.open = false;
                        let rawDir = Settings?.screenshotDir || ((Quickshell.env("HOME") || "") + "/Pictures/Screenshots");
                        let dir = ScreenshotService?.expandHome ? ScreenshotService.expandHome(rawDir) : rawDir.replace(/^~/, Quickshell.env("HOME") || "");
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
