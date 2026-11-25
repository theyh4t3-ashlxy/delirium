pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import ".."
import "../theme/confFormat.mjs" as ConfFmt

Singleton {
    id: root

    property bool isOpen: false
    property string activeMode: "region" // region, window, fullscreen, annotate, eyedropper, record
    property bool startAnnotating: false
    property string editingFilePath: ""
    property var clients: []

    // delay countdown state shared between ScreenCapture pill & IPC
    property int countdownRemaining: 0
    property string _pendingDelayMode: "region"
    readonly property bool hasPendingDelay: delayTimer.running

    // post-capture HUD & floating reference pins
    property var lastCapture: null
    property bool hudVisible: false
    property string hudMode: "capture" // capture | color | message
    property string pickedColorHex: ""
    property string hudMessage: ""
    property var pinnedShots: []
    property int _pinCounter: 0

    readonly property string scriptPath: decodeURIComponent(
        Qt.resolvedUrl("../scripts/screenshot.py").toString().replace(/^file:\/\//, "")
    )

    // coordination signals for the per-screen ScreencopyView overlay
    signal performCapture(var targetScreen, string action, real x, real y, real w, real h)
    signal performFullscreen(var targetScreen, string action)
    signal captureCompleted(var info)

    function parseScriptKv(text) {
        let raw = ConfFmt.parseFlatConf(text || "");
        let out = {};
        for (let k in raw) {
            out[k] = ConfFmt.unescapeField(raw[k]);
        }
        return out;
    }

    // find the Quickshell ShellScreen matching the currently focused Hyprland monitor
    function getFocusedScreen() {
        let screens = Quickshell.screens || [];
        if (screens.length === 0) return null;
        let focusedMon = Hyprland.focusedMonitor;
        if (focusedMon) {
            for (let i = 0; i < screens.length; i++) {
                let mon = Hyprland.monitorFor(screens[i]);
                if ((mon && mon.id === focusedMon.id) || screens[i].name === focusedMon.name) {
                    return screens[i];
                }
            }
        }
        return screens[0];
    }

    function expandHome(rawPath) {
        let s = String(rawPath || "~/Pictures/Screenshots").trim();
        let home = Quickshell.env("HOME") || "";
        return s.replace(/^~/, home);
    }

    function normalizedFormat(fmtOverride) {
        let f = String(fmtOverride || Settings?.screenshotFormat || "png").toLowerCase();
        if (f === "jpeg") f = "jpg";
        if (f !== "png" && f !== "jpg" && f !== "webp") f = "png";
        return f;
    }

    function buildDestPath(screenName, suffix, fmtOverride) {
        let dir = expandHome(Settings?.screenshotDir || "~/Pictures/Screenshots");
        let ext = normalizedFormat(fmtOverride);
        let pattern = Settings?.screenshotFilenamePattern || "timestamp";
        let now = new Date();
        let extra = suffix ? ("_" + suffix) : "";
        if (pattern === "compact") {
            let stamp = Qt.formatDateTime(now, "yyyyMMdd_hhmmss");
            return dir + "/shot_" + stamp + extra + "." + ext;
        }
        let scrSuffix = screenName ? ("_" + screenName) : "";
        let timestamp = Qt.formatDateTime(now, "yyyy-MM-dd_hh-mm-ss") + scrSuffix + extra;
        return dir + "/Screenshot_" + timestamp + "." + ext;
    }

    function buildPrettifySpec(enabledOverride) {
        let enabled = (enabledOverride !== undefined)
            ? Boolean(enabledOverride)
            : Boolean(Settings?.screenshotPrettifyEnabled ?? false);
        let wp = expandHome(Settings?.currentWallpaper || "");
        return {
            enabled: enabled,
            style: Settings?.screenshotPrettifyStyle || "matugen",
            padding: Settings?.screenshotPrettifyPadding ?? 48,
            radius: Settings?.screenshotPrettifyRadius ?? 14,
            shadow: Settings?.screenshotPrettifyShadow ?? true,
            wallpaper: wp,
            c1: String(Theme?.primary_container || Theme?.primary || "#3b82f6"),
            c2: String(Theme?.tertiary_container || Theme?.secondary_container || "#a855f7"),
            bg: String(Theme?.surface_container_lowest || Theme?.background || "#10121a")
        };
    }

    // collect the set of workspace IDs currently visible across all monitors
    function getVisibleWorkspaceIds() {
        let visibleIds = {};
        let monitors = Hyprland.monitors?.values || [];
        for (let i = 0; i < monitors.length; i++) {
            let m = monitors[i];
            if (!m) continue;
            if (m.activeWorkspace?.id !== undefined) {
                visibleIds[m.activeWorkspace.id] = true;
            }
            if (m.lastIpcObject?.specialWorkspace?.id) {
                visibleIds[m.lastIpcObject.specialWorkspace.id] = true;
            }
        }
        if (Hyprland.focusedWorkspace?.id !== undefined) {
            visibleIds[Hyprland.focusedWorkspace.id] = true;
        }
        return visibleIds;
    }

    function filterAndSortClients(rawList) {
        if (!Array.isArray(rawList)) return [];
        let visibleWs = root.getVisibleWorkspaceIds();
        let hasWsInfo = Object.keys(visibleWs).length > 0;

        let filtered = rawList.filter(c => {
            if (!c || c.hidden || c.mapped === false) return false;
            if (!c.size || c.size[0] <= 0 || c.size[1] <= 0) return false;
            if (hasWsInfo && c.workspace?.id !== undefined) {
                return Boolean(visibleWs[c.workspace.id]);
            }
            return true;
        });

        filtered.sort((a, b) => {
            if (Boolean(a.pinned) !== Boolean(b.pinned)) return a.pinned ? -1 : 1;
            if (Boolean(a.floating) !== Boolean(b.floating)) return a.floating ? -1 : 1;
            return (a.focusHistoryID ?? 9999) - (b.focusHistoryID ?? 9999);
        });

        return filtered;
    }

    function seedClientsFromToplevels() {
        Hyprland.refreshMonitors();
        Hyprland.refreshWorkspaces();
        Hyprland.refreshToplevels();

        let toplevels = Hyprland.toplevels?.values || [];
        let seeded = [];
        for (let i = 0; i < toplevels.length; i++) {
            let ipc = toplevels[i]?.lastIpcObject;
            if (ipc) seeded.push(ipc);
        }
        if (seeded.length > 0) {
            root.clients = root.filterAndSortClients(seeded);
        }
    }

    property Process clientsProcess: Process {
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let parsed = JSON.parse(text);
                    root.clients = root.filterAndSortClients(parsed);
                } catch (e) {
                    if (!root.clients || root.clients.length === 0) {
                        root.clients = [];
                    }
                }
            }
        }
    }

    property var _pendingExportMeta: ({})
    property Process exportProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                let res = root.parseScriptKv(text);
                if (res.ok !== "true") {
                    root.showMessageHud("export failed: " + (res.error || "unknown error"));
                    return;
                }
                let meta = root._pendingExportMeta || {};
                let info = {
                    previewPath: res.preview || "",
                    destPath: res.dest || "",
                    width: parseInt(res.width || "0", 10) || 0,
                    height: parseInt(res.height || "0", 10) || 0,
                    sizeText: res.sizeText || "",
                    format: res.format || "png",
                    action: res.action || "both",
                    copied: res.copied === "true",
                    saved: res.saved === "true",
                    prettified: res.prettified === "true",
                    screenName: meta.screenName || (root.getFocusedScreen()?.name ?? ""),
                    timestamp: Date.now()
                };
                root.lastCapture = info;
                root.captureCompleted(info);

                if (info.action === "pin" || meta.pinAfter) {
                    let src = info.previewPath || info.destPath;
                    if (src) root.pinFile(src, info.width, info.height, info.screenName);
                }

                if (info.action !== "pin" && (Settings?.screenshotPostHud ?? true)) {
                    root.hudMode = "capture";
                    root.hudVisible = true;
                }
            }
        }
    }

    property Process prettifyProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                let res = root.parseScriptKv(text);
                if (res.ok !== "true") {
                    root.showMessageHud("prettify failed: " + (res.error || "magick error"));
                    return;
                }
                let info = {
                    previewPath: res.preview || "",
                    destPath: res.dest || "",
                    width: parseInt(res.width || "0", 10) || 0,
                    height: parseInt(res.height || "0", 10) || 0,
                    sizeText: res.sizeText || "",
                    format: res.format || "png",
                    action: res.action || "both",
                    copied: res.copied === "true",
                    saved: res.saved === "true",
                    prettified: true,
                    screenName: root.getFocusedScreen()?.name ?? "",
                    timestamp: Date.now()
                };
                root.lastCapture = info;
                root.captureCompleted(info);
                if (Settings?.screenshotPostHud ?? true) {
                    root.hudMode = "capture";
                    root.hudVisible = true;
                }
            }
        }
    }

    property Process clipLoadProc: Process {
        command: ["python3", root.scriptPath, "clipboard-load"]
        stdout: StdioCollector {
            onStreamFinished: {
                let res = root.parseScriptKv(text);
                if (res.ok === "true" && res.path) {
                    root.editFile(res.path);
                } else {
                    root.showMessageHud(res.error || "no image found in clipboard");
                }
            }
        }
    }

    property Timer fullscreenTimer: Timer {
        interval: 120
        repeat: false
        property var targetScreen: null
        property string action: "both"
        onTriggered: {
            root.performFullscreen(targetScreen, action);
        }
    }

    property Timer delayTimer: Timer {
        interval: 1000
        repeat: true
        onTriggered: {
            if (root.countdownRemaining > 1) {
                root.countdownRemaining -= 1;
            } else {
                stop();
                root.countdownRemaining = 0;
                let mode = root._pendingDelayMode || "region";
                if (mode === "fullscreen") {
                    root.captureFullscreen(root.getFocusedScreen(), Settings?.screenshotDefaultAction || "both");
                } else {
                    root.open(mode);
                }
            }
        }
    }

    function open(mode: string): void {
        let m = mode || "region";
        if (m === "picker") m = "eyedropper";
        delayTimer.stop();
        countdownRemaining = 0;
        editingFilePath = "";
        if (m === "annotate") {
            activeMode = "region";
            startAnnotating = true;
        } else {
            activeMode = m;
            startAnnotating = (m !== "eyedropper" && m !== "record" && Boolean(Settings?.screenshotDefaultAnnotate ?? false));
        }
        if (activeMode !== "fullscreen") {
            seedClientsFromToplevels();
            clientsProcess.running = true;
        }
        hudVisible = false;
        isOpen = true;
    }

    function openDelayed(mode: string, delaySec: int): void {
        let sec = Math.max(0, Math.round(delaySec || 0));
        if (sec <= 0) {
            if (mode === "fullscreen") {
                captureFullscreen(getFocusedScreen(), Settings?.screenshotDefaultAction || "both");
            } else {
                open(mode);
            }
            return;
        }
        _pendingDelayMode = mode || "region";
        countdownRemaining = sec;
        delayTimer.restart();
    }

    function cancelDelay(): void {
        delayTimer.stop();
        countdownRemaining = 0;
    }

    function openAnnotate(): void {
        open("annotate");
    }

    function openEyedropper(): void {
        open("eyedropper");
    }

    function editFile(filePath: string): void {
        let clean = String(filePath || "").replace(/^file:\/\//, "").trim();
        if (!clean) {
            showMessageHud("no screenshot file to edit");
            return;
        }
        delayTimer.stop();
        countdownRemaining = 0;
        editingFilePath = clean;
        activeMode = "annotate";
        startAnnotating = true;
        hudVisible = false;
        isOpen = true;
    }

    function editLast(): void {
        let target = lastCapture ? (lastCapture.destPath || lastCapture.previewPath) : "";
        if (!target) {
            showMessageHud("no recent capture in this session");
            return;
        }
        editFile(target);
    }

    function editClipboard(): void {
        if (clipLoadProc.running) clipLoadProc.running = false;
        clipLoadProc.running = true;
    }

    function close(): void {
        isOpen = false;
        editingFilePath = "";
        startAnnotating = false;
        fullscreenTimer.stop();
    }

    function toggle(mode: string): void {
        if (isOpen) {
            close();
        } else {
            open(mode);
        }
    }

    function dismissHud(): void {
        hudVisible = false;
    }

    function showMessageHud(msg: string): void {
        hudMessage = String(msg || "");
        hudMode = "message";
        hudVisible = true;
    }

    function copyColor(hexColor: string): void {
        let hex = String(hexColor || "").trim();
        if (!hex) return;
        Quickshell.execDetached(["python3", root.scriptPath, "copy-color", hex]);
        pickedColorHex = hex;
        hudMode = "color";
        hudVisible = true;
    }

    function submitExport(rawPath, action, screenName, logicalW, logicalH, redactRects, prettifyOverride, pinAfter) {
        let act = action || Settings?.screenshotDefaultAction || "both";
        let fmt = normalizedFormat();
        let dest = buildDestPath(screenName, "", fmt);
        let spec = {
            rawPath: rawPath,
            destPath: dest,
            action: act,
            format: fmt,
            quality: Settings?.screenshotQuality ?? 92,
            notify: Settings?.screenshotNotify ?? true,
            logicalWidth: logicalW,
            logicalHeight: logicalH,
            redactRects: redactRects || [],
            prettify: buildPrettifySpec(prettifyOverride),
            removeRaw: true
        };
        _pendingExportMeta = { screenName: screenName || "", pinAfter: Boolean(pinAfter) };
        if (exportProc.running) exportProc.running = false;
        exportProc.command = ["python3", root.scriptPath, "export", JSON.stringify(spec)];
        exportProc.running = true;
    }

    function runQuickPrettify(filePath: string): void {
        let clean = String(filePath || "").replace(/^file:\/\//, "").trim();
        if (!clean) return;
        let fmt = normalizedFormat();
        let focused = getFocusedScreen();
        let dest = buildDestPath(focused?.name || "", "pretty", fmt);
        let spec = {
            rawPath: clean,
            destPath: dest,
            action: "both",
            format: fmt,
            quality: Settings?.screenshotQuality ?? 92,
            notify: Settings?.screenshotNotify ?? true,
            logicalWidth: 0,
            logicalHeight: 0,
            redactRects: [],
            prettify: buildPrettifySpec(true),
            removeRaw: false
        };
        if (prettifyProc.running) prettifyProc.running = false;
        prettifyProc.command = ["python3", root.scriptPath, "export", JSON.stringify(spec)];
        prettifyProc.running = true;
    }

    function pinFile(filePath: string, w: int, h: int, screenName: string): void {
        let clean = String(filePath || "").replace(/^file:\/\//, "").trim();
        if (!clean) return;
        let scr = screenName || (getFocusedScreen()?.name ?? "");
        let next = pinnedShots.slice();
        if (next.length >= 6) {
            next.shift();
        }
        _pinCounter += 1;
        let safeW = w > 0 ? w : 420;
        let safeH = h > 0 ? h : 280;
        let initScale = Math.min(1.0, 560 / Math.max(1, safeW));
        next.push({
            id: "pin_" + _pinCounter + "_" + Date.now(),
            path: clean,
            width: safeW,
            height: safeH,
            screenName: scr,
            opacity: 1.0,
            scale: Math.max(0.4, Math.round(initScale * 100) / 100),
            x: -1,
            y: -1
        });
        pinnedShots = next;
    }

    function pinLast(): void {
        if (!lastCapture) {
            showMessageHud("no recent capture to pin");
            return;
        }
        let src = lastCapture.previewPath || lastCapture.destPath;
        if (src) {
            pinFile(src, lastCapture.width, lastCapture.height, lastCapture.screenName);
        }
    }

    function updatePin(pinId: string, patch: var): void {
        let next = [];
        for (let i = 0; i < pinnedShots.length; i++) {
            let p = pinnedShots[i];
            if (p.id === pinId) {
                next.push(Object.assign({}, p, patch));
            } else {
                next.push(p);
            }
        }
        pinnedShots = next;
    }

    function unpin(pinId: string): void {
        pinnedShots = pinnedShots.filter(p => p.id !== pinId);
    }

    function clearPins(): void {
        pinnedShots = [];
    }

    function captureRegion(screen: var, x: real, y: real, w: real, h: real, action: string): void {
        let act = action || Settings?.screenshotDefaultAction || "both";
        let target = screen || root.getFocusedScreen();
        if (!target || w <= 1 || h <= 1) return;
        root.performCapture(target, act, x, y, w, h);
    }

    function captureFullscreen(screen: var, action: string): void {
        let act = action || Settings?.screenshotDefaultAction || "both";
        let target = screen || root.getFocusedScreen();
        if (!target) return;

        editingFilePath = "";
        if (!isOpen) {
            open("fullscreen");
            fullscreenTimer.targetScreen = target;
            fullscreenTimer.action = act;
            fullscreenTimer.restart();
        } else {
            root.performFullscreen(target, act);
        }
    }

    function captureWindow(client: var, action: string): void {
        if (!client || !client.at || !client.size) return;
        let act = action || Settings?.screenshotDefaultAction || "both";
        let cx = Number(client.at[0]);
        let cy = Number(client.at[1]);
        let cw = Number(client.size[0]);
        let ch = Number(client.size[1]);
        if (cw <= 1 || ch <= 1) return;

        let screens = Quickshell.screens || [];
        if (screens.length === 0) return;

        let centerX = cx + (cw / 2);
        let centerY = cy + (ch / 2);
        let matchedScreen = root.getFocusedScreen() || screens[0];

        for (let i = 0; i < screens.length; i++) {
            let s = screens[i];
            let mon = Hyprland.monitorFor(s);
            if (client.monitor !== undefined && mon && mon.id === client.monitor) {
                matchedScreen = s;
                break;
            }
            if (centerX >= s.x && centerY >= s.y && centerX < s.x + s.width && centerY < s.y + s.height) {
                matchedScreen = s;
                break;
            }
        }

        let rawX = cx - matchedScreen.x;
        let rawY = cy - matchedScreen.y;
        let clampedX = Math.max(0, rawX);
        let clampedY = Math.max(0, rawY);
        let clampedW = Math.min(matchedScreen.width - clampedX, cw - (clampedX - rawX));
        let clampedH = Math.min(matchedScreen.height - clampedY, ch - (clampedY - rawY));

        if (clampedW <= 1 || clampedH <= 1) return;
        root.performCapture(matchedScreen, act, clampedX, clampedY, clampedW, clampedH);
    }
}
