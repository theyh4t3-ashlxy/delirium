import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import ".."
import "../controls"
import "../corners"
import "../theme/confFormat.mjs" as ConfFmt
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
    property bool unlocking: false
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
    property string quoteMode: "smart"         // "smart" | "hyprland" | "quotes" | "actions" | "custom" | "off"
    onQuoteModeChanged: refreshQuotes()
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

    // visual redesign, transitions, typography & independent lockscreen matugen palette
    property string lockTransition: "blur-dissolve"     // "blur-dissolve" | "slide-up" | "zoom-snap" | "curtain-fade" | "editorial-stagger"
    property string lockAnimSpeed: "smooth"             // "snappy" | "smooth" | "cinematic"
    property string clockFont: "display"                // "display" | "sans" | "mono" | "serif"
    property string clockWeight: "bold"                 // "light" | "bold" | "black"
    property string backdropTexture: "none"             // "none" | "dots" | "grid"
    property bool syncPaletteWithDesktop: true
    property string lockMatugenScheme: "scheme-tonal-spot"
    property bool isExtractingPalette: false
    property string lockPalPrimary: ""
    property string lockPalOnPrimary: ""
    property string lockPalSecondary: ""
    property string lockPalTertiary: ""
    property string lockPalSurface: ""
    property string lockPalContainer: ""
    property string lockPalText: ""
    property string lockPalSubtext: ""
    property string lockPalSource: ""

    readonly property string spectrumScriptPath: decodeURIComponent(Qt.resolvedUrl("../scripts/spectrum.py").toString().replace(/^file:\/\//, ""))
    property var spectrumBands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

    readonly property real lockAnimFactor: lockAnimSpeed === "snappy" ? 0.65 : (lockAnimSpeed === "cinematic" ? 1.45 : 1.0)
    readonly property int unlockDurationMs: Math.round(240 * lockAnimFactor)

    readonly property string resolvedClockFontFamily: {
        if (clockFont === "mono") return Theme.fontMono;
        if (clockFont === "sans") return Theme.fontFamily;
        if (clockFont === "serif") return "Georgia";
        return Theme.fontDisplay;
    }

    function resolvedClockAxes(px: real): var {
        if (clockFont === "mono") return Theme.monoAxesFor(px);
        if (clockFont === "serif") return ({});
        return Theme.textAxesFor(px, clockFont !== "sans");
    }

    readonly property int resolvedClockWeight: {
        if (clockWeight === "light") return Theme.fontWeightLight;
        if (clockWeight === "black") return Math.min(900, Theme.fontWeightBold + 150);
        return Theme.fontWeightBold;
    }

    readonly property bool useCustomLockPalette: !syncPaletteWithDesktop && !wallpaperSync && localWallpaperOverride !== "" && lockPalPrimary !== ""

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
    readonly property real surfaceLuminance: {
        let sCol = useCustomLockPalette && lockPalSurface !== "" ? Qt.color(lockPalSurface) : Theme.surface;
        return (0.2126 * sCol.r) + (0.7152 * sCol.g) + (0.0722 * sCol.b);
    }
    readonly property bool matugenIsLight: surfaceLuminance > 0.5
    readonly property bool globalCfgLight: (typeof Settings !== "undefined" && Settings)
        ? Boolean(Settings.lightMode || Settings.isLight || Settings.themeMode === "light" || Settings.colorScheme === "light")
        : false
    readonly property bool isLight: backdropMode === "light" || (backdropMode === "auto" && (matugenIsLight || globalCfgLight))

    readonly property color uiAccent: {
        let raw = useCustomLockPalette && lockPalPrimary !== "" ? Qt.color(lockPalPrimary) : Theme.primary;
        if (!isLight) return raw;
        if (matugenIsLight) return raw;
        let darkened = Qt.rgba(raw.r * 0.62, raw.g * 0.62, raw.b * 0.62, 1.0);
        return Theme.blend(darkened, Theme.on_primary_container, 0.35);
    }
    readonly property color uiTertiary: useCustomLockPalette && lockPalTertiary !== "" ? Qt.color(lockPalTertiary) : Theme.tertiary
    readonly property color uiOnAccent: {
        if (!isLight || matugenIsLight) {
            return (useCustomLockPalette && lockPalOnPrimary !== "") ? Qt.color(lockPalOnPrimary) : Theme.on_primary;
        }
        return "#ffffff";
    }
    readonly property color uiAccentOverlay: Theme.alpha(uiAccent, isLight ? 0.16 : 0.18)

    readonly property color uiSurfaceBase: {
        let sCol = useCustomLockPalette && lockPalSurface !== "" ? Qt.color(lockPalSurface) : Theme.surface;
        if (!isLight) return sCol;
        if (matugenIsLight) return sCol;
        return Theme.blend(Qt.rgba(0.97, 0.96, 0.99, 1.0), uiAccent, 0.05);
    }
    readonly property color uiTextPrimary: {
        let fg = useCustomLockPalette && lockPalText !== "" ? Qt.color(lockPalText) : Theme.textPrimary;
        if (!isLight) return matugenIsLight ? Theme.inverse_on_surface : fg;
        return matugenIsLight ? fg : Theme.blend(Qt.rgba(0.11, 0.10, 0.14, 1.0), uiAccent, 0.08);
    }
    readonly property color uiTextSecondary: {
        let sub = useCustomLockPalette && lockPalSubtext !== "" ? Qt.color(lockPalSubtext) : Theme.textSecondary;
        if (!isLight) return matugenIsLight ? Theme.alpha(Theme.inverse_on_surface, 0.72) : sub;
        return matugenIsLight ? sub : Theme.alpha(uiTextPrimary, 0.68);
    }
    readonly property color uiTextDisabled: Theme.alpha(uiTextPrimary, 0.40)

    function applyAlphaBoost(c: color, boost: real): color {
        let targetA = Math.max(0.12, Math.min(1.0, c.a + boost));
        return Qt.rgba(c.r, c.g, c.b, targetA);
    }

    readonly property color uiPillBg: {
        let containerC = useCustomLockPalette && lockPalContainer !== "" ? Qt.color(lockPalContainer) : Theme.pillBg;
        let base = !isLight
            ? (useCustomLockPalette ? Theme.alpha(containerC, Theme.isGlass ? 0.68 : 0.88) : Theme.pillBg)
            : Theme.alpha(matugenIsLight ? (useCustomLockPalette ? containerC : Theme.surface_container_lowest) : Theme.blend(Qt.rgba(0.98, 0.97, 1.0, 1.0), uiAccent, 0.05), Theme.isGlass ? 0.82 : 0.92);
        return applyAlphaBoost(base, cardOpacityBoost);
    }
    readonly property color uiPillHover: {
        let containerC = useCustomLockPalette && lockPalContainer !== "" ? Qt.color(lockPalContainer) : Theme.pillHover;
        let base = !isLight
            ? (useCustomLockPalette ? Theme.blend(containerC, uiAccent, 0.12) : Theme.pillHover)
            : Theme.alpha(matugenIsLight ? (useCustomLockPalette ? containerC : Theme.surface_container_high) : Theme.blend(Qt.rgba(0.93, 0.91, 0.96, 1.0), uiAccent, 0.10), 0.94);
        return applyAlphaBoost(base, cardOpacityBoost);
    }
    readonly property color uiPillBorder: !isLight ? (useCustomLockPalette ? Theme.alpha(uiAccent, 0.28) : Theme.pillBorder) : Theme.alpha(uiAccent, 0.24)

    readonly property color uiCardBg: {
        let containerC = useCustomLockPalette && lockPalSurface !== "" ? Qt.color(lockPalSurface) : Theme.cardBg;
        let base = !isLight
            ? (useCustomLockPalette ? Theme.alpha(containerC, Theme.isGlass ? 0.72 : 0.90) : Theme.cardBg)
            : Theme.alpha(matugenIsLight ? (useCustomLockPalette ? containerC : Theme.surface_container_low) : Theme.blend(Qt.rgba(0.97, 0.96, 0.99, 1.0), uiAccent, 0.06), Theme.isGlass ? 0.85 : 0.94);
        return applyAlphaBoost(base, cardOpacityBoost);
    }
    readonly property color uiCardBorder: !isLight ? (useCustomLockPalette ? Theme.alpha(uiAccent, 0.26) : Theme.cardBorder) : Theme.alpha(uiAccent, 0.22)

    readonly property color uiPopupBg: {
        if (!isLight) return useCustomLockPalette && lockPalSurface !== "" ? Theme.alpha(Qt.color(lockPalSurface), 0.94) : Theme.popupBg;
        let base = matugenIsLight ? Theme.surface_container_lowest : Theme.blend(Qt.rgba(0.98, 0.97, 1.0, 1.0), uiAccent, 0.04);
        return Theme.alpha(base, 0.95);
    }
    readonly property color uiPopupBorder: !isLight ? (useCustomLockPalette ? Theme.alpha(uiAccent, 0.32) : Theme.popupBorderColor) : Theme.alpha(uiAccent, 0.26)

    readonly property color uiWidgetBg: {
        if (!isLight) return useCustomLockPalette && lockPalContainer !== "" ? Theme.alpha(Qt.color(lockPalContainer), 0.82) : Theme.widgetBg;
        let base = matugenIsLight ? Theme.surface_container : Theme.blend(Qt.rgba(0.93, 0.92, 0.96, 1.0), uiAccent, 0.07);
        return Theme.alpha(base, 0.88);
    }
    readonly property color uiWidgetHover: {
        if (!isLight) return useCustomLockPalette && lockPalContainer !== "" ? Theme.blend(Qt.color(lockPalContainer), uiAccent, 0.16) : Theme.widgetHover;
        let base = matugenIsLight ? Theme.surface_container_high : Theme.blend(Qt.rgba(0.89, 0.87, 0.93, 1.0), uiAccent, 0.12);
        return Theme.alpha(base, 0.94);
    }
    readonly property color uiWidgetActive: !isLight ? Theme.alpha(uiAccent, 0.22) : Theme.alpha(uiAccent, 0.20)
    readonly property color uiWidgetBorder: !isLight ? Theme.alpha(uiAccent, 0.20) : Theme.alpha(uiAccent, 0.20)

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

    function parseMatugenField(raw: string, tokenName: string, modeKey: string): string {
        let idx = raw.indexOf('"' + tokenName + '"');
        if (idx < 0) return "";
        let slice = raw.slice(idx, idx + 420);
        let mRe = new RegExp('"' + modeKey + '"\\s*:\\s*\\{\\s*"color"\\s*:\\s*"(#[0-9a-fA-F]{6})"');
        let m = slice.match(mRe);
        if (m && m[1]) return m[1].toLowerCase();
        let defM = slice.match(/"default"\s*:\s*\{\s*"color"\s*:\s*"(#[0-9a-fA-F]{6})"/);
        return (defM && defM[1]) ? defM[1].toLowerCase() : "";
    }

    function extractLockPalette(imagePath: string) {
        let wp = (imagePath || "").trim();
        if (!wp || /\.(mp4|webm|mkv|mov)$/i.test(wp)) {
            wp = (typeof WallpaperService !== "undefined" ? WallpaperService?.currWallStatic : "") || (lockRoot.homeDir + "/.curr_wall_static.jpg");
        }
        if (!wp) return;
        let mode = lockRoot.isLight ? "light" : "dark";
        let scheme = lockRoot.lockMatugenScheme || "scheme-tonal-spot";
        lockRoot.isExtractingPalette = true;
        if (lockMatugenProc.running) lockMatugenProc.running = false;
        lockMatugenProc.command = ["matugen", "image", wp, "--source-color-index", "0", "--dry-run", "-j", "hex", "-m", mode, "-t", scheme];
        lockMatugenProc.running = true;
    }

    Process {
        id: lockMatugenProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                lockRoot.isExtractingPalette = false;
                let raw = text || "";
                if (raw.trim() === "") return;
                let modeKey = lockRoot.isLight ? "light" : "dark";
                let p = lockRoot.parseMatugenField(raw, "primary", modeKey);
                if (p === "") return;
                lockRoot.lockPalPrimary = p;
                lockRoot.lockPalOnPrimary = lockRoot.parseMatugenField(raw, "on_primary", modeKey) || "#111111";
                lockRoot.lockPalSecondary = lockRoot.parseMatugenField(raw, "secondary", modeKey) || p;
                lockRoot.lockPalTertiary = lockRoot.parseMatugenField(raw, "tertiary", modeKey) || p;
                lockRoot.lockPalSurface = lockRoot.parseMatugenField(raw, "surface", modeKey) || "#171217";
                lockRoot.lockPalContainer = lockRoot.parseMatugenField(raw, "surface_container_high", modeKey) || "#262026";
                lockRoot.lockPalText = lockRoot.parseMatugenField(raw, "on_surface", modeKey) || "#ece0eb";
                lockRoot.lockPalSubtext = lockRoot.parseMatugenField(raw, "on_surface_variant", modeKey) || "#cfc3ce";
                lockRoot.lockPalSource = lockRoot.parseMatugenField(raw, "source_color", modeKey) || p;
                lockRoot.saveSandbox();
            }
        }
        onExited: (exitCode) => {
            if (exitCode !== 0) lockRoot.isExtractingPalette = false;
        }
    }

    Process {
        id: lockSpectrumProc
        command: ["python3", lockRoot.spectrumScriptPath]
        running: lockRoot.locked && !lockRoot.unlocking && lockRoot.anyPlayerPlaying && !lockRoot.zenMode && (
            (lockRoot.showMediaCard && lockRoot.showMediaVisualizer) || lockRoot.ambientOrbs
        )
        stdout: SplitParser {
            onRead: (line) => {
                let parts = line.trim().split(",");
                if (parts.length === 24) {
                    let next = [];
                    for (let i = 0; i < 24; i++) {
                        let v = parseInt(parts[i], 10);
                        next.push(isNaN(v) ? 0 : Math.max(0, Math.min(1, v / 99.0)));
                    }
                    lockRoot.spectrumBands = next;
                }
            }
        }
        onRunningChanged: {
            if (!running) {
                lockRoot.spectrumBands = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            }
        }
    }

    function loadState() {
        let raw = lockStateFile.text();
        if (!raw || raw.trim() === "") {
            lockRoot.stateLoaded = true;
            return;
        }

        const parsed = ConfFmt.parseFlatConf(raw);
        for (const k in parsed) {
            let v = ConfFmt.unescapeField(parsed[k]);
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
                case "clockFont":
                    if (["display", "sans", "mono", "serif"].includes(v)) lockRoot.clockFont = v;
                    break;
                case "clockWeight":
                    if (["light", "bold", "black"].includes(v)) lockRoot.clockWeight = v;
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
                    if (v === "unhinged") lockRoot.quoteMode = "actions";
                    else if (["smart", "hyprland", "quotes", "actions", "custom", "off"].includes(v)) lockRoot.quoteMode = v;
                    break;
                case "customQuoteText": lockRoot.customQuoteText = v; break;
                case "backdropMode":
                    if (["auto", "dark", "light"].includes(v)) lockRoot.backdropMode = v;
                    break;
                case "backdropTexture":
                    if (["none", "dots", "grid"].includes(v)) lockRoot.backdropTexture = v;
                    break;
                case "lockTransition":
                    if (["blur-dissolve", "slide-up", "zoom-snap", "curtain-fade", "editorial-stagger"].includes(v)) lockRoot.lockTransition = v;
                    break;
                case "lockAnimSpeed":
                    if (["snappy", "smooth", "cinematic"].includes(v)) lockRoot.lockAnimSpeed = v;
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
                case "syncPaletteWithDesktop": lockRoot.syncPaletteWithDesktop = parseBool(v, lockRoot.syncPaletteWithDesktop); break;
                case "lockMatugenScheme": if (v !== "") lockRoot.lockMatugenScheme = v; break;
                case "lockPalPrimary": lockRoot.lockPalPrimary = v; break;
                case "lockPalOnPrimary": lockRoot.lockPalOnPrimary = v; break;
                case "lockPalSecondary": lockRoot.lockPalSecondary = v; break;
                case "lockPalTertiary": lockRoot.lockPalTertiary = v; break;
                case "lockPalSurface": lockRoot.lockPalSurface = v; break;
                case "lockPalContainer": lockRoot.lockPalContainer = v; break;
                case "lockPalText": lockRoot.lockPalText = v; break;
                case "lockPalSubtext": lockRoot.lockPalSubtext = v; break;
                case "lockPalSource": lockRoot.lockPalSource = v; break;
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
            lockRoot.clockFont = "display";
            lockRoot.clockWeight = "bold";
            lockRoot.secondsStyle = "badge";
            lockRoot.showSeconds = true;
            lockRoot.layoutPosition = "center";
            lockRoot.stackOrder = "clock,media,password";
            lockRoot.shapePreset = "squircle";
            lockRoot.lockTransition = "blur-dissolve";
            lockRoot.backdropTexture = "none";
            lockRoot.clockScale = 1.08;
            lockRoot.scrimDim = 0.54;
            lockRoot.vignetteStrength = 0.40;
            lockRoot.ambientOrbs = true;
            lockRoot.dateAboveClock = true;
        } else if (presetName === "cards") {
            lockRoot.clockStyle = "split";
            lockRoot.clockFont = "display";
            lockRoot.clockWeight = "bold";
            lockRoot.secondsStyle = "badge";
            lockRoot.showSeconds = true;
            lockRoot.layoutPosition = "center";
            lockRoot.stackOrder = "clock,password,media";
            lockRoot.shapePreset = "squircle";
            lockRoot.lockTransition = "zoom-snap";
            lockRoot.backdropTexture = "dots";
            lockRoot.clockScale = 1.0;
            lockRoot.scrimDim = 0.62;
            lockRoot.vignetteStrength = 0.45;
            lockRoot.ambientOrbs = true;
            lockRoot.dateAboveClock = false;
        } else if (presetName === "editorial") {
            lockRoot.clockStyle = "editorial";
            lockRoot.clockFont = "serif";
            lockRoot.clockWeight = "bold";
            lockRoot.showSeconds = true;
            lockRoot.secondsStyle = "tower";
            lockRoot.layoutPosition = "left";
            lockRoot.stackOrder = "clock,media,password";
            lockRoot.shapePreset = "pill";
            lockRoot.lockTransition = "editorial-stagger";
            lockRoot.backdropTexture = "none";
            lockRoot.clockScale = 1.05;
            lockRoot.scrimDim = 0.48;
            lockRoot.vignetteStrength = 0.45;
            lockRoot.dateAboveClock = true;
        } else if (presetName === "cyber") {
            lockRoot.clockStyle = "digital";
            lockRoot.clockFont = "mono";
            lockRoot.clockWeight = "bold";
            lockRoot.showSeconds = true;
            lockRoot.secondsStyle = "inline";
            lockRoot.layoutPosition = "center";
            lockRoot.stackOrder = "clock,password,media";
            lockRoot.shapePreset = "sharp";
            lockRoot.lockTransition = "curtain-fade";
            lockRoot.backdropTexture = "grid";
            lockRoot.clockScale = 1.0;
            lockRoot.scrimDim = 0.65;
            lockRoot.vignetteStrength = 0.50;
            lockRoot.ambientOrbs = true;
        } else if (presetName === "minimal") {
            lockRoot.clockStyle = "minimal";
            lockRoot.clockFont = "sans";
            lockRoot.clockWeight = "light";
            lockRoot.showSeconds = false;
            lockRoot.layoutPosition = "top";
            lockRoot.stackOrder = "clock,password,media";
            lockRoot.shapePreset = "theme";
            lockRoot.lockTransition = "slide-up";
            lockRoot.backdropTexture = "none";
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
        lockRoot.clockFont = "display";
        lockRoot.clockWeight = "bold";
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
        lockRoot.backdropTexture = "none";
        lockRoot.lockTransition = "blur-dissolve";
        lockRoot.lockAnimSpeed = "smooth";
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
        lockRoot.syncPaletteWithDesktop = true;
        lockRoot.lockMatugenScheme = "scheme-tonal-spot";
        lockRoot.saveSandbox();
    }

    function surpriseMe() {
        if (lockRoot.studioLocked) return;
        const cStyles = ["inline", "stacked", "split", "typo", "digital", "editorial", "minimal"];
        const cFonts = ["display", "sans", "mono", "serif"];
        const cWeights = ["light", "bold", "black"];
        const sStyles = ["badge", "supersub", "tower", "inline"];
        const positions = ["center", "top", "bottom", "left", "right"];
        const shapes = ["theme", "pill", "squircle", "sharp"];
        const transitions = ["blur-dissolve", "slide-up", "zoom-snap", "curtain-fade", "editorial-stagger"];
        const textures = ["none", "none", "dots", "grid"];
        const orders = [
            "clock,media,password",
            "clock,password,media",
            "media,clock,password"
        ];
        const qModes = ["smart", "hyprland", "quotes", "actions"];

        lockRoot.clockStyle = cStyles[Math.floor(Math.random() * cStyles.length)];
        lockRoot.clockFont = cFonts[Math.floor(Math.random() * cFonts.length)];
        lockRoot.clockWeight = cWeights[Math.floor(Math.random() * cWeights.length)];
        lockRoot.secondsStyle = sStyles[Math.floor(Math.random() * sStyles.length)];
        lockRoot.shapePreset = shapes[Math.floor(Math.random() * shapes.length)];
        lockRoot.lockTransition = transitions[Math.floor(Math.random() * transitions.length)];
        lockRoot.backdropTexture = textures[Math.floor(Math.random() * textures.length)];
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
            "# Quickshell native lockscreen studio configuration",
            "studioLocked=" + (lockRoot.studioLocked ? "1" : "0"),
            "syncClockGlobal=" + (lockRoot.syncClockGlobal ? "1" : "0"),
            "showClock=" + (lockRoot.showClock ? "1" : "0"),
            "showDate=" + (lockRoot.showDate ? "1" : "0"),
            "clock24h=" + (lockRoot.sandboxClock24h ? "1" : "0"),
            "showSeconds=" + (lockRoot.showSeconds ? "1" : "0"),
            "clockStyle=" + ConfFmt.escapeField(lockRoot.clockStyle),
            "clockFont=" + ConfFmt.escapeField(lockRoot.clockFont),
            "clockWeight=" + ConfFmt.escapeField(lockRoot.clockWeight),
            "secondsStyle=" + ConfFmt.escapeField(lockRoot.secondsStyle),
            "dateFormat=" + ConfFmt.escapeField(lockRoot.dateFormat),
            "textCase=" + ConfFmt.escapeField(lockRoot.textCase),
            "pwMaskChar=" + ConfFmt.escapeField(lockRoot.pwMaskChar),
            "stageWidth=" + lockRoot.stageWidth,
            "shapePreset=" + ConfFmt.escapeField(lockRoot.shapePreset),
            "cardOpacityBoost=" + Number(lockRoot.cardOpacityBoost).toFixed(2),
            "layoutPosition=" + ConfFmt.escapeField(lockRoot.layoutPosition),
            "stackOrder=" + ConfFmt.escapeField(lockRoot.stackOrder),
            "dateAboveClock=" + (lockRoot.dateAboveClock ? "1" : "0"),
            "customNormX=" + Number(lockRoot.customNormX).toFixed(4),
            "customNormY=" + Number(lockRoot.customNormY).toFixed(4),
            "clockScale=" + Number(lockRoot.clockScale).toFixed(2),
            "quoteMode=" + ConfFmt.escapeField(lockRoot.quoteMode),
            "customQuoteText=" + ConfFmt.escapeField(lockRoot.customQuoteText),
            "backdropMode=" + ConfFmt.escapeField(lockRoot.backdropMode),
            "backdropTexture=" + ConfFmt.escapeField(lockRoot.backdropTexture),
            "lockTransition=" + ConfFmt.escapeField(lockRoot.lockTransition),
            "lockAnimSpeed=" + ConfFmt.escapeField(lockRoot.lockAnimSpeed),
            "pamService=" + ConfFmt.escapeField(lockRoot.pamService),
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
            "customWallpaper=" + ConfFmt.escapeField(lockRoot.localWallpaperOverride),
            "syncPaletteWithDesktop=" + (lockRoot.syncPaletteWithDesktop ? "1" : "0"),
            "lockMatugenScheme=" + ConfFmt.escapeField(lockRoot.lockMatugenScheme),
            "lockPalPrimary=" + ConfFmt.escapeField(lockRoot.lockPalPrimary),
            "lockPalOnPrimary=" + ConfFmt.escapeField(lockRoot.lockPalOnPrimary),
            "lockPalSecondary=" + ConfFmt.escapeField(lockRoot.lockPalSecondary),
            "lockPalTertiary=" + ConfFmt.escapeField(lockRoot.lockPalTertiary),
            "lockPalSurface=" + ConfFmt.escapeField(lockRoot.lockPalSurface),
            "lockPalContainer=" + ConfFmt.escapeField(lockRoot.lockPalContainer),
            "lockPalText=" + ConfFmt.escapeField(lockRoot.lockPalText),
            "lockPalSubtext=" + ConfFmt.escapeField(lockRoot.lockPalSubtext),
            "lockPalSource=" + ConfFmt.escapeField(lockRoot.lockPalSource)
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

    function scheduleKeyboardPoll() {
        kbPollDelayTimer.restart();
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
        let mode = lockRoot.quoteMode;
        if (mode === "off" || mode === "custom" || mode === "hyprland") return;

        let cat = (mode === "smart" || mode === "quotes") ? pickSmartCategory() : "system";
        let srcMode = (mode === "quotes") ? "quotes" : "actions";
        if (Theme.rollFlavor) {
            lockRoot.rolledQuote = Theme.rollFlavor(cat, srcMode, lockRoot.rolledQuote, "");
        } else {
            let pool = Theme.getFlavorPool ? Theme.getFlavorPool(srcMode, cat) : (Theme.flavorQuotes?.[cat] ?? Theme.flavorQuotes?.system);
            if (pool && pool.length > 0) {
                let idx = Math.floor(Math.random() * pool.length);
                lockRoot.rolledQuote = pool[idx] || "";
            } else if (Theme.getFlavor) {
                lockRoot.rolledQuote = Theme.getFlavor(cat, "", srcMode) || "";
            }
        }
    }

    readonly property string activeQuoteText: {
        if (lockRoot.quoteMode === "off") return "";
        if (lockRoot.quoteMode === "custom") return fmtText(lockRoot.customQuoteText);
        if (lockRoot.quoteMode === "hyprland") {
            return fmtText(lockRoot.hyprSplash || Theme.hyprSplash);
        }
        return fmtText(lockRoot.rolledQuote || lockRoot.hyprSplash);
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
        return Theme.fixCoverUrl(url);
    }

    function formatTime(seconds): string {
        return Theme.formatTime(seconds);
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

    onIsLightChanged: {
        if (lockRoot.stateLoaded && !lockRoot.syncPaletteWithDesktop && !lockRoot.wallpaperSync && lockRoot.localWallpaperOverride !== "") {
            lockRoot.extractLockPalette(lockRoot.localWallpaperOverride);
        }
    }

    Timer {
        id: unlockFinalizeTimer
        interval: lockRoot.unlockDurationMs
        repeat: false
        onTriggered: {
            lockRoot.unlocking = false;
            lockRoot.locked = false;
        }
    }

    function beginUnlockTransition() {
        if (!lockRoot.locked || lockRoot.unlocking) return;
        lockRoot.unlocking = true;
        unlockFinalizeTimer.interval = Math.max(80, lockRoot.unlockDurationMs);
        unlockFinalizeTimer.restart();
    }

    Timer {
        interval: 75
        running: lockRoot.locked && !lockRoot.unlocking && lockRoot.anyPlayerPlaying && lockRoot.ambientOrbs && !lockRoot.zenMode
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
            unlockFinalizeTimer.stop();
            lockRoot.unlocking = false;
            lockRoot.locked = true;
        }
        function isLocked(): bool {
            return lockRoot.locked;
        }
        function unlock(): void {
            lockRoot.beginUnlockTransition();
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
                lockRoot.authFailed = false;
                lockRoot.pamFeedback = "unlocked";
                lockRoot.pamFeedbackIsError = false;
                lockRoot.beginUnlockTransition();
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

    function cancelAuth() {
        if (pam.active) pam.abort();
        pamSafetyTimeout.stop();
        isChecking = false;
        pamRespondedThisTurn = false;
        pendingPassword = "";
        pamFeedback = "cancelled";
    }

    function resetAuthState() {
        cancelAuth();
        sharedPassword = "";
        revealPassword = false;
        authFailed = false;
        clearAllInputs();
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
                        claimSurfaceFocus();
                    }
                }

                Connections {
                    target: lockRoot
                    function onUnlockingChanged() {
                        if (lockRoot.unlocking) surface.entered = false;
                        else if (lockRoot.locked) surface.entered = true;
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
                    if (optionsCard?.hasInputFocus) return;
                    if (passwordBlock?.pwInput && !passwordBlock.pwInput.activeFocus) {
                        passwordBlock.pwInput.forceActiveFocus();
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
                        if (!(mediaBlock?.isSeeking ?? false)) {
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
                    running: lockRoot.locked && surface.playerIsPlaying && lockRoot.showMediaCard && !lockRoot.zenMode && !(mediaBlock?.isSeeking ?? false)
                    repeat: true
                    onTriggered: {
                        if (surface.activePlayer) {
                            surface.trackPosition = surface.activePlayer.position ?? 0;
                        }
                    }
                }

                Rectangle {
                    id: screenCanvas
                    anchors.fill: parent
                    color: lockRoot.uiSurfaceBase
                    clip: true

                    focus: true
                    Keys.forwardTo: (passwordBlock && passwordBlock.pwInput) ? [passwordBlock.pwInput] : []

                    readonly property bool isDeepFocused: lockRoot.sharedPassword.length > 0 || surface.optionsOpen || lockRoot.isChecking
                    readonly property bool activeVisual: surface.entered && !lockRoot.unlocking
                    readonly property int transMs: Math.round(320 * lockRoot.lockAnimFactor)

                    opacity: activeVisual ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: Math.max(90, screenCanvas.transMs); easing.type: Theme.animEasing } }

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
                            surface.claimSurfaceFocus();
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
                        scale: {
                            if (!surface.entered) {
                                if (lockRoot.lockTransition === "zoom-snap") return 1.14;
                                if (lockRoot.lockTransition === "curtain-fade") return 1.06;
                                return 1.02;
                            }
                            return parent.isDeepFocused ? lockRoot.focusZoom : 1.0;
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: Math.max(120, Math.round(420 * lockRoot.lockAnimFactor))
                                easing.type: Theme.animEasing
                            }
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

                    // optional tactile architectural texture overlay (dots matrix or fine grid)
                    Canvas {
                        id: texCanvas
                        anchors.fill: parent
                        visible: lockRoot.backdropTexture !== "none"
                        opacity: lockRoot.isLight ? 0.12 : 0.09
                        property string curMode: lockRoot.backdropTexture
                        property color inkColor: lockRoot.uiTextPrimary
                        onCurModeChanged: requestPaint()
                        onInkColorChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        onPaint: {
                            let ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            if (curMode === "none" || width <= 0 || height <= 0) return;
                            ctx.fillStyle = inkColor;
                            ctx.strokeStyle = inkColor;
                            if (curMode === "dots") {
                                const step = 22;
                                for (let y = 11; y < height; y += step) {
                                    for (let x = 11; x < width; x += step) {
                                        ctx.fillRect(x, y, 1.5, 1.5);
                                    }
                                }
                            } else if (curMode === "grid") {
                                const step = 44;
                                ctx.lineWidth = 1;
                                ctx.beginPath();
                                for (let x = 0; x < width; x += step) {
                                    ctx.moveTo(x + 0.5, 0);
                                    ctx.lineTo(x + 0.5, height);
                                }
                                for (let y = 0; y < height; y += step) {
                                    ctx.moveTo(0, y + 0.5);
                                    ctx.lineTo(width, y + 0.5);
                                }
                                ctx.stroke();
                            }
                        }
                    }

                    // ambient audio-reactive glow orbs
                    Item {
                        anchors.fill: parent
                        visible: lockRoot.ambientOrbs
                        opacity: surface.entered ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: Math.max(120, Math.round(380 * lockRoot.lockAnimFactor)) } }

                        Rectangle {
                            width: Math.min(parent.width, parent.height) * (0.48 + surface.liveAudioPeak * 0.14)
                            height: width
                            radius: width / 2
                            x: centerStage.x - width * 0.25 + Math.sin(lockRoot.wavePhase * 0.25) * 32
                            y: centerStage.y - height * 0.20 + Math.cos(lockRoot.wavePhase * 0.20) * 24
                            color: surface.artAccent
                            opacity: (lockRoot.isLight ? 0.16 : 0.12) + (surface.liveAudioPeak * 0.11)
                            Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
                            Behavior on color { ColorAnimation { duration: Theme.animSlow } }
                        }

                        Rectangle {
                            width: Math.min(parent.width, parent.height) * (0.40 + surface.liveAudioPeak * 0.12)
                            height: width
                            radius: width / 2
                            x: centerStage.x + centerStage.width * 0.35 - Math.cos(lockRoot.wavePhase * 0.22) * 28
                            y: centerStage.y + centerStage.height * 0.25 + Math.sin(lockRoot.wavePhase * 0.18) * 28
                            color: lockRoot.uiTertiary
                            opacity: (lockRoot.isLight ? 0.13 : 0.09) + (surface.liveAudioPeak * 0.08)
                            Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
                        }
                    }

                    // vignette framing
                    Rectangle {
                        id: vigRect
                        anchors.fill: parent
                        visible: lockRoot.vignetteStrength > 0.01
                        opacity: lockRoot.vignetteStrength

                        readonly property color vigColor: lockRoot.isLight
                            ? Theme.blend(Qt.rgba(0.84, 0.82, 0.88, 1.0), lockRoot.uiAccent, 0.16)
                            : Theme.shadow

                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.alpha(vigRect.vigColor, lockRoot.isLight ? 0.65 : 0.75) }
                            GradientStop { position: 0.22; color: "transparent" }
                            GradientStop { position: 0.78; color: "transparent" }
                            GradientStop { position: 1.0; color: Theme.alpha(vigRect.vigColor, lockRoot.isLight ? 0.75 : 0.85) }
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

                    // top-left user session pill (modularized)
                    LockSessionPill {
                        root: lockRoot
                        lockSurface: surface
                        lock: sessionLock
                    }

                    SequentialAnimation {
                        id: surpriseBurstAnim
                        NumberAnimation { target: surface; property: "stageBurstScale"; from: 1.0; to: 0.95; duration: 85; easing.type: Easing.OutQuad }
                        NumberAnimation { target: surface; property: "stageBurstScale"; from: 0.95; to: 1.0; duration: 250; easing.type: Easing.OutBack }
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

                    // top-right hardware & studio bar (modularized)
                    LockStatusBar {
                        id: statusBar
                        root: lockRoot
                        lockSurface: surface
                        cornerHover: cornerRevealHover
                        burstAnim: surpriseBurstAnim
                    }

                    // tabbed lock screen studio drawer (modularized)
                    LockStudioDrawer {
                        id: optionsCard
                        root: lockRoot
                        lockSurface: surface
                        statusBarItem: statusBar
                        burstAnim: surpriseBurstAnim
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

                        scale: {
                            if (surface.entered) return surface.stageBurstScale;
                            if (lockRoot.lockTransition === "zoom-snap") return 0.84;
                            if (lockRoot.lockTransition === "curtain-fade") return 0.96;
                            return 0.93;
                        }
                        opacity: surface.entered ? 1.0 : 0.0

                        transform: Translate {
                            y: {
                                if (surface.entered) return 0;
                                if (lockRoot.lockTransition === "slide-up") return 56;
                                if (lockRoot.lockTransition === "editorial-stagger") return 28;
                                if (lockRoot.lockTransition === "curtain-fade") return -24;
                                return 12;
                            }
                            Behavior on y {
                                NumberAnimation {
                                    duration: Math.max(100, screenCanvas.transMs)
                                    easing.type: lockRoot.lockTransition === "slide-up" ? Easing.OutBack : Theme.animEasingEntrance
                                }
                            }
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: Math.max(100, screenCanvas.transMs)
                                easing.type: lockRoot.lockTransition === "zoom-snap" ? Easing.OutBack : Theme.animEasingEntrance
                            }
                        }
                        Behavior on opacity { NumberAnimation { duration: Math.max(90, Math.round(screenCanvas.transMs * 0.8)) } }



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
                                    font.variableAxes: Theme.iconAxes
                                    font.pixelSize: Theme.fontSizeXs
                                    color: stageDragMouse.pressed ? lockRoot.uiOnAccent : lockRoot.uiAccent
                                }

                                Text {
                                    text: lockRoot.fmtText("drag stage (snaps to 50%) • double-click to center")
                                    font.family: Theme.fontMono
                                    font.variableAxes: Theme.monoAxes
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: Theme.monoWeightBold
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

                        // clock, date & quote block (modularized)
                        LockClockCard {
                            id: clockBlock
                            root: lockRoot
                            lockSurface: surface
                            stage: centerStage
                        }

                        // media player card with live waveforms (modularized)
                        LockMediaCard {
                            id: mediaBlock
                            root: lockRoot
                            lockSurface: surface
                            stage: centerStage
                            peakMonitor: lockPeakMonitor
                        }

                        // password input pill (modularized)
                        LockAuthCard {
                            id: passwordBlock
                            root: lockRoot
                            lockSurface: surface
                            stage: centerStage
                        }
                    }

                    // bottom power dock (modularized)
                    LockPowerDock {
                        root: lockRoot
                        lockSurface: surface
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
