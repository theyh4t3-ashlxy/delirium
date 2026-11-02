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
    property date currentTime: new Date()
    property date lockedAtTime: new Date()
    property string pendingPassword: ""
    property string sharedPassword: ""
    property bool revealPassword: false
    property int manualPlayerIndex: -1

    // Extensionless Quickshell-controlled state file (~/.config/quickshell/lockscreen/state)
    readonly property string configDir: Quickshell.env("XDG_CONFIG_HOME") || ((Quickshell.env("HOME") || "") + "/.config")
    readonly property string lockStatePath: configDir + "/quickshell/lockscreen/state"

    property bool stateLoaded: false
    property bool syncClockGlobal: false
    property bool sandboxClock24h: false
    property bool showSeconds: true
    property string clockStyle: "inline"       // "inline" | "stacked" | "minimal"
    property string secondsStyle: "badge"      // "badge" | "supersub" | "tower" | "inline"
    property string layoutPosition: "center"   // "center" | "top" | "bottom" | "left" | "right" | "custom"
    property string stackOrder: "clock,media,password"
    property bool dateAboveClock: false
    property bool freeDragMode: false
    property real customNormX: 0.5
    property real customNormY: 0.5

    property real clockScale: 1.0
    property string quoteMode: "hyprland"
    property real scrimDim: 0.58
    property real focusZoom: 1.05
    property bool showMediaCard: true
    property bool showMediaVisualizer: true
    property bool showUserPill: true
    property bool wallpaperSync: true
    property string localWallpaperOverride: ""

    property string hyprSplash: ""
    property string unhingedQuote: ""
    property real wavePhase: 0.0

    readonly property string currentUser: (Quickshell.env("USER") || "user").toLowerCase()
    readonly property string lockTokenPath: (Quickshell.env("XDG_RUNTIME_DIR") ?? "/tmp") + "/qs_session_locked.token"

    // Reactive clock state
    readonly property bool effectiveClock24h: sandboxClock24h
    readonly property bool effectiveShowSeconds: showSeconds

    // How long the screen has been locked
    readonly property string lockedDurationText: {
        let diffSec = Math.max(0, Math.floor((currentTime.getTime() - lockedAtTime.getTime()) / 1000));
        if (diffSec < 60) return "just locked";
        return "locked " + Theme.formatUptime(diffSec);
    }

    // Native PipeWire peak monitor for the lock screen media card
    PwNodePeakMonitor {
        id: lockPeakMonitor
        node: (typeof Pipewire !== "undefined") ? Pipewire?.defaultAudioSink : null
        enabled: lockRoot.locked && lockRoot.showMediaCard && lockRoot.showMediaVisualizer
    }

    // Read-once, write-debounced FileView controlled exclusively by Quickshell
    property FileView lockStateFile: FileView {
        path: lockRoot.lockStatePath
        blockLoading: false
        watchChanges: false
        printErrors: false
        onLoaded: {
            if (!lockRoot.stateLoaded) {
                lockRoot.loadState();
            }
        }
    }

    // Debounce disk writes so sliders, drags & toggles happen in 0ms without I/O stutter
    Timer {
        id: saveDebounceTimer
        interval: 120
        repeat: false
        onTriggered: lockRoot.flushStateToDisk()
    }

    function parseBool(val: string, fallback: bool): bool {
        let v = val.trim().toLowerCase();
        if (v === "1" || v === "true" || v === "yes") return true;
        if (v === "0" || v === "false" || v === "no") return false;
        return fallback;
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
                case "syncClockGlobal": lockRoot.syncClockGlobal = parseBool(v, lockRoot.syncClockGlobal); break;
                case "clock24h": lockRoot.sandboxClock24h = parseBool(v, lockRoot.sandboxClock24h); break;
                case "showSeconds": lockRoot.showSeconds = parseBool(v, lockRoot.showSeconds); break;
                case "clockStyle":
                    if (v === "inline" || v === "stacked" || v === "minimal") lockRoot.clockStyle = v;
                    break;
                case "secondsStyle":
                    if (v === "badge" || v === "supersub" || v === "tower" || v === "inline") lockRoot.secondsStyle = v;
                    break;
                case "layoutPosition":
                    if (["center", "top", "bottom", "left", "right", "custom"].includes(v)) lockRoot.layoutPosition = v;
                    break;
                case "stackOrder":
                    if (v.includes("clock") && v.includes("media") && v.includes("password")) lockRoot.stackOrder = v;
                    break;
                case "dateAboveClock": lockRoot.dateAboveClock = parseBool(v, lockRoot.dateAboveClock); break;
                case "customNormX": {
                    let nx = parseFloat(v);
                    if (!isNaN(nx) && nx >= 0.0 && nx <= 1.0) lockRoot.customNormX = nx;
                    break;
                }
                case "customNormY": {
                    let ny = parseFloat(v);
                    if (!isNaN(ny) && ny >= 0.0 && ny <= 1.0) lockRoot.customNormY = ny;
                    break;
                }
                case "clockScale": {
                    let num = parseFloat(v);
                    if (!isNaN(num) && num >= 0.65 && num <= 1.65) lockRoot.clockScale = num;
                    break;
                }
                case "quoteMode": if (v !== "") lockRoot.quoteMode = v; break;
                case "scrimDim": {
                    let dim = parseFloat(v);
                    if (!isNaN(dim) && dim >= 0.1 && dim <= 0.98) lockRoot.scrimDim = dim;
                    break;
                }
                case "focusZoom": {
                    let zm = parseFloat(v);
                    if (!isNaN(zm) && zm >= 1.0 && zm <= 1.2) lockRoot.focusZoom = zm;
                    break;
                }
                case "showMedia": lockRoot.showMediaCard = parseBool(v, lockRoot.showMediaCard); break;
                case "showMediaVisualizer": lockRoot.showMediaVisualizer = parseBool(v, lockRoot.showMediaVisualizer); break;
                case "showUser": lockRoot.showUserPill = parseBool(v, lockRoot.showUserPill); break;
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

    function resetDefaults() {
        lockRoot.clockStyle = "inline";
        lockRoot.secondsStyle = "badge";
        lockRoot.layoutPosition = "center";
        lockRoot.stackOrder = "clock,media,password";
        lockRoot.dateAboveClock = false;
        lockRoot.freeDragMode = false;
        lockRoot.customNormX = 0.5;
        lockRoot.customNormY = 0.5;
        lockRoot.clockScale = 1.0;
        lockRoot.scrimDim = 0.58;
        lockRoot.focusZoom = 1.05;
        lockRoot.quoteMode = "hyprland";
        lockRoot.showMediaCard = true;
        lockRoot.showMediaVisualizer = true;
        lockRoot.showUserPill = true;
        lockRoot.wallpaperSync = true;
        lockRoot.localWallpaperOverride = "";
        lockRoot.saveSandbox();
    }

    // "Surprise Me!" randomizer: rolls a cohesive aesthetic & layout combination
    function surpriseMe() {
        const cStyles = ["inline", "stacked", "minimal"];
        const sStyles = ["badge", "supersub", "tower", "inline"];
        const positions = ["center", "top", "bottom", "left", "right"];
        const orders = [
            "clock,media,password",
            "clock,password,media",
            "media,clock,password"
        ];
        const qModes = ["hyprland", "unhinged"];

        lockRoot.clockStyle = cStyles[Math.floor(Math.random() * cStyles.length)];
        lockRoot.secondsStyle = sStyles[Math.floor(Math.random() * sStyles.length)];
        lockRoot.showSeconds = true;
        lockRoot.layoutPosition = positions[Math.floor(Math.random() * positions.length)];
        lockRoot.stackOrder = orders[Math.floor(Math.random() * orders.length)];
        lockRoot.dateAboveClock = Math.random() > 0.5;
        lockRoot.sandboxClock24h = Math.random() > 0.45;
        lockRoot.clockScale = Math.round((0.86 + Math.random() * 0.42) * 100) / 100;
        lockRoot.scrimDim = Math.round((0.38 + Math.random() * 0.38) * 100) / 100;
        lockRoot.focusZoom = Math.round((1.03 + Math.random() * 0.09) * 100) / 100;
        lockRoot.quoteMode = qModes[Math.floor(Math.random() * qModes.length)];
        lockRoot.refreshQuotes();
        lockRoot.saveSandbox();
    }

    function saveSandbox() {
        if (lockRoot.syncClockGlobal && typeof Settings !== "undefined" && Settings) {
            let fmt = lockRoot.sandboxClock24h
                ? (lockRoot.showSeconds ? "HH:mm:ss" : "HH:mm")
                : (lockRoot.showSeconds ? "h:mm:ss ap" : "h:mm ap");
            Settings.clockFormat = fmt;
            Settings.clock24h = lockRoot.sandboxClock24h;
            Settings.clockMilitary = lockRoot.sandboxClock24h;
            Settings.clockShowSeconds = lockRoot.showSeconds;
        }
        saveDebounceTimer.restart();
    }

    function flushStateToDisk() {
        let lines = [
            "syncClockGlobal=" + (lockRoot.syncClockGlobal ? "1" : "0"),
            "clock24h=" + (lockRoot.sandboxClock24h ? "1" : "0"),
            "showSeconds=" + (lockRoot.showSeconds ? "1" : "0"),
            "clockStyle=" + lockRoot.clockStyle,
            "secondsStyle=" + lockRoot.secondsStyle,
            "layoutPosition=" + lockRoot.layoutPosition,
            "stackOrder=" + lockRoot.stackOrder,
            "dateAboveClock=" + (lockRoot.dateAboveClock ? "1" : "0"),
            "customNormX=" + Number(lockRoot.customNormX).toFixed(4),
            "customNormY=" + Number(lockRoot.customNormY).toFixed(4),
            "clockScale=" + Number(lockRoot.clockScale).toFixed(2),
            "quoteMode=" + lockRoot.quoteMode,
            "scrimDim=" + Number(lockRoot.scrimDim).toFixed(2),
            "focusZoom=" + Number(lockRoot.focusZoom).toFixed(3),
            "showMedia=" + (lockRoot.showMediaCard ? "1" : "0"),
            "showMediaVisualizer=" + (lockRoot.showMediaVisualizer ? "1" : "0"),
            "showUser=" + (lockRoot.showUserPill ? "1" : "0"),
            "wallpaperSync=" + (lockRoot.wallpaperSync ? "1" : "0"),
            "customWallpaper=" + lockRoot.localWallpaperOverride
        ];
        lockStateFile.setText(lines.join("\n") + "\n");

        if (lockRoot.syncClockGlobal && typeof Settings !== "undefined" && Settings?.save) {
            Settings.save();
        }
    }

    property FileView lockTokenFile: FileView {
        path: lockRoot.lockTokenPath
        blockLoading: true
        watchChanges: false
        printErrors: false
        onLoaded: {
            let t = text();
            if (t && t.trim() === "locked" && !lockRoot.locked) {
                lockRoot.locked = true;
            }
        }
    }

    property Process splashProc: Process {
        command: ["hyprctl", "splash"]
        stdout: StdioCollector {
            onStreamFinished: {
                let raw = (text || "").trim().toLowerCase();
                if (raw !== "" && !raw.startsWith("error") && !raw.startsWith("unknown")) {
                    lockRoot.hyprSplash = raw;
                } else if (lockRoot.hyprSplash === "") {
                    lockRoot.hyprSplash = "hyprland: wayland compositor";
                }
            }
        }
    }

    function refreshQuotes() {
        splashProc.running = true;
        let pool = Theme.flavorQuotes?.system;
        if (pool && pool.length > 0) {
            let idx = Math.floor(Math.random() * pool.length);
            lockRoot.unhingedQuote = (pool[idx] || "").toLowerCase();
        } else if (Theme.getFlavor) {
            lockRoot.unhingedQuote = (Theme.getFlavor("system", "") || "").toLowerCase();
        }
    }

    readonly property string activeQuoteText: {
        if (lockRoot.quoteMode === "off") return "";
        if (lockRoot.quoteMode === "unhinged") {
            return lockRoot.unhingedQuote || (Theme.getFlavor ? Theme.getFlavor("system", "") : "");
        }
        return lockRoot.hyprSplash || (Theme.getFlavor ? Theme.getFlavor("system", "") : "");
    }

    function fixCoverUrl(url) {
        if (!url || typeof url !== "string") return "";
        let cleaned = url.trim();
        if (cleaned.startsWith("/")) return "file://" + cleaned;
        return cleaned;
    }

    function formatTime(seconds) {
        if (seconds === undefined || seconds === null || isNaN(seconds) || seconds < 0) return "0:00";
        let sec = Math.floor(seconds);
        let m = Math.floor(sec / 60);
        let s = sec % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    Component.onCompleted: {
        refreshQuotes();
        let t = lockTokenFile.text();
        if (t && t.trim() === "locked" && !lockRoot.locked) {
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

    onLockedChanged: {
        if (locked) {
            currentTime = new Date();
            lockedAtTime = new Date();
            authFailed = false;
            isChecking = false;
            pendingPassword = "";
            sharedPassword = "";
            revealPassword = false;
            freeDragMode = false;
            if (syncClockGlobal && typeof Settings !== "undefined" && Settings) {
                if (Settings.clock24h !== undefined) sandboxClock24h = Boolean(Settings.clock24h);
                if (Settings.clockShowSeconds !== undefined) showSeconds = Boolean(Settings.clockShowSeconds);
            }
            refreshQuotes();
            lockTokenFile.setText("locked");
        } else {
            sharedPassword = "";
            revealPassword = false;
            freeDragMode = false;
            lockTokenFile.setText("");
            Quickshell.execDetached(["rm", "-f", lockTokenPath]);
        }
    }

    Timer {
        interval: 1000
        running: lockRoot.locked
        repeat: true
        onTriggered: lockRoot.currentTime = new Date()
    }

    Timer {
        interval: 80
        running: lockRoot.locked && lockRoot.showMediaCard && lockRoot.showMediaVisualizer
        repeat: true
        onTriggered: {
            lockRoot.wavePhase = (lockRoot.wavePhase + 0.30) % (Math.PI * 20);
        }
    }

    Timer {
        id: pamSafetyTimeout
        interval: 8000
        onTriggered: {
            if (lockRoot.isChecking) {
                pam.abort();
                lockRoot.isChecking = false;
                lockRoot.pendingPassword = "";
                lockRoot.authFailed = true;
                lockRoot.triggerShake();
            }
        }
    }

    IpcHandler {
        target: "lock"
        function lock(): void {
            lockRoot.locked = true;
        }
    }

    PamContext {
        id: pam
        config: "login"
        user: Quickshell.env("USER") ?? ""

        function handleResponse(): void {
            if (responseRequired && lockRoot.pendingPassword) {
                let pw = lockRoot.pendingPassword;
                lockRoot.pendingPassword = "";
                pam.respond(pw);
            }
        }

        onPamMessage: handleResponse()
        onResponseRequiredChanged: handleResponse()

        onCompleted: (result) => {
            pamSafetyTimeout.stop();
            lockRoot.isChecking = false;
            lockRoot.pendingPassword = "";

            if (result === PamResult.Success) {
                lockRoot.locked = false;
                lockRoot.authFailed = false;
            } else {
                lockRoot.authFailed = true;
                lockRoot.triggerShake();
                shakeTimer.restart();
            }
        }

        onError: (err) => {
            console.warn("[LockScreen PAM Error]:", err);
        }
    }

    function tryUnlock(pw: string) {
        if (isChecking || !pw || pw.length === 0) return;

        isChecking = true;
        authFailed = false;
        pendingPassword = pw;
        sharedPassword = "";
        pamSafetyTimeout.restart();

        if (!pam.start()) {
            pamSafetyTimeout.stop();
            isChecking = false;
            pendingPassword = "";
            authFailed = true;
            triggerShake();
        }
    }

    Timer {
        id: shakeTimer
        interval: 1600
        onTriggered: lockRoot.authFailed = false
    }

    WlSessionLock {
        id: sessionLock
        locked: lockRoot.locked

        surface: Component {
            WlSessionLockSurface {
                id: surface

                property string pendingPowerAction: ""
                property bool optionsOpen: false
                property bool entered: false
                property bool volumeHudVisible: false
                property real trackPosition: activePlayer?.position ?? 0

                Component.onCompleted: {
                    entered = true;
                }

                Timer {
                    id: powerActionResetTimer
                    interval: 3500
                    onTriggered: surface.pendingPowerAction = ""
                }

                Timer {
                    id: volumeHudTimer
                    interval: 1400
                    onTriggered: surface.volumeHudVisible = false
                }

                function requestPowerAction(action: string, cmd: var) {
                    if (surface.pendingPowerAction === action) {
                        surface.pendingPowerAction = "";
                        powerActionResetTimer.stop();
                        Quickshell.execDetached(cmd);
                    } else {
                        surface.pendingPowerAction = action;
                        powerActionResetTimer.restart();
                    }
                }

                // Smart MPRIS player resolution
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
                readonly property string coverArtUrl: lockRoot.fixCoverUrl(activePlayer?.trackArtUrl)

                Connections {
                    target: surface.activePlayer
                    function onPositionChanged() {
                        surface.trackPosition = surface.activePlayer?.position ?? 0;
                    }
                }

                Timer {
                    interval: 500
                    running: lockRoot.locked && surface.playerIsPlaying && lockRoot.showMediaCard
                    repeat: true
                    onTriggered: {
                        if (surface.activePlayer) {
                            surface.trackPosition = surface.activePlayer.position ?? 0;
                        }
                    }
                }

                ColorQuantizer {
                    id: lockArtQuantizer
                    depth: 2
                    source: surface.coverArtUrl
                }

                readonly property color artAccent: {
                    if (Theme.isMonochrome) return Theme.primary;
                    if (surface.coverArtUrl !== "" && lockArtQuantizer.colors && lockArtQuantizer.colors.length > 0) {
                        for (let i = 0; i < lockArtQuantizer.colors.length; i++) {
                            let c = lockArtQuantizer.colors[i];
                            if (!c) continue;
                            let mx = Math.max(c.r, c.g, c.b);
                            let mn = Math.min(c.r, c.g, c.b);
                            if (mx > 0.25 && (mx - mn) > 0.15) {
                                return Theme.blend(c, Theme.primary, 0.45);
                            }
                        }
                    }
                    return Theme.primary;
                }

                // Squishy Theme-cohesive option chip
                component OptChip: Rectangle {
                    id: cRoot
                    property string label: ""
                    property bool selected: false
                    signal clicked()

                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    radius: selected ? Theme.radiusMd : Theme.radiusPill
                    color: selected
                        ? Theme.primary_overlay
                        : (cMouse.pressed ? Theme.widgetActive : (cMouse.containsMouse ? Theme.widgetHover : Theme.widgetBg))
                    border.color: selected
                        ? Theme.alpha(Theme.primary, 0.65)
                        : (cMouse.containsMouse ? Theme.alpha(Theme.primary, 0.35) : Theme.widgetBorder)
                    border.width: 1

                    Behavior on radius { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
                    Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                    Text {
                        anchors.centerIn: parent
                        text: cRoot.label
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXs
                        font.weight: cRoot.selected ? Theme.fontWeightBold : Theme.fontWeightMedium
                        color: cRoot.selected ? Theme.primary : Theme.textSecondary
                    }

                    MouseArea {
                        id: cMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: cRoot.clicked()
                    }
                }

                // Interactive, wheel- & drag-enabled Material 3 Expressive slider
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

                    readonly property real ratio: Math.max(0.0, Math.min(1.0, (value - from) / Math.max(0.0001, to - from)))

                    function setFromRatio(r: real) {
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
                            color: sMouse.pressed || sMouse.containsMouse ? Theme.primary : Theme.textSecondary
                        }

                        Text {
                            text: sRoot.label
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: Theme.fontWeightDemiBold
                            color: Theme.textSecondary
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            height: 18
                            implicitWidth: valTxt.implicitWidth + 10
                            radius: Theme.radiusPill
                            color: sMouse.pressed ? Theme.primary_overlay : Theme.widgetBg
                            border.color: sMouse.pressed ? Theme.alpha(Theme.primary, 0.5) : Theme.widgetBorder
                            border.width: 1

                            Text {
                                id: valTxt
                                anchors.centerIn: parent
                                text: sRoot.displayText
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeXs
                                font.weight: Theme.fontWeightBold
                                color: Theme.primary
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
                            radius: Theme.radiusPill
                            color: Theme.widgetBg
                            border.color: sMouse.containsMouse ? Theme.alpha(Theme.primary, 0.35) : Theme.widgetBorder
                            border.width: 1

                            Behavior on height { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
                            Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: Math.max(parent.height, parent.width * sRoot.ratio)
                                radius: Theme.radiusPill
                                color: sMouse.pressed
                                    ? Theme.statePress(Theme.primary, Theme.on_primary)
                                    : (sMouse.containsMouse ? Theme.stateHover(Theme.primary, Theme.on_primary) : Theme.primary)

                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            }
                        }

                        Rectangle {
                            width: sMouse.pressed ? 6 : 4
                            height: sMouse.pressed ? 20 : (sMouse.containsMouse ? 18 : 14)
                            radius: Theme.radiusPill
                            color: Theme.on_surface
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.max(0, Math.min(parent.width - width, (parent.width * sRoot.ratio) - (width / 2)))

                            Behavior on width { NumberAnimation { duration: Theme.animFast } }
                            Behavior on height { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animExpressiveEasing } }
                        }

                        MouseArea {
                            id: sMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: (mouse) => sRoot.setFromRatio(mouse.x / width)
                            onPositionChanged: (mouse) => {
                                if (pressed) sRoot.setFromRatio(mouse.x / width);
                            }
                            onWheel: (wheel) => {
                                let dir = wheel.angleDelta.y > 0 ? 1 : -1;
                                let next = Math.max(sRoot.from, Math.min(sRoot.to, sRoot.value + (dir * sRoot.stepSize)));
                                sRoot.moved(next);
                            }
                        }
                    }
                }

                // Single-click full-row toggle item
                component SandboxToggleRow: Rectangle {
                    id: tRow
                    property string icon: ""
                    property string label: ""
                    property bool checked: false
                    signal toggled()

                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: Theme.radiusSm
                    color: rowMouse.containsMouse ? Theme.widgetHover : "transparent"

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
                            color: tRow.checked ? Theme.primary : Theme.textSecondary
                            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
                        }

                        Text {
                            text: tRow.label
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textPrimary
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
                        cursorShape: Qt.PointingHandCursor
                        onClicked: tRow.toggled()
                    }
                }

                // Squishy 2-step confirmation power pill
                component PowerPill: Rectangle {
                    id: pRoot
                    property string actionId: ""
                    property string icon: ""
                    property string label: ""
                    property var command: []

                    readonly property bool isArmed: surface.pendingPowerAction === pRoot.actionId

                    height: 40
                    implicitWidth: isArmed ? (pRow.implicitWidth + 28) : 40
                    radius: isArmed ? Theme.radiusMd : Theme.radiusPill
                    color: isArmed
                        ? (pMouse.pressed ? Theme.statePress(Theme.error, Theme.on_error) : Theme.error)
                        : (pMouse.pressed ? Theme.widgetActive : (pMouse.containsMouse ? Theme.pillHover : Theme.pillBg))
                    border.color: isArmed
                        ? Theme.error
                        : (pMouse.containsMouse ? Theme.alpha(Theme.primary, 0.55) : Theme.pillBorder)
                    border.width: (isArmed || pMouse.containsMouse || Theme.pillBorder.a > 0) ? 1 : 0

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
                            color: pRoot.isArmed ? Theme.on_error : (pMouse.containsMouse ? Theme.primary : Theme.textPrimary)
                        }

                        Text {
                            visible: pRoot.isArmed
                            text: "confirm " + pRoot.label + "?"
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
                    color: Theme.background
                    clip: true

                    focus: true
                    Keys.forwardTo: [pwInput]

                    readonly property bool isDeepFocused: pwInput.text.length > 0 || surface.optionsOpen || lockRoot.isChecking

                    MouseArea {
                        anchors.fill: parent
                        z: -1
                        onClicked: {
                            surface.optionsOpen = false;
                            surface.pendingPowerAction = "";
                            pwInput.forceActiveFocus();
                        }
                    }

                    // Backdrop wallpaper with smooth depth-of-field zoom
                    Image {
                        anchors.fill: parent
                        source: {
                            let wp = "";
                            if (!lockRoot.wallpaperSync && lockRoot.localWallpaperOverride !== "") {
                                wp = lockRoot.localWallpaperOverride;
                            } else {
                                wp = WallpaperService?.currentWallpaperPath ?? lockRoot.localWallpaperOverride ?? "";
                            }
                            if (!wp || wp === "" || /\.(mp4|webm|mkv|mov)$/i.test(wp)) {
                                wp = WallpaperService?.currWallStatic ?? ((Quickshell.env("HOME") || "") + "/.curr_wall_static.jpg");
                            }
                            if (!wp) return "";
                            return (wp.startsWith("file://") || wp.startsWith("http://") || wp.startsWith("https://")) ? wp : ("file://" + wp);
                        }
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        scale: parent.isDeepFocused ? lockRoot.focusZoom : 1.0

                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.expressiveSlow
                                easing.type: Theme.animEasing
                            }
                        }
                    }

                    // Adjustable Matugen scrim overlay
                    Rectangle {
                        anchors.fill: parent
                        color: Theme.scrim
                        opacity: Math.min(0.96, lockRoot.scrimDim + (parent.isDeepFocused ? 0.08 : 0.0))
                        Behavior on opacity { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.animEasing } }
                    }

                    // Top-left user session & lock duration badge
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: 32
                        anchors.topMargin: surface.entered ? 32 : 12
                        opacity: surface.entered ? 1.0 : 0.0
                        visible: lockRoot.showUserPill
                        height: 36
                        implicitWidth: userRow.implicitWidth + 22
                        radius: Theme.radiusPill
                        color: Theme.pillBg
                        border.color: Theme.pillBorder
                        border.width: Theme.pillBorder.a > 0 ? 1 : 0

                        Behavior on anchors.topMargin { NumberAnimation { duration: Theme.expressiveDefault; easing.type: Theme.animEasingEntrance } }
                        Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }

                        RowLayout {
                            id: userRow
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                text: Theme.iconDistro ?? Theme.iconUser
                                font.family: Theme.fontIcon
                                font.pixelSize: Theme.fontSizeMd
                                color: Theme.primary
                            }

                            Text {
                                text: lockRoot.currentUser
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeSm
                                font.weight: Theme.fontWeightDemiBold
                                color: Theme.textPrimary
                            }

                            Text {
                                text: "• " + lockRoot.lockedDurationText
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.textSecondary
                            }
                        }
                    }

                    // Top-right status pill
                    Rectangle {
                        id: statusBar
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 32
                        anchors.topMargin: surface.entered ? 32 : 12
                        opacity: surface.entered ? 1.0 : 0.0
                        height: 36
                        implicitWidth: statusRow.implicitWidth + 22
                        radius: Theme.radiusPill
                        color: surface.optionsOpen ? Theme.widgetActive : Theme.pillBg
                        border.color: surface.optionsOpen ? Theme.alpha(Theme.primary, 0.55) : Theme.pillBorder
                        border.width: (surface.optionsOpen || Theme.pillBorder.a > 0) ? 1 : 0

                        Behavior on anchors.topMargin { NumberAnimation { duration: Theme.expressiveDefault; easing.type: Theme.animEasingEntrance } }
                        Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
                        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
                        Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                        RowLayout {
                            id: statusRow
                            anchors.centerIn: parent
                            spacing: 14

                            RowLayout {
                                spacing: 6
                                Text {
                                    text: Theme.getWifiIcon(
                                        NetworkService?.signalStrength ?? 100,
                                        NetworkService?.isConnected ?? false,
                                        NetworkService?.isWiredConnected ?? false
                                    )
                                    font.family: Theme.fontIcon
                                    font.pixelSize: Theme.fontSizeMd
                                    color: (NetworkService?.isConnected ?? false) ? Theme.primary : Theme.textSecondary
                                }
                                Text {
                                    text: ((NetworkService?.isWiredConnected ?? false)
                                        ? "wired"
                                        : (NetworkService?.activeSsid || ((NetworkService?.isConnected ?? false) ? "connected" : "offline"))
                                    ).toLowerCase()
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: Theme.fontWeightMedium
                                    color: Theme.textPrimary
                                }
                            }

                            RowLayout {
                                spacing: 6
                                visible: UPower.displayDevice?.isPresent ?? false

                                readonly property int batPct: {
                                    let p = UPower.displayDevice?.percentage ?? 1.0;
                                    return Math.min(100, Math.max(0, Math.round(p * 100)));
                                }
                                readonly property bool isCharging: UPower.displayDevice?.state === UPowerDeviceState.Charging

                                Text {
                                    text: Theme.getBatteryIcon(parent.batPct, parent.isCharging, !(UPower?.onBattery ?? true), false)
                                    font.family: Theme.fontIcon
                                    font.pixelSize: Theme.fontSizeMd
                                    color: Theme.getBatteryColor(parent.batPct, parent.isCharging)
                                }
                                Text {
                                    text: parent.batPct + "%"
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: Theme.fontWeightMedium
                                    color: Theme.textPrimary
                                }
                            }

                            IconButton {
                                icon: Theme.iconSparkles
                                iconSize: Theme.fontSizeSm
                                tooltip: "surprise me! (randomize)"
                                onClicked: {
                                    surpriseBurstAnim.restart();
                                    lockRoot.surpriseMe();
                                }
                            }

                            IconButton {
                                icon: Theme.iconSliders
                                iconSize: Theme.fontSizeSm
                                tooltip: "customize lock screen"
                                highlighted: surface.optionsOpen
                                onClicked: surface.optionsOpen = !surface.optionsOpen
                            }
                        }
                    }

                    // Sandbox & global customization dropdown panel
                    Rectangle {
                        id: optionsCard
                        anchors.top: statusBar.bottom
                        anchors.right: statusBar.right
                        anchors.topMargin: 10
                        width: 356
                        height: Math.min(parent.height - 110, optionsLayout.implicitHeight + (Theme.popupPadding * 2))
                        radius: Theme.radiusLg
                        color: Theme.popupBg
                        border.color: Theme.popupBorderColor
                        border.width: Theme.popupBorderWidth
                        visible: opacity > 0
                        opacity: surface.optionsOpen ? 1.0 : 0.0
                        scale: surface.optionsOpen ? 1.0 : 0.95
                        transformOrigin: Item.TopRight
                        clip: true
                        z: 100

                        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.animEasing } }
                        Behavior on scale { NumberAnimation { duration: Theme.expressiveFast; easing.type: Theme.animEasingEntrance } }

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
                                        color: Theme.primary
                                    }

                                    Text {
                                        text: "lock screen studio"
                                        font.family: Theme.fontDisplay
                                        font.pixelSize: Theme.fontSizeMd
                                        font.weight: Theme.fontWeightBold
                                        color: Theme.textPrimary
                                        Layout.fillWidth: true
                                    }

                                    Rectangle {
                                        height: 22
                                        implicitWidth: scopeBadge.implicitWidth + 12
                                        radius: Theme.radiusPill
                                        color: lockRoot.syncClockGlobal ? Theme.primary_overlay : Theme.pillBg
                                        border.color: lockRoot.syncClockGlobal ? Theme.alpha(Theme.primary, 0.5) : Theme.pillBorder
                                        border.width: 1

                                        Text {
                                            id: scopeBadge
                                            anchors.centerIn: parent
                                            text: lockRoot.syncClockGlobal ? "global" : "sandbox"
                                            font.family: Theme.fontMono
                                            font.pixelSize: Theme.fontSizeXs
                                            font.weight: Theme.fontWeightBold
                                            color: lockRoot.syncClockGlobal ? Theme.primary : Theme.textSecondary
                                        }
                                    }

                                    IconButton {
                                        icon: Theme.iconRefresh
                                        iconSize: Theme.fontSizeXs
                                        tooltip: "reset defaults"
                                        onClicked: lockRoot.resetDefaults()
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

                                // Featured "Surprise Me!" Hero Action Button
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 38
                                    radius: surpriseMouse.pressed ? Theme.radiusPill : Theme.radiusMd
                                    color: surpriseMouse.pressed
                                        ? Theme.statePress(Theme.primary, Theme.on_primary)
                                        : (surpriseMouse.containsMouse
                                            ? Theme.stateHover(Theme.primary, Theme.on_primary)
                                            : Theme.primary)

                                    Behavior on radius { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
                                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 8

                                        Text {
                                            text: Theme.iconSparkles
                                            font.family: Theme.fontIcon
                                            font.pixelSize: Theme.fontSizeMd
                                            color: Theme.on_primary
                                        }

                                        Text {
                                            text: "surprise me! (randomize layout & vibe)"
                                            font.family: Theme.fontDisplay
                                            font.pixelSize: Theme.fontSizeXs
                                            font.weight: Theme.fontWeightBold
                                            color: Theme.on_primary
                                        }
                                    }

                                    MouseArea {
                                        id: surpriseMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            surpriseBurstAnim.restart();
                                            lockRoot.surpriseMe();
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: Theme.popupDividerHeight
                                    color: Theme.widgetBorder
                                }

                                // Screen Position & Free Drag
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: "screen position"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightDemiBold
                                        color: Theme.textSecondary
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        visible: lockRoot.layoutPosition === "custom"
                                        text: "custom dragged"
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeXs
                                        color: Theme.primary
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

                                // Block Stack Order (Clock / Media / Password)
                                Text {
                                    text: "stack order (click to slide blocks)"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: Theme.fontWeightDemiBold
                                    color: Theme.textSecondary
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 5

                                    OptChip {
                                        label: "clock • media • pw"
                                        selected: lockRoot.stackOrder === "clock,media,password"
                                        onClicked: {
                                            lockRoot.stackOrder = "clock,media,password";
                                            lockRoot.saveSandbox();
                                        }
                                    }

                                    OptChip {
                                        label: "clock • pw • media"
                                        selected: lockRoot.stackOrder === "clock,password,media"
                                        onClicked: {
                                            lockRoot.stackOrder = "clock,password,media";
                                            lockRoot.saveSandbox();
                                        }
                                    }

                                    OptChip {
                                        label: "media • clock • pw"
                                        selected: lockRoot.stackOrder === "media,clock,password"
                                        onClicked: {
                                            lockRoot.stackOrder = "media,clock,password";
                                            lockRoot.saveSandbox();
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: Theme.popupDividerHeight
                                    color: Theme.widgetBorder
                                }

                                // Clock Layout Style
                                Text {
                                    text: "clock style & format"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: Theme.fontWeightDemiBold
                                    color: Theme.textSecondary
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    OptChip {
                                        label: "inline"
                                        selected: lockRoot.clockStyle === "inline"
                                        onClicked: {
                                            lockRoot.clockStyle = "inline";
                                            lockRoot.saveSandbox();
                                        }
                                    }

                                    OptChip {
                                        label: "stacked"
                                        selected: lockRoot.clockStyle === "stacked"
                                        onClicked: {
                                            lockRoot.clockStyle = "stacked";
                                            lockRoot.saveSandbox();
                                        }
                                    }

                                    OptChip {
                                        label: "minimal"
                                        selected: lockRoot.clockStyle === "minimal"
                                        onClicked: {
                                            lockRoot.clockStyle = "minimal";
                                            lockRoot.saveSandbox();
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

                                // Proportional Seconds Style Picker
                                Text {
                                    visible: lockRoot.effectiveShowSeconds
                                    text: "seconds design"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: Theme.fontWeightDemiBold
                                    color: Theme.textSecondary
                                }

                                RowLayout {
                                    visible: lockRoot.effectiveShowSeconds
                                    Layout.fillWidth: true
                                    spacing: 5

                                    OptChip {
                                        label: "big pill"
                                        selected: lockRoot.secondsStyle === "badge"
                                        onClicked: {
                                            lockRoot.secondsStyle = "badge";
                                            lockRoot.saveSandbox();
                                        }
                                    }

                                    OptChip {
                                        label: "split"
                                        selected: lockRoot.secondsStyle === "supersub"
                                        onClicked: {
                                            lockRoot.secondsStyle = "supersub";
                                            lockRoot.saveSandbox();
                                        }
                                    }

                                    OptChip {
                                        label: "tower / bar"
                                        selected: lockRoot.secondsStyle === "tower"
                                        onClicked: {
                                            lockRoot.secondsStyle = "tower";
                                            lockRoot.saveSandbox();
                                        }
                                    }

                                    OptChip {
                                        label: "inline"
                                        selected: lockRoot.secondsStyle === "inline"
                                        onClicked: {
                                            lockRoot.secondsStyle = "inline";
                                            lockRoot.saveSandbox();
                                        }
                                    }
                                }

                                // Interactive Sliders
                                SandboxSlider {
                                    label: "clock scale"
                                    icon: Theme.iconClock
                                    from: 0.70
                                    to: 1.45
                                    stepSize: 0.03
                                    value: lockRoot.clockScale
                                    displayText: Math.round(lockRoot.clockScale * 100) + "%"
                                    onMoved: (v) => {
                                        lockRoot.clockScale = v;
                                        lockRoot.saveSandbox();
                                    }
                                }

                                SandboxSlider {
                                    label: "backdrop dim"
                                    icon: Theme.iconMoon
                                    from: 0.15
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
                                    label: "focus depth zoom"
                                    icon: Theme.iconExpand
                                    from: 1.00
                                    to: 1.15
                                    stepSize: 0.01
                                    value: lockRoot.focusZoom
                                    displayText: Math.round((lockRoot.focusZoom - 1.0) * 100) + "%"
                                    onMoved: (v) => {
                                        lockRoot.focusZoom = v;
                                        lockRoot.saveSandbox();
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: Theme.popupDividerHeight
                                    color: Theme.widgetBorder
                                }

                                // Quote source selector
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Text {
                                        text: "quote source"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightDemiBold
                                        color: Theme.textSecondary
                                        Layout.fillWidth: true
                                    }

                                    IconButton {
                                        icon: Theme.iconRefresh
                                        iconSize: Theme.fontSizeXs
                                        tooltip: "roll new quote"
                                        visible: lockRoot.quoteMode !== "off"
                                        onClicked: lockRoot.refreshQuotes()
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    OptChip {
                                        label: "hyprctl"
                                        selected: lockRoot.quoteMode === "hyprland"
                                        onClicked: {
                                            lockRoot.quoteMode = "hyprland";
                                            lockRoot.refreshQuotes();
                                            lockRoot.saveSandbox();
                                        }
                                    }

                                    OptChip {
                                        label: "unhinged"
                                        selected: lockRoot.quoteMode === "unhinged"
                                        onClicked: {
                                            lockRoot.quoteMode = "unhinged";
                                            lockRoot.refreshQuotes();
                                            lockRoot.saveSandbox();
                                        }
                                    }

                                    OptChip {
                                        label: "off"
                                        selected: lockRoot.quoteMode === "off"
                                        onClicked: {
                                            lockRoot.quoteMode = "off";
                                            lockRoot.saveSandbox();
                                        }
                                    }
                                }

                                // Shuffle wallpaper button
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Theme.popupActionHeight + 2
                                    radius: Theme.radiusMd
                                    color: shuffleMouse.pressed
                                        ? Theme.widgetActive
                                        : (shuffleMouse.containsMouse ? Theme.widgetHover : Theme.widgetBg)
                                    border.color: shuffleMouse.containsMouse ? Theme.alpha(Theme.primary, 0.55) : Theme.widgetBorder
                                    border.width: 1

                                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
                                    Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        spacing: 8

                                        Text {
                                            text: Theme.iconShuffle
                                            font.family: Theme.fontIcon
                                            font.pixelSize: Theme.fontSizeMd
                                            color: Theme.primary
                                        }

                                        Text {
                                            text: "shuffle lock wallpaper"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeXs
                                            font.weight: Theme.fontWeightDemiBold
                                            color: Theme.textPrimary
                                            Layout.fillWidth: true
                                        }
                                    }

                                    MouseArea {
                                        id: shuffleMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            let nextWp = lockRoot.pickRandomWallpaperInMemory();
                                            if (nextWp && nextWp !== "") {
                                                lockRoot.wallpaperSync = false;
                                                lockRoot.localWallpaperOverride = nextWp;
                                                lockRoot.saveSandbox();
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: Theme.popupDividerHeight
                                    color: Theme.widgetBorder
                                }

                                // Single-click toggles
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    SandboxToggleRow {
                                        icon: Theme.iconGrid
                                        label: "free drag mode (move stack with mouse)"
                                        checked: lockRoot.freeDragMode
                                        onToggled: {
                                            lockRoot.freeDragMode = !lockRoot.freeDragMode;
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
                                        label: "sync clock globally across rice"
                                        checked: lockRoot.syncClockGlobal
                                        onToggled: {
                                            lockRoot.syncClockGlobal = !lockRoot.syncClockGlobal;
                                            lockRoot.saveSandbox();
                                        }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconWallpaper
                                        label: "sync wallpaper with desktop"
                                        checked: lockRoot.wallpaperSync
                                        onToggled: {
                                            lockRoot.wallpaperSync = !lockRoot.wallpaperSync;
                                            if (lockRoot.wallpaperSync) {
                                                lockRoot.localWallpaperOverride = "";
                                            }
                                            lockRoot.saveSandbox();
                                        }
                                    }

                                    SandboxToggleRow {
                                        icon: lockRoot.showMediaCard ? Theme.iconMusic : Theme.iconEyeOff
                                        label: "show now playing card"
                                        checked: lockRoot.showMediaCard
                                        onToggled: {
                                            lockRoot.showMediaCard = !lockRoot.showMediaCard;
                                            lockRoot.saveSandbox();
                                        }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconEqualizer
                                        label: "media spectrum & seekbar"
                                        checked: lockRoot.showMediaVisualizer
                                        onToggled: {
                                            lockRoot.showMediaVisualizer = !lockRoot.showMediaVisualizer;
                                            lockRoot.saveSandbox();
                                        }
                                    }

                                    SandboxToggleRow {
                                        icon: lockRoot.showUserPill ? Theme.iconUser : Theme.iconEyeOff
                                        label: "show user & lock timer badge"
                                        checked: lockRoot.showUserPill
                                        onToggled: {
                                            lockRoot.showUserPill = !lockRoot.showUserPill;
                                            lockRoot.saveSandbox();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Dynamic movable & reorderable lock stage
                    Item {
                        id: centerStage
                        width: 440
                        height: totalStageHeight

                        readonly property var orderList: (lockRoot.stackOrder || "clock,media,password").split(",")
                        readonly property int blockGap: 20

                        function blockHeight(name: string): real {
                            if (name === "clock") return clockBlock.implicitHeight;
                            if (name === "media") return mediaBlock.visible ? mediaBlock.implicitHeight : 0;
                            if (name === "password") return passwordBlock.implicitHeight;
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

                        // Target X/Y calculation from preset or custom drag coordinates
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

                        Behavior on x {
                            enabled: !stageDragMouse.pressed
                            NumberAnimation { duration: Theme.expressiveDefault; easing.type: Theme.animEasingEntrance }
                        }
                        Behavior on y {
                            enabled: !stageDragMouse.pressed
                            NumberAnimation { duration: Theme.expressiveDefault; easing.type: Theme.animEasingEntrance }
                        }

                        scale: surface.entered ? 1.0 : 0.94
                        opacity: surface.entered ? 1.0 : 0.0

                        Behavior on scale { NumberAnimation { duration: Theme.expressiveDefault; easing.type: Theme.animEasingEntrance } }
                        Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }

                        SequentialAnimation {
                            id: surpriseBurstAnim
                            NumberAnimation { target: centerStage; property: "scale"; from: 1.0; to: 0.95; duration: 90; easing.type: Easing.OutQuad }
                            NumberAnimation { target: centerStage; property: "scale"; from: 0.95; to: 1.0; duration: 260; easing.type: Easing.OutBack }
                        }

                        // Outline highlight when Free Drag Mode is active
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -14
                            radius: Theme.radiusXl
                            color: stageDragMouse.pressed ? Theme.alpha(Theme.primary, 0.08) : "transparent"
                            border.color: lockRoot.freeDragMode ? Theme.alpha(Theme.primary, 0.55) : "transparent"
                            border.width: lockRoot.freeDragMode ? 1 : 0
                            visible: lockRoot.freeDragMode
                        }

                        // Interactive Drag Handle Pill (when Free Drag Mode is enabled)
                        Rectangle {
                            id: dragHandlePill
                            visible: lockRoot.freeDragMode
                            anchors.top: parent.top
                            anchors.horizontalCenter: parent.horizontalCenter
                            height: 28
                            implicitWidth: dragHandleRow.implicitWidth + 20
                            radius: Theme.radiusPill
                            color: stageDragMouse.pressed ? Theme.primary : Theme.pillBg
                            border.color: Theme.primary
                            border.width: 1

                            RowLayout {
                                id: dragHandleRow
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: Theme.iconGrid
                                    font.family: Theme.fontIcon
                                    font.pixelSize: Theme.fontSizeXs
                                    color: stageDragMouse.pressed ? Theme.on_primary : Theme.primary
                                }

                                Text {
                                    text: "drag anywhere • double-click to center"
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: Theme.fontWeightBold
                                    color: stageDragMouse.pressed ? Theme.on_primary : Theme.textPrimary
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
                                    lockRoot.customNormX = newX / availW;
                                    lockRoot.customNormY = newY / availH;
                                    lockRoot.layoutPosition = "custom";
                                    lockRoot.saveSandbox();
                                }
                                onDoubleClicked: {
                                    lockRoot.layoutPosition = "center";
                                    lockRoot.customNormX = 0.5;
                                    lockRoot.customNormY = 0.5;
                                    lockRoot.saveSandbox();
                                }
                            }
                        }

                        // ==================== BLOCK 1: CLOCK + DATE + QUOTE ====================
                        ColumnLayout {
                            id: clockBlock
                            width: parent.width
                            y: centerStage.blockY("clock")
                            spacing: 6

                            Behavior on y { NumberAnimation { duration: Theme.expressiveDefault; easing.type: Theme.animEasingEntrance } }

                            readonly property int baseClockPx: Math.round((lockRoot.clockStyle === "minimal" ? 56 : 86) * Theme.fontScale * lockRoot.clockScale)
                            readonly property string mainHoursText: Qt.formatDateTime(lockRoot.currentTime, lockRoot.effectiveClock24h ? "HH" : "hh")
                            readonly property string mainMinutesText: Qt.formatDateTime(lockRoot.currentTime, "mm")
                            readonly property string secondsDigits: Qt.formatDateTime(lockRoot.currentTime, "ss")
                            readonly property string amPmText: Qt.formatDateTime(lockRoot.currentTime, "a").toLowerCase()

                            // Date ABOVE Clock option
                            Text {
                                visible: lockRoot.dateAboveClock
                                text: Qt.formatDateTime(lockRoot.currentTime, "dddd, MMMM d").toLowerCase()
                                font.family: Theme.fontDisplay
                                font.pixelSize: Theme.fontSizeMd
                                font.weight: Theme.fontWeightDemiBold
                                color: Theme.primary
                                Layout.alignment: Qt.AlignHCenter
                            }

                            // ---- INLINE / MINIMAL CLOCK ----
                            RowLayout {
                                visible: lockRoot.clockStyle !== "stacked"
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 10

                                // Main Time String
                                Text {
                                    text: {
                                        if (lockRoot.effectiveShowSeconds && lockRoot.secondsStyle === "inline") {
                                            let fmt = lockRoot.effectiveClock24h ? "HH:mm:ss" : "hh:mm:ss a";
                                            return Qt.formatDateTime(lockRoot.currentTime, fmt).toLowerCase();
                                        }
                                        if (!lockRoot.effectiveShowSeconds && !lockRoot.effectiveClock24h) {
                                            return Qt.formatDateTime(lockRoot.currentTime, "hh:mm a").toLowerCase();
                                        }
                                        return clockBlock.mainHoursText + ":" + clockBlock.mainMinutesText;
                                    }
                                    font.family: Theme.fontDisplay
                                    font.pixelSize: (lockRoot.effectiveShowSeconds && lockRoot.secondsStyle === "inline")
                                        ? Math.round(clockBlock.baseClockPx * 0.78)
                                        : clockBlock.baseClockPx
                                    font.weight: lockRoot.clockStyle === "minimal" ? Theme.fontWeightDemiBold : Theme.fontWeightBold
                                    color: Theme.textPrimary
                                    Layout.alignment: Qt.AlignVCenter

                                    Behavior on font.pixelSize { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
                                }

                                // Seconds Style 1: "badge" (Proportional Expressive Squircle Pill)
                                ColumnLayout {
                                    visible: lockRoot.effectiveShowSeconds && lockRoot.secondsStyle === "badge"
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 4

                                    Rectangle {
                                        readonly property int badgeFontPx: Math.max(18, Math.round(clockBlock.baseClockPx * 0.38))
                                        height: badgeFontPx + 14
                                        implicitWidth: secBadgeTxt.implicitWidth + 20
                                        radius: Theme.radiusMd
                                        color: Theme.primary_overlay
                                        border.color: Theme.alpha(Theme.primary, 0.55)
                                        border.width: 1

                                        Text {
                                            id: secBadgeTxt
                                            anchors.centerIn: parent
                                            text: clockBlock.secondsDigits
                                            font.family: Theme.fontMono
                                            font.pixelSize: parent.badgeFontPx
                                            font.weight: Theme.fontWeightBold
                                            color: Theme.primary
                                        }
                                    }

                                    Text {
                                        visible: !lockRoot.effectiveClock24h
                                        text: clockBlock.amPmText
                                        font.family: Theme.fontMono
                                        font.pixelSize: Math.max(11, Math.round(clockBlock.baseClockPx * 0.18))
                                        font.weight: Theme.fontWeightBold
                                        color: Theme.textSecondary
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                }

                                // Seconds Style 2: "supersub" (Typographic Flush Split Stack)
                                ColumnLayout {
                                    visible: lockRoot.effectiveShowSeconds && lockRoot.secondsStyle === "supersub"
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: -2

                                    Text {
                                        text: ":" + clockBlock.secondsDigits
                                        font.family: Theme.fontDisplay
                                        font.pixelSize: Math.max(20, Math.round(clockBlock.baseClockPx * 0.44))
                                        font.weight: Theme.fontWeightBold
                                        color: Theme.primary
                                    }

                                    Text {
                                        visible: !lockRoot.effectiveClock24h
                                        text: clockBlock.amPmText
                                        font.family: Theme.fontMono
                                        font.pixelSize: Math.max(12, Math.round(clockBlock.baseClockPx * 0.22))
                                        font.weight: Theme.fontWeightBold
                                        color: Theme.textSecondary
                                    }
                                }
                            }

                            // Seconds Style 3 ("tower" in inline mode): 60-second animated bar + proportional pill under clock
                            RowLayout {
                                visible: lockRoot.clockStyle !== "stacked" && lockRoot.effectiveShowSeconds && lockRoot.secondsStyle === "tower"
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 10

                                Rectangle {
                                    width: 150
                                    height: 8
                                    radius: Theme.radiusPill
                                    color: Theme.widgetBg
                                    border.color: Theme.widgetBorder
                                    border.width: 1

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: Math.max(parent.height, parent.width * ((lockRoot.currentTime.getSeconds() + 1) / 60.0))
                                        radius: Theme.radiusPill
                                        color: Theme.primary

                                        Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                                    }
                                }

                                Text {
                                    text: clockBlock.secondsDigits + "s" + (!lockRoot.effectiveClock24h ? (" • " + clockBlock.amPmText) : "")
                                    font.family: Theme.fontMono
                                    font.pixelSize: Math.max(13, Math.round(Theme.fontSizeSm * lockRoot.clockScale))
                                    font.weight: Theme.fontWeightBold
                                    color: Theme.primary
                                }
                            }

                            // ---- STACKED MATERIAL 3 EXPRESSIVE CLOCK ----
                            RowLayout {
                                visible: lockRoot.clockStyle === "stacked"
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 14

                                ColumnLayout {
                                    spacing: -20

                                    Text {
                                        text: clockBlock.mainHoursText
                                        font.family: Theme.fontDisplay
                                        font.pixelSize: Math.round(92 * Theme.fontScale * lockRoot.clockScale)
                                        font.weight: Theme.fontWeightBold
                                        color: Theme.textPrimary
                                        Layout.alignment: Qt.AlignHCenter
                                    }

                                    Text {
                                        text: clockBlock.mainMinutesText
                                        font.family: Theme.fontDisplay
                                        font.pixelSize: Math.round(92 * Theme.fontScale * lockRoot.clockScale)
                                        font.weight: Theme.fontWeightBold
                                        color: Theme.primary
                                        Layout.alignment: Qt.AlignHCenter
                                    }

                                    // 3-Tier Vertical Tower when secondsStyle === "tower"
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

                                // Proportional side-stack for Stacked mode (scales with clockScale!)
                                ColumnLayout {
                                    visible: (lockRoot.effectiveShowSeconds && lockRoot.secondsStyle !== "tower") || !lockRoot.effectiveClock24h
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 8

                                    Rectangle {
                                        visible: !lockRoot.effectiveClock24h
                                        readonly property int amPx: Math.max(14, Math.round(22 * Theme.fontScale * lockRoot.clockScale))
                                        height: amPx + 14
                                        implicitWidth: stackAmTxt.implicitWidth + 18
                                        radius: Theme.radiusMd
                                        color: Theme.pillBg
                                        border.color: Theme.pillBorder
                                        border.width: 1

                                        Text {
                                            id: stackAmTxt
                                            anchors.centerIn: parent
                                            text: clockBlock.amPmText
                                            font.family: Theme.fontMono
                                            font.pixelSize: parent.amPx
                                            font.weight: Theme.fontWeightBold
                                            color: Theme.textSecondary
                                        }
                                    }

                                    Rectangle {
                                        visible: lockRoot.effectiveShowSeconds && lockRoot.secondsStyle !== "tower"
                                        readonly property int secPx: Math.max(22, Math.round(38 * Theme.fontScale * lockRoot.clockScale))
                                        height: secPx + 18
                                        implicitWidth: stackSecTxt.implicitWidth + 22
                                        radius: Theme.radiusLg
                                        color: Theme.primary_overlay
                                        border.color: Theme.alpha(Theme.primary, 0.55)
                                        border.width: 1

                                        Text {
                                            id: stackSecTxt
                                            anchors.centerIn: parent
                                            text: ":" + clockBlock.secondsDigits
                                            font.family: Theme.fontMono
                                            font.pixelSize: parent.secPx
                                            font.weight: Theme.fontWeightBold
                                            color: Theme.primary
                                        }
                                    }
                                }
                            }

                            // Date BELOW Clock (default)
                            Text {
                                visible: !lockRoot.dateAboveClock
                                text: Qt.formatDateTime(lockRoot.currentTime, "dddd, MMMM d").toLowerCase()
                                font.family: Theme.fontDisplay
                                font.pixelSize: Theme.fontSizeMd
                                font.weight: Theme.fontWeightDemiBold
                                color: Theme.primary
                                Layout.alignment: Qt.AlignHCenter
                            }

                            // Lowercase quote pill (click to cycle a new quote)
                            Rectangle {
                                visible: lockRoot.activeQuoteText !== ""
                                Layout.alignment: Qt.AlignHCenter
                                Layout.topMargin: 4
                                Layout.maximumWidth: 430
                                implicitWidth: Math.min(430, quoteTxt.implicitWidth + 24)
                                implicitHeight: quoteTxt.implicitHeight + 12
                                radius: Theme.radiusPill
                                color: quoteMouse.containsMouse ? Theme.pillHover : "transparent"
                                border.color: quoteMouse.containsMouse ? Theme.pillBorder : "transparent"
                                border.width: 1

                                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                Text {
                                    id: quoteTxt
                                    anchors.centerIn: parent
                                    width: Math.min(406, implicitWidth)
                                    text: "\"" + lockRoot.activeQuoteText + "\""
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeXs
                                    font.italic: true
                                    color: quoteMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                }

                                MouseArea {
                                    id: quoteMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: lockRoot.refreshQuotes()
                                }
                            }
                        }

                        // ==================== BLOCK 2: COHESIVE MPRIS MEDIA CARD ====================
                        ClippingRectangle {
                            id: mediaBlock
                            width: parent.width
                            y: centerStage.blockY("media")
                            implicitHeight: mediaCardCol.implicitHeight + 24
                            height: implicitHeight
                            radius: Theme.radiusLg
                            color: Theme.blend(Theme.cardBg, surface.artAccent, surface.playerIsPlaying ? 0.14 : 0.04)
                            border.color: surface.playerIsPlaying ? Theme.alpha(surface.artAccent, 0.35) : Theme.cardBorder
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
                                        surface.activePlayer.volume = Math.max(0.0, Math.min(1.0, cur + delta));
                                        surface.volumeHudVisible = true;
                                        volumeHudTimer.restart();
                                    }
                                }
                            }

                            // Integrated 24-band ambient spectrum backdrop
                            RowLayout {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                height: 42
                                spacing: 3
                                visible: lockRoot.showMediaVisualizer
                                opacity: surface.playerIsPlaying ? 0.22 : 0.06

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
                                            let pList = (typeof lockPeakMonitor !== "undefined" && lockPeakMonitor.peaks && lockPeakMonitor.peaks.length > 0)
                                                ? lockPeakMonitor.peaks
                                                : [];
                                            if (pList.length >= 2) {
                                                let mix = index / 23.0;
                                                return (pList[0] * (1.0 - mix)) + (pList[1] * mix);
                                            }
                                            return (typeof lockPeakMonitor !== "undefined" && lockPeakMonitor.peak !== undefined) ? lockPeakMonitor.peak : 0;
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
                                            NumberAnimation {
                                                duration: 80
                                                easing.type: Theme.animColorEasing
                                            }
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
                                        radius: Theme.radiusMd
                                        color: Theme.widgetBg
                                        border.color: Theme.isGlass ? Theme.glassHighlight : Theme.cardBorder
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
                                                text: (surface.activePlayer?.trackTitle || "unknown track").toLowerCase()
                                                font.family: Theme.fontDisplay
                                                font.pixelSize: Theme.fontSizeSm
                                                font.weight: Theme.fontWeightBold
                                                color: Theme.textPrimary
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }

                                            Rectangle {
                                                visible: surface.volumeHudVisible || surface.playerList.length > 1
                                                height: 20
                                                implicitWidth: mediaBadgeTxt.implicitWidth + 12
                                                radius: Theme.radiusPill
                                                color: surface.volumeHudVisible ? Theme.primary_overlay : Theme.pillBg
                                                border.color: Theme.alpha(surface.artAccent, 0.45)
                                                border.width: 1

                                                Text {
                                                    id: mediaBadgeTxt
                                                    anchors.centerIn: parent
                                                    text: surface.volumeHudVisible
                                                        ? ("vol " + Math.round((surface.activePlayer?.volume ?? 1.0) * 100) + "%")
                                                        : ((surface.activePlayer?.identity || "player").toLowerCase() + " " + (surface.currentPlayerIdx + 1) + "/" + surface.playerList.length)
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
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            text: (surface.activePlayer?.trackArtist || "unknown artist").toLowerCase()
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
                                        onClicked: surface.activePlayer?.previous()
                                    }

                                    Rectangle {
                                        width: surface.playerIsPlaying ? 44 : 36
                                        height: 36
                                        radius: surface.playerIsPlaying ? Theme.radiusMd : Theme.radiusPill
                                        color: lockPlayMouse.pressed
                                            ? Theme.statePress(surface.artAccent, Theme.on_primary)
                                            : (lockPlayMouse.containsMouse
                                                ? Theme.stateHover(surface.artAccent, Theme.on_primary)
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
                                            color: Theme.on_primary
                                        }

                                        MouseArea {
                                            id: lockPlayMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: surface.activePlayer?.togglePlaying()
                                        }
                                    }

                                    IconButton {
                                        icon: Theme.iconNext
                                        iconSize: Theme.fontSizeSm
                                        tooltip: "next"
                                        enabled: surface.activePlayer?.canGoNext ?? false
                                        onClicked: surface.activePlayer?.next()
                                    }
                                }

                                // Interactive lock screen seekbar + timestamps
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    visible: lockRoot.showMediaVisualizer && (surface.activePlayer?.length ?? 0) > 0

                                    Text {
                                        text: lockRoot.formatTime(surface.trackPosition)
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeXs
                                        color: Theme.textSecondary
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 12

                                        readonly property real progRatio: {
                                            let len = surface.activePlayer?.length ?? 0;
                                            if (len <= 0) return 0;
                                            return Math.max(0.0, Math.min(1.0, surface.trackPosition / len));
                                        }

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            height: seekMouse.containsMouse ? 7 : 5
                                            radius: Theme.radiusPill
                                            color: Theme.alpha(Theme.on_surface, 0.14)

                                            Behavior on height { NumberAnimation { duration: Theme.animFast } }

                                            Rectangle {
                                                anchors.left: parent.left
                                                anchors.top: parent.top
                                                anchors.bottom: parent.bottom
                                                width: parent.width * parent.parent.progRatio
                                                radius: Theme.radiusPill
                                                color: surface.artAccent
                                            }
                                        }

                                        MouseArea {
                                            id: seekMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            enabled: (surface.activePlayer?.canSeek ?? true) && (surface.activePlayer?.length ?? 0) > 0
                                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            onClicked: (mouse) => {
                                                let len = surface.activePlayer?.length ?? 0;
                                                if (len > 0 && surface.activePlayer) {
                                                    let pos = Math.max(0, Math.min(len, (mouse.x / width) * len));
                                                    surface.activePlayer.position = pos;
                                                    surface.trackPosition = pos;
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        text: lockRoot.formatTime(surface.activePlayer?.length ?? 0)
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeXs
                                        color: Theme.textSecondary
                                    }
                                }
                            }
                        }

                        // ==================== BLOCK 3: PASSWORD PILL + STATUS ====================
                        ColumnLayout {
                            id: passwordBlock
                            width: parent.width
                            y: centerStage.blockY("password")
                            spacing: 8

                            Behavior on y { NumberAnimation { duration: Theme.expressiveDefault; easing.type: Theme.animEasingEntrance } }

                            Rectangle {
                                id: pwContainer
                                Layout.fillWidth: true
                                Layout.preferredHeight: 50
                                radius: Theme.radiusPill
                                color: pwInput.activeFocus ? Theme.pillHover : Theme.pillBg
                                border.color: lockRoot.authFailed
                                    ? Theme.error
                                    : (pwInput.text.length > 0
                                        ? Theme.primary
                                        : (pwInput.activeFocus ? Theme.alpha(Theme.primary, 0.65) : Theme.pillBorder))
                                border.width: (pwInput.activeFocus || lockRoot.authFailed) ? 2 : 1

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
                                            : (pwInput.activeFocus ? Theme.primary : Theme.textSecondary)

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
                                        text: lockRoot.sharedPassword
                                        echoMode: lockRoot.revealPassword ? TextInput.Normal : TextInput.Password
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeMd
                                        color: Theme.textPrimary
                                        selectionColor: Theme.primary_container
                                        selectedTextColor: Theme.on_primary_container
                                        enabled: !lockRoot.isChecking
                                        passwordCharacter: "•"
                                        clip: true

                                        Text {
                                            anchors.fill: parent
                                            verticalAlignment: Text.AlignVCenter
                                            text: lockRoot.isChecking ? "verifying..." : "enter password to unlock..."
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeSm
                                            color: Theme.on_surface_disabled
                                            visible: pwInput.text.length === 0
                                        }

                                        onTextEdited: {
                                            lockRoot.sharedPassword = text;
                                            if (lockRoot.authFailed) lockRoot.authFailed = false;
                                            keyPulseAnim.restart();
                                        }

                                        Keys.onEscapePressed: {
                                            if (surface.optionsOpen) {
                                                surface.optionsOpen = false;
                                            } else {
                                                lockRoot.sharedPassword = "";
                                                lockRoot.authFailed = false;
                                            }
                                        }

                                        onAccepted: {
                                            const p = lockRoot.sharedPassword;
                                            lockRoot.sharedPassword = "";
                                            lockRoot.tryUnlock(p);
                                        }

                                        Component.onCompleted: forceActiveFocus()

                                        Connections {
                                            target: lockRoot
                                            function onLockedChanged() {
                                                if (lockRoot.locked) {
                                                    pwInput.forceActiveFocus();
                                                }
                                            }
                                        }
                                    }

                                    IconButton {
                                        icon: Theme.iconClose
                                        tooltip: "clear"
                                        iconSize: Theme.fontSizeXs
                                        visible: pwInput.text.length > 0 && !lockRoot.isChecking
                                        onClicked: {
                                            lockRoot.sharedPassword = "";
                                            lockRoot.authFailed = false;
                                            pwInput.forceActiveFocus();
                                        }
                                    }

                                    IconButton {
                                        icon: lockRoot.revealPassword ? Theme.iconEyeOff : Theme.iconEye
                                        tooltip: lockRoot.revealPassword ? "hide password" : "show password"
                                        iconSize: Theme.fontSizeSm
                                        visible: pwInput.text.length > 0 && !lockRoot.isChecking
                                        onClicked: {
                                            lockRoot.revealPassword = !lockRoot.revealPassword;
                                            pwInput.forceActiveFocus();
                                        }
                                    }

                                    Rectangle {
                                        readonly property bool canSubmit: pwInput.text.length > 0 && !lockRoot.isChecking
                                        width: canSubmit ? 38 : 0
                                        height: 34
                                        opacity: canSubmit ? 1.0 : 0.0
                                        visible: width > 0
                                        radius: Theme.radiusPill
                                        color: submitMouse.pressed
                                            ? Theme.statePress(Theme.primary, Theme.on_primary)
                                            : (submitMouse.containsMouse
                                                ? Theme.stateHover(Theme.primary, Theme.on_primary)
                                                : Theme.primary)

                                        Behavior on width { NumberAnimation { duration: Theme.expressiveFast; easing.type: Theme.animExpressiveEasing } }
                                        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                                        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: Theme.iconChevronRight
                                            font.family: Theme.fontIcon
                                            font.pixelSize: Theme.fontSizeSm
                                            font.weight: Theme.fontWeightBold
                                            color: Theme.on_primary
                                        }

                                        MouseArea {
                                            id: submitMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                const p = lockRoot.sharedPassword;
                                                lockRoot.sharedPassword = "";
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
                                    text: lockRoot.isChecking
                                        ? "authenticating..."
                                        : (lockRoot.authFailed ? "incorrect password, try again" : "")
                                    opacity: (lockRoot.isChecking || lockRoot.authFailed) ? 1.0 : 0.0
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: Theme.fontWeightMedium
                                    color: lockRoot.authFailed ? Theme.error : Theme.textSecondary

                                    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                                }
                            }
                        }
                    }

                    // Bottom power dock with inline 2-step confirmation pills
                    RowLayout {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.margins: 36
                        anchors.bottomMargin: surface.entered ? 36 : 12
                        opacity: surface.entered ? 1.0 : 0.0
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
                            actionId: "logout"
                            icon: Theme.iconLogout
                            label: "log out"
                            command: ["hyprctl", "dispatch", "exit"]
                        }
                    }

                    // Themed concave screen corners
                    ConcaveCorner {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        radiusX: Theme.screenCornerRadius
                        radiusY: Theme.screenCornerRadius
                        fillColor: Theme.cornerFill
                        flipX: false
                        flipY: false
                        visible: Theme.screenCornerRadius > 0
                    }

                    ConcaveCorner {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        radiusX: Theme.screenCornerRadius
                        radiusY: Theme.screenCornerRadius
                        fillColor: Theme.cornerFill
                        flipX: true
                        flipY: false
                        visible: Theme.screenCornerRadius > 0
                    }

                    ConcaveCorner {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        radiusX: Theme.screenCornerRadius
                        radiusY: Theme.screenCornerRadius
                        fillColor: Theme.cornerFill
                        flipX: false
                        flipY: true
                        visible: Theme.screenCornerRadius > 0
                    }

                    ConcaveCorner {
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        radiusX: Theme.screenCornerRadius
                        radiusY: Theme.screenCornerRadius
                        fillColor: Theme.cornerFill
                        flipX: true
                        flipY: true
                        visible: Theme.screenCornerRadius > 0
                    }
                }
            }
        }
    }
}
