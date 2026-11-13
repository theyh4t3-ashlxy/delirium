// WallpaperService.qml
pragma Singleton
import QtQuick
import ".."
import Quickshell
import Quickshell.Io

QtObject {
    id: service

    property string currentSchemeType: Settings?.matugenScheme ?? "scheme-tonal-spot"
    property string currentMode: Settings?.matugenMode ?? "dark"
    property string currentWallpaperPath: Settings?.currentWallpaper || ""
    property string targetMonitor: "all"
    property var wallpaperList: []

    signal wallpapersUpdated()

    readonly property string userHome: Quickshell.env("HOME") || ""
    readonly property string stateDir: {
        let xdg = Quickshell.env("XDG_STATE_HOME");
        if (xdg && xdg.trim() !== "") return xdg.trim() + "/quickshell";
        return userHome ? (userHome + "/.local/state/quickshell") : "/tmp/quickshell-state";
    }
    readonly property string savedWpPath: stateDir + "/saved_wp"
    readonly property string currWallSymlink: userHome + "/.curr_wall"
    readonly property string currWallStatic: userHome + "/.curr_wall_static.jpg"
    readonly property string scriptPath: decodeURIComponent(Qt.resolvedUrl("../scripts/wallpaper.py").toString().replace(/^file:\/\//, ""))

    property FileView savedWpFile: FileView {
        path: service.savedWpPath
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: service.parseSavedWp()
        onFileChanged: {
            reload();
            service.parseSavedWp();
        }
    }

    // run scan/set through a tracked Process so we always reload saved_wp when python finishes
    property Process wpProc: Process {
        running: false
        onExited: {
            service.savedWpFile.reload();
            service.parseSavedWp();
        }
    }

    property Process scanProc: Process {
        command: ["python3", service.scriptPath, "scan"]
        running: false
        onExited: {
            service.savedWpFile.reload();
            service.parseSavedWp();
        }
    }

    property Connections settingsConn: Connections {
        target: Settings
        function onMatugenModeChanged() {
            if (Settings.matugenMode && Settings.matugenMode !== service.currentMode) {
                service.currentMode = Settings.matugenMode;
            }
        }
        function onMatugenSchemeChanged() {
            if (Settings.matugenScheme && Settings.matugenScheme !== service.currentSchemeType) {
                service.currentSchemeType = Settings.matugenScheme;
            }
        }
        function onCurrentWallpaperChanged() {
            if (Settings.currentWallpaper && Settings.currentWallpaper !== service.currentWallpaperPath) {
                service.currentWallpaperPath = Settings.currentWallpaper;
            }
        }
    }

    function runWpCmd(args) {
        if (wpProc.running) {
            Quickshell.execDetached(["python3", scriptPath, ...args]);
        } else {
            wpProc.command = ["python3", scriptPath, ...args];
            wpProc.running = true;
        }
    }

    function parseSavedWp() {
        if (!savedWpFile) return;
        let raw = savedWpFile.text();
        if (!raw || raw.trim() === "") return;

        let list = [];
        const lines = raw.split("\n");
        for (let i = 0; i < lines.length; i++) {
            let line = lines[i].trim();
            if (!line || line.startsWith("#")) continue;

            if (line.startsWith("current=")) {
                let p = line.slice(8).trim();
                if (p !== "" && p !== service.currentWallpaperPath) {
                    service.currentWallpaperPath = p;
                    if (Settings && Settings.currentWallpaper !== p) {
                        Settings.currentWallpaper = p;
                    }
                }
            } else if (line.startsWith("mode=")) {
                let m = line.slice(5).trim();
                if (m !== "" && m !== service.currentMode) {
                    service.currentMode = m;
                }
            } else if (line.startsWith("scheme=")) {
                let s = line.slice(7).trim();
                if (s !== "" && s !== service.currentSchemeType) {
                    service.currentSchemeType = s;
                }
            } else if (line.startsWith("wp=")) {
                let parts = line.slice(3).split("|");
                let p = parts[0] || "";
                if (p === "") continue;

                let item = {
                    path: p,
                    thumb: p,
                    name: "",
                    ext: "",
                    isLive: false,
                    isVideo: false,
                    isGif: false,
                    category: "root",
                    parentCategory: "root",
                    subCategory: ""
                };

                for (let j = 1; j < parts.length; j++) {
                    let kv = parts[j];
                    let eq = kv.indexOf("=");
                    if (eq < 0) continue;
                    let k = kv.slice(0, eq);
                    let v = kv.slice(eq + 1);
                    switch (k) {
                        case "thumb": item.thumb = v || p; break;
                        case "name": item.name = v; break;
                        case "ext": item.ext = v; break;
                        case "live": item.isLive = (v === "1" || v === "true"); break;
                        case "video": item.isVideo = (v === "1" || v === "true"); break;
                        case "gif": item.isGif = (v === "1" || v === "true"); break;
                        case "cat": item.category = v || "root"; break;
                        case "parent": item.parentCategory = v || "root"; break;
                        case "sub": item.subCategory = v; break;
                    }
                }
                list.push(item);
            }
        }

        service.wallpaperList = list;
        service.wallpapersUpdated();
    }

    function updateWallpaperList() {
        savedWpFile.reload();
        parseSavedWp();
    }

    function setMode(mode) {
        currentMode = mode;
        if (Settings) {
            Settings.matugenMode = mode;
            if (Settings.save) Settings.save();
        }
        reapplyTheme();
    }

    function setScheme(scheme) {
        currentSchemeType = scheme;
        if (Settings) {
            Settings.matugenScheme = scheme;
            if (Settings.save) Settings.save();
        }
        reapplyTheme();
    }

    function getRandomWallpaperPath(): string {
        if (!wallpaperList || wallpaperList.length === 0) {
            updateWallpaperList();
        }
        if (wallpaperList && wallpaperList.length > 0) {
            let idx = Math.floor(Math.random() * wallpaperList.length);
            let item = wallpaperList[idx];
            return item?.path ?? item?.url ?? "";
        }
        return currentWallpaperPath;
    }

    function getTransitionArgs(monitor) {
        let tType = Settings?.awwwTransitionType ?? "wipe";
        let tAngle = "" + (Settings?.awwwTransitionAngle ?? 30);
        let tStep = "" + (Settings?.awwwTransitionStep ?? 90);
        let tDur = "" + (Settings?.awwwTransitionDuration ?? 3);
        let tFps = "" + (Settings?.awwwTransitionFps ?? 60);
        let tFilter = Settings?.awwwFilter ?? "Lanczos3";
        let mode = currentMode ?? "dark";
        let scheme = currentSchemeType ?? "scheme-tonal-spot";
        let mon = monitor || targetMonitor || "all";
        let panscan = "" + (Settings?.mpvPanscan ?? 1.0);
        let audio = Settings?.mpvAudio ? "true" : "false";
        let resize = Settings?.awwwResize ?? "crop";
        let pos = Settings?.awwwTransitionPos ?? "center";
        return [tType, tAngle, tStep, tDur, tFps, tFilter, mode, scheme, mon, panscan, audio, resize, pos];
    }

    function scanLocalWallpapers() {
        scanProc.running = false;
        scanProc.running = true;
    }

    function applyLocalWallpaper(filePath, monitor) {
        currentWallpaperPath = filePath;
        if (Settings) Settings.currentWallpaper = filePath;
        runWpCmd(["set", filePath, ...getTransitionArgs(monitor)]);
    }

    function applyRandomWallpaper(category, monitor) {
        let cat = category ?? "all";
        runWpCmd(["random", cat, ...getTransitionArgs(monitor)]);
    }

    function setWallpaper(url, monitor) {
        runWpCmd(["download", url, ...getTransitionArgs(monitor)]);
    }

    function batchDownload(urls) {
        if (!urls || urls.length === 0) return;
        runWpCmd(["batch-download", ...urls]);
    }

    function applyColor(hex) {
        let mode = currentMode ?? "dark";
        let scheme = currentSchemeType ?? "scheme-tonal-spot";
        runWpCmd(["color", hex, mode, scheme]);
    }

    function reapplyTheme() {
        let mode = currentMode ?? "dark";
        let scheme = currentSchemeType ?? "scheme-tonal-spot";
        runWpCmd(["reapply", mode, scheme]);
    }

    Component.onCompleted: {
        parseSavedWp();
        scanLocalWallpapers();
    }
}
