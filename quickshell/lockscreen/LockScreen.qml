import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import ".."
import "../controls"
import "../corners"
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.Pam

Scope {
    id: lockRoot

    property bool locked: false
    property bool authFailed: false
    property bool isChecking: false
    property bool pamRespondedThisTurn: false
    property string pamFeedback: ""
    property bool pamFeedbackIsError: false
    property int failedAttempts: 0

    property var activeSurface: null

    property date lockedAtTime: new Date()
    property string pendingPassword: ""
    property string sharedPassword: ""
    property bool revealPassword: false
    property int manualPlayerIndex: -1
    property bool zenMode: false

    property bool capsLockActive: false
    property string kbLayoutShort: ""

    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string configDir: Quickshell.env("XDG_CONFIG_HOME") || (homeDir + "/.config")
    readonly property string lockStateDir: configDir + "/quickshell/lockscreen"
    readonly property string lockStatePath: lockStateDir + "/state"

    readonly property string runtimeDir: {
        let xdg = (Quickshell.env("XDG_RUNTIME_DIR") || "").trim();
        return xdg !== "" ? xdg : "/tmp";
    }
    readonly property string currentUser: (Quickshell.env("USER") || Quickshell.env("LOGNAME") || "user")
    readonly property string lockTokenPath: runtimeDir + "/qs_session_locked_" + currentUser + ".token"
    readonly property string remoteArtCachePath: runtimeDir + "/qs_lock_art_" + currentUser + ".img"

    PersistentProperties {
        id: sessionPersist
        reloadableId: "qsLockScreenSessionState"
        property bool wasLocked: false
        property double lockedAtEpochMs: 0
        property int failedCount: 0
    }

    property bool stateLoaded: false
    property bool studioLocked: false
    property string studioTab: "layout"        // "layout" | "clock" | "vibe" | "widgets"

    // user-controlled layout & geometry
    property string layoutPosition: "center"   // "center" | "top" | "bottom" | "left" | "right" | "custom"
    property string stackOrder: "clock,media,password"
    property bool freeDragMode: false
    property real customNormX: 0.5
    property real customNormY: 0.5
    property int stageWidth: 448               // 340 .. 620
    property string shapePreset: "theme"       // "theme" | "pill" | "squircle" | "sharp"
    property real cardOpacityBoost: 0.0        // -0.35 .. +0.35

    // user-controlled clock & typography
    property bool syncClockGlobal: false
    property bool showClock: true
    property bool showDate: true
    property bool sandboxClock24h: false
    property bool showSeconds: true
    property string clockStyle: "inline"       // "inline" | "stacked" | "split" | "typo" | "digital" | "editorial" | "minimal"
    property string secondsStyle: "badge"      // "badge" | "supersub" | "tower" | "inline"
    property string dateFormat: "dddd, MMMM d" // customizable date format string
    property bool dateAboveClock: false
    property real clockScale: 1.0
    property string textCase: "lower"          // "lower" | "normal" | "upper"
    property string pwMaskChar: "•"            // "•" | "*" | "✦" | "▪" | "none"
    property bool autoSubmitLength: false
    property int autoSubmitTargetLen: 0

    // user-controlled vibe & quotes
    property string quoteMode: "smart"         // "smart" | "hyprland" | "unhinged" | "custom" | "off"
    property string customQuoteText: "welcome back"
    property string backdropMode: "auto"       // "auto" | "dark" | "light"
    property string pamService: "login"
    property real scrimDim: 0.58
    property real vignetteStrength: 0.35
    property real focusZoom: 1.05

    // user-controlled widgets & dock (nothing forced, everything optional)
    property bool showMediaCard: true
    property bool showMediaVisualizer: true
    property bool showUserPill: true
    property bool showStatusBar: true
    property bool showSystemVol: true
    property bool showPowerDock: true
    property bool confirmPowerActions: true
    property bool allowLogoutOnLock: true
    property bool showScreenCorners: true
    property bool ambientOrbs: true
    property bool albumArtBackdrop: false
    property bool autoZenIdle: false
    property bool wallpaperSync: true
    property string localWallpaperOverride: ""

    property string hyprSplash: ""
    property string rolledQuote: ""
    property real wavePhase: 0.0

    // respects the user's text casing preference instead of forcing .toLowerCase() everywhere
    function fmtText(s: string): string {
        if (!s) return "";
        if (lockRoot.textCase === "lower") return s.toLowerCase();
        if (lockRoot.textCase === "upper") return s.toUpperCase();
        return s;
    }

    // shape preset overrides so the user can go full sharp brutalist, squircle, or pill
    readonly property int uiRadiusSm: {
        if (shapePreset === "sharp") return 0;
        if (shapePreset === "pill") return 9999;
        if (shapePreset === "squircle") return 10;
        return Theme.radiusSm;
    }
    readonly property int uiRadiusMd: {
        if (shapePreset === "sharp") return 2;
        if (shapePreset === "pill") return 9999;
        if (shapePreset === "squircle") return 14;
        return Theme.radiusMd;
    }
    readonly property int uiRadiusLg: {
        if (shapePreset === "sharp") return 2;
        if (shapePreset === "pill") return 32;
        if (shapePreset === "squircle") return 22;
        return Theme.radiusLg;
    }
    readonly property int uiRadiusXl: {
        if (shapePreset === "sharp") return 4;
        if (shapePreset === "pill") return 42;
        if (shapePreset === "squircle") return 28;
        return Theme.radiusXl;
    }
    readonly property int uiRadiusPill: shapePreset === "sharp" ? 2 : Theme.radiusPill

    /*
    full light & dark mode palette engine:
    works whether matugen generated light tokens OR dark tokens
    */
    readonly property real surfaceLuminance: (0.2126 * Theme.surface.r) + (0.7152 * Theme.surface.g) + (0.0722 * Theme.surface.b)
    readonly property bool matugenIsLight: surfaceLuminance > 0.5
    readonly property bool globalCfgLight: (typeof Settings !== "undefined" && Settings)
        ? Boolean(Settings.lightMode || Settings.isLight || Settings.themeMode === "light" || Settings.colorScheme === "light")
        : false
    readonly property bool isLight: backdropMode === "light" || (backdropMode === "auto" && (matugenIsLight || globalCfgLight))

    readonly property color uiAccent: {
        if (!isLight) return Theme.primary;
        if (matugenIsLight) return Theme.primary;
        let darkened = Qt.rgba(Theme.primary.r * 0.62, Theme.primary.g * 0.62, Theme.primary.b * 0.62, 1.0);
        return Theme.blend(darkened, Theme.on_primary_container, 0.35);
    }
    readonly property color uiOnAccent: isLight ? "#ffffff" : Theme.on_primary
    readonly property color uiAccentOverlay: Theme.alpha(uiAccent, isLight ? 0.16 : 0.18)

    readonly property color uiSurfaceBase: {
        if (!isLight) return Theme.surface;
        if (matugenIsLight) return Theme.surface;
        return Theme.blend(Qt.rgba(0.97, 0.96, 0.99, 1.0), Theme.primary, 0.05);
    }
    readonly property color uiTextPrimary: {
        if (!isLight) return matugenIsLight ? Theme.inverse_on_surface : Theme.textPrimary;
        return matugenIsLight ? Theme.textPrimary : Theme.blend(Qt.rgba(0.11, 0.10, 0.14, 1.0), Theme.primary, 0.08);
    }
    readonly property color uiTextSecondary: {
        if (!isLight) return matugenIsLight ? Theme.alpha(Theme.inverse_on_surface, 0.72) : Theme.textSecondary;
        return matugenIsLight ? Theme.textSecondary : Theme.alpha(uiTextPrimary, 0.68);
    }
    readonly property color uiTextDisabled: Theme.alpha(uiTextPrimary, 0.40)

    function applyAlphaBoost(c: color, boost: real): color {
        let targetA = Math.max(0.12, Math.min(1.0, c.a + boost));
        return Qt.rgba(c.r, c.g, c.b, targetA);
    }

    readonly property color uiPillBg: {
        let base = !isLight
            ? Theme.pillBg
            : Theme.alpha(matugenIsLight ? Theme.surface_container_lowest : Theme.blend(Qt.rgba(0.98, 0.97, 1.0, 1.0), Theme.primary, 0.05), Theme.isGlass ? 0.82 : 0.92);
        return applyAlphaBoost(base, cardOpacityBoost);
    }
    readonly property color uiPillHover: {
        let base = !isLight
            ? Theme.pillHover
            : Theme.alpha(matugenIsLight ? Theme.surface_container_high : Theme.blend(Qt.rgba(0.93, 0.91, 0.96, 1.0), Theme.primary, 0.10), 0.94);
        return applyAlphaBoost(base, cardOpacityBoost);
    }
    readonly property color uiPillBorder: !isLight ? Theme.pillBorder : Theme.alpha(uiAccent, 0.24)

    readonly property color uiCardBg: {
        let base = !isLight
            ? Theme.cardBg
            : Theme.alpha(matugenIsLight ? Theme.surface_container_low : Theme.blend(Qt.rgba(0.97, 0.96, 0.99, 1.0), Theme.primary, 0.06), Theme.isGlass ? 0.85 : 0.94);
        return applyAlphaBoost(base, cardOpacityBoost);
    }
    readonly property color uiCardBorder: !isLight ? Theme.cardBorder : Theme.alpha(uiAccent, 0.22)

    readonly property color uiPopupBg: {
        if (!isLight) return Theme.popupBg;
        let base = matugenIsLight ? Theme.surface_container_lowest : Theme.blend(Qt.rgba(0.98, 0.97, 1.0, 1.0), Theme.primary, 0.04);
        return Theme.alpha(base, 0.95);
    }
    readonly property color uiPopupBorder: !isLight ? Theme.popupBorderColor : Theme.alpha(uiAccent, 0.26)

    readonly property color uiWidgetBg: {
        if (!isLight) return Theme.widgetBg;
        let base = matugenIsLight ? Theme.surface_container : Theme.blend(Qt.rgba(0.93, 0.92, 0.96, 1.0), Theme.primary, 0.07);
        return Theme.alpha(base, 0.88);
    }
    readonly property color uiWidgetHover: {
        if (!isLight) return Theme.widgetHover;
        let base = matugenIsLight ? Theme.surface_container_high : Theme.blend(Qt.rgba(0.89, 0.87, 0.93, 1.0), Theme.primary, 0.12);
        return Theme.alpha(base, 0.94);
    }
    readonly property color uiWidgetActive: !isLight ? Theme.widgetActive : Theme.alpha(uiAccent, 0.20)
    readonly property color uiWidgetBorder: !isLight ? Theme.widgetBorder : Theme.alpha(uiAccent, 0.20)

    SystemClock {
        id: sysClock
        precision: lockRoot.locked ? SystemClock.Seconds : SystemClock.Minutes
    }

    readonly property date currentTime: sysClock.date
    readonly property bool effectiveClock24h: sandboxClock24h
    readonly property bool effectiveShowSeconds: showSeconds

    readonly property var playerList: Mpris?.players?.values ?? []
    readonly property var activePlayer: {
        if (!playerList || playerList.length === 0) return null;
        if (lockRoot.manualPlayerIndex >= 0 && lockRoot.manualPlayerIndex < playerList.length) {
            let manual = playerList[lockRoot.manualPlayerIndex];
            if (manual && manual.isPlaying) return manual;
            let otherPlaying = playerList.find(p => p.isPlaying);
            if (!otherPlaying) return manual;
        }
        return playerList.find(p => p.isPlaying)
            ?? playerList.find(p => p.trackTitle)
            ?? playerList[0]
            ?? null;
    }
    readonly property int currentPlayerIdx: {
        if (!activePlayer || !playerList) return 0;
        let idx = playerList.indexOf(activePlayer);
        return idx >= 0 ? idx : 0;
    }
    readonly property bool playerIsPlaying: activePlayer?.isPlaying ?? false
    readonly property bool anyPlayerPlaying: {
        for (let i = 0; i < playerList.length; i++) {
            if (playerList[i]?.isPlaying) return true;
        }
        return false;
    }

    readonly property string coverArtUrl: fixCoverUrl(activePlayer?.trackArtUrl)
    property string lastFetchedRemoteArtUrl: ""
    property string localQuantizerArtUrl: ""

    property string pendingCurlUrl: ""
    property Process artFetchProc: Process {
        command: ["curl", "-fsSL", "--max-time", "4", "-o", lockRoot.remoteArtCachePath, lockRoot.pendingCurlUrl]
        onExited: (code) => {
            if (code === 0 && lockRoot.coverArtUrl === lockRoot.pendingCurlUrl) {
                lockRoot.lastFetchedRemoteArtUrl = lockRoot.pendingCurlUrl;
                lockRoot.localQuantizerArtUrl = "";
                lockRoot.localQuantizerArtUrl = "file://" + lockRoot.remoteArtCachePath;
            }
        }
    }

    onCoverArtUrlChanged: {
        if (!coverArtUrl || coverArtUrl === "") {
            localQuantizerArtUrl = "";
            return;
        }
        if (coverArtUrl.startsWith("file://")) {
            localQuantizerArtUrl = coverArtUrl;
            return;
        }
        if (coverArtUrl.startsWith("http://") || coverArtUrl.startsWith("https://")) {
            if (coverArtUrl === lastFetchedRemoteArtUrl) {
                localQuantizerArtUrl = "file://" + remoteArtCachePath;
            } else {
                localQuantizerArtUrl = "";
                pendingCurlUrl = coverArtUrl;
                if (artFetchProc.running) artFetchProc.running = false;
                artFetchProc.running = true;
            }
        } else {
            localQuantizerArtUrl = "";
        }
    }

    Loader {
        id: artQuantizerLoader
        active: lockRoot.localQuantizerArtUrl !== ""
        sourceComponent: ColorQuantizer {
            depth: 2
            rescaleSize: 64
            source: lockRoot.localQuantizerArtUrl
        }
    }

    readonly property color artAccent: {
        if (Theme.isMonochrome) return lockRoot.uiAccent;
        let qColors = artQuantizerLoader.item?.colors;
        if (lockRoot.localQuantizerArtUrl !== "" && qColors && qColors.length > 0) {
            for (let i = 0; i < qColors.length; i++) {
                let c = qColors[i];
                if (!c) continue;
                let mx = Math.max(c.r, c.g, c.b);
                let mn = Math.min(c.r, c.g, c.b);
                let sat = mx === 0 ? 0 : (mx - mn) / mx;
                if (sat < 0.18) continue;

                if (lockRoot.isLight) {
                    if (mx > 0.15) {
                        let darkened = Qt.rgba(c.r * 0.60, c.g * 0.60, c.b * 0.60, 1.0);
                        return Theme.blend(darkened, lockRoot.uiAccent, 0.45);
                    }
                } else {
                    if (mx > 0.25 && (mx - mn) > 0.15) {
                        return Theme.blend(c, lockRoot.uiAccent, 0.42);
                    }
                }
            }
        }
        return lockRoot.uiAccent;
    }

    readonly property string lockedDurationText: {
        let diffSec = Math.max(0, Math.floor((currentTime.getTime() - lockedAtTime.getTime()) / 1000));
        if (diffSec < 60) return fmtText("just locked");
        return fmtText("locked " + Theme.formatUptime(diffSec));
    }

    readonly property var defaultSink: (typeof Pipewire !== "undefined") ? Pipewire?.defaultAudioSink : null
    PwObjectTracker {
        objects: lockRoot.defaultSink ? [lockRoot.defaultSink] : []
    }

    PwNodePeakMonitor {
        id: lockPeakMonitor
        node: lockRoot.defaultSink
        enabled: lockRoot.locked && !lockRoot.zenMode && (
            (lockRoot.showMediaCard && lockRoot.showMediaVisualizer) || lockRoot.ambientOrbs
        ) && lockRoot.anyPlayerPlaying
    }

    property FileView lockStateFile: FileView {
        path: lockRoot.lockStatePath
        blockLoading: false
        watchChanges: false
        printErrors: false
        onLoaded: {
            if (!lockRoot.stateLoaded) lockRoot.loadState();
        }
        onLoadFailed: {
            lockRoot.stateLoaded = true;
        }
    }

    Timer {
        id: saveDebounceTimer
        interval: 140
        repeat: false
        onTriggered: lockRoot.flushStateToDisk()
    }

    function parseBool(val: string, fallback: bool): bool {
        let v = val.trim().toLowerCase();
        if (v === "1" || v === "true" || v === "yes") return true;
        if (v === "0" || v === "false" || v === "no") return false;
        return fallback;
    }

    function parseClamped(val: string, minVal: real, maxVal: real, fallback: real): real {
        let n = parseFloat(val);
        if (isNaN(n)) return fallback;
        return Math.max(minVal, Math.min(maxVal, n));
    }

    function loadState() {
        let raw = lockStateFile.text();
        if (!raw || raw.trim() === "") {
            lockRoot.stateLoaded = true;
            return;
        }

        const lines = raw.trim().split("\n");
        for (let i = 0; i < lines.length; i++) {
            let line = lines[i].trim();
            if (!line || line.startsWith("#")) continue;
            let eqIdx = line.indexOf("=");
            if (eqIdx < 0) continue;
            let k = line.slice(0, eqIdx).trim();
            let v = line.slice(eqIdx + 1).trim();

            switch (k) {
                case "studioLocked": lockRoot.studioLocked = parseBool(v, lockRoot.studioLocked); break;
                case "syncClockGlobal": lockRoot.syncClockGlobal = parseBool(v, lockRoot.syncClockGlobal); break;
                case "showClock": lockRoot.showClock = parseBool(v, lockRoot.showClock); break;
                case "showDate": lockRoot.showDate = parseBool(v, lockRoot.showDate); break;
                case "clock24h": lockRoot.sandboxClock24h = parseBool(v, lockRoot.sandboxClock24h); break;
                case "showSeconds": lockRoot.showSeconds = parseBool(v, lockRoot.showSeconds); break;
                case "clockStyle":
                    if (["inline", "stacked", "split", "typo", "digital", "editorial", "minimal"].includes(v)) lockRoot.clockStyle = v;
                    break;
                case "secondsStyle":
                    if (["badge", "supersub", "tower", "inline"].includes(v)) lockRoot.secondsStyle = v;
                    break;
                case "dateFormat": if (v !== "") lockRoot.dateFormat = v; break;
                case "textCase":
                    if (["lower", "normal", "upper"].includes(v)) lockRoot.textCase = v;
                    break;
                case "pwMaskChar": if (v !== "") lockRoot.pwMaskChar = v; break;
                case "stageWidth": lockRoot.stageWidth = Math.round(parseClamped(v, 340, 620, 448)); break;
                case "shapePreset":
                    if (["theme", "pill", "squircle", "sharp"].includes(v)) lockRoot.shapePreset = v;
                    break;
                case "cardOpacityBoost": lockRoot.cardOpacityBoost = parseClamped(v, -0.35, 0.35, 0.0); break;
                case "layoutPosition":
                    if (["center", "top", "bottom", "left", "right", "custom"].includes(v)) lockRoot.layoutPosition = v;
                    break;
                case "stackOrder":
                    if (v.includes("clock") && v.includes("media") && v.includes("password")) lockRoot.stackOrder = v;
                    break;
                case "dateAboveClock": lockRoot.dateAboveClock = parseBool(v, lockRoot.dateAboveClock); break;
                case "customNormX": lockRoot.customNormX = parseClamped(v, 0.0, 1.0, 0.5); break;
                case "customNormY": lockRoot.customNormY = parseClamped(v, 0.0, 1.0, 0.5); break;
                case "clockScale": lockRoot.clockScale = parseClamped(v, 0.65, 1.65, 1.0); break;
                case "quoteMode":
                    if (["smart", "hyprland", "unhinged", "custom", "off"].includes(v)) lockRoot.quoteMode = v;
                    break;
                case "customQuoteText": lockRoot.customQuoteText = v; break;
                case "backdropMode":
                    if (["auto", "dark", "light"].includes(v)) lockRoot.backdropMode = v;
                    break;
                case "pamService": if (v !== "") lockRoot.pamService = v; break;
                case "scrimDim": lockRoot.scrimDim = parseClamped(v, 0.05, 0.98, 0.58); break;
                case "vignetteStrength": lockRoot.vignetteStrength = parseClamped(v, 0.0, 0.95, 0.35); break;
                case "focusZoom": lockRoot.focusZoom = parseClamped(v, 1.0, 1.25, 1.05); break;
                case "showMedia": lockRoot.showMediaCard = parseBool(v, lockRoot.showMediaCard); break;
                case "showMediaVisualizer": lockRoot.showMediaVisualizer = parseBool(v, lockRoot.showMediaVisualizer); break;
                case "showUser": lockRoot.showUserPill = parseBool(v, lockRoot.showUserPill); break;
                case "showStatusBar": lockRoot.showStatusBar = parseBool(v, lockRoot.showStatusBar); break;
                case "showSystemVol": lockRoot.showSystemVol = parseBool(v, lockRoot.showSystemVol); break;
                case "showPowerDock": lockRoot.showPowerDock = parseBool(v, lockRoot.showPowerDock); break;
                case "confirmPowerActions": lockRoot.confirmPowerActions = parseBool(v, lockRoot.confirmPowerActions); break;
                case "allowLogoutOnLock": lockRoot.allowLogoutOnLock = parseBool(v, lockRoot.allowLogoutOnLock); break;
                case "showScreenCorners": lockRoot.showScreenCorners = parseBool(v, lockRoot.showScreenCorners); break;
                case "ambientOrbs": lockRoot.ambientOrbs = parseBool(v, lockRoot.ambientOrbs); break;
                case "albumArtBackdrop": lockRoot.albumArtBackdrop = parseBool(v, lockRoot.albumArtBackdrop); break;
                case "autoZenIdle": lockRoot.autoZenIdle = parseBool(v, lockRoot.autoZenIdle); break;
                case "wallpaperSync": lockRoot.wallpaperSync = parseBool(v, lockRoot.wallpaperSync); break;
                case "customWallpaper": lockRoot.localWallpaperOverride = v; break;
            }
        }

        if (lockRoot.syncClockGlobal && typeof Settings !== "undefined" && Settings) {
            if (Settings.clock24h !== undefined) lockRoot.sandboxClock24h = Boolean(Settings.clock24h);
            if (Settings.clockShowSeconds !== undefined) lockRoot.showSeconds = Boolean(Settings.clockShowSeconds);
        }

        lockRoot.stateLoaded = true;
    }

    function applyPreset(presetName: string) {
        if (lockRoot.studioLocked) return;
        if (presetName === "expressive") {
            lockRoot.clockStyle = "stacked";
            lockRoot.secondsStyle = "badge";
            lockRoot.showSeconds = true;
            lockRoot.layoutPosition = "center";
            lockRoot.stackOrder = "clock,media,password";
            lockRoot.shapePreset = "squircle";
            lockRoot.clockScale = 1.08;
            lockRoot.scrimDim = 0.54;
            lockRoot.vignetteStrength = 0.40;
            lockRoot.ambientOrbs = true;
            lockRoot.dateAboveClock = true;
        } else if (presetName === "cards") {
            lockRoot.clockStyle = "split";
            lockRoot.secondsStyle = "badge";
            lockRoot.showSeconds = true;
            lockRoot.layoutPosition = "center";
            lockRoot.stackOrder = "clock,password,media";
            lockRoot.shapePreset = "squircle";
            lockRoot.clockScale = 1.0;
            lockRoot.scrimDim = 0.62;
            lockRoot.vignetteStrength = 0.45;
            lockRoot.ambientOrbs = true;
            lockRoot.dateAboveClock = false;
        } else if (presetName === "editorial") {
            lockRoot.clockStyle = "editorial";
            lockRoot.showSeconds = true;
            lockRoot.secondsStyle = "tower";
            lockRoot.layoutPosition = "left";
            lockRoot.stackOrder = "clock,media,password";
            lockRoot.shapePreset = "pill";
            lockRoot.clockScale = 1.05;
            lockRoot.scrimDim = 0.48;
            lockRoot.vignetteStrength = 0.45;
            lockRoot.dateAboveClock = true;
        } else if (presetName === "cyber") {
            lockRoot.clockStyle = "digital";
            lockRoot.showSeconds = true;
            lockRoot.secondsStyle = "inline";
            lockRoot.layoutPosition = "center";
            lockRoot.stackOrder = "clock,password,media";
            lockRoot.shapePreset = "sharp";
            lockRoot.clockScale = 1.0;
            lockRoot.scrimDim = 0.65;
            lockRoot.vignetteStrength = 0.50;
            lockRoot.ambientOrbs = true;
        } else if (presetName === "minimal") {
            lockRoot.clockStyle = "minimal";
            lockRoot.showSeconds = false;
            lockRoot.layoutPosition = "top";
            lockRoot.stackOrder = "clock,password,media";
            lockRoot.shapePreset = "theme";
            lockRoot.clockScale = 0.95;
            lockRoot.scrimDim = 0.42;
            lockRoot.vignetteStrength = 0.20;
            lockRoot.ambientOrbs = false;
            lockRoot.dateAboveClock = false;
        }
        lockRoot.saveSandbox();
    }

    function resetDefaults() {
        if (lockRoot.studioLocked) return;
        lockRoot.showClock = true;
        lockRoot.showDate = true;
        lockRoot.clockStyle = "inline";
        lockRoot.secondsStyle = "badge";
        lockRoot.dateFormat = "dddd, MMMM d";
        lockRoot.textCase = "lower";
        lockRoot.pwMaskChar = "•";
        lockRoot.stageWidth = 448;
        lockRoot.shapePreset = "theme";
        lockRoot.cardOpacityBoost = 0.0;
        lockRoot.layoutPosition = "center";
        lockRoot.stackOrder = "clock,media,password";
        lockRoot.dateAboveClock = false;
        lockRoot.freeDragMode = false;
        lockRoot.customNormX = 0.5;
        lockRoot.customNormY = 0.5;
        lockRoot.clockScale = 1.0;
        lockRoot.backdropMode = "auto";
        lockRoot.scrimDim = 0.58;
        lockRoot.vignetteStrength = 0.35;
        lockRoot.focusZoom = 1.05;
        lockRoot.quoteMode = "smart";
        lockRoot.showMediaCard = true;
        lockRoot.showMediaVisualizer = true;
        lockRoot.showUserPill = true;
        lockRoot.showStatusBar = true;
        lockRoot.showSystemVol = true;
        lockRoot.showPowerDock = true;
        lockRoot.confirmPowerActions = true;
        lockRoot.allowLogoutOnLock = true;
        lockRoot.showScreenCorners = true;
        lockRoot.ambientOrbs = true;
        lockRoot.albumArtBackdrop = false;
        lockRoot.autoZenIdle = false;
        lockRoot.wallpaperSync = true;
        lockRoot.localWallpaperOverride = "";
        lockRoot.saveSandbox();
    }

    function surpriseMe() {
        if (lockRoot.studioLocked) return;
        const cStyles = ["inline", "stacked", "split", "typo", "digital", "editorial", "minimal"];
        const sStyles = ["badge", "supersub", "tower", "inline"];
        const positions = ["center", "top", "bottom", "left", "right"];
        const shapes = ["theme", "pill", "squircle", "sharp"];
        const orders = [
            "clock,media,password",
            "clock,password,media",
            "media,clock,password"
        ];
        const qModes = ["smart", "hyprland", "unhinged"];

        lockRoot.clockStyle = cStyles[Math.floor(Math.random() * cStyles.length)];
        lockRoot.secondsStyle = sStyles[Math.floor(Math.random() * sStyles.length)];
        lockRoot.shapePreset = shapes[Math.floor(Math.random() * shapes.length)];
        lockRoot.showSeconds = true;
        lockRoot.layoutPosition = positions[Math.floor(Math.random() * positions.length)];
        lockRoot.stackOrder = orders[Math.floor(Math.random() * orders.length)];
        lockRoot.dateAboveClock = Math.random() > 0.5;
        lockRoot.sandboxClock24h = Math.random() > 0.45;
        lockRoot.clockScale = Math.round((0.86 + Math.random() * 0.40) * 100) / 100;
        lockRoot.scrimDim = Math.round((0.38 + Math.random() * 0.36) * 100) / 100;
        lockRoot.vignetteStrength = Math.round((0.15 + Math.random() * 0.45) * 100) / 100;
        lockRoot.focusZoom = Math.round((1.03 + Math.random() * 0.09) * 100) / 100;
        lockRoot.ambientOrbs = Math.random() > 0.25;
        lockRoot.quoteMode = qModes[Math.floor(Math.random() * qModes.length)];
        lockRoot.refreshQuotes();
        lockRoot.saveSandbox();
    }

    function syncToGlobalSettings() {
        if (lockRoot.syncClockGlobal && typeof Settings !== "undefined" && Settings) {
            let fmt = lockRoot.sandboxClock24h
                ? (lockRoot.showSeconds ? "HH:mm:ss" : "HH:mm")
                : (lockRoot.showSeconds ? "h:mm:ss ap" : "h:mm ap");
            Settings.clockFormat = fmt;
            Settings.clock24h = lockRoot.sandboxClock24h;
            Settings.clockMilitary = lockRoot.sandboxClock24h;
            Settings.clockShowSeconds = lockRoot.showSeconds;
            if (Settings.save) Settings.save();
        }
    }

    function saveSandbox() {
        syncToGlobalSettings();
        saveDebounceTimer.restart();
    }

    function flushStateToDisk() {
        let lines = [
            "studioLocked=" + (lockRoot.studioLocked ? "1" : "0"),
            "syncClockGlobal=" + (lockRoot.syncClockGlobal ? "1" : "0"),
            "showClock=" + (lockRoot.showClock ? "1" : "0"),
            "showDate=" + (lockRoot.showDate ? "1" : "0"),
            "clock24h=" + (lockRoot.sandboxClock24h ? "1" : "0"),
            "showSeconds=" + (lockRoot.showSeconds ? "1" : "0"),
            "clockStyle=" + lockRoot.clockStyle,
            "secondsStyle=" + lockRoot.secondsStyle,
            "dateFormat=" + lockRoot.dateFormat,
            "textCase=" + lockRoot.textCase,
            "pwMaskChar=" + lockRoot.pwMaskChar,
            "stageWidth=" + lockRoot.stageWidth,
            "shapePreset=" + lockRoot.shapePreset,
            "cardOpacityBoost=" + Number(lockRoot.cardOpacityBoost).toFixed(2),
            "layoutPosition=" + lockRoot.layoutPosition,
            "stackOrder=" + lockRoot.stackOrder,
            "dateAboveClock=" + (lockRoot.dateAboveClock ? "1" : "0"),
            "customNormX=" + Number(lockRoot.customNormX).toFixed(4),
            "customNormY=" + Number(lockRoot.customNormY).toFixed(4),
            "clockScale=" + Number(lockRoot.clockScale).toFixed(2),
            "quoteMode=" + lockRoot.quoteMode,
            "customQuoteText=" + lockRoot.customQuoteText,
            "backdropMode=" + lockRoot.backdropMode,
            "pamService=" + lockRoot.pamService,
            "scrimDim=" + Number(lockRoot.scrimDim).toFixed(2),
            "vignetteStrength=" + Number(lockRoot.vignetteStrength).toFixed(2),
            "focusZoom=" + Number(lockRoot.focusZoom).toFixed(3),
            "showMedia=" + (lockRoot.showMediaCard ? "1" : "0"),
            "showMediaVisualizer=" + (lockRoot.showMediaVisualizer ? "1" : "0"),
            "showUser=" + (lockRoot.showUserPill ? "1" : "0"),
            "showStatusBar=" + (lockRoot.showStatusBar ? "1" : "0"),
            "showSystemVol=" + (lockRoot.showSystemVol ? "1" : "0"),
            "showPowerDock=" + (lockRoot.showPowerDock ? "1" : "0"),
            "confirmPowerActions=" + (lockRoot.confirmPowerActions ? "1" : "0"),
            "allowLogoutOnLock=" + (lockRoot.allowLogoutOnLock ? "1" : "0"),
            "showScreenCorners=" + (lockRoot.showScreenCorners ? "1" : "0"),
            "ambientOrbs=" + (lockRoot.ambientOrbs ? "1" : "0"),
            "albumArtBackdrop=" + (lockRoot.albumArtBackdrop ? "1" : "0"),
            "autoZenIdle=" + (lockRoot.autoZenIdle ? "1" : "0"),
            "wallpaperSync=" + (lockRoot.wallpaperSync ? "1" : "0"),
            "customWallpaper=" + lockRoot.localWallpaperOverride
        ];
        lockStateFile.setText(lines.join("\n") + "\n");
    }

    property FileView lockTokenFile: FileView {
        path: lockRoot.lockTokenPath
        blockLoading: true
        watchChanges: false
        printErrors: false
        onLoaded: {
            let t = (text() || "").trim();
            if (t === "locked" && !lockRoot.locked) {
                lockRoot.locked = true;
            }
        }
    }

    property Process mkdirProc: Process {
        command: ["mkdir", "-p", lockRoot.lockStateDir]
    }

    property Process splashProc: Process {
        command: ["hyprctl", "splash"]
        stdout: StdioCollector {
            onStreamFinished: {
                let raw = (text || "").trim();
                if (raw !== "" && !raw.toLowerCase().startsWith("error") && !raw.toLowerCase().startsWith("unknown")) {
                    lockRoot.hyprSplash = raw;
                } else if (lockRoot.hyprSplash === "") {
                    lockRoot.hyprSplash = "Hyprland: Lua-powered Wayland compositor";
                }
            }
        }
    }

    // checks caps lock, active xkb layout, AND whether pam_faillock has locked the user out
    property bool faillockTripped: false
    property Process kbPollProc: Process {
        command: [
            "sh", "-c",
            "caps=0; for f in /sys/class/leds/*capslock*/brightness; do [ -f \"$f\" ] && [ \"$(cat \"$f\" 2>/dev/null)\" = \"1\" ] && caps=1 && break; done; " +
            "lay=$(hyprctl devices -j 2>/dev/null | grep -o '\"active_keymap\": *\"[^\"]*\"' | head -n1 | cut -d'\"' -f4); " +
            "fl=$(faillock --user \"$USER\" 2>/dev/null | grep -c 'V' || true); " +
            "printf '%s|%s|%s\\n' \"$caps\" \"$lay\" \"$fl\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let raw = (text || "").trim();
                let parts = raw.split("|");
                if (parts.length >= 2) {
                    lockRoot.capsLockActive = parts[0].trim() === "1";
                    let fullLay = parts[1].trim();
                    if (fullLay !== "") {
                        let paren = fullLay.match(/\(([A-Za-z0-9_-]{2,5})\)/);
                        lockRoot.kbLayoutShort = paren ? paren[1] : fullLay.slice(0, 3);
                    }
                }
                if (parts.length >= 3) {
                    let validFails = parseInt(parts[2].trim()) || 0;
                    lockRoot.faillockTripped = validFails >= 3;
                }
            }
        }
    }

    function pollKeyboardState() {
        if (!kbPollProc.running) kbPollProc.running = true;
    }

    function switchKeyboardLayout() {
        Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"]);
        kbPollDelayTimer.restart();
    }

    Timer {
        id: kbPollDelayTimer
        interval: 80
        repeat: false
        onTriggered: lockRoot.pollKeyboardState()
    }

    function pickSmartCategory(): string {
        let batPresent = UPower.displayDevice?.isPresent ?? false;
        let batPct = Math.round((UPower.displayDevice?.percentage ?? 1.0) * 100);
        let isCharging = UPower.displayDevice?.state === UPowerDeviceState.Charging;

        if (batPresent && !isCharging && batPct <= 20) return "battery_low";
        if (batPresent && isCharging && batPct < 95) return "battery_charging";
        if (lockRoot.anyPlayerPlaying) return "media_playing";
        if (typeof NetworkService !== "undefined" && NetworkService && !NetworkService.isConnected && !NetworkService.isWiredConnected) {
            return "network_off";
        }
        if (lockRoot.defaultSink?.audio?.muted) return "volume_muted";
        if ((lockRoot.defaultSink?.audio?.volume ?? 0) > 0.95) return "volume_high";
        return "system";
    }

    function refreshQuotes() {
        if (!splashProc.running) splashProc.running = true;
        let cat = lockRoot.quoteMode === "smart" ? pickSmartCategory() : "system";
        let pool = Theme.flavorQuotes?.[cat] ?? Theme.flavorQuotes?.system;
        if (pool && pool.length > 0) {
            let idx = Math.floor(Math.random() * pool.length);
            lockRoot.rolledQuote = pool[idx] || "";
        } else if (Theme.getFlavor) {
            lockRoot.rolledQuote = Theme.getFlavor(cat, "") || "";
        }
    }

    readonly property string activeQuoteText: {
        if (lockRoot.quoteMode === "off") return "";
        if (lockRoot.quoteMode === "custom") return fmtText(lockRoot.customQuoteText);
        if (lockRoot.quoteMode === "unhinged" || lockRoot.quoteMode === "smart") {
            return fmtText(lockRoot.rolledQuote || lockRoot.hyprSplash);
        }
        return fmtText(lockRoot.hyprSplash || lockRoot.rolledQuote);
    }

    function numberToWords(n: int): string {
        const ones = [
            "Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine",
            "Ten", "Eleven", "Twelve", "Thirteen", "Fourteen", "Fifteen", "Sixteen",
            "Seventeen", "Eighteen", "Nineteen"
        ];
        const tens = ["", "", "Twenty", "Thirty", "Forty", "Fifty"];
        if (n < 0 || n >= 60) return String(n);
        if (n < 20) return fmtText(ones[n]);
        let t = Math.floor(n / 10);
        let r = n % 10;
        return fmtText(r === 0 ? tens[t] : (tens[t] + "-" + ones[r].toLowerCase()));
    }

    function fixCoverUrl(url): string {
        if (!url || typeof url !== "string") return "";
        let cleaned = url.trim();
        if (cleaned.startsWith("/")) return "file://" + cleaned;
        return cleaned;
    }

    function formatTime(seconds): string {
        if (seconds === undefined || seconds === null || isNaN(seconds) || seconds < 0) return "0:00";
        let sec = Math.floor(seconds);
        let m = Math.floor(sec / 60);
        let s = sec % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    function formatBatteryEta(): string {
        let dev = UPower.displayDevice;
        if (!dev || !dev.isPresent) return "";
        let isChg = dev.state === UPowerDeviceState.Charging;
        let sec = isChg ? (dev.timeToFull ?? 0) : (dev.timeToEmpty ?? 0);
        if (!sec || sec <= 60 || isNaN(sec)) return "";
        return fmtText((isChg ? "full in " : "left ") + Theme.formatUptime(Math.round(sec)));
    }

    Component.onCompleted: {
        mkdirProc.running = true;
        refreshQuotes();
        let t = (lockTokenFile.text() || "").trim();
        if (sessionPersist.wasLocked || t === "locked") {
            if (sessionPersist.lockedAtEpochMs > 0) {
                lockRoot.lockedAtTime = new Date(sessionPersist.lockedAtEpochMs);
            }
            lockRoot.failedAttempts = sessionPersist.failedCount;
            lockRoot.locked = true;
        }
    }

    function pickRandomWallpaperInMemory(): string {
        if (typeof WallpaperService !== "undefined" && WallpaperService) {
            if (typeof WallpaperService.getRandomWallpaperPath === "function") {
                let wp = WallpaperService.getRandomWallpaperPath();
                if (wp && wp !== "") return wp;
            }
            if (WallpaperService.wallpaperList && WallpaperService.wallpaperList.length > 0) {
                let list = WallpaperService.wallpaperList;
                let item = list[Math.floor(Math.random() * list.length)];
                let p = item?.path ?? item?.url ?? "";
                if (p !== "") return p;
            }
            if (WallpaperService.localWpListFile) {
                try {
                    let raw = WallpaperService.localWpListFile.text();
                    let parsed = JSON.parse(raw) || [];
                    let staticList = parsed.filter(w => w && w.path && !/\.(mp4|webm|mkv|mov)$/i.test(w.path));
                    let pool = staticList.length > 0 ? staticList : parsed;
                    if (pool.length > 0) {
                        return pool[Math.floor(Math.random() * pool.length)].path || "";
                    }
                } catch (e) {}
            }
            if (WallpaperService.currentWallpaperPath) return WallpaperService.currentWallpaperPath;
            if (WallpaperService.currWallStatic) return WallpaperService.currWallStatic;
        }
        return "";
    }

    signal triggerShake()
    signal clearAllInputs()

    onLockedChanged: {
        if (locked) {
            if (!sessionPersist.wasLocked) {
                lockedAtTime = new Date();
                sessionPersist.lockedAtEpochMs = lockedAtTime.getTime();
                failedAttempts = 0;
                sessionPersist.failedCount = 0;
            }
            sessionPersist.wasLocked = true;
            authFailed = false;
            isChecking = false;
            pamRespondedThisTurn = false;
            pamFeedback = "";
            pamFeedbackIsError = false;
            pendingPassword = "";
            sharedPassword = "";
            revealPassword = false;
            freeDragMode = false;
            zenMode = false;
            clearAllInputs();

            if (syncClockGlobal && typeof Settings !== "undefined" && Settings) {
                if (Settings.clock24h !== undefined) sandboxClock24h = Boolean(Settings.clock24h);
                if (Settings.clockShowSeconds !== undefined) showSeconds = Boolean(Settings.clockShowSeconds);
            }
            refreshQuotes();
            pollKeyboardState();
            lockTokenFile.setText("locked");
        } else {
            if (pam.active) pam.abort();
            pamSafetyTimeout.stop();
            activeSurface = null;
            sessionPersist.wasLocked = false;
            sessionPersist.lockedAtEpochMs = 0;
            sessionPersist.failedCount = 0;
            failedAttempts = 0;
            pendingPassword = "";
            sharedPassword = "";
            revealPassword = false;
            freeDragMode = false;
            zenMode = false;
            pamFeedback = "";
            clearAllInputs();
            syncToGlobalSettings();
            lockTokenFile.setText("");
            Quickshell.execDetached(["rm", "-f", lockTokenPath]);
        }
    }

    Timer {
        interval: 75
        running: lockRoot.locked && lockRoot.anyPlayerPlaying && (
            (lockRoot.showMediaCard && lockRoot.showMediaVisualizer) || lockRoot.ambientOrbs
        )
        repeat: true
        onTriggered: {
            lockRoot.wavePhase = (lockRoot.wavePhase + 0.28) % (Math.PI * 20);
        }
    }

    Timer {
        id: pamSafetyTimeout
        interval: 9000
        onTriggered: {
            if (lockRoot.isChecking) {
                if (pam.active) pam.abort();
                lockRoot.isChecking = false;
                lockRoot.pendingPassword = "";
                lockRoot.authFailed = true;
                lockRoot.pamFeedback = "authentication timed out";
                lockRoot.pamFeedbackIsError = true;
                lockRoot.triggerShake();
                shakeTimer.restart();
            }
        }
    }

    IpcHandler {
        target: "lock"
        function lock(): void {
            lockRoot.locked = true;
        }
        function isLocked(): bool {
            return lockRoot.locked;
        }
    }

    /*
    rock-solid PAM handler:
    never calls pam.abort() inside handleResponse() when both onResponseRequiredChanged
    and onPamMessage fire on the same prompt!
    */
    PamContext {
        id: pam
        config: lockRoot.pamService || "login"
        user: Quickshell.env("USER") ?? ""

        function handleResponse(): void {
            if (responseRequired && !lockRoot.pamRespondedThisTurn) {
                lockRoot.pamRespondedThisTurn = true;
                let pw = lockRoot.pendingPassword;
                lockRoot.pendingPassword = "";
                pam.respond(pw);
            }
        }

        onPamMessage: {
            if (pam.message && pam.message.trim() !== "") {
                let msg = pam.message.trim();
                if (!msg.toLowerCase().startsWith("password")) {
                    lockRoot.pamFeedback = msg;
                    lockRoot.pamFeedbackIsError = pam.messageIsError;
                }
            }
            handleResponse();
        }

        onResponseRequiredChanged: {
            if (!responseRequired) {
                lockRoot.pamRespondedThisTurn = false;
            } else {
                handleResponse();
            }
        }

        onCompleted: (result) => {
            pamSafetyTimeout.stop();
            lockRoot.isChecking = false;
            lockRoot.pamRespondedThisTurn = false;
            lockRoot.pendingPassword = "";

            if (result === PamResult.Success) {
                lockRoot.locked = false;
                lockRoot.authFailed = false;
                lockRoot.pamFeedback = "";
            } else {
                lockRoot.authFailed = true;
                lockRoot.failedAttempts += 1;
                sessionPersist.failedCount = lockRoot.failedAttempts;
                lockRoot.pollKeyboardState();

                if (result === PamResult.MaxTries || lockRoot.faillockTripped) {
                    lockRoot.pamFeedback = "account locked by pam_faillock (run 'faillock --reset' in tty)";
                } else if (!lockRoot.pamFeedback) {
                    lockRoot.pamFeedback = "incorrect password, try again";
                }
                lockRoot.pamFeedbackIsError = true;
                lockRoot.triggerShake();
                shakeTimer.restart();
            }
        }

        onError: (err) => {
            console.warn("[LockScreen PAM Error]:", err);
            lockRoot.pamFeedback = "pam error: " + err;
            lockRoot.pamFeedbackIsError = true;
        }
    }

    function tryUnlock(pw: string) {
        if (isChecking) return;

        if (pam.active) {
            pam.abort();
        }

        isChecking = true;
        pamRespondedThisTurn = false;
        authFailed = false;
        pamFeedback = (!pw || pw.length === 0) ? "checking pam / passkey..." : "authenticating...";
        pamFeedbackIsError = false;
        pendingPassword = pw ?? "";
        sharedPassword = "";
        revealPassword = false;
        clearAllInputs();
        pamSafetyTimeout.restart();

        if (!pam.start()) {
            pamSafetyTimeout.stop();
            isChecking = false;
            pamRespondedThisTurn = false;
            pendingPassword = "";
            authFailed = true;
            pamFeedback = "failed to start pam session";
            pamFeedbackIsError = true;
            triggerShake();
            shakeTimer.restart();
        }
    }

    Timer {
        id: shakeTimer
        interval: 3200
        onTriggered: {
            lockRoot.authFailed = false;
            if (!lockRoot.isChecking) {
                lockRoot.pamFeedback = "";
            }
        }
    }

    WlSessionLock {
        id: sessionLock
        locked: lockRoot.locked

        surface: Component {
            WlSessionLockSurface {
                id: surface
                color: lockRoot.uiSurfaceBase

                property string pendingPowerAction: ""
                property bool optionsOpen: false
                property bool entered: false
                property bool volumeHudVisible: false
                property string volumeHudLabel: ""
                property real trackPosition: lockRoot.activePlayer?.position ?? 0
                property real stageBurstScale: 1.0
                property bool snappedX: false
                property bool snappedY: false

                Component.onCompleted: {
                    entered = true;
                    if (lockRoot.activeSurface === null) {
                        lockRoot.activeSurface = surface;
                        pwInput.forceActiveFocus();
                    }
                }

                Component.onDestruction: {
                    if (lockRoot.activeSurface === surface) {
                        lockRoot.activeSurface = null;
                    }
                }

                function claimSurfaceFocus() {
                    if (lockRoot.activeSurface !== surface) {
                        lockRoot.activeSurface = surface;
                    }
                    if (!customQuoteInput.activeFocus && !pwInput.activeFocus) {
                        pwInput.forceActiveFocus();
                    }
                }

                Timer {
                    id: autoZenTimer
                    interval: 30000
                    running: lockRoot.locked && lockRoot.autoZenIdle && !lockRoot.zenMode && !surface.optionsOpen && lockRoot.sharedPassword.length === 0
                    repeat: false
                    onTriggered: lockRoot.zenMode = true
                }

                function wakeFromZen() {
                    if (lockRoot.zenMode) lockRoot.zenMode = false;
                    if (lockRoot.autoZenIdle) autoZenTimer.restart();
                }

                Timer {
                    id: powerActionResetTimer
                    interval: 3500
                    onTriggered: surface.pendingPowerAction = ""
                }

                Timer {
                    id: volumeHudTimer
                    interval: 1500
                    onTriggered: surface.volumeHudVisible = false
                }

                function showVolumeToast(txt: string) {
                    surface.volumeHudLabel = lockRoot.fmtText(txt);
                    surface.volumeHudVisible = true;
                    volumeHudTimer.restart();
                }

                function adjustSystemVolume(delta: real) {
                    let audio = lockRoot.defaultSink?.audio;
                    if (!audio) return;
                    if (audio.muted && delta > 0) audio.muted = false;
                    let next = Math.max(0.0, Math.min(1.5, (audio.volume ?? 0.5) + delta));
                    audio.volume = next;
                    showVolumeToast("sys " + Math.round(next * 100) + "%");
                }

                function toggleSystemMute() {
                    let audio = lockRoot.defaultSink?.audio;
                    if (!audio) return;
                    audio.muted = !audio.muted;
                    showVolumeToast(audio.muted ? "sys muted" : ("sys " + Math.round((audio.volume ?? 0) * 100) + "%"));
                }

                function requestPowerAction(action: string, cmd: var) {
                    if (!lockRoot.confirmPowerActions || surface.pendingPowerAction === action) {
                        surface.pendingPowerAction = "";
                        powerActionResetTimer.stop();
                        surface.optionsOpen = false;
                        lockRoot.sharedPassword = "";
                        lockRoot.revealPassword = false;
                        lockRoot.clearAllInputs();
                        Quickshell.execDetached(cmd);
                    } else {
                        surface.pendingPowerAction = action;
                        powerActionResetTimer.restart();
                    }
                }

                readonly property var playerList: lockRoot.playerList
                readonly property var activePlayer: lockRoot.activePlayer
                readonly property int currentPlayerIdx: lockRoot.currentPlayerIdx
                readonly property bool playerIsPlaying: lockRoot.playerIsPlaying
                readonly property string coverArtUrl: lockRoot.coverArtUrl
                readonly property color artAccent: lockRoot.artAccent

                readonly property real liveAudioPeak: {
                    if (!surface.playerIsPlaying) return 0.0;
                    let pList = lockPeakMonitor.peaks;
                    if (pList && pList.length >= 2) return Math.min(1.0, (pList[0] + pList[1]) * 0.5);
                    return Math.min(1.0, lockPeakMonitor.peak ?? 0.0);
                }

                Connections {
                    target: surface.activePlayer
                    function onPositionChanged() {
                        if (!seekMouse.pressed) {
                            surface.trackPosition = surface.activePlayer?.position ?? 0;
                        }
                    }
                    function onTrackTitleChanged() {
                        surface.trackPosition = surface.activePlayer?.position ?? 0;
                        if (lockRoot.quoteMode === "smart") lockRoot.refreshQuotes();
                    }
                }

                Timer {
                    interval: 500
                    running: lockRoot.locked && surface.playerIsPlaying && lockRoot.showMediaCard && !lockRoot.zenMode && !seekMouse.pressed
                    repeat: true
                    onTriggered: {
                        if (surface.activePlayer) {
                            surface.trackPosition = surface.activePlayer.position ?? 0;
                        }
                    }
                }

                component OptChip: Rectangle {
                    id: cRoot
                    property string label: ""
                    property string icon: ""
                    property bool selected: false
                    signal clicked()

                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    radius: selected ? lockRoot.uiRadiusMd : lockRoot.uiRadiusPill
                    opacity: lockRoot.studioLocked ? 0.55 : 1.0
                    color: selected
                        ? lockRoot.uiAccentOverlay
                        : (cMouse.pressed ? lockRoot.uiWidgetActive : (cMouse.containsMouse ? lockRoot.uiWidgetHover : lockRoot.uiWidgetBg))
                    border.color: selected
                        ? Theme.alpha(lockRoot.uiAccent, 0.65)
                        : (cMouse.containsMouse ? Theme.alpha(lockRoot.uiAccent, 0.35) : lockRoot.uiWidgetBorder)
                    border.width: 1

                    Behavior on radius { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
                    Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            visible: cRoot.icon !== ""
                            text: cRoot.icon
                            font.family: Theme.fontIcon
                            font.pixelSize: Theme.fontSizeXs
                            color: cRoot.selected ? lockRoot.uiAccent : lockRoot.uiTextSecondary
                        }

                        Text {
                            text: lockRoot.fmtText(cRoot.label)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: cRoot.selected ? Theme.fontWeightBold : Theme.fontWeightMedium
                            color: cRoot.selected ? lockRoot.uiAccent : lockRoot.uiTextSecondary
                        }
                    }

                    MouseArea {
                        id: cMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !lockRoot.studioLocked
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                        onClicked: {
                            cRoot.clicked();
                            surface.claimSurfaceFocus();
                        }
                    }
                }

                component SandboxSlider: ColumnLayout {
                    id: sRoot
                    property string label: ""
                    property string icon: ""
                    property real from: 0.0
                    property real to: 1.0
                    property real value: 0.5
                    property real stepSize: 0.02
                    property string displayText: Math.round(value * 100) + "%"
                    signal moved(real newValue)

                    Layout.fillWidth: true
                    spacing: 5
                    opacity: lockRoot.studioLocked ? 0.55 : 1.0

                    readonly property real ratio: Math.max(0.0, Math.min(1.0, (value - from) / Math.max(0.0001, to - from)))

                    function setFromRatio(r: real) {
                        if (lockRoot.studioLocked) return;
                        let clamped = Math.max(0.0, Math.min(1.0, r));
                        let raw = from + clamped * (to - from);
                        if (stepSize > 0) {
                            raw = Math.round(raw / stepSize) * stepSize;
                        }
                        let finalVal = Math.max(from, Math.min(to, raw));
                        sRoot.moved(finalVal);
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            visible: sRoot.icon !== ""
                            text: sRoot.icon
                            font.family: Theme.fontIcon
                            font.pixelSize: Theme.fontSizeXs
                            color: sMouse.pressed || sMouse.containsMouse ? lockRoot.uiAccent : lockRoot.uiTextSecondary
                        }

                        Text {
                            text: lockRoot.fmtText(sRoot.label)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: Theme.fontWeightDemiBold
                            color: lockRoot.uiTextSecondary
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            height: 18
                            implicitWidth: valTxt.implicitWidth + 10
                            radius: lockRoot.uiRadiusPill
                            color: sMouse.pressed ? lockRoot.uiAccentOverlay : lockRoot.uiWidgetBg
                            border.color: sMouse.pressed ? Theme.alpha(lockRoot.uiAccent, 0.5) : lockRoot.uiWidgetBorder
                            border.width: 1

                            Text {
                                id: valTxt
                                anchors.centerIn: parent
                                text: sRoot.displayText
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeXs
                                font.weight: Theme.fontWeightBold
                                color: lockRoot.uiAccent
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 20

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: sMouse.pressed ? 14 : (sMouse.containsMouse ? 12 : 8)
                            radius: lockRoot.uiRadiusPill
                            color: lockRoot.uiWidgetBg
                            border.color: sMouse.containsMouse ? Theme.alpha(lockRoot.uiAccent, 0.35) : lockRoot.uiWidgetBorder
                            border.width: 1

                            Behavior on height { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
                            Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: Math.max(parent.height, parent.width * sRoot.ratio)
                                radius: lockRoot.uiRadiusPill
                                color: sMouse.pressed
                                    ? Theme.statePress(lockRoot.uiAccent, lockRoot.uiOnAccent)
                                    : (sMouse.containsMouse ? Theme.stateHover(lockRoot.uiAccent, lockRoot.uiOnAccent) : lockRoot.uiAccent)

                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            }
                        }

                        Rectangle {
                            width: sMouse.pressed ? 6 : 4
                            height: sMouse.pressed ? 20 : (sMouse.containsMouse ? 18 : 14)
                            radius: lockRoot.uiRadiusPill
                            color: lockRoot.uiTextPrimary
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.max(0, Math.min(parent.width - width, (parent.width * sRoot.ratio) - (width / 2)))

                            Behavior on width { NumberAnimation { duration: Theme.animFast } }
                            Behavior on height { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animExpressiveEasing } }
                        }

                        MouseArea {
                            id: sMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !lockRoot.studioLocked
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                            onPressed: (mouse) => sRoot.setFromRatio(mouse.x / width)
                            onPositionChanged: (mouse) => {
                                if (pressed) sRoot.setFromRatio(mouse.x / width);
                            }
                            onReleased: surface.claimSurfaceFocus()
                            onWheel: (wheel) => {
                                let dir = wheel.angleDelta.y > 0 ? 1 : -1;
                                let next = Math.max(sRoot.from, Math.min(sRoot.to, sRoot.value + (dir * sRoot.stepSize)));
                                sRoot.moved(next);
                            }
                        }
                    }
                }

                component SandboxToggleRow: Rectangle {
                    id: tRow
                    property string icon: ""
                    property string label: ""
                    property bool checked: false
                    signal toggled()

                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: lockRoot.uiRadiusSm
                    opacity: lockRoot.studioLocked ? 0.55 : 1.0
                    color: rowMouse.containsMouse ? lockRoot.uiWidgetHover : "transparent"

                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        spacing: 10

                        Text {
                            text: tRow.icon
                            font.family: Theme.fontIcon
                            font.pixelSize: Theme.fontSizeMd
                            color: tRow.checked ? lockRoot.uiAccent : lockRoot.uiTextSecondary
                            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
                        }

                        Text {
                            text: lockRoot.fmtText(tRow.label)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            color: lockRoot.uiTextPrimary
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        ToggleSwitch {
                            id: sw
                            enabled: false
                            checked: tRow.checked

                            Binding {
                                target: sw
                                property: "checked"
                                value: tRow.checked
                            }
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !lockRoot.studioLocked
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                        onClicked: {
                            tRow.toggled();
                            surface.claimSurfaceFocus();
                        }
                    }
                }

                component PowerPill: Rectangle {
                    id: pRoot
                    property string actionId: ""
                    property string icon: ""
                    property string label: ""
                    property var command: []

                    readonly property bool isArmed: surface.pendingPowerAction === pRoot.actionId

                    height: 40
                    implicitWidth: isArmed ? (pRow.implicitWidth + 28) : 40
                    radius: isArmed ? lockRoot.uiRadiusMd : lockRoot.uiRadiusPill
                    color: isArmed
                        ? (pMouse.pressed ? Theme.statePress(Theme.error, Theme.on_error) : Theme.error)
                        : (pMouse.pressed ? lockRoot.uiWidgetActive : (pMouse.containsMouse ? lockRoot.uiPillHover : lockRoot.uiPillBg))
                    border.color: isArmed
                        ? Theme.error
                        : (pMouse.containsMouse ? Theme.alpha(lockRoot.uiAccent, 0.55) : lockRoot.uiPillBorder)
                    border.width: (isArmed || pMouse.containsMouse || lockRoot.uiPillBorder.a > 0) ? 1 : 0

                    Behavior on implicitWidth { NumberAnimation { duration: Theme.expressiveFast; easing.type: Theme.animExpressiveEasing } }
                    Behavior on radius { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.animEasing } }
                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
                    Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                    RowLayout {
                        id: pRow
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: pRoot.isArmed ? Theme.iconFlame : pRoot.icon
                            font.family: Theme.fontIcon
                            font.pixelSize: Theme.fontSizeMd
                            color: pRoot.isArmed ? Theme.on_error : (pMouse.containsMouse ? lockRoot.uiAccent : lockRoot.uiTextPrimary)
                        }

                        Text {
                            visible: pRoot.isArmed
                            text: lockRoot.fmtText("confirm " + pRoot.label + "?")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: Theme.fontWeightBold
                            color: Theme.on_error
                        }
                    }

                    MouseArea {
                        id: pMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: surface.requestPowerAction(pRoot.actionId, pRoot.command)
                    }
                }

                Rectangle {
                    id: screenCanvas
                    anchors.fill: parent
                    color: lockRoot.uiSurfaceBase
                    clip: true

                    focus: true
                    Keys.forwardTo: [pwInput]

                    readonly property bool isDeepFocused: lockRoot.sharedPassword.length > 0 || surface.optionsOpen || lockRoot.isChecking

                    MouseArea {
                        anchors.fill: parent
                        z: -1
                        hoverEnabled: true
                        onEntered: {
                            surface.claimSurfaceFocus();
                        }
                        onPositionChanged: {
                            surface.wakeFromZen();
                        }
                        onClicked: {
                            surface.wakeFromZen();
                            surface.optionsOpen = false;
                            surface.pendingPowerAction = "";
                            pwInput.forceActiveFocus();
                        }
                    }

                    Image {
                        id: baseWall
                        anchors.fill: parent
                        source: {
                            let wp = "";
                            if (!lockRoot.wallpaperSync && lockRoot.localWallpaperOverride !== "") {
                                wp = lockRoot.localWallpaperOverride;
                            } else {
                                wp = (typeof WallpaperService !== "undefined" ? WallpaperService?.currentWallpaperPath : "")
                                    || lockRoot.localWallpaperOverride || "";
                            }
                            if (!wp || wp === "" || /\.(mp4|webm|mkv|mov)$/i.test(wp)) {
                                wp = (typeof WallpaperService !== "undefined" ? WallpaperService?.currWallStatic : "")
                                    || (lockRoot.homeDir + "/.curr_wall_static.jpg");
                            }
                            if (!wp) return "";
                            return (wp.startsWith("file://") || wp.startsWith("http://") || wp.startsWith("https://")) ? wp : ("file://" + wp);
                        }
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        scale: parent.isDeepFocused ? lockRoot.focusZoom : 1.0

                        Behavior on scale {
                            NumberAnimation { duration: Theme.expressiveSlow; easing.type: Theme.animEasing }
                        }
                    }

                    Image {
                        anchors.fill: parent
                        source: (lockRoot.albumArtBackdrop && surface.coverArtUrl !== "") ? surface.coverArtUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        opacity: (lockRoot.albumArtBackdrop && surface.playerIsPlaying && status === Image.Ready) ? 0.55 : 0.0
                        scale: parent.isDeepFocused ? (lockRoot.focusZoom + 0.08) : 1.08
                        visible: opacity > 0.001

                        Behavior on opacity { NumberAnimation { duration: Theme.expressiveSlow; easing.type: Theme.animEasing } }
                        Behavior on scale { NumberAnimation { duration: Theme.expressiveSlow; easing.type: Theme.animEasing } }
                    }

                    // light/dark backdrop scrim
                    Rectangle {
                        anchors.fill: parent
                        color: lockRoot.isLight ? lockRoot.uiSurfaceBase : Theme.scrim
                        opacity: {
                            let base = lockRoot.scrimDim + (parent.isDeepFocused ? 0.08 : 0.0);
                            if (lockRoot.isLight) return Math.min(0.96, Math.max(0.32, base + 0.12));
                            return Math.min(0.96, base);
                        }
                        Behavior on color { ColorAnimation { duration: Theme.animSlow; easing.type: Theme.animColorEasing } }
                        Behavior on opacity { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.animEasing } }
                    }

                    // ambient audio-reactive glow orbs
                    Item {
                        anchors.fill: parent
                        visible: lockRoot.ambientOrbs
                        opacity: surface.entered ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: Theme.expressiveSlow } }

                        Rectangle {
                            width: Math.min(parent.width, parent.height) * (0.48 + surface.liveAudioPeak * 0.14)
                            height: width
                            radius: width / 2
                            x: centerStage.x - width * 0.25 + Math.sin(lockRoot.wavePhase * 0.25) * 32
                            y: centerStage.y - height * 0.20 + Math.cos(lockRoot.wavePhase * 0.20) * 24
                            color: surface.artAccent
                            opacity: (lockRoot.isLight ? 0.16 : 0.11) + (surface.liveAudioPeak * 0.10)
                            Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
                            Behavior on color { ColorAnimation { duration: Theme.animSlow } }
                        }

                        Rectangle {
                            width: Math.min(parent.width, parent.height) * (0.40 + surface.liveAudioPeak * 0.12)
                            height: width
                            radius: width / 2
                            x: centerStage.x + centerStage.width * 0.35 - Math.cos(lockRoot.wavePhase * 0.22) * 28
                            y: centerStage.y + centerStage.height * 0.25 + Math.sin(lockRoot.wavePhase * 0.18) * 28
                            color: Theme.tertiary
                            opacity: (lockRoot.isLight ? 0.13 : 0.08) + (surface.liveAudioPeak * 0.08)
                            Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
                        }
                    }

                    // vignette framing
                    Rectangle {
                        anchors.fill: parent
                        visible: lockRoot.vignetteStrength > 0.01
                        opacity: lockRoot.vignetteStrength

                        readonly property color vigColor: lockRoot.isLight
                            ? Theme.blend(Qt.rgba(0.84, 0.82, 0.88, 1.0), lockRoot.uiAccent, 0.16)
                            : Theme.shadow

                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.alpha(parent.vigColor, lockRoot.isLight ? 0.65 : 0.75) }
                            GradientStop { position: 0.22; color: "transparent" }
                            GradientStop { position: 0.78; color: "transparent" }
                            GradientStop { position: 1.0; color: Theme.alpha(parent.vigColor, lockRoot.isLight ? 0.75 : 0.85) }
                        }
                    }

                    // alignment snap crosshairs
                    Rectangle {
                        visible: lockRoot.freeDragMode && stageDragMouse.pressed && surface.snappedX
                        width: 1
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        x: parent.width / 2
                        color: Theme.alpha(lockRoot.uiAccent, 0.55)
                    }
                    Rectangle {
                        visible: lockRoot.freeDragMode && stageDragMouse.pressed && surface.snappedY
                        height: 1
                        anchors.left: parent.left
                        anchors.right: parent.right
                        y: parent.height / 2
                        color: Theme.alpha(lockRoot.uiAccent, 0.55)
                    }

                    // top-left user session, lock duration, and security status pill
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: 32
                        anchors.topMargin: (surface.entered && !lockRoot.zenMode) ? 32 : 12
                        opacity: (surface.entered && !lockRoot.zenMode) ? 1.0 : 0.0
                        visible: lockRoot.showUserPill && opacity > 0.01
                        height: 36
                        implicitWidth: userRow.implicitWidth + 24
                        radius: lockRoot.uiRadiusPill
                        color: lockRoot.uiPillBg
                        border.color: lockRoot.failedAttempts > 0 ? Theme.alpha(Theme.error, 0.65) : lockRoot.uiPillBorder
                        border.width: (lockRoot.failedAttempts > 0 || lockRoot.uiPillBorder.a > 0) ? 1 : 0

                        Behavior on anchors.topMargin { NumberAnimation { duration: Theme.expressiveDefault; easing.type: Theme.animEasingEntrance } }
                        Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
                        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                        RowLayout {
                            id: userRow
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                text: sessionLock.secure ? (Theme.iconDistro ?? Theme.iconUser) : Theme.iconShield
                                font.family: Theme.fontIcon
                                font.pixelSize: Theme.fontSizeMd
                                color: lockRoot.uiAccent
                            }

                            Text {
                                text: lockRoot.fmtText(lockRoot.currentUser)
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeSm
                                font.weight: Theme.fontWeightDemiBold
                                color: lockRoot.uiTextPrimary
                            }

                            Text {
                                text: "• " + lockRoot.lockedDurationText
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeXs
                                color: lockRoot.uiTextSecondary
                            }

                            Rectangle {
                                visible: lockRoot.failedAttempts > 0
                                height: 20
                                implicitWidth: failBadgeTxt.implicitWidth + 12
                                radius: lockRoot.uiRadiusPill
                                color: Theme.error_overlay
                                border.color: Theme.alpha(Theme.error, 0.55)
                                border.width: 1

                                Text {
                                    id: failBadgeTxt
                                    anchors.centerIn: parent
                                    text: lockRoot.fmtText(lockRoot.failedAttempts + (lockRoot.failedAttempts === 1 ? " failed try" : " failed tries"))
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: Theme.fontWeightBold
                                    color: Theme.error
                                }
                            }
                        }
                    }

                    // subtle corner hover zone so if the user hides statusBar, they can still open the studio!
                    MouseArea {
                        id: cornerRevealHover
                        anchors.top: parent.top
                        anchors.right: parent.right
                        width: 160
                        height: 80
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                        visible: !lockRoot.showStatusBar
                    }

                    // top-right hardware & studio bar
                    Rectangle {
                        id: statusBar
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 32
                        anchors.topMargin: (surface.entered && !lockRoot.zenMode) ? 32 : 12
                        opacity: (surface.entered && !lockRoot.zenMode && (lockRoot.showStatusBar || surface.optionsOpen || cornerRevealHover.containsMouse || barHoverDetect.containsMouse)) ? 1.0 : 0.0
                        visible: opacity > 0.01
                        height: 36
                        implicitWidth: statusRow.implicitWidth + 22
                        radius: lockRoot.uiRadiusPill
                        color: surface.optionsOpen ? lockRoot.uiWidgetActive : lockRoot.uiPillBg
                        border.color: surface.optionsOpen ? Theme.alpha(lockRoot.uiAccent, 0.55) : lockRoot.uiPillBorder
                        border.width: (surface.optionsOpen || lockRoot.uiPillBorder.a > 0) ? 1 : 0

                        Behavior on anchors.topMargin { NumberAnimation { duration: Theme.expressiveDefault; easing.type: Theme.animEasingEntrance } }
                        Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
                        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
                        Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                        MouseArea {
                            id: barHoverDetect
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                        }

                        RowLayout {
                            id: statusRow
                            anchors.centerIn: parent
                            spacing: 12

                            Rectangle {
                                visible: lockRoot.kbLayoutShort !== ""
                                height: 22
                                implicitWidth: kbRow.implicitWidth + 12
                                radius: lockRoot.uiRadiusPill
                                color: kbMouse.containsMouse ? lockRoot.uiWidgetHover : lockRoot.uiWidgetBg
                                border.color: lockRoot.uiWidgetBorder
                                border.width: 1

                                RowLayout {
                                    id: kbRow
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        text: Theme.iconKeyboard
                                        font.family: Theme.fontIcon
                                        font.pixelSize: Theme.fontSizeXs
                                        color: lockRoot.uiAccent
                                    }
                                    Text {
                                        text: lockRoot.fmtText(lockRoot.kbLayoutShort)
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightBold
                                        color: lockRoot.uiTextPrimary
                                    }
                                }

                                MouseArea {
                                    id: kbMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        lockRoot.switchKeyboardLayout();
                                        surface.claimSurfaceFocus();
                                    }
                                }
                            }

                            Item {
                                visible: lockRoot.showSystemVol && lockRoot.defaultSink !== null
                                implicitWidth: sysVolRow.implicitWidth
                                implicitHeight: sysVolRow.implicitHeight

                                readonly property real sinkVol: lockRoot.defaultSink?.audio?.volume ?? 0.0
                                readonly property bool sinkMuted: lockRoot.defaultSink?.audio?.muted ?? false

                                RowLayout {
                                    id: sysVolRow
                                    anchors.centerIn: parent
                                    spacing: 5

                                    Text {
                                        text: Theme.getVolumeIcon(parent.parent.sinkVol, parent.parent.sinkMuted)
                                        font.family: Theme.fontIcon
                                        font.pixelSize: Theme.fontSizeMd
                                        color: parent.parent.sinkMuted ? Theme.error : lockRoot.uiAccent
                                    }

                                    Text {
                                        text: lockRoot.fmtText(parent.parent.sinkMuted ? "mute" : (Math.round(parent.parent.sinkVol * 100) + "%"))
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightMedium
                                        color: lockRoot.uiTextPrimary
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        surface.toggleSystemMute();
                                        surface.claimSurfaceFocus();
                                    }
                                    onWheel: (wheel) => {
                                        surface.adjustSystemVolume(wheel.angleDelta.y > 0 ? 0.05 : -0.05);
                                    }
                                }
                            }

                            RowLayout {
                                spacing: 6
                                Text {
                                    text: Theme.getWifiIcon(
                                        (typeof NetworkService !== "undefined" ? NetworkService?.signalStrength : 100) ?? 100,
                                        (typeof NetworkService !== "undefined" ? NetworkService?.isConnected : false) ?? false,
                                        (typeof NetworkService !== "undefined" ? NetworkService?.isWiredConnected : false) ?? false
                                    )
                                    font.family: Theme.fontIcon
                                    font.pixelSize: Theme.fontSizeMd
                                    color: ((typeof NetworkService !== "undefined" && NetworkService?.isConnected) ?? false) ? lockRoot.uiAccent : lockRoot.uiTextSecondary
                                }
                                Text {
                                    text: lockRoot.fmtText(((typeof NetworkService !== "undefined" && NetworkService?.isWiredConnected) ?? false)
                                        ? "wired"
                                        : ((typeof NetworkService !== "undefined" ? NetworkService?.activeSsid : "") || (((typeof NetworkService !== "undefined" && NetworkService?.isConnected) ?? false) ? "online" : "offline"))
                                    )
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: Theme.fontWeightMedium
                                    color: lockRoot.uiTextPrimary
                                }
                            }

                            Item {
                                visible: UPower.displayDevice?.isPresent ?? false
                                implicitWidth: batStatusRow.implicitWidth
                                implicitHeight: batStatusRow.implicitHeight

                                readonly property int batPct: {
                                    let p = UPower.displayDevice?.percentage ?? 1.0;
                                    return Math.min(100, Math.max(0, Math.round(p * 100)));
                                }
                                readonly property bool isCharging: UPower.displayDevice?.state === UPowerDeviceState.Charging
                                readonly property string etaStr: lockRoot.formatBatteryEta()

                                RowLayout {
                                    id: batStatusRow
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        text: Theme.getBatteryIcon(parent.parent.batPct, parent.parent.isCharging, !(UPower?.onBattery ?? true), false)
                                        font.family: Theme.fontIcon
                                        font.pixelSize: Theme.fontSizeMd
                                        color: parent.parent.isCharging ? lockRoot.uiAccent : (parent.parent.batPct <= 20 ? Theme.error : lockRoot.uiTextPrimary)
                                    }
                                    Text {
                                        text: parent.parent.batPct + "%" + (batHover.containsMouse && parent.parent.etaStr !== "" ? (" (" + parent.parent.etaStr + ")") : "")
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightMedium
                                        color: lockRoot.uiTextPrimary
                                    }
                                }

                                MouseArea {
                                    id: batHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                }
                            }

                            IconButton {
                                icon: lockRoot.isLight ? Theme.iconSun : Theme.iconMoon
                                iconSize: Theme.fontSizeSm
                                tooltip: lockRoot.isLight ? "switch to dark mode" : "switch to light mode"
                                onClicked: {
                                    lockRoot.backdropMode = lockRoot.isLight ? "dark" : "light";
                                    lockRoot.saveSandbox();
                                    surface.claimSurfaceFocus();
                                }
                            }

                            IconButton {
                                icon: Theme.iconEyeOff
                                iconSize: Theme.fontSizeSm
                                tooltip: "zen screensaver mode (tab)"
                                onClicked: {
                                    surface.optionsOpen = false;
                                    lockRoot.zenMode = true;
                                    surface.claimSurfaceFocus();
                                }
                            }

                            IconButton {
                                icon: Theme.iconSparkles
                                iconSize: Theme.fontSizeSm
                                tooltip: lockRoot.studioLocked ? "studio is locked" : "surprise me! (randomize)"
                                enabled: !lockRoot.studioLocked
                                onClicked: {
                                    surpriseBurstAnim.restart();
                                    lockRoot.surpriseMe();
                                    surface.claimSurfaceFocus();
                                }
                            }

                            IconButton {
                                icon: Theme.iconSliders
                                iconSize: Theme.fontSizeSm
                                tooltip: "lock screen studio"
                                highlighted: surface.optionsOpen
                                onClicked: {
                                    surface.optionsOpen = !surface.optionsOpen;
                                    surface.claimSurfaceFocus();
                                }
                            }
                        }
                    }

                    // tabbed lock screen studio drawer
                    Rectangle {
                        id: optionsCard
                        anchors.top: statusBar.bottom
                        anchors.right: statusBar.right
                        anchors.topMargin: 10
                        width: 380
                        height: Math.min(parent.height - 110, optionsLayout.implicitHeight + (Theme.popupPadding * 2))
                        radius: lockRoot.uiRadiusLg
                        color: lockRoot.uiPopupBg
                        border.color: lockRoot.uiPopupBorder
                        border.width: Theme.popupBorderWidth
                        visible: opacity > 0.01 && !lockRoot.zenMode
                        opacity: surface.optionsOpen ? 1.0 : 0.0
                        scale: surface.optionsOpen ? 1.0 : 0.95
                        transformOrigin: Item.TopRight
                        clip: true
                        z: 100

                        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.animEasing } }
                        Behavior on scale { NumberAnimation { duration: Theme.expressiveFast; easing.type: Theme.animEasingEntrance } }
                        Behavior on height { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
                        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                        }

                        Flickable {
                            anchors.fill: parent
                            anchors.margins: Theme.popupPadding
                            contentHeight: optionsLayout.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            ColumnLayout {
                                id: optionsLayout
                                width: parent.width
                                spacing: Theme.popupSpacing

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: Theme.iconSliders
                                        font.family: Theme.fontIcon
                                        font.pixelSize: Theme.fontSizeMd
                                        color: lockRoot.uiAccent
                                    }

                                    Text {
                                        text: lockRoot.fmtText("lock screen studio")
                                        font.family: Theme.fontDisplay
                                        font.pixelSize: Theme.fontSizeMd
                                        font.weight: Theme.fontWeightBold
                                        color: lockRoot.uiTextPrimary
                                        Layout.fillWidth: true
                                    }

                                    IconButton {
                                        icon: lockRoot.studioLocked ? Theme.iconLock : Theme.iconShield
                                        iconSize: Theme.fontSizeXs
                                        highlighted: lockRoot.studioLocked
                                        tooltip: lockRoot.studioLocked ? "unlock studio controls" : "lock studio controls"
                                        onClicked: {
                                            lockRoot.studioLocked = !lockRoot.studioLocked;
                                            lockRoot.flushStateToDisk();
                                            surface.claimSurfaceFocus();
                                        }
                                    }

                                    IconButton {
                                        icon: Theme.iconRefresh
                                        iconSize: Theme.fontSizeXs
                                        enabled: !lockRoot.studioLocked
                                        tooltip: "reset defaults"
                                        onClicked: {
                                            lockRoot.resetDefaults();
                                            surface.claimSurfaceFocus();
                                        }
                                    }

                                    IconButton {
                                        icon: Theme.iconClose
                                        iconSize: Theme.fontSizeXs
                                        tooltip: "close"
                                        onClicked: {
                                            surface.optionsOpen = false;
                                            pwInput.forceActiveFocus();
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 36
                                    opacity: lockRoot.studioLocked ? 0.5 : 1.0
                                    radius: surpriseMouse.pressed ? lockRoot.uiRadiusPill : lockRoot.uiRadiusMd
                                    color: surpriseMouse.pressed
                                        ? Theme.statePress(lockRoot.uiAccent, lockRoot.uiOnAccent)
                                        : (surpriseMouse.containsMouse
                                            ? Theme.stateHover(lockRoot.uiAccent, lockRoot.uiOnAccent)
                                            : lockRoot.uiAccent)

                                    Behavior on radius { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
                                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 8

                                        Text {
                                            text: Theme.iconSparkles
                                            font.family: Theme.fontIcon
                                            font.pixelSize: Theme.fontSizeMd
                                            color: lockRoot.uiOnAccent
                                        }

                                        Text {
                                            text: lockRoot.fmtText("surprise me! (roll layout & vibe)")
                                            font.family: Theme.fontDisplay
                                            font.pixelSize: Theme.fontSizeXs
                                            font.weight: Theme.fontWeightBold
                                            color: lockRoot.uiOnAccent
                                        }
                                    }

                                    MouseArea {
                                        id: surpriseMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        enabled: !lockRoot.studioLocked
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                                        onClicked: {
                                            surpriseBurstAnim.restart();
                                            lockRoot.surpriseMe();
                                            surface.claimSurfaceFocus();
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 5

                                    Repeater {
                                        model: [
                                            { id: "layout",  label: "layout",  icon: Theme.iconGrid },
                                            { id: "clock",   label: "clock",   icon: Theme.iconClock },
                                            { id: "vibe",    label: "vibe",    icon: Theme.iconPalette },
                                            { id: "widgets", label: "widgets", icon: Theme.iconSettings }
                                        ]
                                        delegate: OptChip {
                                            required property var modelData
                                            label: modelData.label
                                            icon: modelData.icon
                                            selected: lockRoot.studioTab === modelData.id
                                            onClicked: lockRoot.studioTab = modelData.id
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: Theme.popupDividerHeight
                                    color: lockRoot.uiWidgetBorder
                                }

                                // tab 1: presets, position, stack order, stage width, corner shape
                                ColumnLayout {
                                    visible: lockRoot.studioTab === "layout"
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: lockRoot.fmtText("quick presets")
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightDemiBold
                                        color: lockRoot.uiTextSecondary
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Repeater {
                                            model: ["expressive", "cards", "editorial", "cyber", "minimal"]
                                            delegate: OptChip {
                                                required property string modelData
                                                label: modelData
                                                selected: false
                                                onClicked: {
                                                    surpriseBurstAnim.restart();
                                                    lockRoot.applyPreset(modelData);
                                                }
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text {
                                            text: lockRoot.fmtText("screen position")
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeXs
                                            font.weight: Theme.fontWeightDemiBold
                                            color: lockRoot.uiTextSecondary
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            visible: lockRoot.layoutPosition === "custom"
                                            text: Math.round(lockRoot.customNormX * 100) + "% , " + Math.round(lockRoot.customNormY * 100) + "%"
                                            font.family: Theme.fontMono
                                            font.pixelSize: Theme.fontSizeXs
                                            color: lockRoot.uiAccent
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 5

                                        Repeater {
                                            model: ["left", "top", "center", "bottom", "right"]
                                            delegate: OptChip {
                                                required property string modelData
                                                label: modelData
                                                selected: lockRoot.layoutPosition === modelData
                                                onClicked: {
                                                    lockRoot.layoutPosition = modelData;
                                                    lockRoot.saveSandbox();
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        text: lockRoot.fmtText("block stack order")
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightDemiBold
                                        color: lockRoot.uiTextSecondary
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Repeater {
                                            model: [
                                                { ord: "clock,media,password", lbl: "clk•med•pw" },
                                                { ord: "clock,password,media", lbl: "clk•pw•med" },
                                                { ord: "media,clock,password", lbl: "med•clk•pw" },
                                                { ord: "password,clock,media", lbl: "pw•clk•med" }
                                            ]
                                            delegate: OptChip {
                                                required property var modelData
                                                label: modelData.lbl
                                                selected: lockRoot.stackOrder === modelData.ord
                                                onClicked: {
                                                    lockRoot.stackOrder = modelData.ord;
                                                    lockRoot.saveSandbox();
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        text: lockRoot.fmtText("corner shape style")
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightDemiBold
                                        color: lockRoot.uiTextSecondary
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 5

                                        Repeater {
                                            model: ["theme", "pill", "squircle", "sharp"]
                                            delegate: OptChip {
                                                required property string modelData
                                                label: modelData
                                                selected: lockRoot.shapePreset === modelData
                                                onClicked: {
                                                    lockRoot.shapePreset = modelData;
                                                    lockRoot.saveSandbox();
                                                }
                                            }
                                        }
                                    }

                                    SandboxSlider {
                                        label: "stage width"
                                        icon: Theme.iconExpand
                                        from: 340
                                        to: 620
                                        stepSize: 8
                                        value: lockRoot.stageWidth
                                        displayText: Math.round(lockRoot.stageWidth) + "px"
                                        onMoved: (v) => {
                                            lockRoot.stageWidth = Math.round(v);
                                            lockRoot.saveSandbox();
                                        }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconGrid
                                        label: "free drag mode (snap guides + arrow keys)"
                                        checked: lockRoot.freeDragMode
                                        onToggled: lockRoot.freeDragMode = !lockRoot.freeDragMode
                                    }
                                }

                                // tab 2: clock design, date format, text casing, password mask
                                ColumnLayout {
                                    visible: lockRoot.studioTab === "clock"
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: lockRoot.fmtText("clock architecture")
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightDemiBold
                                        color: lockRoot.uiTextSecondary
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Repeater {
                                            model: ["inline", "stacked", "split", "typo"]
                                            delegate: OptChip {
                                                required property string modelData
                                                label: modelData
                                                selected: lockRoot.clockStyle === modelData
                                                onClicked: {
                                                    lockRoot.clockStyle = modelData;
                                                    lockRoot.saveSandbox();
                                                }
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Repeater {
                                            model: ["digital", "editorial", "minimal"]
                                            delegate: OptChip {
                                                required property string modelData
                                                label: modelData
                                                selected: lockRoot.clockStyle === modelData
                                                onClicked: {
                                                    lockRoot.clockStyle = modelData;
                                                    lockRoot.saveSandbox();
                                                }
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        OptChip {
                                            label: "12-hour"
                                            selected: !lockRoot.effectiveClock24h
                                            onClicked: {
                                                lockRoot.sandboxClock24h = false;
                                                lockRoot.saveSandbox();
                                            }
                                        }
                                        OptChip {
                                            label: "24-hour"
                                            selected: lockRoot.effectiveClock24h
                                            onClicked: {
                                                lockRoot.sandboxClock24h = true;
                                                lockRoot.saveSandbox();
                                            }
                                        }
                                        OptChip {
                                            label: "seconds"
                                            selected: lockRoot.effectiveShowSeconds
                                            onClicked: {
                                                lockRoot.showSeconds = !lockRoot.showSeconds;
                                                lockRoot.saveSandbox();
                                            }
                                        }
                                    }

                                    RowLayout {
                                        visible: lockRoot.effectiveShowSeconds
                                        Layout.fillWidth: true
                                        spacing: 5

                                        OptChip {
                                            label: "pill"
                                            selected: lockRoot.secondsStyle === "badge"
                                            onClicked: { lockRoot.secondsStyle = "badge"; lockRoot.saveSandbox(); }
                                        }
                                        OptChip {
                                            label: "split"
                                            selected: lockRoot.secondsStyle === "supersub"
                                            onClicked: { lockRoot.secondsStyle = "supersub"; lockRoot.saveSandbox(); }
                                        }
                                        OptChip {
                                            label: "bar"
                                            selected: lockRoot.secondsStyle === "tower"
                                            onClicked: { lockRoot.secondsStyle = "tower"; lockRoot.saveSandbox(); }
                                        }
                                        OptChip {
                                            label: "inline"
                                            selected: lockRoot.secondsStyle === "inline"
                                            onClicked: { lockRoot.secondsStyle = "inline"; lockRoot.saveSandbox(); }
                                        }
                                    }

                                    Text {
                                        text: lockRoot.fmtText("date format")
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightDemiBold
                                        color: lockRoot.uiTextSecondary
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Repeater {
                                            model: [
                                                { fmt: "dddd, MMMM d", lbl: "full" },
                                                { fmt: "ddd, MMM d",   lbl: "short" },
                                                { fmt: "yyyy-MM-dd",   lbl: "iso" },
                                                { fmt: "dd.MM.yyyy",   lbl: "eu" },
                                                { fmt: "MM/dd/yyyy",   lbl: "us" }
                                            ]
                                            delegate: OptChip {
                                                required property var modelData
                                                label: modelData.lbl
                                                selected: lockRoot.dateFormat === modelData.fmt
                                                onClicked: {
                                                    lockRoot.dateFormat = modelData.fmt;
                                                    lockRoot.saveSandbox();
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        text: lockRoot.fmtText("text casing (follow user preference)")
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightDemiBold
                                        color: lockRoot.uiTextSecondary
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 5

                                        Repeater {
                                            model: [
                                                { id: "lower",  lbl: "lowercase" },
                                                { id: "normal", lbl: "Normal" },
                                                { id: "upper",  lbl: "UPPER" }
                                            ]
                                            delegate: OptChip {
                                                required property var modelData
                                                label: modelData.lbl
                                                selected: lockRoot.textCase === modelData.id
                                                onClicked: {
                                                    lockRoot.textCase = modelData.id;
                                                    lockRoot.saveSandbox();
                                                }
                                            }
                                        }
                                    }

                                    SandboxSlider {
                                        label: "clock scale"
                                        icon: Theme.iconClock
                                        from: 0.70
                                        to: 1.50
                                        stepSize: 0.03
                                        value: lockRoot.clockScale
                                        displayText: Math.round(lockRoot.clockScale * 100) + "%"
                                        onMoved: (v) => {
                                            lockRoot.clockScale = v;
                                            lockRoot.saveSandbox();
                                        }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconCalendar
                                        label: "place date above clock"
                                        checked: lockRoot.dateAboveClock
                                        onToggled: {
                                            lockRoot.dateAboveClock = !lockRoot.dateAboveClock;
                                            lockRoot.saveSandbox();
                                        }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconClock
                                        label: "sync clock format across rice"
                                        checked: lockRoot.syncClockGlobal
                                        onToggled: {
                                            lockRoot.syncClockGlobal = !lockRoot.syncClockGlobal;
                                            lockRoot.saveSandbox();
                                        }
                                    }
                                }

                                // tab 3: theme mode, atmosphere, custom quote, password mask
                                ColumnLayout {
                                    visible: lockRoot.studioTab === "vibe"
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: lockRoot.fmtText("theme mode (" + (lockRoot.isLight ? "light" : "dark") + ")")
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightDemiBold
                                        color: lockRoot.uiTextSecondary
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 5

                                        OptChip {
                                            label: "auto"
                                            icon: Theme.iconSparkles
                                            selected: lockRoot.backdropMode === "auto"
                                            onClicked: { lockRoot.backdropMode = "auto"; lockRoot.saveSandbox(); }
                                        }
                                        OptChip {
                                            label: "dark"
                                            icon: Theme.iconMoon
                                            selected: lockRoot.backdropMode === "dark"
                                            onClicked: { lockRoot.backdropMode = "dark"; lockRoot.saveSandbox(); }
                                        }
                                        OptChip {
                                            label: "light"
                                            icon: Theme.iconSun
                                            selected: lockRoot.backdropMode === "light"
                                            onClicked: { lockRoot.backdropMode = "light"; lockRoot.saveSandbox(); }
                                        }
                                    }

                                    SandboxSlider {
                                        label: lockRoot.isLight ? "frost wash intensity" : "backdrop dim"
                                        icon: lockRoot.isLight ? Theme.iconSun : Theme.iconMoon
                                        from: 0.05
                                        to: 0.95
                                        stepSize: 0.02
                                        value: lockRoot.scrimDim
                                        displayText: Math.round(lockRoot.scrimDim * 100) + "%"
                                        onMoved: (v) => {
                                            lockRoot.scrimDim = v;
                                            lockRoot.saveSandbox();
                                        }
                                    }

                                    SandboxSlider {
                                        label: "card & pill opacity boost"
                                        icon: Theme.iconPalette
                                        from: -0.35
                                        to: 0.35
                                        stepSize: 0.05
                                        value: lockRoot.cardOpacityBoost
                                        displayText: (lockRoot.cardOpacityBoost >= 0 ? "+" : "") + Math.round(lockRoot.cardOpacityBoost * 100) + "%"
                                        onMoved: (v) => {
                                            lockRoot.cardOpacityBoost = v;
                                            lockRoot.saveSandbox();
                                        }
                                    }

                                    SandboxSlider {
                                        label: "cinematic vignette"
                                        icon: Theme.iconEye
                                        from: 0.0
                                        to: 0.85
                                        stepSize: 0.05
                                        value: lockRoot.vignetteStrength
                                        displayText: Math.round(lockRoot.vignetteStrength * 100) + "%"
                                        onMoved: (v) => {
                                            lockRoot.vignetteStrength = v;
                                            lockRoot.saveSandbox();
                                        }
                                    }

                                    SandboxSlider {
                                        label: "focus depth zoom"
                                        icon: Theme.iconExpand
                                        from: 1.00
                                        to: 1.18
                                        stepSize: 0.01
                                        value: lockRoot.focusZoom
                                        displayText: Math.round((lockRoot.focusZoom - 1.0) * 100) + "%"
                                        onMoved: (v) => {
                                            lockRoot.focusZoom = v;
                                            lockRoot.saveSandbox();
                                        }
                                    }

                                    Text {
                                        text: lockRoot.fmtText("password mask character")
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightDemiBold
                                        color: lockRoot.uiTextSecondary
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Repeater {
                                            model: [
                                                { ch: "•",    lbl: "dot •" },
                                                { ch: "*",    lbl: "star *" },
                                                { ch: "✦",    lbl: "spark ✦" },
                                                { ch: "▪",    lbl: "block ▪" },
                                                { ch: "none", lbl: "stealth" }
                                            ]
                                            delegate: OptChip {
                                                required property var modelData
                                                label: modelData.lbl
                                                selected: lockRoot.pwMaskChar === modelData.ch
                                                onClicked: {
                                                    lockRoot.pwMaskChar = modelData.ch;
                                                    lockRoot.saveSandbox();
                                                }
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text {
                                            text: lockRoot.fmtText("quote / greeting source")
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeXs
                                            font.weight: Theme.fontWeightDemiBold
                                            color: lockRoot.uiTextSecondary
                                            Layout.fillWidth: true
                                        }
                                        IconButton {
                                            icon: Theme.iconRefresh
                                            iconSize: Theme.fontSizeXs
                                            tooltip: "roll new quote"
                                            visible: lockRoot.quoteMode !== "off" && lockRoot.quoteMode !== "custom"
                                            onClicked: lockRoot.refreshQuotes()
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Repeater {
                                            model: ["smart", "hyprland", "unhinged", "custom", "off"]
                                            delegate: OptChip {
                                                required property string modelData
                                                label: modelData
                                                selected: lockRoot.quoteMode === modelData
                                                onClicked: {
                                                    lockRoot.quoteMode = modelData;
                                                    lockRoot.refreshQuotes();
                                                    lockRoot.saveSandbox();
                                                }
                                            }
                                        }
                                    }

                                    // custom quote input box when quoteMode === "custom"
                                    Rectangle {
                                        visible: lockRoot.quoteMode === "custom"
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 34
                                        radius: lockRoot.uiRadiusMd
                                        color: lockRoot.uiWidgetBg
                                        border.color: customQuoteInput.activeFocus ? lockRoot.uiAccent : lockRoot.uiWidgetBorder
                                        border.width: 1

                                        TextInput {
                                            id: customQuoteInput
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            verticalAlignment: TextInput.AlignVCenter
                                            text: lockRoot.customQuoteText
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeXs
                                            color: lockRoot.uiTextPrimary
                                            clip: true
                                            onTextEdited: {
                                                lockRoot.customQuoteText = text;
                                                lockRoot.saveSandbox();
                                            }
                                            onAccepted: pwInput.forceActiveFocus()
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: Theme.popupActionHeight + 2
                                        radius: lockRoot.uiRadiusMd
                                        opacity: lockRoot.studioLocked ? 0.5 : 1.0
                                        color: shuffleMouse.pressed
                                            ? lockRoot.uiWidgetActive
                                            : (shuffleMouse.containsMouse ? lockRoot.uiWidgetHover : lockRoot.uiWidgetBg)
                                        border.color: shuffleMouse.containsMouse ? Theme.alpha(lockRoot.uiAccent, 0.55) : lockRoot.uiWidgetBorder
                                        border.width: 1

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 12
                                            spacing: 8

                                            Text {
                                                text: Theme.iconShuffle
                                                font.family: Theme.fontIcon
                                                font.pixelSize: Theme.fontSizeMd
                                                color: lockRoot.uiAccent
                                            }
                                            Text {
                                                text: lockRoot.fmtText("shuffle lock wallpaper")
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeXs
                                                font.weight: Theme.fontWeightDemiBold
                                                color: lockRoot.uiTextPrimary
                                                Layout.fillWidth: true
                                            }
                                        }

                                        MouseArea {
                                            id: shuffleMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            enabled: !lockRoot.studioLocked
                                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                                            onClicked: {
                                                let nextWp = lockRoot.pickRandomWallpaperInMemory();
                                                if (nextWp && nextWp !== "") {
                                                    lockRoot.wallpaperSync = false;
                                                    lockRoot.localWallpaperOverride = nextWp;
                                                    lockRoot.saveSandbox();
                                                }
                                                surface.claimSurfaceFocus();
                                            }
                                        }
                                    }
                                }

                                // tab 4: modular widget visibility (nothing forced!)
                                ColumnLayout {
                                    visible: lockRoot.studioTab === "widgets"
                                    Layout.fillWidth: true
                                    spacing: 2

                                    SandboxToggleRow {
                                        icon: Theme.iconClock
                                        label: "show clock readout"
                                        checked: lockRoot.showClock
                                        onToggled: { lockRoot.showClock = !lockRoot.showClock; lockRoot.saveSandbox(); }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconCalendar
                                        label: "show date label"
                                        checked: lockRoot.showDate
                                        onToggled: { lockRoot.showDate = !lockRoot.showDate; lockRoot.saveSandbox(); }
                                    }

                                    SandboxToggleRow {
                                        icon: lockRoot.showMediaCard ? Theme.iconMusic : Theme.iconEyeOff
                                        label: "show now playing media card"
                                        checked: lockRoot.showMediaCard
                                        onToggled: { lockRoot.showMediaCard = !lockRoot.showMediaCard; lockRoot.saveSandbox(); }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconEqualizer
                                        label: "media spectrum & seekbar"
                                        checked: lockRoot.showMediaVisualizer
                                        onToggled: { lockRoot.showMediaVisualizer = !lockRoot.showMediaVisualizer; lockRoot.saveSandbox(); }
                                    }

                                    SandboxToggleRow {
                                        icon: lockRoot.showUserPill ? Theme.iconUser : Theme.iconEyeOff
                                        label: "show top-left user & timer pill"
                                        checked: lockRoot.showUserPill
                                        onToggled: { lockRoot.showUserPill = !lockRoot.showUserPill; lockRoot.saveSandbox(); }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconSliders
                                        label: "show top-right status bar (hover corner if off)"
                                        checked: lockRoot.showStatusBar
                                        onToggled: { lockRoot.showStatusBar = !lockRoot.showStatusBar; lockRoot.saveSandbox(); }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconVolHigh
                                        label: "show system volume in top bar"
                                        checked: lockRoot.showSystemVol
                                        onToggled: { lockRoot.showSystemVol = !lockRoot.showSystemVol; lockRoot.saveSandbox(); }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconPower
                                        label: "show bottom power dock"
                                        checked: lockRoot.showPowerDock
                                        onToggled: { lockRoot.showPowerDock = !lockRoot.showPowerDock; lockRoot.saveSandbox(); }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconShield
                                        label: "2-step confirmation on power buttons"
                                        checked: lockRoot.confirmPowerActions
                                        onToggled: { lockRoot.confirmPowerActions = !lockRoot.confirmPowerActions; lockRoot.saveSandbox(); }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconLogout
                                        label: "include logout button in power dock"
                                        checked: lockRoot.allowLogoutOnLock
                                        onToggled: { lockRoot.allowLogoutOnLock = !lockRoot.allowLogoutOnLock; lockRoot.saveSandbox(); }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconSparkles
                                        label: "ambient audio-reactive glow orbs"
                                        checked: lockRoot.ambientOrbs
                                        onToggled: { lockRoot.ambientOrbs = !lockRoot.ambientOrbs; lockRoot.saveSandbox(); }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconMusic
                                        label: "album art backdrop when playing"
                                        checked: lockRoot.albumArtBackdrop
                                        onToggled: { lockRoot.albumArtBackdrop = !lockRoot.albumArtBackdrop; lockRoot.saveSandbox(); }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconWallpaper
                                        label: "sync wallpaper with desktop"
                                        checked: lockRoot.wallpaperSync
                                        onToggled: {
                                            lockRoot.wallpaperSync = !lockRoot.wallpaperSync;
                                            if (lockRoot.wallpaperSync) lockRoot.localWallpaperOverride = "";
                                            lockRoot.saveSandbox();
                                        }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconCrop
                                        label: "show concave screen corners"
                                        checked: lockRoot.showScreenCorners
                                        onToggled: { lockRoot.showScreenCorners = !lockRoot.showScreenCorners; lockRoot.saveSandbox(); }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconMoon
                                        label: "auto-zen screensaver after 30s idle"
                                        checked: lockRoot.autoZenIdle
                                        onToggled: { lockRoot.autoZenIdle = !lockRoot.autoZenIdle; lockRoot.saveSandbox(); }
                                    }
                                }
                            }
                        }
                    }

                    // main movable & reorderable stage
                    Item {
                        id: centerStage
                        width: lockRoot.stageWidth
                        height: totalStageHeight

                        readonly property var orderList: (lockRoot.stackOrder || "clock,media,password").split(",")
                        readonly property int blockGap: 20

                        function blockHeight(name: string): real {
                            if (name === "clock") return clockBlock.visible ? clockBlock.implicitHeight : 0;
                            if (name === "media") return mediaBlock.visible ? mediaBlock.implicitHeight : 0;
                            if (name === "password") return lockRoot.zenMode ? 0 : passwordBlock.implicitHeight;
                            return 0;
                        }

                        function blockY(name: string): real {
                            let yPos = dragHandlePill.visible ? (dragHandlePill.height + 12) : 0;
                            for (let i = 0; i < orderList.length; i++) {
                                let cur = orderList[i];
                                if (cur === name) break;
                                let h = blockHeight(cur);
                                if (h > 0) yPos += h + blockGap;
                            }
                            return yPos;
                        }

                        readonly property real totalStageHeight: {
                            let total = dragHandlePill.visible ? (dragHandlePill.height + 12) : 0;
                            let count = 0;
                            for (let i = 0; i < orderList.length; i++) {
                                let h = blockHeight(orderList[i]);
                                if (h > 0) {
                                    total += h;
                                    count++;
                                }
                            }
                            if (count > 1) total += (count - 1) * blockGap;
                            return total;
                        }

                        x: {
                            let availW = Math.max(1, screenCanvas.width - width);
                            if (lockRoot.layoutPosition === "left") return 64;
                            if (lockRoot.layoutPosition === "right") return Math.max(64, screenCanvas.width - width - 64);
                            if (lockRoot.layoutPosition === "custom") {
                                return Math.max(24, Math.min(screenCanvas.width - width - 24, lockRoot.customNormX * availW));
                            }
                            return availW / 2;
                        }

                        y: {
                            let availH = Math.max(1, screenCanvas.height - height);
                            if (lockRoot.layoutPosition === "top") return 88;
                            if (lockRoot.layoutPosition === "bottom") return Math.max(88, screenCanvas.height - height - 100);
                            if (lockRoot.layoutPosition === "custom") {
                                return Math.max(64, Math.min(screenCanvas.height - height - 88, lockRoot.customNormY * availH));
                            }
                            return availH / 2;
                        }

                        Behavior on width { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
                        Behavior on x {
                            enabled: !stageDragMouse.pressed
                            NumberAnimation { duration: Theme.expressiveDefault; easing.type: Theme.animEasingEntrance }
                        }
                        Behavior on y {
                            enabled: !stageDragMouse.pressed
                            NumberAnimation { duration: Theme.expressiveDefault; easing.type: Theme.animEasingEntrance }
                        }

                        scale: (surface.entered ? 1.0 : 0.94) * surface.stageBurstScale
                        opacity: surface.entered ? 1.0 : 0.0

                        Behavior on scale { NumberAnimation { duration: Theme.expressiveDefault; easing.type: Theme.animEasingEntrance } }
                        Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }

                        SequentialAnimation {
                            id: surpriseBurstAnim
                            NumberAnimation { target: surface; property: "stageBurstScale"; from: 1.0; to: 0.95; duration: 85; easing.type: Easing.OutQuad }
                            NumberAnimation { target: surface; property: "stageBurstScale"; from: 0.95; to: 1.0; duration: 250; easing.type: Easing.OutBack }
                        }

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -14
                            radius: lockRoot.uiRadiusXl
                            color: stageDragMouse.pressed ? Theme.alpha(lockRoot.uiAccent, 0.08) : "transparent"
                            border.color: lockRoot.freeDragMode ? Theme.alpha(lockRoot.uiAccent, 0.55) : "transparent"
                            border.width: lockRoot.freeDragMode ? 1 : 0
                            visible: lockRoot.freeDragMode && !lockRoot.zenMode
                        }

                        // drag handle pill with center-snap logic
                        Rectangle {
                            id: dragHandlePill
                            visible: lockRoot.freeDragMode && !lockRoot.zenMode
                            anchors.top: parent.top
                            anchors.horizontalCenter: parent.horizontalCenter
                            height: 28
                            implicitWidth: dragHandleRow.implicitWidth + 20
                            radius: lockRoot.uiRadiusPill
                            color: stageDragMouse.pressed ? lockRoot.uiAccent : lockRoot.uiPillBg
                            border.color: lockRoot.uiAccent
                            border.width: 1

                            RowLayout {
                                id: dragHandleRow
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: Theme.iconGrid
                                    font.family: Theme.fontIcon
                                    font.pixelSize: Theme.fontSizeXs
                                    color: stageDragMouse.pressed ? lockRoot.uiOnAccent : lockRoot.uiAccent
                                }

                                Text {
                                    text: lockRoot.fmtText("drag stage (snaps to 50%) • double-click to center")
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: Theme.fontWeightBold
                                    color: stageDragMouse.pressed ? lockRoot.uiOnAccent : lockRoot.uiTextPrimary
                                }
                            }

                            MouseArea {
                                id: stageDragMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                property point pressOffset: Qt.point(0, 0)

                                onPressed: (mouse) => {
                                    let globalPt = mapToItem(screenCanvas, mouse.x, mouse.y);
                                    pressOffset = Qt.point(globalPt.x - centerStage.x, globalPt.y - centerStage.y);
                                }
                                onPositionChanged: (mouse) => {
                                    if (!pressed) return;
                                    let globalPt = mapToItem(screenCanvas, mouse.x, mouse.y);
                                    let availW = Math.max(1, screenCanvas.width - centerStage.width);
                                    let availH = Math.max(1, screenCanvas.height - centerStage.height);
                                    let newX = Math.max(24, Math.min(screenCanvas.width - centerStage.width - 24, globalPt.x - pressOffset.x));
                                    let newY = Math.max(64, Math.min(screenCanvas.height - centerStage.height - 88, globalPt.y - pressOffset.y));

                                    let nx = newX / availW;
                                    let ny = newY / availH;

                                    if (Math.abs(nx - 0.5) < 0.025) { nx = 0.5; surface.snappedX = true; }
                                    else { surface.snappedX = false; }

                                    if (Math.abs(ny - 0.5) < 0.025) { ny = 0.5; surface.snappedY = true; }
                                    else { surface.snappedY = false; }

                                    lockRoot.customNormX = nx;
                                    lockRoot.customNormY = ny;
                                    lockRoot.layoutPosition = "custom";
                                    lockRoot.saveSandbox();
                                }
                                onReleased: {
                                    surface.snappedX = false;
                                    surface.snappedY = false;
                                    surface.claimSurfaceFocus();
                                }
                                onDoubleClicked: {
                                    lockRoot.layoutPosition = "center";
                                    lockRoot.customNormX = 0.5;
                                    lockRoot.customNormY = 0.5;
                                    lockRoot.saveSandbox();
                                }
                            }
                        }

                        // clock, date & quote block
                        ColumnLayout {
                            id: clockBlock
                            visible: lockRoot.showClock || lockRoot.showDate || lockRoot.activeQuoteText !== ""
                            width: parent.width
                            y: centerStage.blockY("clock")
                            spacing: 6

                            Behavior on y { NumberAnimation { duration: Theme.expressiveDefault; easing.type: Theme.animEasingEntrance } }

                            readonly property int baseClockPx: Math.round((lockRoot.clockStyle === "minimal" ? 56 : 86) * Theme.fontScale * lockRoot.clockScale)
                            readonly property int rawHours: lockRoot.currentTime.getHours()
                            readonly property int displayHourNum: lockRoot.effectiveClock24h ? rawHours : ((rawHours % 12) || 12)
                            readonly property int displayMinNum: lockRoot.currentTime.getMinutes()
                            readonly property int displaySecNum: lockRoot.currentTime.getSeconds()

                            readonly property string mainHoursText: (displayHourNum < 10 ? "0" : "") + displayHourNum
                            readonly property string mainMinutesText: (displayMinNum < 10 ? "0" : "") + displayMinNum
                            readonly property string secondsDigits: (displaySecNum < 10 ? "0" : "") + displaySecNum
                            readonly property string amPmText: lockRoot.fmtText(rawHours >= 12 ? "PM" : "AM")
                            readonly property string formattedDateText: lockRoot.fmtText(Qt.formatDateTime(lockRoot.currentTime, lockRoot.dateFormat))

                            Text {
                                visible: lockRoot.showDate && lockRoot.dateAboveClock && lockRoot.clockStyle !== "editorial"
                                text: clockBlock.formattedDateText
                                font.family: Theme.fontDisplay
                                font.pixelSize: Theme.fontSizeMd
                                font.weight: Theme.fontWeightDemiBold
                                color: lockRoot.uiAccent
                                Layout.alignment: Qt.AlignHCenter
                            }

                            // style 1 & 2: inline or minimal clock
                            RowLayout {
                                visible: lockRoot.showClock && (lockRoot.clockStyle === "inline" || lockRoot.clockStyle === "minimal")
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 10

                                Text {
                                    text: {
                                        let hm = clockBlock.mainHoursText + ":" + clockBlock.mainMinutesText;
                                        if (lockRoot.effectiveShowSeconds && lockRoot.secondsStyle === "inline") {
                                            return hm + ":" + clockBlock.secondsDigits + (!lockRoot.effectiveClock24h ? (" " + clockBlock.amPmText) : "");
                                        }
                                        if (!lockRoot.effectiveShowSeconds && !lockRoot.effectiveClock24h) {
                                            return hm + " " + clockBlock.amPmText;
                                        }
                                        return hm;
                                    }
                                    font.family: Theme.fontDisplay
                                    font.pixelSize: (lockRoot.effectiveShowSeconds && lockRoot.secondsStyle === "inline")
                                        ? Math.round(clockBlock.baseClockPx * 0.76)
                                        : clockBlock.baseClockPx
                                    font.weight: lockRoot.clockStyle === "minimal" ? Theme.fontWeightDemiBold : Theme.fontWeightBold
                                    color: lockRoot.uiTextPrimary
                                    Layout.alignment: Qt.AlignVCenter

                                    Behavior on font.pixelSize { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
                                }

                                ColumnLayout {
                                    visible: lockRoot.effectiveShowSeconds && lockRoot.secondsStyle === "badge"
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 4

                                    Rectangle {
                                        readonly property int badgeFontPx: Math.max(18, Math.round(clockBlock.baseClockPx * 0.38))
                                        height: badgeFontPx + 14
                                        implicitWidth: secBadgeTxt.implicitWidth + 20
                                        radius: lockRoot.uiRadiusMd
                                        color: lockRoot.uiAccentOverlay
                                        border.color: Theme.alpha(lockRoot.uiAccent, 0.55)
                                        border.width: 1

                                        Text {
                                            id: secBadgeTxt
                                            anchors.centerIn: parent
                                            text: clockBlock.secondsDigits
                                            font.family: Theme.fontMono
                                            font.pixelSize: parent.badgeFontPx
                                            font.weight: Theme.fontWeightBold
                                            color: lockRoot.uiAccent
                                        }
                                    }

                                    Text {
                                        visible: !lockRoot.effectiveClock24h
                                        text: clockBlock.amPmText
                                        font.family: Theme.fontMono
                                        font.pixelSize: Math.max(11, Math.round(clockBlock.baseClockPx * 0.18))
                                        font.weight: Theme.fontWeightBold
                                        color: lockRoot.uiTextSecondary
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                }

                                ColumnLayout {
                                    visible: lockRoot.effectiveShowSeconds && lockRoot.secondsStyle === "supersub"
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: -2

                                    Text {
                                        text: ":" + clockBlock.secondsDigits
                                        font.family: Theme.fontDisplay
                                        font.pixelSize: Math.max(20, Math.round(clockBlock.baseClockPx * 0.44))
                                        font.weight: Theme.fontWeightBold
                                        color: lockRoot.uiAccent
                                    }

                                    Text {
                                        visible: !lockRoot.effectiveClock24h
                                        text: clockBlock.amPmText
                                        font.family: Theme.fontMono
                                        font.pixelSize: Math.max(12, Math.round(clockBlock.baseClockPx * 0.22))
                                        font.weight: Theme.fontWeightBold
                                        color: lockRoot.uiTextSecondary
                                    }
                                }
                            }

                            // style 3: stacked m3 expressive clock
                            RowLayout {
                                visible: lockRoot.showClock && lockRoot.clockStyle === "stacked"
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 14

                                ColumnLayout {
                                    spacing: -20

                                    Text {
                                        text: clockBlock.mainHoursText
                                        font.family: Theme.fontDisplay
                                        font.pixelSize: Math.round(92 * Theme.fontScale * lockRoot.clockScale)
                                        font.weight: Theme.fontWeightBold
                                        color: lockRoot.uiTextPrimary
                                        Layout.alignment: Qt.AlignHCenter
                                    }

                                    Text {
                                        text: clockBlock.mainMinutesText
                                        font.family: Theme.fontDisplay
                                        font.pixelSize: Math.round(92 * Theme.fontScale * lockRoot.clockScale)
                                        font.weight: Theme.fontWeightBold
                                        color: lockRoot.uiAccent
                                        Layout.alignment: Qt.AlignHCenter
                                    }

                                    Text {
                                        visible: lockRoot.effectiveShowSeconds && lockRoot.secondsStyle === "tower"
                                        text: clockBlock.secondsDigits
                                        font.family: Theme.fontDisplay
                                        font.pixelSize: Math.round(92 * Theme.fontScale * lockRoot.clockScale)
                                        font.weight: Theme.fontWeightBold
                                        color: Theme.tertiary
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                }

                                ColumnLayout {
                                    visible: (lockRoot.effectiveShowSeconds && lockRoot.secondsStyle !== "tower") || !lockRoot.effectiveClock24h
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 8

                                    Rectangle {
                                        visible: !lockRoot.effectiveClock24h
                                        readonly property int amPx: Math.max(14, Math.round(22 * Theme.fontScale * lockRoot.clockScale))
                                        height: amPx + 14
                                        implicitWidth: stackAmTxt.implicitWidth + 18
                                        radius: lockRoot.uiRadiusMd
                                        color: lockRoot.uiPillBg
                                        border.color: lockRoot.uiPillBorder
                                        border.width: 1

                                        Text {
                                            id: stackAmTxt
                                            anchors.centerIn: parent
                                            text: clockBlock.amPmText
                                            font.family: Theme.fontMono
                                            font.pixelSize: parent.amPx
                                            font.weight: Theme.fontWeightBold
                                            color: lockRoot.uiTextSecondary
                                        }
                                    }

                                    Rectangle {
                                        visible: lockRoot.effectiveShowSeconds && lockRoot.secondsStyle !== "tower"
                                        readonly property int secPx: Math.max(22, Math.round(38 * Theme.fontScale * lockRoot.clockScale))
                                        height: secPx + 18
                                        implicitWidth: stackSecTxt.implicitWidth + 22
                                        radius: lockRoot.uiRadiusLg
                                        color: lockRoot.uiAccentOverlay
                                        border.color: Theme.alpha(lockRoot.uiAccent, 0.55)
                                        border.width: 1

                                        Text {
                                            id: stackSecTxt
                                            anchors.centerIn: parent
                                            text: ":" + clockBlock.secondsDigits
                                            font.family: Theme.fontMono
                                            font.pixelSize: parent.secPx
                                            font.weight: Theme.fontWeightBold
                                            color: lockRoot.uiAccent
                                        }
                                    }
                                }
                            }

                            // style 4: "split" twin squircle flip-cards
                            RowLayout {
                                visible: lockRoot.showClock && lockRoot.clockStyle === "split"
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 10

                                readonly property int cardSize: Math.round(108 * Theme.fontScale * lockRoot.clockScale)
                                readonly property int digitPx: Math.round(62 * Theme.fontScale * lockRoot.clockScale)

                                Rectangle {
                                    width: parent.cardSize
                                    height: parent.cardSize
                                    radius: lockRoot.uiRadiusXl
                                    color: lockRoot.uiCardBg
                                    border.color: Theme.alpha(lockRoot.uiAccent, 0.35)
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: clockBlock.mainHoursText
                                        font.family: Theme.fontDisplay
                                        font.pixelSize: parent.parent.digitPx
                                        font.weight: Theme.fontWeightBold
                                        color: lockRoot.uiTextPrimary
                                    }

                                    Text {
                                        visible: !lockRoot.effectiveClock24h
                                        anchors.bottom: parent.bottom
                                        anchors.right: parent.right
                                        anchors.margins: 8
                                        text: clockBlock.amPmText
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightBold
                                        color: lockRoot.uiAccent
                                    }
                                }

                                ColumnLayout {
                                    spacing: 10
                                    Layout.alignment: Qt.AlignVCenter
                                    Rectangle {
                                        width: 8; height: 8; radius: 4
                                        color: lockRoot.uiAccent
                                        opacity: (clockBlock.displaySecNum % 2 === 0) ? 1.0 : 0.35
                                        Behavior on opacity { NumberAnimation { duration: 250 } }
                                    }
                                    Rectangle {
                                        width: 8; height: 8; radius: 4
                                        color: lockRoot.uiAccent
                                        opacity: (clockBlock.displaySecNum % 2 === 0) ? 1.0 : 0.35
                                        Behavior on opacity { NumberAnimation { duration: 250 } }
                                    }
                                }

                                Rectangle {
                                    width: parent.cardSize
                                    height: parent.cardSize
                                    radius: lockRoot.uiRadiusXl
                                    color: Theme.blend(lockRoot.uiCardBg, lockRoot.uiAccent, 0.14)
                                    border.color: Theme.alpha(lockRoot.uiAccent, 0.55)
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: clockBlock.mainMinutesText
                                        font.family: Theme.fontDisplay
                                        font.pixelSize: parent.parent.digitPx
                                        font.weight: Theme.fontWeightBold
                                        color: lockRoot.uiAccent
                                    }

                                    Text {
                                        visible: lockRoot.effectiveShowSeconds
                                        anchors.bottom: parent.bottom
                                        anchors.right: parent.right
                                        anchors.margins: 8
                                        text: ":" + clockBlock.secondsDigits
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightBold
                                        color: lockRoot.uiTextSecondary
                                    }
                                }
                            }

                            // style 5: "typo" word clock
                            ColumnLayout {
                                visible: lockRoot.showClock && lockRoot.clockStyle === "typo"
                                Layout.alignment: Qt.AlignHCenter
                                spacing: -6

                                Text {
                                    text: lockRoot.numberToWords(clockBlock.displayHourNum)
                                    font.family: Theme.fontDisplay
                                    font.pixelSize: Math.round(56 * Theme.fontScale * lockRoot.clockScale)
                                    font.weight: Theme.fontWeightBold
                                    color: lockRoot.uiTextPrimary
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                Text {
                                    text: clockBlock.displayMinNum === 0
                                        ? lockRoot.fmtText("o'clock")
                                        : (clockBlock.displayMinNum < 10
                                            ? (lockRoot.fmtText("oh ") + lockRoot.numberToWords(clockBlock.displayMinNum))
                                            : lockRoot.numberToWords(clockBlock.displayMinNum))
                                    font.family: Theme.fontDisplay
                                    font.pixelSize: Math.round(48 * Theme.fontScale * lockRoot.clockScale)
                                    font.italic: true
                                    font.weight: Theme.fontWeightDemiBold
                                    color: lockRoot.uiAccent
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }

                            // style 6: "digital" terminal monospace readout
                            Rectangle {
                                visible: lockRoot.showClock && lockRoot.clockStyle === "digital"
                                Layout.alignment: Qt.AlignHCenter
                                implicitWidth: digRow.implicitWidth + 36
                                implicitHeight: digRow.implicitHeight + 24
                                radius: lockRoot.uiRadiusLg
                                color: lockRoot.uiCardBg
                                border.color: Theme.alpha(lockRoot.uiAccent, 0.55)
                                border.width: 1

                                RowLayout {
                                    id: digRow
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        text: clockBlock.mainHoursText + ":" + clockBlock.mainMinutesText + (lockRoot.effectiveShowSeconds ? (":" + clockBlock.secondsDigits) : "")
                                        font.family: Theme.fontMono
                                        font.pixelSize: Math.round(54 * Theme.fontScale * lockRoot.clockScale)
                                        font.weight: Theme.fontWeightBold
                                        color: lockRoot.uiAccent
                                    }

                                    Text {
                                        visible: !lockRoot.effectiveClock24h
                                        text: clockBlock.amPmText
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeSm
                                        font.weight: Theme.fontWeightBold
                                        color: lockRoot.uiTextSecondary
                                        Layout.alignment: Qt.AlignBottom
                                        Layout.bottomMargin: 8
                                    }
                                }
                            }

                            // style 7: "editorial" magazine weekday banner + time pill
                            ColumnLayout {
                                visible: lockRoot.showClock && lockRoot.clockStyle === "editorial"
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 6

                                Text {
                                    text: lockRoot.fmtText(Qt.formatDateTime(lockRoot.currentTime, "dddd"))
                                    font.family: Theme.fontDisplay
                                    font.pixelSize: Math.round(58 * Theme.fontScale * lockRoot.clockScale)
                                    font.weight: Theme.fontWeightBold
                                    color: lockRoot.uiTextPrimary
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                RowLayout {
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: 8

                                    Rectangle {
                                        height: 34
                                        implicitWidth: edTimeTxt.implicitWidth + 24
                                        radius: lockRoot.uiRadiusPill
                                        color: lockRoot.uiAccent

                                        Text {
                                            id: edTimeTxt
                                            anchors.centerIn: parent
                                            text: clockBlock.mainHoursText + ":" + clockBlock.mainMinutesText
                                                + (lockRoot.effectiveShowSeconds ? (":" + clockBlock.secondsDigits) : "")
                                                + (!lockRoot.effectiveClock24h ? (" " + clockBlock.amPmText) : "")
                                            font.family: Theme.fontMono
                                            font.pixelSize: Theme.fontSizeMd
                                            font.weight: Theme.fontWeightBold
                                            color: lockRoot.uiOnAccent
                                        }
                                    }

                                    Rectangle {
                                        visible: lockRoot.showDate
                                        height: 34
                                        implicitWidth: edDateTxt.implicitWidth + 24
                                        radius: lockRoot.uiRadiusPill
                                        color: lockRoot.uiPillBg
                                        border.color: lockRoot.uiPillBorder
                                        border.width: 1

                                        Text {
                                            id: edDateTxt
                                            anchors.centerIn: parent
                                            text: lockRoot.fmtText(Qt.formatDateTime(lockRoot.currentTime, "MMMM d, yyyy"))
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeSm
                                            font.weight: Theme.fontWeightDemiBold
                                            color: lockRoot.uiTextPrimary
                                        }
                                    }
                                }
                            }

                            // 60-second animated bar when secondsStyle === "tower"
                            RowLayout {
                                visible: lockRoot.showClock && lockRoot.clockStyle !== "stacked" && lockRoot.clockStyle !== "editorial" && lockRoot.effectiveShowSeconds && (lockRoot.secondsStyle === "tower" || lockRoot.clockStyle === "typo")
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 10

                                Rectangle {
                                    width: 150
                                    height: 8
                                    radius: lockRoot.uiRadiusPill
                                    color: lockRoot.uiPillBg
                                    border.color: lockRoot.uiPillBorder
                                    border.width: 1

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: Math.max(parent.height, parent.width * ((clockBlock.displaySecNum + 1) / 60.0))
                                        radius: lockRoot.uiRadiusPill
                                        color: lockRoot.uiAccent

                                        Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                                    }
                                }

                                Text {
                                    text: clockBlock.secondsDigits + "s" + (!lockRoot.effectiveClock24h ? (" • " + clockBlock.amPmText) : "")
                                    font.family: Theme.fontMono
                                    font.pixelSize: Math.max(12, Math.round(Theme.fontSizeSm * lockRoot.clockScale))
                                    font.weight: Theme.fontWeightBold
                                    color: lockRoot.uiAccent
                                }
                            }

                            Text {
                                visible: lockRoot.showDate && !lockRoot.dateAboveClock && lockRoot.clockStyle !== "editorial"
                                text: clockBlock.formattedDateText
                                font.family: Theme.fontDisplay
                                font.pixelSize: Theme.fontSizeMd
                                font.weight: Theme.fontWeightDemiBold
                                color: lockRoot.uiAccent
                                Layout.alignment: Qt.AlignHCenter
                            }

                            // quote pill
                            Rectangle {
                                visible: lockRoot.activeQuoteText !== ""
                                Layout.alignment: Qt.AlignHCenter
                                Layout.topMargin: 4
                                Layout.maximumWidth: centerStage.width - 16
                                implicitWidth: Math.min(centerStage.width - 16, quoteTxt.implicitWidth + 24)
                                implicitHeight: quoteTxt.implicitHeight + 12
                                radius: lockRoot.uiRadiusPill
                                color: quoteMouse.containsMouse ? lockRoot.uiPillHover : "transparent"
                                border.color: quoteMouse.containsMouse ? lockRoot.uiPillBorder : "transparent"
                                border.width: 1

                                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                Text {
                                    id: quoteTxt
                                    anchors.centerIn: parent
                                    width: Math.min(centerStage.width - 40, implicitWidth)
                                    text: "\"" + lockRoot.activeQuoteText + "\""
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeXs
                                    font.italic: true
                                    color: quoteMouse.containsMouse ? lockRoot.uiTextPrimary : lockRoot.uiTextSecondary
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                }

                                MouseArea {
                                    id: quoteMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        lockRoot.refreshQuotes();
                                        surface.claimSurfaceFocus();
                                    }
                                }
                            }
                        }

                        // mpris media player card + visualizer
                        ClippingRectangle {
                            id: mediaBlock
                            width: parent.width
                            y: centerStage.blockY("media")
                            implicitHeight: mediaCardCol.implicitHeight + 24
                            height: implicitHeight
                            radius: lockRoot.uiRadiusLg
                            color: Theme.blend(lockRoot.uiCardBg, surface.artAccent, surface.playerIsPlaying ? 0.14 : 0.04)
                            border.color: surface.playerIsPlaying ? Theme.alpha(surface.artAccent, 0.45) : lockRoot.uiCardBorder
                            border.width: 1
                            visible: lockRoot.showMediaCard
                                && surface.activePlayer !== null
                                && ((surface.activePlayer?.trackTitle ?? "") !== "" || surface.playerIsPlaying)

                            Behavior on y { NumberAnimation { duration: Theme.expressiveDefault; easing.type: Theme.animEasingEntrance } }
                            Behavior on color { ColorAnimation { duration: Theme.animSlow; easing.type: Theme.animColorEasing } }
                            Behavior on border.color { ColorAnimation { duration: Theme.animSlow; easing.type: Theme.animColorEasing } }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.NoButton
                                onWheel: (wheel) => {
                                    if (surface.activePlayer && (surface.activePlayer.volumeSupported ?? true)) {
                                        let delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                                        let cur = (surface.activePlayer.volume !== undefined && !isNaN(surface.activePlayer.volume))
                                            ? surface.activePlayer.volume
                                            : 1.0;
                                        let next = Math.max(0.0, Math.min(1.0, cur + delta));
                                        surface.activePlayer.volume = next;
                                        surface.showVolumeToast("vol " + Math.round(next * 100) + "%");
                                    } else {
                                        surface.adjustSystemVolume(wheel.angleDelta.y > 0 ? 0.05 : -0.05);
                                    }
                                }
                            }

                            RowLayout {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                height: 42
                                spacing: 3
                                visible: lockRoot.showMediaVisualizer
                                opacity: surface.playerIsPlaying ? (lockRoot.isLight ? 0.28 : 0.22) : 0.06

                                Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }

                                Repeater {
                                    model: 24
                                    Rectangle {
                                        required property int index
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignBottom
                                        radius: 2

                                        readonly property real env: {
                                            let norm = index / 23.0;
                                            return Math.sin(norm * Math.PI) * 0.72 + 0.28;
                                        }

                                        readonly property real chPeak: {
                                            let pList = (lockPeakMonitor.peaks && lockPeakMonitor.peaks.length > 0) ? lockPeakMonitor.peaks : [];
                                            if (pList.length >= 2) {
                                                let mix = index / 23.0;
                                                return (pList[0] * (1.0 - mix)) + (pList[1] * mix);
                                            }
                                            return lockPeakMonitor.peak ?? 0;
                                        }

                                        height: {
                                            if (!surface.playerIsPlaying) return 3;
                                            let p = chPeak;
                                            let ripple = Math.sin((index * 0.65) + lockRoot.wavePhase) * 0.3 + Math.cos((index * 1.2) - lockRoot.wavePhase * 0.7) * 0.2;
                                            if (p > 0.008) {
                                                let target = (p * env * 36) + (Math.abs(ripple) * 12 * Math.min(1.0, p * 3.5));
                                                return Math.max(3, Math.min(40, Math.round(target)));
                                            }
                                            return Math.max(3, Math.round(3 + Math.abs(ripple) * 5));
                                        }

                                        color: chPeak > 0.55 ? Theme.tertiary : surface.artAccent

                                        Behavior on height {
                                            NumberAnimation { duration: 75; easing.type: Theme.animColorEasing }
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                id: mediaCardCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.margins: 12
                                spacing: 10

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 12

                                    ClippingRectangle {
                                        Layout.preferredWidth: 56
                                        Layout.preferredHeight: 56
                                        radius: lockRoot.uiRadiusMd
                                        color: lockRoot.uiWidgetBg
                                        border.color: lockRoot.uiCardBorder
                                        border.width: 1

                                        Image {
                                            anchors.fill: parent
                                            source: surface.coverArtUrl
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            visible: status === Image.Ready && source != ""
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: Theme.iconSet === "kaomoji" ? Theme.kaoMusic : Theme.iconMusic
                                            font.family: Theme.fontIcon
                                            font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeSm : Theme.fontSizeLg
                                            color: surface.artAccent
                                            visible: surface.coverArtUrl === ""
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: 2

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 6

                                            Text {
                                                text: lockRoot.fmtText(surface.activePlayer?.trackTitle || "Unknown Track")
                                                font.family: Theme.fontDisplay
                                                font.pixelSize: Theme.fontSizeSm
                                                font.weight: Theme.fontWeightBold
                                                color: lockRoot.uiTextPrimary
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }

                                            Rectangle {
                                                visible: surface.volumeHudVisible || surface.playerList.length > 1
                                                height: 20
                                                implicitWidth: mediaBadgeTxt.implicitWidth + 12
                                                radius: lockRoot.uiRadiusPill
                                                color: surface.volumeHudVisible ? lockRoot.uiAccentOverlay : lockRoot.uiPillBg
                                                border.color: Theme.alpha(surface.artAccent, 0.45)
                                                border.width: 1

                                                Text {
                                                    id: mediaBadgeTxt
                                                    anchors.centerIn: parent
                                                    text: surface.volumeHudVisible
                                                        ? surface.volumeHudLabel
                                                        : lockRoot.fmtText((surface.activePlayer?.identity || "player") + " " + (surface.currentPlayerIdx + 1) + "/" + surface.playerList.length)
                                                    font.family: Theme.fontMono
                                                    font.pixelSize: Theme.fontSizeXs
                                                    font.weight: Theme.fontWeightBold
                                                    color: surface.artAccent
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    enabled: surface.playerList.length > 1
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        lockRoot.manualPlayerIndex = (surface.currentPlayerIdx + 1) % surface.playerList.length;
                                                        surface.claimSurfaceFocus();
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            text: lockRoot.fmtText(surface.activePlayer?.trackArtist || "Unknown Artist")
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeXs
                                            font.weight: Theme.fontWeightDemiBold
                                            color: surface.artAccent
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                            Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.animColorEasing } }
                                        }
                                    }

                                    IconButton {
                                        icon: Theme.iconPrev
                                        iconSize: Theme.fontSizeSm
                                        tooltip: "previous"
                                        enabled: surface.activePlayer?.canGoPrevious ?? false
                                        onClicked: {
                                            surface.activePlayer?.previous();
                                            surface.claimSurfaceFocus();
                                        }
                                    }

                                    Rectangle {
                                        width: surface.playerIsPlaying ? 44 : 36
                                        height: 36
                                        radius: surface.playerIsPlaying ? lockRoot.uiRadiusMd : lockRoot.uiRadiusPill
                                        color: lockPlayMouse.pressed
                                            ? Theme.statePress(surface.artAccent, lockRoot.uiOnAccent)
                                            : (lockPlayMouse.containsMouse
                                                ? Theme.stateHover(surface.artAccent, lockRoot.uiOnAccent)
                                                : surface.artAccent)

                                        Behavior on width { NumberAnimation { duration: Theme.expressiveFast; easing.type: Theme.animExpressiveEasing } }
                                        Behavior on radius { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.animEasing } }
                                        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: surface.playerIsPlaying ? Theme.iconPause : Theme.iconPlay
                                            font.family: Theme.fontIcon
                                            font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeXs : Theme.fontSizeMd
                                            font.weight: Theme.fontWeightBold
                                            color: lockRoot.uiOnAccent
                                        }

                                        MouseArea {
                                            id: lockPlayMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                surface.activePlayer?.togglePlaying();
                                                surface.claimSurfaceFocus();
                                            }
                                        }
                                    }

                                    IconButton {
                                        icon: Theme.iconNext
                                        iconSize: Theme.fontSizeSm
                                        tooltip: "next"
                                        enabled: surface.activePlayer?.canGoNext ?? false
                                        onClicked: {
                                            surface.activePlayer?.next();
                                            surface.claimSurfaceFocus();
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    visible: lockRoot.showMediaVisualizer && (surface.activePlayer?.length ?? 0) > 0

                                    Text {
                                        text: lockRoot.formatTime(surface.trackPosition)
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeXs
                                        color: lockRoot.uiTextSecondary
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 14

                                        readonly property real progRatio: {
                                            let len = surface.activePlayer?.length ?? 0;
                                            if (len <= 0) return 0;
                                            return Math.max(0.0, Math.min(1.0, surface.trackPosition / len));
                                        }

                                        function seekToMouse(mx: real) {
                                            let len = surface.activePlayer?.length ?? 0;
                                            if (len > 0 && surface.activePlayer) {
                                                let pos = Math.max(0, Math.min(len, (mx / Math.max(1, width)) * len));
                                                surface.trackPosition = pos;
                                                surface.activePlayer.position = pos;
                                            }
                                        }

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            height: seekMouse.pressed ? 9 : (seekMouse.containsMouse ? 7 : 5)
                                            radius: lockRoot.uiRadiusPill
                                            color: Theme.alpha(lockRoot.uiTextPrimary, lockRoot.isLight ? 0.16 : 0.14)

                                            Behavior on height { NumberAnimation { duration: Theme.animFast } }

                                            Rectangle {
                                                anchors.left: parent.left
                                                anchors.top: parent.top
                                                anchors.bottom: parent.bottom
                                                width: parent.width * parent.parent.progRatio
                                                radius: lockRoot.uiRadiusPill
                                                color: surface.artAccent
                                            }
                                        }

                                        MouseArea {
                                            id: seekMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            enabled: (surface.activePlayer?.canSeek ?? true) && (surface.activePlayer?.length ?? 0) > 0
                                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            onPressed: (mouse) => parent.seekToMouse(mouse.x)
                                            onPositionChanged: (mouse) => {
                                                if (pressed) parent.seekToMouse(mouse.x);
                                            }
                                            onReleased: surface.claimSurfaceFocus()
                                        }
                                    }

                                    Text {
                                        text: lockRoot.formatTime(surface.activePlayer?.length ?? 0)
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeXs
                                        color: lockRoot.uiTextSecondary
                                    }
                                }
                            }
                        }

                        /*
                        password input pill:
                        stays visible: true even in zenMode (only opacity: 0) and uses readOnly instead of enabled: false
                        so pwInput never drops activeFocus or eats your first character!
                        */
                        ColumnLayout {
                            id: passwordBlock
                            width: parent.width
                            y: centerStage.blockY("password")
                            spacing: 8
                            opacity: lockRoot.zenMode ? 0.0 : 1.0

                            Behavior on y { NumberAnimation { duration: Theme.expressiveDefault; easing.type: Theme.animEasingEntrance } }
                            Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }

                            Rectangle {
                                id: pwContainer
                                Layout.fillWidth: true
                                Layout.preferredHeight: 50
                                radius: lockRoot.uiRadiusPill
                                color: pwInput.activeFocus ? lockRoot.uiPillHover : lockRoot.uiPillBg
                                border.color: lockRoot.authFailed
                                    ? Theme.error
                                    : (lockRoot.capsLockActive && lockRoot.sharedPassword.length > 0
                                        ? Theme.warn
                                        : (lockRoot.sharedPassword.length > 0
                                            ? lockRoot.uiAccent
                                            : (pwInput.activeFocus ? Theme.alpha(lockRoot.uiAccent, 0.65) : lockRoot.uiPillBorder)))
                                border.width: (pwInput.activeFocus || lockRoot.authFailed || lockRoot.capsLockActive) ? 2 : 1

                                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
                                Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                transform: Translate { id: pwShake }

                                SequentialAnimation {
                                    id: shakeAnim
                                    NumberAnimation { target: pwShake; property: "x"; from: 0; to: -14; duration: Math.max(30, Math.round(Theme.animFast / 3)); easing.type: Easing.OutQuad }
                                    NumberAnimation { target: pwShake; property: "x"; from: -14; to: 14; duration: Math.max(30, Math.round(Theme.animFast / 3)); easing.type: Easing.InOutQuad }
                                    NumberAnimation { target: pwShake; property: "x"; from: 14; to: -8; duration: Math.max(30, Math.round(Theme.animFast / 3)); easing.type: Easing.InOutQuad }
                                    NumberAnimation { target: pwShake; property: "x"; from: -8; to: 8; duration: Math.max(30, Math.round(Theme.animFast / 3)); easing.type: Easing.InOutQuad }
                                    NumberAnimation { target: pwShake; property: "x"; from: 8; to: 0; duration: Math.max(30, Math.round(Theme.animFast / 3)); easing.type: Easing.OutQuad }
                                }

                                SequentialAnimation {
                                    id: keyPulseAnim
                                    NumberAnimation { target: lockGlyph; property: "scale"; from: 1.0; to: 1.24; duration: 65; easing.type: Easing.OutQuad }
                                    NumberAnimation { target: lockGlyph; property: "scale"; from: 1.24; to: 1.0; duration: 130; easing.type: Easing.OutBack }
                                }

                                Connections {
                                    target: lockRoot
                                    function onTriggerShake() {
                                        shakeAnim.restart();
                                    }
                                    function onClearAllInputs() {
                                        if (pwInput.text !== "") pwInput.text = "";
                                    }
                                    function onSharedPasswordChanged() {
                                        if (pwInput.text !== lockRoot.sharedPassword) {
                                            pwInput.text = lockRoot.sharedPassword;
                                        }
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 18
                                    anchors.rightMargin: 8
                                    spacing: 10

                                    Text {
                                        id: lockGlyph
                                        text: lockRoot.isChecking ? Theme.iconRefresh : Theme.iconLock
                                        font.family: Theme.fontIcon
                                        font.pixelSize: Theme.fontSizeMd
                                        color: lockRoot.authFailed
                                            ? Theme.error
                                            : (pwInput.activeFocus ? lockRoot.uiAccent : lockRoot.uiTextSecondary)

                                        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                        RotationAnimator on rotation {
                                            running: lockRoot.isChecking
                                            loops: Animation.Infinite
                                            from: 0
                                            to: 360
                                            duration: 900
                                        }
                                    }

                                    TextInput {
                                        id: pwInput
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        verticalAlignment: TextInput.AlignVCenter
                                        echoMode: lockRoot.revealPassword
                                            ? TextInput.Normal
                                            : (lockRoot.pwMaskChar === "none" ? TextInput.NoEcho : TextInput.Password)
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeMd
                                        color: lockRoot.uiTextPrimary
                                        selectionColor: lockRoot.uiAccentOverlay
                                        selectedTextColor: lockRoot.uiTextPrimary
                                        readOnly: lockRoot.isChecking
                                        passwordCharacter: (lockRoot.pwMaskChar !== "" && lockRoot.pwMaskChar !== "none") ? lockRoot.pwMaskChar : "•"
                                        passwordMaskDelay: 0
                                        clip: true

                                        Text {
                                            anchors.fill: parent
                                            verticalAlignment: Text.AlignVCenter
                                            text: lockRoot.fmtText(
                                                lockRoot.isChecking
                                                    ? "verifying..."
                                                    : (lockRoot.pwMaskChar === "none" && lockRoot.sharedPassword.length > 0
                                                        ? (lockRoot.sharedPassword.length + " chars typed (stealth)...")
                                                        : "enter password to unlock...")
                                            )
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeSm
                                            color: lockRoot.pwMaskChar === "none" && lockRoot.sharedPassword.length > 0
                                                ? lockRoot.uiAccent
                                                : lockRoot.uiTextDisabled
                                            visible: pwInput.text.length === 0 || (lockRoot.pwMaskChar === "none" && !lockRoot.revealPassword)
                                        }

                                        onTextEdited: {
                                            surface.wakeFromZen();
                                            lockRoot.sharedPassword = pwInput.text;
                                            if (lockRoot.authFailed) lockRoot.authFailed = false;
                                            keyPulseAnim.restart();
                                        }

                                        Keys.onPressed: (event) => {
                                            surface.wakeFromZen();
                                            if (event.key === Qt.Key_CapsLock) {
                                                kbPollDelayTimer.restart();
                                            } else if (event.key === Qt.Key_Tab && pwInput.text.length === 0 && !surface.optionsOpen) {
                                                lockRoot.zenMode = !lockRoot.zenMode;
                                                event.accepted = true;
                                            } else if (lockRoot.freeDragMode && pwInput.text.length === 0) {
                                                let step = (event.modifiers & Qt.ShiftModifier) ? 0.04 : 0.01;
                                                if (event.key === Qt.Key_Left) {
                                                    lockRoot.customNormX = Math.max(0.02, lockRoot.customNormX - step);
                                                    lockRoot.layoutPosition = "custom";
                                                    lockRoot.saveSandbox();
                                                    event.accepted = true;
                                                } else if (event.key === Qt.Key_Right) {
                                                    lockRoot.customNormX = Math.min(0.98, lockRoot.customNormX + step);
                                                    lockRoot.layoutPosition = "custom";
                                                    lockRoot.saveSandbox();
                                                    event.accepted = true;
                                                } else if (event.key === Qt.Key_Up) {
                                                    lockRoot.customNormY = Math.max(0.05, lockRoot.customNormY - step);
                                                    lockRoot.layoutPosition = "custom";
                                                    lockRoot.saveSandbox();
                                                    event.accepted = true;
                                                } else if (event.key === Qt.Key_Down) {
                                                    lockRoot.customNormY = Math.min(0.95, lockRoot.customNormY + step);
                                                    lockRoot.layoutPosition = "custom";
                                                    lockRoot.saveSandbox();
                                                    event.accepted = true;
                                                }
                                            }
                                        }

                                        Keys.onEscapePressed: {
                                            if (lockRoot.zenMode) {
                                                lockRoot.zenMode = false;
                                            } else if (surface.optionsOpen) {
                                                surface.optionsOpen = false;
                                            } else if (lockRoot.isChecking && pam.active) {
                                                pam.abort();
                                                pamSafetyTimeout.stop();
                                                lockRoot.isChecking = false;
                                                lockRoot.pamFeedback = "cancelled";
                                            } else {
                                                lockRoot.sharedPassword = "";
                                                lockRoot.revealPassword = false;
                                                lockRoot.authFailed = false;
                                                pwInput.text = "";
                                            }
                                        }

                                        onAccepted: {
                                            const p = pwInput.text !== "" ? pwInput.text : lockRoot.sharedPassword;
                                            lockRoot.sharedPassword = "";
                                            pwInput.text = "";
                                            lockRoot.tryUnlock(p);
                                        }

                                        Connections {
                                            target: lockRoot
                                            function onLockedChanged() {
                                                if (lockRoot.locked) {
                                                    pwInput.text = "";
                                                    if (lockRoot.activeSurface === null || lockRoot.activeSurface === surface) {
                                                        lockRoot.activeSurface = surface;
                                                        pwInput.forceActiveFocus();
                                                    }
                                                }
                                            }
                                            function onIsCheckingChanged() {
                                                if (!lockRoot.isChecking && lockRoot.locked && lockRoot.activeSurface === surface) {
                                                    pwInput.forceActiveFocus();
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        visible: lockRoot.capsLockActive
                                        height: 22
                                        implicitWidth: capsTxt.implicitWidth + 10
                                        radius: lockRoot.uiRadiusPill
                                        color: Theme.warn_overlay
                                        border.color: Theme.alpha(Theme.warn, 0.65)
                                        border.width: 1

                                        Text {
                                            id: capsTxt
                                            anchors.centerIn: parent
                                            text: lockRoot.fmtText("caps")
                                            font.family: Theme.fontMono
                                            font.pixelSize: Theme.fontSizeXs
                                            font.weight: Theme.fontWeightBold
                                            color: Theme.warn
                                        }
                                    }

                                    IconButton {
                                        icon: Theme.iconClose
                                        tooltip: "clear"
                                        iconSize: Theme.fontSizeXs
                                        visible: lockRoot.sharedPassword.length > 0 && !lockRoot.isChecking
                                        onClicked: {
                                            lockRoot.sharedPassword = "";
                                            lockRoot.revealPassword = false;
                                            lockRoot.authFailed = false;
                                            pwInput.text = "";
                                            pwInput.forceActiveFocus();
                                        }
                                    }

                                    IconButton {
                                        icon: lockRoot.revealPassword ? Theme.iconEyeOff : Theme.iconEye
                                        tooltip: lockRoot.revealPassword ? "hide password" : "show password"
                                        iconSize: Theme.fontSizeSm
                                        visible: lockRoot.sharedPassword.length > 0 && !lockRoot.isChecking
                                        onClicked: {
                                            lockRoot.revealPassword = !lockRoot.revealPassword;
                                            pwInput.forceActiveFocus();
                                        }
                                    }

                                    Rectangle {
                                        readonly property bool canSubmit: lockRoot.sharedPassword.length > 0 && !lockRoot.isChecking
                                        width: canSubmit ? 38 : 0
                                        height: 34
                                        opacity: canSubmit ? 1.0 : 0.0
                                        visible: width > 0
                                        radius: lockRoot.uiRadiusPill
                                        color: submitMouse.pressed
                                            ? Theme.statePress(lockRoot.uiAccent, lockRoot.uiOnAccent)
                                            : (submitMouse.containsMouse
                                                ? Theme.stateHover(lockRoot.uiAccent, lockRoot.uiOnAccent)
                                                : lockRoot.uiAccent)

                                        Behavior on width { NumberAnimation { duration: Theme.expressiveFast; easing.type: Theme.animExpressiveEasing } }
                                        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                                        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: Theme.iconChevronRight
                                            font.family: Theme.fontIcon
                                            font.pixelSize: Theme.fontSizeSm
                                            font.weight: Theme.fontWeightBold
                                            color: lockRoot.uiOnAccent
                                        }

                                        MouseArea {
                                            id: submitMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                const p = pwInput.text !== "" ? pwInput.text : lockRoot.sharedPassword;
                                                lockRoot.sharedPassword = "";
                                                pwInput.text = "";
                                                lockRoot.tryUnlock(p);
                                            }
                                        }
                                    }
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 18

                                Text {
                                    anchors.centerIn: parent
                                    text: lockRoot.fmtText(
                                        lockRoot.pamFeedback !== ""
                                            ? lockRoot.pamFeedback
                                            : (lockRoot.isChecking
                                                ? "authenticating..."
                                                : (lockRoot.authFailed
                                                    ? (lockRoot.faillockTripped
                                                        ? "account locked by pam_faillock (run 'faillock --reset' in tty)"
                                                        : "incorrect password, try again")
                                                    : (lockRoot.capsLockActive ? "caps lock is on" : "")))
                                    )
                                    opacity: text !== "" ? 1.0 : 0.0
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: Theme.fontWeightMedium
                                    color: (lockRoot.authFailed || lockRoot.pamFeedbackIsError)
                                        ? Theme.error
                                        : (lockRoot.capsLockActive ? Theme.warn : lockRoot.uiTextSecondary)

                                    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                                }
                            }
                        }
                    }

                    // bottom power dock
                    RowLayout {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.margins: 36
                        anchors.bottomMargin: (surface.entered && !lockRoot.zenMode && lockRoot.showPowerDock) ? 36 : 12
                        opacity: (surface.entered && !lockRoot.zenMode && lockRoot.showPowerDock) ? 1.0 : 0.0
                        visible: opacity > 0.01
                        spacing: 12

                        Behavior on anchors.bottomMargin { NumberAnimation { duration: Theme.expressiveDefault; easing.type: Theme.animEasingEntrance } }
                        Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }

                        PowerPill {
                            actionId: "poweroff"
                            icon: Theme.iconPower
                            label: "shut down"
                            command: ["systemctl", "poweroff"]
                        }

                        PowerPill {
                            actionId: "reboot"
                            icon: Theme.iconReboot
                            label: "restart"
                            command: ["systemctl", "reboot"]
                        }

                        PowerPill {
                            actionId: "suspend"
                            icon: Theme.iconSuspend
                            label: "sleep"
                            command: ["systemctl", "suspend"]
                        }

                        PowerPill {
                            visible: lockRoot.allowLogoutOnLock
                            actionId: "logout"
                            icon: Theme.iconLogout
                            label: "log out"
                            command: [
                                "sh", "-c",
                                "hyprshutdown 2>/dev/null || uwsm stop 2>/dev/null || hyprctl dispatch 'hl.dsp.exit()' 2>/dev/null || hyprctl dispatch exit"
                            ]
                        }
                    }

                    // concave screen corners
                    ConcaveCorner {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        radiusX: Theme.screenCornerRadius
                        radiusY: Theme.screenCornerRadius
                        fillColor: Theme.cornerFill
                        flipX: false
                        flipY: false
                        visible: lockRoot.showScreenCorners && Theme.screenCornerRadius > 0
                    }

                    ConcaveCorner {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        radiusX: Theme.screenCornerRadius
                        radiusY: Theme.screenCornerRadius
                        fillColor: Theme.cornerFill
                        flipX: true
                        flipY: false
                        visible: lockRoot.showScreenCorners && Theme.screenCornerRadius > 0
                    }

                    ConcaveCorner {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        radiusX: Theme.screenCornerRadius
                        radiusY: Theme.screenCornerRadius
                        fillColor: Theme.cornerFill
                        flipX: false
                        flipY: true
                        visible: lockRoot.showScreenCorners && Theme.screenCornerRadius > 0
                    }

                    ConcaveCorner {
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        radiusX: Theme.screenCornerRadius
                        radiusY: Theme.screenCornerRadius
                        fillColor: Theme.cornerFill
                        flipX: true
                        flipY: true
                        visible: lockRoot.showScreenCorners && Theme.screenCornerRadius > 0
                    }
                }
            }
        }
    }
}
