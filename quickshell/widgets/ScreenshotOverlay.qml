import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import ".."
import "../controls"

PanelWindow {
    id: overlayRoot

    required property var modelData
    screen: modelData

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"

    WlrLayershell.namespace: "quickshell:screenshot"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: (ScreenshotService.isOpen && !overlayRoot.isQuickFullscreen && overlayRoot.activeOnThisScreen)
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    readonly property bool isEditingFile: (ScreenshotService.editingFilePath || "") !== ""
    readonly property bool activeOnThisScreen: {
        if (!isEditingFile) return true;
        let focused = ScreenshotService.getFocusedScreen ? ScreenshotService.getFocusedScreen() : null;
        return !focused || focused.name === overlayRoot.screen.name;
    }

    visible: (ScreenshotService.isOpen && overlayRoot.activeOnThisScreen) || closeAfterFlashTimer.running

    // selection state
    property bool isPointerDown: false
    property bool isDragging: false
    property bool hasSelection: false
    property real startX: 0
    property real startY: 0
    property real currX: 0
    property real currY: 0
    property string dragAction: "none" // none|create|move|nw|n|ne|e|se|s|sw|w
    property real dragAnchorX: 0
    property real dragAnchorY: 0
    property real origSelX: 0
    property real origSelY: 0
    property real origSelW: 0
    property real origSelH: 0

    property var hoveredClient: null
    property bool isCapturing: false
    property real grabOffsetX: 0
    property real grabOffsetY: 0

    // cursor + pixel sampler + loupe state
    property real cursorX: overlayRoot.width / 2
    property real cursorY: overlayRoot.height / 2
    property bool cursorInside: false
    property string hoveredHex: "#000000"
    property bool pixelMapReady: false
    property string frozenStageUrl: ""
    property string _stageTmpPath: ""

    // studio annotation state
    property var annotations: []
    property var redoStack: []
    property var draftAnnotation: null
    property int stepCounter: 0
    property bool showTextInput: false
    property real pendingTextX: 0
    property real pendingTextY: 0

    readonly property bool isQuickFullscreen: ScreenshotService.activeMode === "fullscreen" && !overlayRoot.hasSelection && !overlayRoot.isEditingFile
    readonly property string scriptPath: decodeURIComponent(
        Qt.resolvedUrl("../scripts/screenshot.py").toString().replace(/^file:\/\//, "")
    )

    readonly property real selX: Math.min(startX, currX)
    readonly property real selY: Math.min(startY, currY)
    readonly property real selW: Math.abs(currX - startX)
    readonly property real selH: Math.abs(currY - startY)

    readonly property bool windowSnapEnabled: !isEditingFile
        && ScreenshotService.activeMode !== "eyedropper"
        && (ScreenshotService.activeMode === "window" || (Settings?.screenshotWindowSnapping ?? true))
    readonly property bool clientSnapped: !hasSelection && !isDragging && hoveredClient !== null

    readonly property real clientRawX: hoveredClient ? (Number(hoveredClient.at[0]) - screen.x) : 0
    readonly property real clientRawY: hoveredClient ? (Number(hoveredClient.at[1]) - screen.y) : 0
    readonly property real clientRelX: Math.max(0, clientRawX)
    readonly property real clientRelY: Math.max(0, clientRawY)
    readonly property real clientRelW: hoveredClient
        ? Math.max(0, Math.min(screen.width - clientRelX, Number(hoveredClient.size[0]) - (clientRelX - clientRawX)))
        : 0
    readonly property real clientRelH: hoveredClient
        ? Math.max(0, Math.min(screen.height - clientRelY, Number(hoveredClient.size[1]) - (clientRelY - clientRawY)))
        : 0

    readonly property real activeX: hasSelection ? selX : (clientSnapped ? clientRelX : (isDragging && dragAction === "create" ? selX : 0))
    readonly property real activeY: hasSelection ? selY : (clientSnapped ? clientRelY : (isDragging && dragAction === "create" ? selY : 0))
    readonly property real activeW: hasSelection ? selW : (clientSnapped ? clientRelW : (isDragging && dragAction === "create" ? selW : 0))
    readonly property real activeH: hasSelection ? selH : (clientSnapped ? clientRelH : (isDragging && dragAction === "create" ? selH : 0))
    readonly property bool hasActiveRegion: activeW > 4 && activeH > 4

    readonly property bool isDrawingTool: actionsBar.annotating && actionsBar.activeTool !== "select" && ScreenshotService.activeMode !== "record" && ScreenshotService.activeMode !== "eyedropper"
    readonly property real strokeWidthPx: actionsBar.strokeLevel === 0 ? 3 : (actionsBar.strokeLevel === 1 ? 6 : 11)

    readonly property var redactAnnotations: {
        let out = [];
        for (let i = 0; i < annotations.length; i++) {
            if (annotations[i] && annotations[i].kind === "redact") out.push(annotations[i]);
        }
        if (draftAnnotation && draftAnnotation.kind === "redact") out.push(draftAnnotation);
        return out;
    }

    readonly property bool showLoupe: {
        if (isQuickFullscreen || closeAfterFlashTimer.running || !cursorInside) return false;
        if (ScreenshotService.activeMode === "eyedropper") return true;
        if (!actionsBar.loupeActive || actionsBar.annotating || isEditingFile || ScreenshotService.activeMode === "record") return false;
        if (hasSelection && !isDragging) return false;
        return !mouseCapture.isOverActions(cursorX, cursorY);
    }

    function resetSelectionState() {
        overlayRoot.isPointerDown = false;
        overlayRoot.isDragging = false;
        overlayRoot.dragAction = "none";
        overlayRoot.hasSelection = false;
        overlayRoot.hoveredClient = null;
        overlayRoot.startX = 0;
        overlayRoot.startY = 0;
        overlayRoot.currX = 0;
        overlayRoot.currY = 0;
    }

    function resetStudioState() {
        overlayRoot.annotations = [];
        overlayRoot.redoStack = [];
        overlayRoot.draftAnnotation = null;
        overlayRoot.stepCounter = 0;
        overlayRoot.showTextInput = false;
        overlayRoot.grabOffsetX = 0;
        overlayRoot.grabOffsetY = 0;
        overlayRoot.pixelMapReady = false;
        overlayRoot.frozenStageUrl = "";
        actionsBar.activeTool = "select";
        vectorCanvas.requestPaint();
    }

    function lockClientSelection(c) {
        if (!c || !c.at || !c.size) return;
        let rawX = Number(c.at[0]) - screen.x;
        let rawY = Number(c.at[1]) - screen.y;
        let relX = Math.max(0, rawX);
        let relY = Math.max(0, rawY);
        let relW = Math.max(0, Math.min(screen.width - relX, Number(c.size[0]) - (relX - rawX)));
        let relH = Math.max(0, Math.min(screen.height - relY, Number(c.size[1]) - (relY - rawY)));
        if (relW <= 4 || relH <= 4) return;

        overlayRoot.hoveredClient = c;
        overlayRoot.startX = relX;
        overlayRoot.startY = relY;
        overlayRoot.currX = relX + relW;
        overlayRoot.currY = relY + relH;
        overlayRoot.hasSelection = true;
    }

    function checkHoveredClient(mx: real, my: real): void {
        if (!overlayRoot.windowSnapEnabled || isDragging || hasSelection) {
            if (!hasSelection) hoveredClient = null;
            return;
        }
        let gx = screen.x + mx;
        let gy = screen.y + my;
        let list = ScreenshotService.clients || [];
        for (let i = 0; i < list.length; i++) {
            let c = list[i];
            if (!c || !c.at || !c.size) continue;
            let cx = Number(c.at[0]);
            let cy = Number(c.at[1]);
            let cw = Number(c.size[0]);
            let ch = Number(c.size[1]);
            if (gx >= cx && gx <= cx + cw && gy >= cy && gy <= cy + ch) {
                hoveredClient = c;
                return;
            }
        }
        hoveredClient = null;
    }

    function hitTestHandle(mx: real, my: real): string {
        if (!hasSelection || isDrawingTool) return "none";
        let x1 = selX, y1 = selY, x2 = selX + selW, y2 = selY + selH;
        let xm = (x1 + x2) / 2, ym = (y1 + y2) / 2;
        let tol = 11;
        let nearL = Math.abs(mx - x1) <= tol;
        let nearR = Math.abs(mx - x2) <= tol;
        let nearT = Math.abs(my - y1) <= tol;
        let nearB = Math.abs(my - y2) <= tol;

        if (nearL && nearT) return "nw";
        if (nearR && nearT) return "ne";
        if (nearR && nearB) return "se";
        if (nearL && nearB) return "sw";
        if (nearT && Math.abs(mx - xm) <= tol * 1.5 && selW > 36) return "n";
        if (nearB && Math.abs(mx - xm) <= tol * 1.5 && selW > 36) return "s";
        if (nearL && Math.abs(my - ym) <= tol * 1.5 && selH > 36) return "w";
        if (nearR && Math.abs(my - ym) <= tol * 1.5 && selH > 36) return "e";
        if (mx > x1 && mx < x2 && my > y1 && my < y2) return "move";
        return "none";
    }

    function cursorForHandle(h: string): int {
        if (h === "nw" || h === "se") return Qt.SizeFDiagCursor;
        if (h === "ne" || h === "sw") return Qt.SizeBDiagCursor;
        if (h === "n" || h === "s") return Qt.SizeVerCursor;
        if (h === "e" || h === "w") return Qt.SizeHorCursor;
        if (h === "move") return Qt.SizeAllCursor;
        return overlayRoot.clientSnapped ? Qt.PointingHandCursor : Qt.CrossCursor;
    }

    function pushAnnotation(item) {
        if (!item) return;
        let next = annotations.slice();
        next.push(item);
        annotations = next;
        redoStack = [];
        vectorCanvas.requestPaint();
    }

    function undoAnnotation() {
        commitInlineText();
        if (annotations.length === 0) return;
        let next = annotations.slice();
        let popped = next.pop();
        if (popped && popped.kind === "step" && stepCounter > 0) {
            stepCounter = Math.max(0, popped.num - 1);
        }
        annotations = next;
        let rnext = redoStack.slice();
        rnext.push(popped);
        redoStack = rnext;
        vectorCanvas.requestPaint();
    }

    function redoAnnotation() {
        if (redoStack.length === 0) return;
        let rnext = redoStack.slice();
        let item = rnext.pop();
        redoStack = rnext;
        let next = annotations.slice();
        next.push(item);
        if (item && item.kind === "step") {
            stepCounter = Math.max(stepCounter, item.num);
        }
        annotations = next;
        vectorCanvas.requestPaint();
    }

    function clearAnnotations() {
        showTextInput = false;
        annotations = [];
        redoStack = [];
        draftAnnotation = null;
        stepCounter = 0;
        vectorCanvas.requestPaint();
    }

    function commitInlineText() {
        if (!showTextInput) return;
        let txt = inlineTextField.text.trim();
        showTextInput = false;
        inlineTextField.text = "";
        if (txt !== "") {
            pushAnnotation({
                kind: "text",
                x: pendingTextX,
                y: pendingTextY,
                text: txt,
                color: String(actionsBar.strokeColor),
                size: Math.max(13, Math.round(Theme.fontSizeMd + overlayRoot.strokeWidthPx * 1.4))
            });
        }
        keyHandler.forceActiveFocus();
    }

    function sampleHexAt(px: real, py: real): string {
        if (!overlayRoot.pixelMapReady || !pixelSamplerCanvas.available) return overlayRoot.hoveredHex;
        let ctx = pixelSamplerCanvas.getContext("2d");
        if (!ctx) return overlayRoot.hoveredHex;
        let sx = Math.max(0, Math.min(overlayRoot.width - 1, Math.round(px)));
        let sy = Math.max(0, Math.min(overlayRoot.height - 1, Math.round(py)));
        try {
            let d = ctx.getImageData(sx, sy, 1, 1).data;
            if (d && d.length >= 3) {
                let toHex = (n) => ("0" + Math.max(0, Math.min(255, n)).toString(16)).slice(-2);
                return "#" + toHex(d[0]) + toHex(d[1]) + toHex(d[2]);
            }
        } catch (e) {}
        return overlayRoot.hoveredHex;
    }

    function captureStageForSampling() {
        if (overlayRoot.isEditingFile) {
            if (overlayRoot.frozenStageUrl !== "") {
                pixelSamplerCanvas.unloadImage(overlayRoot.frozenStageUrl);
            }
            overlayRoot.frozenStageUrl = "file://" + ScreenshotService.editingFilePath;
            pixelSamplerCanvas.loadImage(overlayRoot.frozenStageUrl);
            return;
        }
        if (!frozenScreencopy.hasContent || overlayRoot.isQuickFullscreen) return;
        let runtime = Quickshell.env("XDG_RUNTIME_DIR") || "/tmp";
        let prevTmp = overlayRoot._stageTmpPath;
        let path = runtime + "/qs_stage_" + overlayRoot.screen.name + "_" + Date.now() + ".png";
        overlayRoot._stageTmpPath = path;
        cropExporter.grabToImage(function(result) {
            if (!result) return;
            if (result.saveToFile(path)) {
                if (overlayRoot.frozenStageUrl !== "") {
                    pixelSamplerCanvas.unloadImage(overlayRoot.frozenStageUrl);
                }
                if (prevTmp && prevTmp !== path) {
                    Quickshell.execDetached(["rm", "-f", "--", prevTmp]);
                }
                overlayRoot.frozenStageUrl = "file://" + path;
                pixelSamplerCanvas.loadImage(overlayRoot.frozenStageUrl);
            }
        });
    }

    function fitSelectionToEditedImage() {
        if (!overlayRoot.isEditingFile) return;
        if (editSourceImage.status !== Image.Ready || editSourceImage.implicitWidth <= 0 || editSourceImage.implicitHeight <= 0) return;
        let padX = 80;
        let padTop = 76;
        let padBot = 100;
        let availW = Math.max(120, overlayRoot.width - padX * 2);
        let availH = Math.max(120, overlayRoot.height - padTop - padBot);
        let scale = Math.min(1.0, Math.min(availW / editSourceImage.implicitWidth, availH / editSourceImage.implicitHeight));
        let drawW = Math.max(40, Math.round(editSourceImage.implicitWidth * scale));
        let drawH = Math.max(40, Math.round(editSourceImage.implicitHeight * scale));
        let drawX = Math.round((overlayRoot.width - drawW) / 2);
        let drawY = Math.round(padTop + (availH - drawH) / 2);
        editSourceImage.x = drawX;
        editSourceImage.y = drawY;
        editSourceImage.width = drawW;
        editSourceImage.height = drawH;
        overlayRoot.startX = drawX;
        overlayRoot.startY = drawY;
        overlayRoot.currX = drawX + drawW;
        overlayRoot.currY = drawY + drawH;
        overlayRoot.hasSelection = true;
        stageSampleTimer.restart();
    }

    Timer {
        id: stageSampleTimer
        interval: 45
        repeat: false
        onTriggered: overlayRoot.captureStageForSampling()
    }

    Timer {
        id: pendingGrabTimer
        interval: 35
        repeat: false
        property int retries: 0
        property real grabX: 0
        property real grabY: 0
        property real grabW: 0
        property real grabH: 0
        property string action: "both"
        onTriggered: {
            if (retries > 12) {
                retries = 0;
                overlayRoot.isCapturing = false;
                ScreenshotService.close();
                return;
            }
            retries++;
            overlayRoot.executeNativeGrab(grabX, grabY, grabW, grabH, action);
        }
    }

    Timer {
        id: closeAfterFlashTimer
        interval: 180
        repeat: false
        onTriggered: ScreenshotService.close()
    }

    function executeNativeGrab(x: real, y: real, w: real, h: real, action: string): void {
        if (overlayRoot.isCapturing && !pendingGrabTimer.running) return;
        commitInlineText();

        let grabX = Math.max(0, Math.round(x));
        let grabY = Math.max(0, Math.round(y));
        let grabW = Math.min(screen.width - grabX, Math.round(w));
        let grabH = Math.min(screen.height - grabY, Math.round(h));

        if (grabW <= 2 || grabH <= 2) {
            grabX = 0;
            grabY = 0;
            grabW = screen.width;
            grabH = screen.height;
        }

        if (ScreenshotService.activeMode === "record" || action === "record") {
            overlayRoot.isCapturing = false;
            ScreenshotService.close();
            if (typeof ScreenRecService !== "undefined" && ScreenRecService?.startRecordingRegion) {
                ScreenRecService.startRecordingRegion(overlayRoot.screen, grabX, grabY, grabW, grabH);
            }
            return;
        }

        overlayRoot.isCapturing = true;

        if (!overlayRoot.isEditingFile && !frozenScreencopy.hasContent) {
            frozenScreencopy.captureFrame();
            pendingGrabTimer.grabX = grabX;
            pendingGrabTimer.grabY = grabY;
            pendingGrabTimer.grabW = grabW;
            pendingGrabTimer.grabH = grabH;
            pendingGrabTimer.action = action;
            pendingGrabTimer.restart();
            return;
        }

        pendingGrabTimer.retries = 0;
        let act = action || Settings?.screenshotDefaultAction || "both";

        // shift container so cropExporter grabs exactly [grabX, grabY, grabW, grabH]
        // along with all vector annotations and mosaic layers in lockstep
        overlayRoot.grabOffsetX = grabX;
        overlayRoot.grabOffsetY = grabY;
        cropExporter.x = grabX;
        cropExporter.y = grabY;
        cropExporter.width = grabW;
        cropExporter.height = grabH;

        let runtime = Quickshell.env("XDG_RUNTIME_DIR") || "/tmp";
        let rawTmp = runtime + "/qs_raw_" + Date.now() + "_" + overlayRoot.screen.name + ".png";

        // only blur redactions need post-export ImageMagick pass; mosaic and solid are already baked into captureContent
        let cropRedacts = [];
        for (let i = 0; i < overlayRoot.redactAnnotations.length; i++) {
            let r = overlayRoot.redactAnnotations[i];
            if (!r || r.mode !== "blur") continue;
            cropRedacts.push({
                x: r.x - grabX,
                y: r.y - grabY,
                w: r.w,
                h: r.h,
                mode: r.mode,
                color: r.color
            });
        }

        let isPin = (act === "pin");
        let prettyEnabled = actionsBar.prettifyActive;

        cropExporter.grabToImage(function(result) {
            cropExporter.x = 0;
            cropExporter.y = 0;
            cropExporter.width = overlayRoot.screen.width;
            cropExporter.height = overlayRoot.screen.height;
            overlayRoot.grabOffsetX = 0;
            overlayRoot.grabOffsetY = 0;
            overlayRoot.isCapturing = false;

            if (!result || !result.saveToFile(rawTmp)) {
                ScreenshotService.close();
                return;
            }

            let rawDir = Settings?.screenshotDir || "~/Pictures/Screenshots";
            let dir = rawDir.replace(/^~/, Quickshell.env("HOME") || "");
            Quickshell.execDetached(["mkdir", "-p", dir]);

            ScreenshotService.submitExport(
                rawTmp,
                act,
                overlayRoot.screen.name,
                grabW,
                grabH,
                cropRedacts,
                prettyEnabled,
                isPin
            );

            if ((Settings?.screenshotFlash ?? true) && !isPin) {
                flashAnim.restart();
                closeAfterFlashTimer.restart();
            } else {
                ScreenshotService.close();
            }
        });
    }

    Connections {
        target: ScreenshotService
        function onIsOpenChanged() {
            if (!ScreenshotService.isOpen) {
                overlayRoot.resetSelectionState();
                overlayRoot.resetStudioState();
                overlayRoot.isCapturing = false;
                pendingGrabTimer.stop();
                pendingGrabTimer.retries = 0;
            } else if (overlayRoot.activeOnThisScreen) {
                let rawDir = Settings?.screenshotDir || "~/Pictures/Screenshots";
                let dir = rawDir.replace(/^~/, Quickshell.env("HOME") || "");
                Quickshell.execDetached(["mkdir", "-p", dir]);

                actionsBar.randomizeQuote();
                actionsBar.annotating = ScreenshotService.startAnnotating || overlayRoot.isEditingFile;
                actionsBar.prettifyActive = Boolean(Settings?.screenshotPrettifyEnabled ?? false);
                actionsBar.loupeActive = Boolean(Settings?.screenshotShowLoupe ?? true);
                overlayRoot.resetStudioState();

                if (overlayRoot.isEditingFile) {
                    actionsBar.activeTool = "pen";
                    fitSelectionToEditedImage();
                } else {
                    frozenScreencopy.captureFrame();
                    stageSampleTimer.restart();
                }
                keyHandler.forceActiveFocus();
            }
        }

        function onPerformCapture(targetScreen, action, x, y, w, h) {
            if (targetScreen && targetScreen.name !== overlayRoot.screen.name) return;
            overlayRoot.executeNativeGrab(x, y, w, h, action);
        }

        function onPerformFullscreen(targetScreen, action) {
            if (targetScreen && targetScreen.name !== overlayRoot.screen.name) return;
            overlayRoot.executeNativeGrab(0, 0, overlayRoot.screen.width, overlayRoot.screen.height, action);
        }
    }

    // off-screen canvas purely for sub-millisecond pixel color readout
    Canvas {
        id: pixelSamplerCanvas
        width: overlayRoot.width
        height: overlayRoot.height
        visible: overlayRoot.visible
        opacity: 0.001
        enabled: false
        z: -50
        onImageLoaded: {
            if (available) requestPaint();
        }
        onAvailableChanged: {
            if (available && overlayRoot.frozenStageUrl !== "" && isImageLoaded(overlayRoot.frozenStageUrl)) {
                requestPaint();
            }
        }
        onPaint: {
            if (!available || overlayRoot.frozenStageUrl === "" || !isImageLoaded(overlayRoot.frozenStageUrl)) return;
            let ctx = getContext("2d");
            if (!ctx) return;
            ctx.clearRect(0, 0, width, height);
            if (overlayRoot.isEditingFile && editSourceImage.status === Image.Ready) {
                ctx.drawImage(overlayRoot.frozenStageUrl, editSourceImage.x, editSourceImage.y, editSourceImage.width, editSourceImage.height);
            } else {
                ctx.drawImage(overlayRoot.frozenStageUrl, 0, 0, width, height);
            }
            overlayRoot.pixelMapReady = true;
            overlayRoot.hoveredHex = overlayRoot.sampleHexAt(overlayRoot.cursorX, overlayRoot.cursorY);
        }
    }

    // dark blurred workspace backdrop when editing an existing saved/clipboard image
    Rectangle {
        anchors.fill: parent
        visible: overlayRoot.isEditingFile
        color: Theme.alpha("#090a10", 0.90)
        z: 0
    }

    // cropExporter wraps captureContent (background + mosaic/solid redacts + vector annotations)
    Item {
        id: cropExporter
        x: 0
        y: 0
        width: overlayRoot.screen.width
        height: overlayRoot.screen.height
        clip: true
        z: 0

        Item {
            id: captureContent
            x: -overlayRoot.grabOffsetX
            y: -overlayRoot.grabOffsetY
            width: overlayRoot.screen.width
            height: overlayRoot.screen.height

            ScreencopyView {
                id: frozenScreencopy
                x: 0
                y: 0
                width: overlayRoot.screen.width
                height: overlayRoot.screen.height
                paintCursor: Boolean(Settings?.screenshotIncludeCursor ?? false)
                captureSource: (!overlayRoot.isEditingFile && (ScreenshotService.isOpen || overlayRoot.isCapturing)) ? overlayRoot.screen : null
                live: !(Settings?.screenshotFreeze ?? true) && !actionsBar.annotating && !overlayRoot.isCapturing
                visible: !overlayRoot.isEditingFile && ((Settings?.screenshotFreeze ?? true) || overlayRoot.isCapturing)
                onHasContentChanged: {
                    if (hasContent && ScreenshotService.isOpen && !overlayRoot.isQuickFullscreen) {
                        stageSampleTimer.restart();
                    }
                }
            }

            Image {
                id: editSourceImage
                visible: overlayRoot.isEditingFile
                source: overlayRoot.isEditingFile ? ("file://" + ScreenshotService.editingFilePath) : ""
                fillMode: Image.PreserveAspectFit
                smooth: true
                cache: false
                onStatusChanged: {
                    if (status === Image.Ready) {
                        overlayRoot.fitSelectionToEditedImage();
                    }
                }
            }

            // live pixelation / solid / blur preview redaction blocks
            Repeater {
                model: overlayRoot.redactAnnotations

                delegate: Item {
                    required property var modelData
                    x: modelData.x
                    y: modelData.y
                    width: Math.max(2, modelData.w)
                    height: Math.max(2, modelData.h)
                    clip: true

                    ShaderEffectSource {
                        visible: modelData.mode === "mosaic"
                        anchors.fill: parent
                        sourceItem: overlayRoot.isEditingFile ? editSourceImage : frozenScreencopy
                        sourceRect: overlayRoot.isEditingFile
                            ? Qt.rect(
                                Math.max(0, modelData.x - editSourceImage.x),
                                Math.max(0, modelData.y - editSourceImage.y),
                                Math.max(2, modelData.w),
                                Math.max(2, modelData.h)
                            )
                            : Qt.rect(modelData.x, modelData.y, Math.max(2, modelData.w), Math.max(2, modelData.h))
                        textureSize: Qt.size(Math.max(2, Math.round(modelData.w / 14)), Math.max(2, Math.round(modelData.h / 14)))
                        smooth: false
                        live: false
                    }

                    Rectangle {
                        visible: modelData.mode === "solid"
                        anchors.fill: parent
                        color: modelData.color || "#0f1016"
                    }

                    Rectangle {
                        visible: modelData.mode === "blur"
                        anchors.fill: parent
                        color: Theme.alpha("#0c0e14", overlayRoot.isCapturing ? 0.0 : 0.72)
                        border.width: overlayRoot.isCapturing ? 0 : 1
                        border.color: Theme.alpha(Theme.primary, 0.7)

                        Text {
                            visible: !overlayRoot.isCapturing && parent.width > 42 && parent.height > 18
                            anchors.centerIn: parent
                            text: "blur"
                            font.family: Theme.fontMono
                            font.variableAxes: Theme.monoAxes
                            font.pixelSize: 10
                            font.weight: Theme.monoWeightBold
                            color: Theme.on_surface
                        }
                    }
                }
            }

            // vector annotations layer
            Canvas {
                id: vectorCanvas
                x: 0
                y: 0
                width: overlayRoot.screen.width
                height: overlayRoot.screen.height

                function drawAnnotationItem(ctx, item) {
                    if (!item) return;
                    let kind = item.kind;
                    if (kind === "redact") return; // drawn in redact Repeater above

                    ctx.save();
                    let col = item.color || "#ffffff";

                    if (kind === "pen" || kind === "highlighter") {
                        let pts = item.points || [];
                        if (pts.length < 1) { ctx.restore(); return; }
                        ctx.globalAlpha = (kind === "highlighter") ? 0.36 : 1.0;
                        ctx.strokeStyle = col;
                        ctx.lineWidth = item.width || 6;
                        ctx.lineCap = "round";
                        ctx.lineJoin = "round";
                        ctx.beginPath();
                        ctx.moveTo(pts[0].x, pts[0].y);
                        if (pts.length === 1) {
                            ctx.lineTo(pts[0].x + 0.1, pts[0].y + 0.1);
                        } else {
                            for (let i = 1; i < pts.length; i++) {
                                let midX = (pts[i - 1].x + pts[i].x) / 2;
                                let midY = (pts[i - 1].y + pts[i].y) / 2;
                                ctx.quadraticCurveTo(pts[i - 1].x, pts[i - 1].y, midX, midY);
                            }
                            ctx.lineTo(pts[pts.length - 1].x, pts[pts.length - 1].y);
                        }
                        ctx.stroke();
                    } else if (kind === "arrow") {
                        let x1 = item.x1, y1 = item.y1, x2 = item.x2, y2 = item.y2;
                        let dx = x2 - x1, dy = y2 - y1;
                        let len = Math.sqrt(dx * dx + dy * dy);
                        if (len < 3) { ctx.restore(); return; }
                        let angle = Math.atan2(dy, dx);
                        let lw = item.width || 6;
                        let headLen = Math.max(12, lw * 3.1);
                        let backX = x2 - Math.cos(angle) * (headLen * 0.65);
                        let backY = y2 - Math.sin(angle) * (headLen * 0.65);

                        ctx.strokeStyle = col;
                        ctx.fillStyle = col;
                        ctx.lineWidth = lw;
                        ctx.lineCap = "round";
                        ctx.beginPath();
                        ctx.moveTo(x1, y1);
                        ctx.lineTo(backX, backY);
                        ctx.stroke();

                        ctx.beginPath();
                        ctx.moveTo(x2, y2);
                        ctx.lineTo(x2 - headLen * Math.cos(angle - Math.PI / 6), y2 - headLen * Math.sin(angle - Math.PI / 6));
                        ctx.lineTo(x2 - headLen * 0.72 * Math.cos(angle), y2 - headLen * 0.72 * Math.sin(angle));
                        ctx.lineTo(x2 - headLen * Math.cos(angle + Math.PI / 6), y2 - headLen * Math.sin(angle + Math.PI / 6));
                        ctx.closePath();
                        ctx.fill();
                    } else if (kind === "rect") {
                        ctx.strokeStyle = col;
                        ctx.lineWidth = item.width || 4;
                        ctx.lineJoin = "round";
                        ctx.strokeRect(item.x, item.y, item.w, item.h);
                    } else if (kind === "ellipse") {
                        let rx = Math.abs(item.w) / 2;
                        let ry = Math.abs(item.h) / 2;
                        if (rx > 1 && ry > 1) {
                            let cx = item.x + rx;
                            let cy = item.y + ry;
                            ctx.strokeStyle = col;
                            ctx.lineWidth = item.width || 4;
                            ctx.beginPath();
                            ctx.ellipse(cx - rx, cy - ry, rx * 2, ry * 2);
                            ctx.stroke();
                        }
                    } else if (kind === "step") {
                        let r = item.size || 14;
                        ctx.fillStyle = "rgba(0,0,0,0.45)";
                        ctx.beginPath();
                        ctx.arc(item.x, item.y + 2, r + 1, 0, Math.PI * 2);
                        ctx.fill();

                        ctx.fillStyle = col;
                        ctx.beginPath();
                        ctx.arc(item.x, item.y, r, 0, Math.PI * 2);
                        ctx.fill();

                        ctx.strokeStyle = "#ffffff";
                        ctx.lineWidth = 2;
                        ctx.stroke();

                        let luma = (col.toLowerCase() === "#ffffff" || col.toLowerCase() === "#f59e0b" || col.toLowerCase() === "#38bdf8");
                        ctx.fillStyle = luma ? "#111116" : "#ffffff";
                        ctx.font = "bold " + Math.round(r * 1.05) + "px \"" + Theme.fontSans + "\"";
                        ctx.textAlign = "center";
                        ctx.textBaseline = "middle";
                        ctx.fillText(String(item.num || 1), item.x, item.y + 0.5);
                    } else if (kind === "text") {
                        let px = item.size || 16;
                        ctx.font = "bold " + px + "px \"" + Theme.fontSans + "\"";
                        ctx.textAlign = "left";
                        ctx.textBaseline = "top";
                        ctx.lineWidth = Math.max(3, Math.round(px * 0.22));
                        ctx.strokeStyle = col.toLowerCase() === "#111116" ? "rgba(255,255,255,0.85)" : "rgba(10,12,18,0.82)";
                        ctx.lineJoin = "round";
                        ctx.strokeText(item.text || "", item.x, item.y);
                        ctx.fillStyle = col;
                        ctx.fillText(item.text || "", item.x, item.y);
                    }

                    ctx.restore();
                }

                onPaint: {
                    let ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    let list = overlayRoot.annotations;
                    for (let i = 0; i < list.length; i++) {
                        drawAnnotationItem(ctx, list[i]);
                    }
                    if (overlayRoot.draftAnnotation) {
                        drawAnnotationItem(ctx, overlayRoot.draftAnnotation);
                    }
                }
            }
        }
    }

    Item {
        id: keyHandler
        anchors.fill: parent
        focus: ScreenshotService.isOpen && overlayRoot.activeOnThisScreen && !overlayRoot.showTextInput
        z: 1

        Keys.onPressed: (event) => {
            if (overlayRoot.showTextInput) return;

            let ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
            let shift = (event.modifiers & Qt.ShiftModifier) !== 0;

            if (event.key === Qt.Key_Escape) {
                if (overlayRoot.hasSelection && !overlayRoot.isEditingFile) {
                    overlayRoot.resetSelectionState();
                } else {
                    ScreenshotService.close();
                }
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                let act = Settings?.screenshotDefaultAction || "both";
                if (overlayRoot.hasActiveRegion) {
                    overlayRoot.executeNativeGrab(overlayRoot.activeX, overlayRoot.activeY, overlayRoot.activeW, overlayRoot.activeH, act);
                } else {
                    overlayRoot.executeNativeGrab(0, 0, overlayRoot.screen.width, overlayRoot.screen.height, act);
                }
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_Space && !overlayRoot.isEditingFile) {
                overlayRoot.hasSelection = true;
                overlayRoot.startX = 0;
                overlayRoot.startY = 0;
                overlayRoot.currX = overlayRoot.screen.width;
                overlayRoot.currY = overlayRoot.screen.height;
                event.accepted = true;
                return;
            }

            if (ctrl && event.key === Qt.Key_Z) {
                if (shift) overlayRoot.redoAnnotation();
                else overlayRoot.undoAnnotation();
                event.accepted = true;
                return;
            }
            if (ctrl && event.key === Qt.Key_Y) {
                overlayRoot.redoAnnotation();
                event.accepted = true;
                return;
            }
            if (ctrl && event.key === Qt.Key_C) {
                if (ScreenshotService.activeMode === "eyedropper") {
                    ScreenshotService.copyColor(overlayRoot.hoveredHex);
                    ScreenshotService.close();
                } else {
                    let gx = overlayRoot.hasActiveRegion ? overlayRoot.activeX : 0;
                    let gy = overlayRoot.hasActiveRegion ? overlayRoot.activeY : 0;
                    let gw = overlayRoot.hasActiveRegion ? overlayRoot.activeW : overlayRoot.screen.width;
                    let gh = overlayRoot.hasActiveRegion ? overlayRoot.activeH : overlayRoot.screen.height;
                    overlayRoot.executeNativeGrab(gx, gy, gw, gh, "copy");
                }
                event.accepted = true;
                return;
            }
            if (ctrl && event.key === Qt.Key_S) {
                let gx = overlayRoot.hasActiveRegion ? overlayRoot.activeX : 0;
                let gy = overlayRoot.hasActiveRegion ? overlayRoot.activeY : 0;
                let gw = overlayRoot.hasActiveRegion ? overlayRoot.activeW : overlayRoot.screen.width;
                let gh = overlayRoot.hasActiveRegion ? overlayRoot.activeH : overlayRoot.screen.height;
                overlayRoot.executeNativeGrab(gx, gy, gw, gh, "save");
                event.accepted = true;
                return;
            }

            // arrow key selection nudge / resize
            if (overlayRoot.hasSelection && (
                event.key === Qt.Key_Left || event.key === Qt.Key_Right ||
                event.key === Qt.Key_Up || event.key === Qt.Key_Down
            )) {
                let step = shift ? 10 : 1;
                let alt = (event.modifiers & Qt.AltModifier) !== 0;
                let x = overlayRoot.selX, y = overlayRoot.selY, w = overlayRoot.selW, h = overlayRoot.selH;
                if (alt) {
                    if (event.key === Qt.Key_Right) w = Math.min(overlayRoot.width - x, w + step);
                    else if (event.key === Qt.Key_Left) w = Math.max(12, w - step);
                    else if (event.key === Qt.Key_Down) h = Math.min(overlayRoot.height - y, h + step);
                    else if (event.key === Qt.Key_Up) h = Math.max(12, h - step);
                } else {
                    if (event.key === Qt.Key_Left) x = Math.max(0, x - step);
                    else if (event.key === Qt.Key_Right) x = Math.min(overlayRoot.width - w, x + step);
                    else if (event.key === Qt.Key_Up) y = Math.max(0, y - step);
                    else if (event.key === Qt.Key_Down) y = Math.min(overlayRoot.height - h, y + step);
                }
                overlayRoot.startX = x;
                overlayRoot.startY = y;
                overlayRoot.currX = x + w;
                overlayRoot.currY = y + h;
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_Backspace && overlayRoot.annotations.length > 0) {
                overlayRoot.undoAnnotation();
                event.accepted = true;
                return;
            }

            // single-key studio shortcuts
            if (!ctrl) {
                if (event.key === Qt.Key_A) {
                    actionsBar.annotating = !actionsBar.annotating;
                    if (!actionsBar.annotating) actionsBar.activeTool = "select";
                } else if (event.key === Qt.Key_P) {
                    actionsBar.prettifyActive = !actionsBar.prettifyActive;
                } else if (event.key === Qt.Key_Z) {
                    actionsBar.loupeActive = !actionsBar.loupeActive;
                } else if (event.key === Qt.Key_C) {
                    ScreenshotService.copyColor(overlayRoot.hoveredHex);
                    ScreenshotService.close();
                } else if (actionsBar.annotating) {
                    if (event.key === Qt.Key_V) actionsBar.activeTool = "select";
                    else if (event.key === Qt.Key_B) actionsBar.activeTool = "pen";
                    else if (event.key === Qt.Key_H) actionsBar.activeTool = "highlighter";
                    else if (event.key === Qt.Key_R) actionsBar.activeTool = "rect";
                    else if (event.key === Qt.Key_O) actionsBar.activeTool = "ellipse";
                    else if (event.key === Qt.Key_N) actionsBar.activeTool = "step";
                    else if (event.key === Qt.Key_T) actionsBar.activeTool = "text";
                    else if (event.key === Qt.Key_M) actionsBar.activeTool = "blur";
                }
            }
        }
    }

    // full-screen dim when no region is active
    Rectangle {
        anchors.fill: parent
        color: Theme.alpha("#000000", ScreenshotService.activeMode === "eyedropper" ? 0.08 : (Settings?.screenshotDimOpacity ?? 0.45))
        visible: !overlayRoot.hasActiveRegion && !overlayRoot.isQuickFullscreen && !closeAfterFlashTimer.running && !overlayRoot.isCapturing
        z: 2
    }

    // 4-part dim mask surrounding active selection
    Item {
        anchors.fill: parent
        visible: overlayRoot.hasActiveRegion && !overlayRoot.isQuickFullscreen && !closeAfterFlashTimer.running && !overlayRoot.isCapturing
        z: 2

        readonly property color dimColor: Theme.alpha("#000000", overlayRoot.isEditingFile ? 0.65 : (Settings?.screenshotDimOpacity ?? 0.45))

        Rectangle { x: 0; y: 0; width: overlayRoot.width; height: Math.max(0, overlayRoot.activeY); color: parent.dimColor }
        Rectangle { x: 0; y: overlayRoot.activeY + overlayRoot.activeH; width: overlayRoot.width; height: Math.max(0, overlayRoot.height - (overlayRoot.activeY + overlayRoot.activeH)); color: parent.dimColor }
        Rectangle { x: 0; y: overlayRoot.activeY; width: Math.max(0, overlayRoot.activeX); height: overlayRoot.activeH; color: parent.dimColor }
        Rectangle { x: overlayRoot.activeX + overlayRoot.activeW; y: overlayRoot.activeY; width: Math.max(0, overlayRoot.width - (overlayRoot.activeX + overlayRoot.activeW)); height: overlayRoot.activeH; color: parent.dimColor }
    }

    // alignment crosshair
    Item {
        anchors.fill: parent
        visible: ((Settings?.screenshotShowCrosshair ?? true) || ScreenshotService.activeMode === "eyedropper")
            && !overlayRoot.hasSelection
            && !overlayRoot.isDragging
            && !overlayRoot.clientSnapped
            && !overlayRoot.isQuickFullscreen
            && !closeAfterFlashTimer.running
            && !overlayRoot.isCapturing
        z: 3

        Rectangle {
            x: 0
            y: overlayRoot.cursorY
            width: parent.width
            height: 1
            color: Theme.alpha(Theme.primary, 0.42)
        }
        Rectangle {
            x: overlayRoot.cursorX
            y: 0
            width: 1
            height: parent.height
            color: Theme.alpha(Theme.primary, 0.42)
        }
    }

    MouseArea {
        id: mouseCapture
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        visible: !overlayRoot.isQuickFullscreen && !closeAfterFlashTimer.running
        z: 5

        cursorShape: {
            if (ScreenshotService.activeMode === "eyedropper") return Qt.CrossCursor;
            if (overlayRoot.isDrawingTool) return Qt.CrossCursor;
            if (overlayRoot.dragAction !== "none") return overlayRoot.cursorForHandle(overlayRoot.dragAction);
            if (overlayRoot.hasSelection) {
                let h = overlayRoot.hitTestHandle(mouseX, mouseY);
                if (h !== "none") return overlayRoot.cursorForHandle(h);
            }
            return overlayRoot.clientSnapped ? Qt.PointingHandCursor : Qt.CrossCursor;
        }

        function isOverActions(mx: real, my: real): bool {
            if (!actionsBar.visible) return false;
            let pad = 8;
            let actW = actionsBar.width > 0 ? actionsBar.width : actionsBar.implicitWidth;
            let actH = actionsBar.height > 0 ? actionsBar.height : actionsBar.implicitHeight;
            let bx = actionsBar.x - pad;
            let by = actionsBar.y - 32;
            let bw = actW + pad * 2;
            let bh = actH + 32 + pad * 2;
            return (mx >= bx && mx <= bx + bw && my >= by && my <= by + bh);
        }

        onEntered: overlayRoot.cursorInside = true
        onExited: overlayRoot.cursorInside = false

        onPressed: (mouse) => {
            overlayRoot.cursorX = mouse.x;
            overlayRoot.cursorY = mouse.y;
            overlayRoot.cursorInside = true;

            if (overlayRoot.showTextInput) {
                overlayRoot.commitInlineText();
            }
            keyHandler.forceActiveFocus();

            if (mouse.button === Qt.RightButton) {
                if (overlayRoot.isDrawingTool && overlayRoot.annotations.length > 0) {
                    overlayRoot.undoAnnotation();
                } else if (overlayRoot.hasSelection && !overlayRoot.isEditingFile) {
                    overlayRoot.resetSelectionState();
                    overlayRoot.checkHoveredClient(mouse.x, mouse.y);
                } else {
                    ScreenshotService.close();
                }
                return;
            }

            if (isOverActions(mouse.x, mouse.y)) {
                mouse.accepted = false;
                return;
            }

            // eyedropper single click picks pixel color and exits cleanly
            if (ScreenshotService.activeMode === "eyedropper") {
                let hex = overlayRoot.sampleHexAt(mouse.x, mouse.y);
                ScreenshotService.copyColor(hex);
                ScreenshotService.close();
                return;
            }

            // annotation drawing tools
            if (overlayRoot.isDrawingTool) {
                let tool = actionsBar.activeTool;
                let col = String(actionsBar.strokeColor);
                let lw = overlayRoot.strokeWidthPx;

                if (tool === "step") {
                    overlayRoot.stepCounter += 1;
                    overlayRoot.pushAnnotation({
                        kind: "step",
                        x: mouse.x,
                        y: mouse.y,
                        num: overlayRoot.stepCounter,
                        color: col,
                        size: 12 + overlayRoot.strokeLevel * 3
                    });
                    return;
                }

                if (tool === "text") {
                    overlayRoot.pendingTextX = Math.max(8, Math.min(overlayRoot.width - 220, mouse.x));
                    overlayRoot.pendingTextY = Math.max(8, Math.min(overlayRoot.height - 48, mouse.y));
                    overlayRoot.showTextInput = true;
                    inlineTextField.text = "";
                    inlineTextField.forceActiveFocus();
                    return;
                }

                overlayRoot.isPointerDown = true;
                overlayRoot.isDragging = true;
                overlayRoot.dragAnchorX = mouse.x;
                overlayRoot.dragAnchorY = mouse.y;

                if (tool === "pen" || tool === "highlighter") {
                    overlayRoot.draftAnnotation = {
                        kind: tool,
                        points: [{ x: mouse.x, y: mouse.y }],
                        color: col,
                        width: tool === "highlighter" ? Math.round(lw * 2.8) : lw
                    };
                } else if (tool === "arrow") {
                    overlayRoot.draftAnnotation = {
                        kind: "arrow",
                        x1: mouse.x, y1: mouse.y,
                        x2: mouse.x, y2: mouse.y,
                        color: col,
                        width: lw
                    };
                } else if (tool === "rect" || tool === "ellipse") {
                    overlayRoot.draftAnnotation = {
                        kind: tool,
                        x: mouse.x, y: mouse.y, w: 0, h: 0,
                        color: col,
                        width: lw
                    };
                } else if (tool === "blur") {
                    overlayRoot.draftAnnotation = {
                        kind: "redact",
                        x: mouse.x, y: mouse.y, w: 0, h: 0,
                        mode: actionsBar.redactMode,
                        color: col
                    };
                }
                vectorCanvas.requestPaint();
                return;
            }

            // selection / move / resize state
            overlayRoot.isPointerDown = true;
            overlayRoot.dragAnchorX = mouse.x;
            overlayRoot.dragAnchorY = mouse.y;

            if (overlayRoot.hasSelection) {
                let handle = overlayRoot.hitTestHandle(mouse.x, mouse.y);
                if (handle !== "none") {
                    overlayRoot.dragAction = handle;
                    overlayRoot.origSelX = overlayRoot.selX;
                    overlayRoot.origSelY = overlayRoot.selY;
                    overlayRoot.origSelW = overlayRoot.selW;
                    overlayRoot.origSelH = overlayRoot.selH;
                    overlayRoot.isDragging = true;
                    return;
                }
            }

            overlayRoot.dragAction = "create";
            overlayRoot.isDragging = false;
            overlayRoot.startX = mouse.x;
            overlayRoot.startY = mouse.y;
            overlayRoot.currX = mouse.x;
            overlayRoot.currY = mouse.y;
        }

        onPositionChanged: (mouse) => {
            overlayRoot.cursorX = mouse.x;
            overlayRoot.cursorY = mouse.y;
            overlayRoot.cursorInside = true;

            if (overlayRoot.showLoupe) {
                overlayRoot.hoveredHex = overlayRoot.sampleHexAt(mouse.x, mouse.y);
            }

            // drawing active annotation
            if (overlayRoot.isPointerDown && overlayRoot.isDrawingTool && overlayRoot.draftAnnotation) {
                let d = overlayRoot.draftAnnotation;
                let shift = (mouse.modifiers & Qt.ShiftModifier) !== 0;

                if (d.kind === "pen" || d.kind === "highlighter") {
                    let pts = d.points.slice();
                    let last = pts[pts.length - 1];
                    if (Math.abs(mouse.x - last.x) > 1.5 || Math.abs(mouse.y - last.y) > 1.5) {
                        pts.push({ x: mouse.x, y: mouse.y });
                        overlayRoot.draftAnnotation = Object.assign({}, d, { points: pts });
                    }
                } else if (d.kind === "arrow") {
                    let x2 = mouse.x, y2 = mouse.y;
                    if (shift) {
                        let dx = x2 - d.x1, dy = y2 - d.y1;
                        let angle = Math.round(Math.atan2(dy, dx) / (Math.PI / 4)) * (Math.PI / 4);
                        let dist = Math.sqrt(dx * dx + dy * dy);
                        x2 = d.x1 + Math.cos(angle) * dist;
                        y2 = d.y1 + Math.sin(angle) * dist;
                    }
                    overlayRoot.draftAnnotation = Object.assign({}, d, { x2: x2, y2: y2 });
                } else if (d.kind === "rect" || d.kind === "ellipse" || d.kind === "redact") {
                    let dx = mouse.x - overlayRoot.dragAnchorX;
                    let dy = mouse.y - overlayRoot.dragAnchorY;
                    if (shift && d.kind !== "redact") {
                        let side = Math.max(Math.abs(dx), Math.abs(dy));
                        dx = dx >= 0 ? side : -side;
                        dy = dy >= 0 ? side : -side;
                    }
                    let rx = dx >= 0 ? overlayRoot.dragAnchorX : overlayRoot.dragAnchorX + dx;
                    let ry = dy >= 0 ? overlayRoot.dragAnchorY : overlayRoot.dragAnchorY + dy;
                    overlayRoot.draftAnnotation = Object.assign({}, d, {
                        x: rx, y: ry,
                        w: Math.abs(dx), h: Math.abs(dy)
                    });
                }
                vectorCanvas.requestPaint();
                return;
            }

            // dragging or resizing crop box
            if (overlayRoot.isPointerDown) {
                if (overlayRoot.dragAction === "create") {
                    let dx = Math.abs(mouse.x - overlayRoot.startX);
                    let dy = Math.abs(mouse.y - overlayRoot.startY);
                    if (!overlayRoot.isDragging && (dx > 5 || dy > 5)) {
                        overlayRoot.isDragging = true;
                        overlayRoot.hasSelection = false;
                        overlayRoot.hoveredClient = null;
                    }
                    if (overlayRoot.isDragging) {
                        overlayRoot.currX = Math.max(0, Math.min(overlayRoot.width, mouse.x));
                        overlayRoot.currY = Math.max(0, Math.min(overlayRoot.height, mouse.y));
                    }
                } else if (overlayRoot.dragAction === "move") {
                    let dx = mouse.x - overlayRoot.dragAnchorX;
                    let dy = mouse.y - overlayRoot.dragAnchorY;
                    let nx = Math.max(0, Math.min(overlayRoot.width - overlayRoot.origSelW, overlayRoot.origSelX + dx));
                    let ny = Math.max(0, Math.min(overlayRoot.height - overlayRoot.origSelH, overlayRoot.origSelY + dy));
                    overlayRoot.startX = nx;
                    overlayRoot.startY = ny;
                    overlayRoot.currX = nx + overlayRoot.origSelW;
                    overlayRoot.currY = ny + overlayRoot.origSelH;
                } else if (overlayRoot.dragAction !== "none") {
                    let l = overlayRoot.origSelX;
                    let t = overlayRoot.origSelY;
                    let r = overlayRoot.origSelX + overlayRoot.origSelW;
                    let b = overlayRoot.origSelY + overlayRoot.origSelH;
                    let mx = Math.max(0, Math.min(overlayRoot.width, mouse.x));
                    let my = Math.max(0, Math.min(overlayRoot.height, mouse.y));
                    let h = overlayRoot.dragAction;
                    let minSize = 14;

                    if (h.indexOf("w") !== -1) l = Math.min(r - minSize, mx);
                    if (h.indexOf("e") !== -1) r = Math.max(l + minSize, mx);
                    if (h.indexOf("n") !== -1) t = Math.min(b - minSize, my);
                    if (h.indexOf("s") !== -1) b = Math.max(t + minSize, my);

                    overlayRoot.startX = l;
                    overlayRoot.startY = t;
                    overlayRoot.currX = r;
                    overlayRoot.currY = b;
                }
            } else if (!isOverActions(mouse.x, mouse.y)) {
                overlayRoot.checkHoveredClient(mouse.x, mouse.y);
            }
        }

        onReleased: (mouse) => {
            if (mouse.button === Qt.RightButton) return;
            overlayRoot.isPointerDown = false;

            if (overlayRoot.isDrawingTool && overlayRoot.draftAnnotation) {
                let d = overlayRoot.draftAnnotation;
                overlayRoot.draftAnnotation = null;
                overlayRoot.isDragging = false;

                let valid = true;
                if (d.kind === "arrow") {
                    valid = Math.hypot(d.x2 - d.x1, d.y2 - d.y1) > 8;
                } else if (d.kind === "rect" || d.kind === "ellipse" || d.kind === "redact") {
                    valid = d.w > 6 && d.h > 6;
                }
                if (valid) overlayRoot.pushAnnotation(d);
                else vectorCanvas.requestPaint();
                return;
            }

            if (overlayRoot.isDragging) {
                overlayRoot.isDragging = false;
                if (overlayRoot.dragAction === "create") {
                    overlayRoot.hasSelection = (overlayRoot.selW > 12 && overlayRoot.selH > 12);
                }
                overlayRoot.dragAction = "none";
                return;
            }
            overlayRoot.dragAction = "none";

            if (isOverActions(mouse.x, mouse.y)) {
                mouse.accepted = false;
                return;
            }

            if (overlayRoot.hoveredClient && !overlayRoot.hasSelection) {
                overlayRoot.lockClientSelection(overlayRoot.hoveredClient);
            } else if (overlayRoot.hasSelection && !overlayRoot.isEditingFile) {
                let inBox = mouse.x >= overlayRoot.selX && mouse.x <= overlayRoot.selX + overlayRoot.selW
                    && mouse.y >= overlayRoot.selY && mouse.y <= overlayRoot.selY + overlayRoot.selH;
                if (!inBox) {
                    overlayRoot.resetSelectionState();
                    overlayRoot.checkHoveredClient(mouse.x, mouse.y);
                }
            }
        }

        onDoubleClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton && overlayRoot.hasActiveRegion && !overlayRoot.isDrawingTool) {
                overlayRoot.executeNativeGrab(
                    overlayRoot.activeX,
                    overlayRoot.activeY,
                    overlayRoot.activeW,
                    overlayRoot.activeH,
                    Settings?.screenshotDefaultAction || "both"
                );
            }
        }
    }

    // active selection frame + rule-of-thirds + 8 resize handles (4 corners + 4 midpoints)
    Rectangle {
        id: selectionBox
        visible: overlayRoot.hasActiveRegion && !overlayRoot.isQuickFullscreen && !closeAfterFlashTimer.running && !overlayRoot.isCapturing
        x: overlayRoot.activeX
        y: overlayRoot.activeY
        width: overlayRoot.activeW
        height: overlayRoot.activeH
        color: "transparent"
        radius: Settings?.screenshotBorderRadius ?? 0
        border.width: Settings?.screenshotBorderWidth ?? 2
        border.color: ScreenshotService.activeMode === "record" ? (Theme.error ?? "#ff5449") : Theme.primary
        z: 10

        Item {
            anchors.fill: parent
            visible: overlayRoot.isDragging && !overlayRoot.isDrawingTool && parent.width > 60 && parent.height > 60

            Rectangle { x: parent.width / 3; y: 0; width: 1; height: parent.height; color: Theme.alpha(Theme.primary, 0.25) }
            Rectangle { x: (parent.width * 2) / 3; y: 0; width: 1; height: parent.height; color: Theme.alpha(Theme.primary, 0.25) }
            Rectangle { x: 0; y: parent.height / 3; width: parent.width; height: 1; color: Theme.alpha(Theme.primary, 0.25) }
            Rectangle { x: 0; y: (parent.height * 2) / 3; width: parent.width; height: 1; color: Theme.alpha(Theme.primary, 0.25) }
        }

        // 8 resize handles
        Item {
            anchors.fill: parent
            visible: (Settings?.screenshotShowHandles ?? true) && !overlayRoot.isDrawingTool

            readonly property color handleColor: ScreenshotService.activeMode === "record"
                ? (Theme.error ?? "#ff5449")
                : Theme.primary

            // corners
            Rectangle { x: -4; y: -4; width: 9; height: 9; radius: 3; color: parent.handleColor; border.width: 1; border.color: "#090a10" }
            Rectangle { x: parent.width - 5; y: -4; width: 9; height: 9; radius: 3; color: parent.handleColor; border.width: 1; border.color: "#090a10" }
            Rectangle { x: -4; y: parent.height - 5; width: 9; height: 9; radius: 3; color: parent.handleColor; border.width: 1; border.color: "#090a10" }
            Rectangle { x: parent.width - 5; y: parent.height - 5; width: 9; height: 9; radius: 3; color: parent.handleColor; border.width: 1; border.color: "#090a10" }

            // edge midpoints when box is big enough
            Rectangle { visible: parent.width > 48; x: parent.width / 2 - 8; y: -3; width: 16; height: 6; radius: 3; color: parent.handleColor }
            Rectangle { visible: parent.width > 48; x: parent.width / 2 - 8; y: parent.height - 3; width: 16; height: 6; radius: 3; color: parent.handleColor }
            Rectangle { visible: parent.height > 48; x: -3; y: parent.height / 2 - 8; width: 6; height: 16; radius: 3; color: parent.handleColor }
            Rectangle { visible: parent.height > 48; x: parent.width - 3; y: parent.height / 2 - 8; width: 6; height: 16; radius: 3; color: parent.handleColor }
        }
    }

    // dimension, window title & live prettify/studio badge
    Rectangle {
        id: dimBadge
        visible: (Settings?.screenshotShowBadge ?? true)
            && overlayRoot.hasActiveRegion
            && !overlayRoot.isQuickFullscreen
            && !closeAfterFlashTimer.running
            && !overlayRoot.isCapturing
        x: Math.max(12, Math.min(overlayRoot.width - implicitWidth - 12, overlayRoot.activeX))
        y: (overlayRoot.activeY > 36) ? (overlayRoot.activeY - 30) : (overlayRoot.activeY + 8)
        height: 24
        implicitWidth: badgeRow.implicitWidth + 16
        radius: Theme.radiusPill
        color: Theme.surface_container_highest
        border.color: Theme.outline_variant
        border.width: 1
        z: 20

        RowLayout {
            id: badgeRow
            anchors.centerIn: parent
            spacing: 6

            Text {
                visible: overlayRoot.hoveredClient !== null && Boolean(overlayRoot.hoveredClient.class || overlayRoot.hoveredClient.title)
                text: overlayRoot.hoveredClient ? (overlayRoot.hoveredClient.class || overlayRoot.hoveredClient.title) : ""
                font.family: Theme.fontFamily
                font.variableAxes: Theme.sansAxes
                font.pixelSize: Theme.fontSizeXs
                font.weight: Theme.fontWeightDemiBold
                color: Theme.primary
                elide: Text.ElideRight
                Layout.maximumWidth: 180
            }

            Text {
                text: Math.round(overlayRoot.activeW) + " × " + Math.round(overlayRoot.activeH)
                font.family: Theme.fontMono
                font.variableAxes: Theme.monoAxes
                font.weight: Theme.monoWeightRegular
                font.pixelSize: Theme.fontSizeXs
                color: Theme.on_surface
            }

            Rectangle {
                visible: actionsBar.prettifyActive
                height: 16
                implicitWidth: prettyBadgeTxt.implicitWidth + 10
                radius: Theme.radiusPill
                color: Theme.primary_overlay
                border.color: Theme.primary
                border.width: 1

                Text {
                    id: prettyBadgeTxt
                    anchors.centerIn: parent
                    text: "prettify: " + (Settings?.screenshotPrettifyStyle || "matugen")
                    font.family: Theme.fontMono
                    font.variableAxes: Theme.monoAxes
                    font.pixelSize: 9
                    font.weight: Theme.monoWeightBold
                    color: Theme.primary
                }
            }
        }
    }

    // live 5x pixel magnifier loupe + HEX color inspector
    Rectangle {
        id: loupeCard
        visible: overlayRoot.showLoupe
        width: 132
        height: 156
        radius: Theme.radiusLg
        color: Theme.surface_container_highest
        border.color: Theme.outline_variant
        border.width: 1
        z: 40

        readonly property bool flipLeft: overlayRoot.cursorX + 24 + width > overlayRoot.width
        readonly property bool flipTop: overlayRoot.cursorY + 24 + height > overlayRoot.height
        x: flipLeft ? Math.max(8, overlayRoot.cursorX - width - 20) : Math.min(overlayRoot.width - width - 8, overlayRoot.cursorX + 20)
        y: flipTop ? Math.max(8, overlayRoot.cursorY - height - 20) : Math.min(overlayRoot.height - height - 8, overlayRoot.cursorY + 20)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 5

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radiusMd
                color: "#090a10"
                border.color: Theme.outline_variant
                border.width: 1
                clip: true

                ShaderEffectSource {
                    anchors.fill: parent
                    sourceItem: overlayRoot.isEditingFile ? editSourceImage : frozenScreencopy
                    sourceRect: overlayRoot.isEditingFile
                        ? Qt.rect(
                            overlayRoot.cursorX - editSourceImage.x - 12,
                            overlayRoot.cursorY - editSourceImage.y - 10,
                            24, 20
                        )
                        : Qt.rect(overlayRoot.cursorX - 12, overlayRoot.cursorY - 10, 24, 20)
                    smooth: false
                    live: true
                }

                // pixel crosshair guides + center pixel target frame
                Rectangle { x: parent.width / 2; y: 0; width: 1; height: parent.height; color: Theme.alpha(Theme.primary, 0.35) }
                Rectangle { x: 0; y: parent.height / 2; width: parent.width; height: 1; color: Theme.alpha(Theme.primary, 0.35) }
                Rectangle {
                    anchors.centerIn: parent
                    width: 7
                    height: 7
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.primary
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 5

                Rectangle {
                    width: 12
                    height: 12
                    radius: 3
                    color: overlayRoot.hoveredHex
                    border.color: Theme.outline_variant
                    border.width: 1
                }

                Text {
                    text: overlayRoot.hoveredHex
                    font.family: Theme.fontMono
                    font.variableAxes: Theme.monoAxes
                    font.pixelSize: 10
                    font.weight: Theme.monoWeightBold
                    color: Theme.primary
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: Math.round(overlayRoot.cursorX) + "," + Math.round(overlayRoot.cursorY)
                    font.family: Theme.fontMono
                    font.variableAxes: Theme.monoAxes
                    font.pixelSize: 9
                    color: Theme.on_surface_variant
                }
            }
        }
    }

    // inline floating text annotation input
    Rectangle {
        id: inlineTextBox
        visible: overlayRoot.showTextInput
        x: overlayRoot.pendingTextX
        y: overlayRoot.pendingTextY
        width: Math.max(150, inlineTextField.implicitWidth + 24)
        height: 36
        radius: Theme.radiusSm
        color: Theme.alpha("#0c0e14", 0.90)
        border.color: actionsBar.strokeColor
        border.width: 2
        z: 120

        TextField {
            id: inlineTextField
            anchors.fill: parent
            anchors.margins: 4
            placeholderText: "type label (enter)..."
            placeholderTextColor: Theme.on_surface_variant
            color: actionsBar.strokeColor
            font.family: Theme.fontSans
            font.variableAxes: Theme.sansAxes
            font.weight: Theme.fontWeightBold
            font.pixelSize: Math.max(13, Math.round(Theme.fontSizeMd + overlayRoot.strokeWidthPx))
            background: Item {}
            onAccepted: overlayRoot.commitInlineText()
            Keys.onEscapePressed: {
                overlayRoot.showTextInput = false;
                inlineTextField.text = "";
                keyHandler.forceActiveFocus();
            }
        }
    }

    ScreenshotActions {
        id: actionsBar
        visible: !overlayRoot.isDragging && !overlayRoot.isQuickFullscreen && !closeAfterFlashTimer.running && !overlayRoot.isCapturing
        isRecordMode: ScreenshotService.activeMode === "record"
        isEditingExisting: overlayRoot.isEditingFile
        canUndo: overlayRoot.annotations.length > 0
        canRedo: overlayRoot.redoStack.length > 0
        hasAnnotations: overlayRoot.annotations.length > 0
        z: 100

        x: Math.max(16, Math.min(overlayRoot.width - implicitWidth - 16,
            overlayRoot.hasActiveRegion
                ? (overlayRoot.activeX + (overlayRoot.activeW - implicitWidth) / 2)
                : ((overlayRoot.width - implicitWidth) / 2)
        ))

        y: overlayRoot.hasActiveRegion
            ? Math.max(36, Math.min(overlayRoot.height - implicitHeight - 20,
                ((overlayRoot.activeY + overlayRoot.activeH + implicitHeight + 40 < overlayRoot.height)
                    ? (overlayRoot.activeY + overlayRoot.activeH + 16)
                    : (overlayRoot.activeY - implicitHeight - 36))
              ))
            : 36

        Behavior on x { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

        onRegionClicked: {
            ScreenshotService.activeMode = "region";
            overlayRoot.resetSelectionState();
        }
        onWindowClicked: {
            ScreenshotService.activeMode = "window";
            let clients = ScreenshotService.clients || [];
            if (overlayRoot.hoveredClient) {
                overlayRoot.lockClientSelection(overlayRoot.hoveredClient);
            } else if (clients.length > 0) {
                overlayRoot.lockClientSelection(clients[0]);
            }
        }
        onFullClicked: {
            ScreenshotService.activeMode = "fullscreen";
            overlayRoot.hoveredClient = null;
            overlayRoot.hasSelection = true;
            overlayRoot.startX = 0;
            overlayRoot.startY = 0;
            overlayRoot.currX = overlayRoot.screen.width;
            overlayRoot.currY = overlayRoot.screen.height;
        }
        onPickerClicked: {
            ScreenshotService.activeMode = "eyedropper";
            actionsBar.annotating = false;
            actionsBar.activeTool = "select";
            overlayRoot.resetSelectionState();
        }
        onCopyClicked: {
            overlayRoot.executeNativeGrab(overlayRoot.activeX, overlayRoot.activeY, overlayRoot.activeW, overlayRoot.activeH, "copy");
        }
        onSaveClicked: {
            overlayRoot.executeNativeGrab(overlayRoot.activeX, overlayRoot.activeY, overlayRoot.activeW, overlayRoot.activeH, "save");
        }
        onBothClicked: {
            overlayRoot.executeNativeGrab(overlayRoot.activeX, overlayRoot.activeY, overlayRoot.activeW, overlayRoot.activeH, "both");
        }
        onPinClicked: {
            overlayRoot.executeNativeGrab(overlayRoot.activeX, overlayRoot.activeY, overlayRoot.activeW, overlayRoot.activeH, "pin");
        }
        onRecordClicked: {
            overlayRoot.executeNativeGrab(overlayRoot.activeX, overlayRoot.activeY, overlayRoot.activeW, overlayRoot.activeH, "record");
        }
        onCancelClicked: {
            ScreenshotService.close();
        }
        onUndoClicked: overlayRoot.undoAnnotation()
        onRedoClicked: overlayRoot.redoAnnotation()
        onClearAnnotationsClicked: overlayRoot.clearAnnotations()
    }

    Rectangle {
        id: flashRect
        anchors.fill: parent
        color: "#ffffff"
        opacity: 0
        visible: opacity > 0
        z: 200

        SequentialAnimation {
            id: flashAnim
            NumberAnimation { target: flashRect; property: "opacity"; to: 0.55; duration: 40 }
            NumberAnimation { target: flashRect; property: "opacity"; to: 0.0; duration: 140 }
        }
    }
}
