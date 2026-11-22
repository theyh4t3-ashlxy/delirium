import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import ".."
import "../controls"
import "../services"

PopupPanel {
    id: root

    wantsFocus: true
    keyboardFocusMode: WlrKeyboardFocus.Exclusive

    cardWidth: launcherWide ? 560 : 480
    cardHeight: 580

    property string query: ""
    property string activeCategory: "all"
    property bool gridViewMode: false
    property bool showCategoryManager: false
    property bool showLauncherStudio: false
    property string activeManagingCatId: ""
    property string categoryAppFilter: ""
    property string newCategoryName: ""
    property string newCategoryIcon: "terminal"
    property var categoryAssignApp: null

    // user-customizable launcher preferences (persisted in ~/.config/quickshell/launcher_state)
    property string sortMode: "smart"          // "smart" (frecency) | "recent" | "alpha"
    property string textCase: "lower"          // "lower" | "normal" | "upper"
    property string subtitleMode: "desc"       // "desc" | "exec" | "hide"
    property string rowDensity: "cozy"         // "compact" | "cozy" | "roomy"
    property int gridColumns: 4                // 3 | 4 | 5
    property bool autoDesktopCats: true        // auto-populate dev/games/media/web from .desktop categories
    property bool showUsageBadges: true
    property bool launcherWide: false

    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string stateDir: {
        let xdgState = Quickshell.env("XDG_STATE_HOME");
        if (xdgState && xdgState.trim() !== "") return xdgState.trim() + "/quickshell";
        return homeDir ? (homeDir + "/.local/state/quickshell") : "/tmp/quickshell-state";
    }
    readonly property string configDir: Quickshell.env("XDG_CONFIG_HOME") || (homeDir + "/.config")
    readonly property string pinnedStatePath: stateDir + "/pinned_apps"
    readonly property string launcherStatePath: stateDir + "/launcher_state.conf"
    readonly property string legacyStatePath: stateDir + "/launcher_state.json"
    readonly property string legacyConfigStatePath: configDir + "/quickshell/launcher_state.json"
    readonly property string legacyPinnedStatePath: configDir + "/quickshell/pinned_apps"
    readonly property string userShell: Quickshell.env("SHELL") || "zsh"
    readonly property string userTerminal: Quickshell.env("TERMINAL") || ""

    property var pinnedApps: []
    property var usageMap: ({}) // { [appKey]: { count: int, lastUsed: int } }
    property bool stateLoaded: false

    function fmtText(s: string): string {
        if (!s) return "";
        if (root.textCase === "lower") return s.toLowerCase();
        if (root.textCase === "upper") return s.toUpperCase();
        return s;
    }

    FileView {
        id: legacyPinnedFile
        path: root.legacyPinnedStatePath
        blockLoading: true
        watchChanges: false
        printErrors: false
    }

    FileView {
        id: legacyStateFile
        path: root.legacyStatePath
        blockLoading: true
        watchChanges: false
        printErrors: false
    }

    FileView {
        id: legacyConfigStateFile
        path: root.legacyConfigStatePath
        blockLoading: true
        watchChanges: false
        printErrors: false
    }

    FileView {
        id: pinnedFile
        path: root.pinnedStatePath
        blockLoading: false
        watchChanges: false
        printErrors: false
        onLoaded: {
            let raw = text();
            if (!raw || raw.trim() === "") {
                let leg = legacyPinnedFile.text();
                if (leg && leg.trim() !== "") {
                    root.pinnedApps = leg.trim().split("\n").map(s => s.trim().toLowerCase()).filter(Boolean);
                    pinnedFile.setText(leg.trim() + "\n");
                    return;
                }
                return;
            }
            root.pinnedApps = raw.trim().split("\n").map(s => s.trim().toLowerCase()).filter(Boolean);
        }
        onLoadFailed: {
            let leg = legacyPinnedFile.text();
            if (leg && leg.trim() !== "") {
                root.pinnedApps = leg.trim().split("\n").map(s => s.trim().toLowerCase()).filter(Boolean);
                pinnedFile.setText(leg.trim() + "\n");
            }
        }
    }

    FileView {
        id: launcherStateFile
        path: root.launcherStatePath
        blockLoading: false
        watchChanges: false
        printErrors: false
        onLoaded: {
            if (!root.stateLoaded) root.loadLauncherState();
        }
        onLoadFailed: {
            if (!root.stateLoaded) root.loadLauncherState();
        }
    }

    function parseKeyValueText(raw: string) {
        let lines = raw.split("\n");
        let usage = {};
        for (let i = 0; i < lines.length; i++) {
            let line = lines[i].trim();
            if (!line || line.startsWith("#")) continue;
            let eqIdx = line.startsWith("usage.") ? line.lastIndexOf("=") : line.indexOf("=");
            if (eqIdx === -1) continue;
            let key = line.substring(0, eqIdx).trim();
            let val = line.substring(eqIdx + 1).trim();
            if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
                val = val.substring(1, val.length - 1);
            }

            if (key === "gridViewMode") root.gridViewMode = (val === "true");
            else if (key === "sortMode" && ["smart", "recent", "alpha"].includes(val)) root.sortMode = val;
            else if (key === "textCase" && ["lower", "normal", "upper"].includes(val)) root.textCase = val;
            else if (key === "subtitleMode" && ["desc", "exec", "hide"].includes(val)) root.subtitleMode = val;
            else if (key === "rowDensity" && ["compact", "cozy", "roomy"].includes(val)) root.rowDensity = val;
            else if (key === "gridColumns") { let n = parseInt(val); if ([3, 4, 5].includes(n)) root.gridColumns = n; }
            else if (key === "autoDesktopCats") root.autoDesktopCats = (val === "true");
            else if (key === "showUsageBadges") root.showUsageBadges = (val === "true");
            else if (key === "launcherWide") root.launcherWide = (val === "true");
            else if (key.startsWith("usage.")) {
                let id = key.substring(6);
                let parts = val.split(",");
                usage[id] = {
                    count: parseInt(parts[0]) || 0,
                    lastUsed: parseInt(parts[1]) || 0
                };
            }
        }
        root.usageMap = usage;
    }

    function tryMigrateLegacyJson(): bool {
        let legacyRaw = legacyStateFile.text();
        if (!legacyRaw || legacyRaw.trim() === "") {
            legacyRaw = legacyConfigStateFile.text();
        }
        if (!legacyRaw || legacyRaw.trim() === "") return false;

        try {
            let data = JSON.parse(legacyRaw);
            if (data && typeof data === "object") {
                if (typeof data.gridViewMode === "boolean") root.gridViewMode = data.gridViewMode;
                if (["smart", "recent", "alpha"].includes(data.sortMode)) root.sortMode = data.sortMode;
                if (["lower", "normal", "upper"].includes(data.textCase)) root.textCase = data.textCase;
                if (["desc", "exec", "hide"].includes(data.subtitleMode)) root.subtitleMode = data.subtitleMode;
                if (["compact", "cozy", "roomy"].includes(data.rowDensity)) root.rowDensity = data.rowDensity;
                if ([3, 4, 5].includes(data.gridColumns)) root.gridColumns = data.gridColumns;
                if (typeof data.autoDesktopCats === "boolean") root.autoDesktopCats = data.autoDesktopCats;
                if (typeof data.showUsageBadges === "boolean") root.showUsageBadges = data.showUsageBadges;
                if (typeof data.launcherWide === "boolean") root.launcherWide = data.launcherWide;
                if (data.usage && typeof data.usage === "object") root.usageMap = data.usage;
                saveLauncherState();
                return true;
            }
        } catch (e) {}
        return false;
    }

    function loadLauncherState() {
        let raw = launcherStateFile.text();
        if (raw && raw.trim() !== "") {
            parseKeyValueText(raw);
            root.stateLoaded = true;
            return;
        }
        tryMigrateLegacyJson();
        root.stateLoaded = true;
    }

    function saveLauncherState() {
        let lines = [
            "# Quickshell App Launcher State & Preferences",
            "gridViewMode=" + root.gridViewMode,
            'sortMode="' + root.sortMode + '"',
            'textCase="' + root.textCase + '"',
            'subtitleMode="' + root.subtitleMode + '"',
            'rowDensity="' + root.rowDensity + '"',
            "gridColumns=" + root.gridColumns,
            "autoDesktopCats=" + root.autoDesktopCats,
            "showUsageBadges=" + root.showUsageBadges,
            "launcherWide=" + root.launcherWide,
            "",
            "# App Usage Statistics: usage.<appKey>=<count>,<lastUsed>"
        ];

        let keys = Object.keys(root.usageMap || {}).sort();
        for (let i = 0; i < keys.length; i++) {
            let k = keys[i];
            let entry = root.usageMap[k];
            if (entry && (entry.count > 0 || entry.lastUsed > 0)) {
                lines.push("usage." + k + "=" + (entry.count || 0) + "," + (entry.lastUsed || 0));
            }
        }
        launcherStateFile.setText(lines.join("\n") + "\n");
    }

    function appKey(app): string {
        if (!app) return "";
        return ((app.id || app.name) || "").trim().toLowerCase().replace(/=/g, "_");
    }

    function recordAppLaunch(app) {
        let k = appKey(app);
        if (!k) return;
        let next = Object.assign({}, root.usageMap);
        let prev = next[k] || { count: 0, lastUsed: 0 };
        next[k] = {
            count: (prev.count || 0) + 1,
            lastUsed: Date.now()
        };
        root.usageMap = next;
        root.saveLauncherState();
    }

    function getAppUsageCount(app): int {
        let k = appKey(app);
        return k && root.usageMap[k] ? (root.usageMap[k].count || 0) : 0;
    }

    // smart frecency score combining launch count and recency decay
    function getFrecencyScore(app): real {
        let k = appKey(app);
        if (!k || !root.usageMap[k]) return 0;
        let entry = root.usageMap[k];
        let count = entry.count || 0;
        let ageHours = Math.max(0, (Date.now() - (entry.lastUsed || 0)) / 3600000);
        let recencyMult = ageHours < 4 ? 2.5 : (ageHours < 24 ? 1.8 : (ageHours < 168 ? 1.2 : 0.7));
        return count * recencyMult;
    }

    function isAppPinned(app): bool {
        if (!app) return false;
        let aid = (app.id || "").toLowerCase();
        let aname = (app.name || "").toLowerCase();
        return (aid !== "" && root.pinnedApps.includes(aid)) || (aname !== "" && root.pinnedApps.includes(aname));
    }

    function togglePinApp(app) {
        if (!app) return;
        let key = appKey(app);
        if (!key) return;
        let next = root.pinnedApps.slice();
        let idx = next.indexOf(key);
        if (idx >= 0) {
            next.splice(idx, 1);
            if (root.activeCategory === "pinned" && next.length === 0) {
                root.activeCategory = "all";
            }
        } else {
            next.push(key);
        }
        root.pinnedApps = next;
        pinnedFile.setText(next.join("\n") + (next.length > 0 ? "\n" : ""));
    }

    /*
    executes an app respecting runInTerminal, optional terminal override (Shift+Enter),
    or discrete GPU override (DRI_PRIME=1)
    */
    function executeApp(app, forceTerminal: bool, useDgpu: bool) {
        if (!app) return;
        recordAppLaunch(app);

        let needsTerm = forceTerminal || Boolean(app.runInTerminal);
        let cmdList = app.command && app.command.length > 0 ? app.command : [];
        let rawExec = (app.execString || "").replace(/%[fFuUdDnNickvm]/g, "").trim();

        if (needsTerm) {
            let innerCmd = cmdList.length > 0 ? cmdList.join(" ") : rawExec;
            let termBin = root.userTerminal !== ""
                ? root.userTerminal
                : "kitty";
            let shScript = "for t in " + (root.userTerminal ? ("\"" + root.userTerminal + "\" ") : "") + "kitty foot ghostty alacritty wezterm xterm; do " +
                           "if command -v \"$t\" >/dev/null 2>&1; then exec \"$t\" -e " + innerCmd + "; fi; done";
            Quickshell.execDetached([root.userShell, "-c", shScript]);
        } else if (useDgpu && (rawExec !== "" || cmdList.length > 0)) {
            let innerCmd = cmdList.length > 0 ? cmdList.join(" ") : rawExec;
            Quickshell.execDetached(["env", "DRI_PRIME=1", "__NV_PRIME_RENDER_OFFLOAD=1", "__GLX_VENDOR_LIBRARY_NAME=nvidia", root.userShell, "-c", innerCmd]);
        } else if (app.execute) {
            app.execute();
        }
        root.open = false;
    }

    // prefix modes: > or $ for shell, @ for windows, : for system actions, ? for web search
    readonly property string cleanQuery: query.trim()
    readonly property bool isWindowMode: cleanQuery.startsWith("@") || activeCategory === "windows"
    readonly property bool isActionMode: cleanQuery.startsWith(":") && !cleanQuery.startsWith("::")
    readonly property bool isWebSearch: cleanQuery.startsWith("?") && cleanQuery.length > 1
    readonly property bool isCommand: (cleanQuery.startsWith(">") || cleanQuery.startsWith("$")) && (Settings?.launcherCommandEnabled ?? true)
    readonly property string cleanCommand: isCommand ? cleanQuery.slice(1).trim() : ""
    readonly property string cleanWebQuery: isWebSearch ? cleanQuery.slice(1).trim() : ""
    readonly property var calcResult: (Settings?.launcherCalcEnabled ?? true) && !isCommand && !isWindowMode && !isActionMode && !isWebSearch
        ? evaluateMath(cleanQuery)
        : null

    // built-in quick system & rice actions when typing ":"
    readonly property var quickActions: [
        { id: "lock",   name: "Lock Screen",        desc: "Engage Wayland session lock",      icon: Theme.iconLock,     cmd: ["qs", "ipc", "call", "lock", "lock"] },
        { id: "reload", name: "Reload Quickshell",  desc: "Hot-reload shell configuration",   icon: Theme.iconRefresh,  cmd: ["hyprctl", "reload"] },
        { id: "sleep",  name: "Suspend System",     desc: "Put machine to sleep",             icon: Theme.iconSuspend,  cmd: ["systemctl", "suspend"] },
        { id: "reboot", name: "Reboot System",      desc: "Restart computer",                 icon: Theme.iconReboot,   cmd: ["systemctl", "reboot"] },
        { id: "power",  name: "Power Off",          desc: "Shut down computer",               icon: Theme.iconPower,    cmd: ["systemctl", "poweroff"] },
        { id: "logout", name: "Log Out Session",    desc: "Exit Hyprland compositor",         icon: Theme.iconLogout,   cmd: [root.userShell, "-c", "hyprshutdown 2>/dev/null || uwsm stop 2>/dev/null || hyprctl dispatch 'hl.dsp.exit()' 2>/dev/null || hyprctl dispatch exit"] }
    ]

    readonly property var filteredQuickActions: {
        if (!root.isActionMode) return [];
        let q = root.cleanQuery.slice(1).trim().toLowerCase();
        if (!q) return root.quickActions;
        return root.quickActions.filter(a => a.id.includes(q) || a.name.toLowerCase().includes(q) || a.desc.toLowerCase().includes(q));
    }

    // active hyprland windows for "@" window switcher mode
    readonly property var filteredWindows: {
        if (!root.isWindowMode) return [];
        let q = (root.cleanQuery.startsWith("@") ? root.cleanQuery.slice(1) : root.cleanQuery).trim().toLowerCase();
        let list = [...(Hyprland?.toplevels?.values ?? [])];
        if (!q) return list;
        return list.filter(w => {
            let title = (w.title || "").toLowerCase();
            let ipc = w.lastIpcObject;
            let cls = (ipc?.class || ipc?.initialClass || "").toLowerCase();
            return title.includes(q) || cls.includes(q);
        });
    }

    function focusHyprlandWindow(winObj) {
        if (!winObj) return;
        let addr = winObj.address ? String(winObj.address) : "";
        if (addr !== "") {
            if (!addr.startsWith("0x")) addr = "0x" + addr;
            Quickshell.execDetached([
                root.userShell, "-c",
                "hyprctl dispatch 'hl.dsp.focus({ window = \"" + addr + "\" })' 2>/dev/null || hyprctl dispatch focuswindow address:" + addr
            ]);
        }
        root.open = false;
    }

    readonly property var availableIcons: [
        { key: "terminal", icon: Theme?.iconTerminal ?? "utilities-terminal", label: "dev" },
        { key: "globe",    icon: Theme?.iconGlobe ?? "applications-internet", label: "web" },
        { key: "music",    icon: Theme?.iconMusic ?? "audio-x-generic", label: "media" },
        { key: "flame",    icon: Theme?.iconFlame ?? "dialog-warning", label: "games" },
        { key: "folder",   icon: Theme?.iconFolder ?? "folder", label: "files" },
        { key: "settings", icon: Theme?.iconSettings ?? "preferences-system", label: "sys" },
        { key: "heart",    icon: Theme?.iconHeart ?? "emblem-favorite", label: "fav" },
        { key: "sparkles", icon: Theme?.iconSparkles ?? "applications-other", label: "cool" },
        { key: "palette",  icon: Theme?.iconPalette ?? "preferences-desktop-theme", label: "art" },
        { key: "sliders",  icon: Theme?.iconSliders ?? "preferences-other", label: "tools" }
    ]

    function resolveCategoryIcon(iconKey) {
        if (!iconKey) return Theme?.iconFolder ?? "folder";
        for (let i = 0; i < availableIcons.length; i++) {
            if (availableIcons[i].key === iconKey) return availableIcons[i].icon;
        }
        return iconKey;
    }

    // maps FreeDesktop standard categories to clean tabs when autoDesktopCats is enabled
    readonly property var autoCatDefs: [
        { id: "auto:dev",   label: "dev",   icon: Theme.iconTerminal, match: ["Development", "IDE", "TextEditor"] },
        { id: "auto:web",   label: "web",   icon: Theme.iconGlobe,    match: ["Network", "WebBrowser", "Email", "InstantMessaging", "Chat"] },
        { id: "auto:games", label: "games", icon: Theme.iconFlame,    match: ["Game"] },
        { id: "auto:media", label: "media", icon: Theme.iconMusic,    match: ["AudioVideo", "Audio", "Video", "Music", "Player"] },
        { id: "auto:gfx",   label: "gfx",   icon: Theme.iconPalette,  match: ["Graphics", "2DGraphics", "3DGraphics", "Photography"] },
        { id: "auto:sys",   label: "sys",   icon: Theme.iconSettings, match: ["System", "Settings", "Monitor", "PackageManager", "Utility"] }
    ]

    function appMatchesAutoCat(app, matchList): bool {
        let cats = app?.categories;
        if (!cats || cats.length === 0) return false;
        for (let i = 0; i < cats.length; i++) {
            if (matchList.includes(cats[i])) return true;
        }
        return false;
    }

    readonly property var categoryList: {
        let list = [{ id: "all", label: fmtText("all"), icon: Theme?.iconGrid ?? "view-grid" }];
        if (root.pinnedApps.length > 0) {
            list.push({ id: "pinned", label: fmtText("pinned"), icon: Theme?.iconHeart ?? "♥" });
        }
        if ((Hyprland?.toplevels?.values?.length ?? 0) > 0) {
            list.push({ id: "windows", label: fmtText("win"), icon: Theme?.iconWorkspaces ?? "view-paged" });
        }
        let custom = Settings?.launcherCustomCategories ?? [];
        if (Array.isArray(custom)) {
            for (let i = 0; i < custom.length; i++) {
                let c = custom[i];
                if (c && c.id && c.name) {
                    list.push({
                        id: c.id,
                        label: fmtText(c.name),
                        icon: resolveCategoryIcon(c.icon),
                        appIds: c.appIds || []
                    });
                }
            }
        }
        if (root.autoDesktopCats) {
            for (let j = 0; j < autoCatDefs.length; j++) {
                let ac = autoCatDefs[j];
                list.push({
                    id: ac.id,
                    label: fmtText(ac.label),
                    icon: ac.icon,
                    autoMatch: ac.match
                });
            }
        }
        return list;
    }

    function getActiveCatName() {
        let custom = Settings?.launcherCustomCategories ?? [];
        let c = custom.find(x => x && x.id === activeManagingCatId);
        return c ? fmtText(c.name) : "";
    }

    function getAppCategories(app) {
        if (!app) return [];
        let custom = Settings?.launcherCustomCategories ?? [];
        let aid = (app.id || "").toLowerCase();
        let aname = (app.name || "").toLowerCase();
        let res = [];
        for (let i = 0; i < custom.length; i++) {
            let c = custom[i];
            if (!c || !c.appIds) continue;
            let assigned = c.appIds.map(x => String(x).toLowerCase());
            if (assigned.includes(aid) || assigned.includes(aname)) {
                res.push({ id: c.id, name: fmtText(c.name), icon: resolveCategoryIcon(c.icon) });
            }
        }
        return res;
    }

    /*
    upgraded math & programmer calculator:
    handles "% of", "to hex", "to bin", 0xff hex literals, trig, and standard expressions safely
    */
    function evaluateMath(expr) {
        if (!expr || expr.length < 2) return null;
        let s = expr.trim();

        // "255 to hex" or "0xff to bin"
        let convMatch = s.match(/^(0x[0-9a-fA-F]+|0b[01]+|\d+)\s+(?:to|in)\s+(hex|bin|dec|oct)$/i);
        if (convMatch) {
            let num = Number(convMatch[1]);
            let target = convMatch[2].toLowerCase();
            if (!isNaN(num)) {
                if (target === "hex") return "0x" + num.toString(16).toUpperCase();
                if (target === "bin") return "0b" + num.toString(2);
                if (target === "oct") return "0o" + num.toString(8);
                return String(num);
            }
        }

        // standalone hex or binary literal (e.g. "0xff" -> "255 (0xFF)")
        if (/^0x[0-9a-fA-F]{1,12}$/.test(s)) {
            let n = parseInt(s, 16);
            return isNaN(n) ? null : (n + "  (0b" + n.toString(2) + ")");
        }
        if (/^0b[01]{1,32}$/.test(s)) {
            let n = parseInt(s.slice(2), 2);
            return isNaN(n) ? null : (n + "  (0x" + n.toString(16).toUpperCase() + ")");
        }

        // "15% of 240" -> "(15 / 100) * 240"
        let normalized = s.replace(/(\d+(?:\.\d+)?)\s*%\s*of\s*(\d+(?:\.\d+)?)/gi, "(($1 / 100) * $2)");

        // strip allowed function names before checking remaining characters so words like "cat" or "steam" don't match
        let strippedTokens = normalized
            .replace(/\b(sqrt|abs|sin|cos|tan|log|floor|ceil|round|pi|e)\b/gi, "")
            .replace(/0x[0-9a-fA-F]+/g, "0");

        if (!/^[\d\s\+\-\*\/\(\)\.\^\%\<\>\&\|\~]+$/.test(strippedTokens)) {
            return null;
        }
        if (!/[\+\-\*\/\^\%\<\>\&\|]|sqrt|abs|sin|cos|tan|log|floor|ceil|round/i.test(normalized)) {
            return null;
        }

        try {
            let sanitized = normalized
                .replace(/\bsqrt\(/gi, "Math.sqrt(")
                .replace(/\babs\(/gi, "Math.abs(")
                .replace(/\bsin\(/gi, "Math.sin(")
                .replace(/\bcos\(/gi, "Math.cos(")
                .replace(/\btan\(/gi, "Math.tan(")
                .replace(/\blog\(/gi, "Math.log(")
                .replace(/\bfloor\(/gi, "Math.floor(")
                .replace(/\bceil\(/gi, "Math.ceil(")
                .replace(/\bround\(/gi, "Math.round(")
                .replace(/\^/g, "**")
                .replace(/\bpi\b/gi, "Math.PI");
            let res = Function('"use strict"; return (' + sanitized + ')')();
            if (typeof res === "number" && !isNaN(res) && isFinite(res)) {
                return String(Math.round(res * 1000000) / 1000000);
            }
        } catch(e) {}
        return null;
    }

    // subsequence + acronym fuzzy score so "vsc" matches "Visual Studio Code" and "ffx" matches "Firefox"
    function fuzzySubsequenceScore(queryStr: string, targetStr: string): int {
        if (!queryStr || !targetStr) return 0;
        let qLen = queryStr.length;
        let tLen = targetStr.length;
        if (qLen > tLen) return 0;

        let qIdx = 0;
        let consecutive = 0;
        let boundaryHits = 0;

        for (let i = 0; i < tLen && qIdx < qLen; i++) {
            if (targetStr[i] === queryStr[qIdx]) {
                if (i === 0 || targetStr[i - 1] === " " || targetStr[i - 1] === "-" || targetStr[i - 1] === "_") {
                    boundaryHits++;
                }
                consecutive++;
                qIdx++;
            } else {
                consecutive = 0;
            }
        }
        if (qIdx < qLen) return 0;
        return 18 + (boundaryHits * 14) + (consecutive * 6) - Math.min(12, tLen - qLen);
    }

    function resolveIconSource(app) {
        let ic = app?.icon || "";
        if (ic.startsWith("/")) return "file://" + ic;
        if (Quickshell?.hasThemeIcon && Quickshell.hasThemeIcon(ic)) {
            return Quickshell.iconPath(ic);
        }
        if (Quickshell?. iconPath) {
            let p = Quickshell.iconPath(ic, true);
            if (p) return p;
        }
        if (Quickshell?.hasThemeIcon && Quickshell.hasThemeIcon("application-x-executable")) {
            return Quickshell.iconPath("application-x-executable");
        }
        return "";
    }

    readonly property var filteredApps: {
        if (root.isWindowMode || root.isActionMode) return [];
        const q = root.query.trim().toLowerCase();
        const cat = root.activeCategory;
        const pinned = root.pinnedApps;
        const _usage = root.usageMap;
        let apps = [...(DesktopEntries?.applications?.values ?? [])].filter(a => a && a.name && !a.noDisplay);

        if (cat === "pinned") {
            apps = apps.filter(app => root.isAppPinned(app));
        } else if (cat.startsWith("auto:")) {
            let def = root.autoCatDefs.find(d => d.id === cat);
            if (def) {
                apps = apps.filter(app => root.appMatchesAutoCat(app, def.match));
            }
        } else if (cat !== "all") {
            let customList = Array.isArray(Settings?.launcherCustomCategories) ? Settings.launcherCustomCategories : [];
            let targetCat = customList.find(c => c && c.id === cat);
            if (targetCat) {
                let assigned = (targetCat.appIds || []).map(x => String(x).toLowerCase());
                apps = apps.filter(app => {
                    let aid = (app.id || "").toLowerCase();
                    let aname = (app.name || "").toLowerCase();
                    return assigned.includes(aid) || assigned.includes(aname);
                });
            }
        }

        if (!q) {
            return apps.sort((a, b) => {
                let ap = root.isAppPinned(a) ? 1 : 0;
                let bp = root.isAppPinned(b) ? 1 : 0;
                if (ap !== bp) return bp - ap;

                if (root.sortMode === "smart") {
                    let fa = root.getFrecencyScore(a);
                    let fb = root.getFrecencyScore(b);
                    if (Math.abs(fa - fb) > 0.01) return fb - fa;
                } else if (root.sortMode === "recent") {
                    let la = root.usageMap[root.appKey(a)]?.lastUsed || 0;
                    let lb = root.usageMap[root.appKey(b)]?.lastUsed || 0;
                    if (la !== lb) return lb - la;
                }
                return (a.name || "").localeCompare(b.name || "");
            });
        }

        return apps.map(app => {
            let score = 0;
            const name = (app.name || "").toLowerCase();
            const gen = (app.genericName || "").toLowerCase();
            const comment = (app.comment || "").toLowerCase();
            const execBin = ((app.execString || "").split(" ")[0] || "").replace(/^.*\//, "").toLowerCase();
            const kw = app.keywords || [];

            if (name === q || execBin === q) score += 200;
            else if (name.startsWith(q)) score += 130;
            else if (execBin.startsWith(q)) score += 110;
            else if (name.includes(q)) score += 75;
            else if (execBin.includes(q)) score += 65;
            else {
                let fz = root.fuzzySubsequenceScore(q, name);
                if (fz > 0) score += fz;
            }

            if (gen.startsWith(q)) score += 45;
            else if (gen.includes(q)) score += 28;

            if (kw.some(k => (k || "").toLowerCase().includes(q))) score += 20;
            if (comment.includes(q)) score += 12;

            if (score > 0) {
                if (root.isAppPinned(app)) score += 18;
                score += Math.min(25, Math.round(root.getFrecencyScore(app) * 2));
            }

            return { app, score };
        })
        .filter(item => item.score > 0)
        .sort((a, b) => b.score !== a.score ? b.score - a.score : (a.app.name || "").localeCompare(b.app.name || ""))
        .map(item => item.app);
    }

    readonly property int rowHeightPx: {
        if (rowDensity === "compact") return 44;
        if (rowDensity === "roomy") return 62;
        return 54;
    }

    function resetSelection() {
        appList.currentIndex = 0;
        appGrid.currentIndex = 0;
        winList.currentIndex = 0;
        actionList.currentIndex = 0;
        appList.positionViewAtBeginning();
        appGrid.positionViewAtBeginning();
    }

    function launchCurrentSelection(forceTerminal: bool) {
        if (root.isActionMode) {
            let act = root.filteredQuickActions[actionList.currentIndex];
            if (act && act.cmd) {
                Quickshell.execDetached(act.cmd);
                root.open = false;
            }
            return;
        }
        if (root.isWindowMode) {
            let w = root.filteredWindows[winList.currentIndex];
            if (w) root.focusHyprlandWindow(w);
            return;
        }
        let idx = root.gridViewMode ? appGrid.currentIndex : appList.currentIndex;
        let targetApp = (idx >= 0 && idx < root.filteredApps.length) ? root.filteredApps[idx] : null;
        if (targetApp) {
            root.executeApp(targetApp, forceTerminal, false);
        }
    }

    onOpenChanged: {
        if (open) {
            query = "";
            if (activeCategory === "windows") activeCategory = "all";
            showCategoryManager = false;
            showLauncherStudio = false;
            activeManagingCatId = "";
            categoryAssignApp = null;
            searchInput.text = "";
            Qt.callLater(() => {
                searchInput.forceActiveFocus();
                root.resetSelection();
            });
        } else {
            query = "";
            showCategoryManager = false;
            showLauncherStudio = false;
            activeManagingCatId = "";
            categoryAssignApp = null;
            searchInput.text = "";
        }
    }

    content: Item {
        anchors.fill: parent

        ColumnLayout {
            anchors.fill: parent
            spacing: Theme.popupSpacing
            Keys.forwardTo: [searchInput]

            // search bar pill with mode badge, view switcher, and studio button
            Rectangle {
                visible: !root.showCategoryManager
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                color: searchInput.activeFocus ? Theme.pillHover : Theme.pillBg
                radius: searchInput.text.length > 0 ? Theme.radiusLg : Theme.radiusPill
                border.color: root.isCommand
                    ? Theme.tertiary
                    : (root.calcResult !== null || root.isWindowMode || root.isActionMode
                        ? Theme.primary
                        : (searchInput.activeFocus ? Theme.alpha(Theme.primary, 0.65) : Theme.pillBorder))
                border.width: (searchInput.activeFocus || root.isCommand || root.calcResult !== null || root.isWindowMode || root.isActionMode) ? 2 : 1

                Behavior on radius { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.animEasing } }
                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
                Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 8
                    spacing: 10

                    Rectangle {
                        width: 28
                        height: 28
                        radius: Theme.radiusPill
                        color: (root.isCommand || root.calcResult !== null || root.isWindowMode || root.isActionMode || root.isWebSearch)
                            ? Theme.primary_overlay
                            : "transparent"

                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        Icon {
                            anchors.centerIn: parent
                            visible: root.calcResult === null
                            source: root.isCommand
                                ? Theme.iconTerminal
                                : (root.isWindowMode
                                    ? Theme.iconWorkspaces
                                    : (root.isActionMode
                                        ? Theme.iconFlame
                                        : (root.isWebSearch ? Theme.iconGlobe : Theme.iconSearch)))
                            size: Theme.fontSizeMd
                            color: root.isCommand
                                ? Theme.tertiary
                                : (searchInput.activeFocus ? Theme.primary : Theme.textSecondary)
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: root.calcResult !== null
                            text: "="
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeMd
                            font.weight: Theme.fontWeightBold
                            color: Theme.primary
                        }
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: root.isCommand ? Theme.fontMono : Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                        color: Theme.textPrimary
                        selectionColor: Theme.primary_container
                        selectedTextColor: Theme.on_primary_container
                        selectByMouse: true
                        focus: true
                        clip: true

                        Text {
                            text: root.fmtText("search apps, math, @windows, :actions, or >zsh...")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.on_surface_disabled
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !searchInput.text && !searchInput.inputMethodComposing
                        }

                        onTextChanged: {
                            root.query = text;
                            root.resetSelection();
                        }

                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Escape) {
                                if (root.categoryAssignApp !== null) {
                                    root.categoryAssignApp = null;
                                    event.accepted = true;
                                    return;
                                }
                                if (root.showLauncherStudio) {
                                    root.showLauncherStudio = false;
                                    event.accepted = true;
                                    return;
                                }
                                if (root.showCategoryManager) {
                                    if (root.activeManagingCatId !== "") {
                                        root.activeManagingCatId = "";
                                    } else {
                                        root.showCategoryManager = false;
                                    }
                                    event.accepted = true;
                                    return;
                                }
                                if (searchInput.text.length > 0) {
                                    searchInput.text = "";
                                    event.accepted = true;
                                    return;
                                }
                                root.open = false;
                                event.accepted = true;
                                return;
                            }

                            // alt+enter or ctrl+e opens the app's desktop actions & context menu
                            if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (event.modifiers & Qt.AltModifier)) {
                                let idx = root.gridViewMode ? appGrid.currentIndex : appList.currentIndex;
                                let targetApp = (idx >= 0 && idx < root.filteredApps.length) ? root.filteredApps[idx] : null;
                                if (targetApp) {
                                    root.categoryAssignApp = targetApp;
                                    event.accepted = true;
                                    return;
                                }
                            }

                            // ctrl+p pins/unpins the currently selected app
                            if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier)) {
                                let idx = root.gridViewMode ? appGrid.currentIndex : appList.currentIndex;
                                let targetApp = (idx >= 0 && idx < root.filteredApps.length) ? root.filteredApps[idx] : null;
                                if (targetApp) {
                                    root.togglePinApp(targetApp);
                                    event.accepted = true;
                                    return;
                                }
                            }

                            if (root.isActionMode) {
                                if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                                    if (actionList.count > 0) actionList.incrementCurrentIndex();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                                    if (actionList.count > 0) actionList.decrementCurrentIndex();
                                    event.accepted = true;
                                }
                            } else if (root.isWindowMode) {
                                if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                                    if (winList.count > 0) winList.incrementCurrentIndex();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                                    if (winList.count > 0) winList.decrementCurrentIndex();
                                    event.accepted = true;
                                }
                            } else if (root.gridViewMode) {
                                if (event.key === Qt.Key_Right || (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier))) {
                                    if (appGrid.count > 0) appGrid.moveCurrentIndexRight();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                                    if (appGrid.count > 0) appGrid.moveCurrentIndexLeft();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Down) {
                                    if (appGrid.count > 0) appGrid.moveCurrentIndexDown();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Up) {
                                    if (appGrid.count > 0) appGrid.moveCurrentIndexUp();
                                    event.accepted = true;
                                }
                            } else {
                                if (event.key === Qt.Key_Down || (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier))) {
                                    if (appList.count > 0) {
                                        appList.incrementCurrentIndex();
                                        appList.positionViewAtIndex(appList.currentIndex, ListView.Contain);
                                    }
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                                    if (appList.count > 0) {
                                        appList.decrementCurrentIndex();
                                        appList.positionViewAtIndex(appList.currentIndex, ListView.Contain);
                                    }
                                    event.accepted = true;
                                }
                            }

                            if (!event.accepted && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                                let shiftHeld = Boolean(event.modifiers & Qt.ShiftModifier);
                                let ctrlHeld = Boolean(event.modifiers & Qt.ControlModifier);

                                if (root.isWebSearch || (ctrlHeld && root.cleanQuery.length > 0)) {
                                    let qStr = root.isWebSearch ? root.cleanWebQuery : root.cleanQuery;
                                    Quickshell.execDetached(["xdg-open", "https://duckduckgo.com/?q=" + encodeURIComponent(qStr)]);
                                    root.open = false;
                                    event.accepted = true;
                                    return;
                                }
                                if (root.isCommand && root.cleanCommand.length > 0) {
                                    Quickshell.execDetached([root.userShell, "-c", root.cleanCommand]);
                                    root.open = false;
                                    event.accepted = true;
                                    return;
                                }
                                if (root.calcResult !== null) {
                                    Quickshell.execDetached(["wl-copy", "--", root.calcResult]);
                                    root.open = false;
                                    event.accepted = true;
                                    return;
                                }
                                if (root.isActionMode || root.isWindowMode) {
                                    root.launchCurrentSelection(shiftHeld);
                                    event.accepted = true;
                                    return;
                                }
                                if (root.filteredApps.length === 0 && root.cleanQuery.length > 0 && (Settings?.launcherCommandEnabled ?? true)) {
                                    Quickshell.execDetached([root.userShell, "-c", root.cleanQuery]);
                                    root.open = false;
                                    event.accepted = true;
                                    return;
                                }
                                root.launchCurrentSelection(shiftHeld);
                                event.accepted = true;
                            }
                        }
                    }

                    IconButton {
                        icon: Theme.iconClose
                        iconSize: Theme.fontSizeXs
                        tooltip: "clear search"
                        visible: searchInput.text.length > 0
                        onClicked: {
                            searchInput.text = "";
                            searchInput.forceActiveFocus();
                        }
                    }

                    // list vs bento grid view switcher
                    Rectangle {
                        width: 30
                        height: 30
                        radius: root.gridViewMode ? Theme.radiusMd : Theme.radiusPill
                        color: root.gridViewMode
                            ? Theme.primary_overlay
                            : (viewModeMouse.containsMouse ? Theme.widgetHover : Theme.widgetBg)
                        border.color: root.gridViewMode ? Theme.alpha(Theme.primary, 0.5) : Theme.widgetBorder
                        border.width: 1

                        Behavior on radius { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
                        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                        Icon {
                            anchors.centerIn: parent
                            source: root.gridViewMode ? Theme.iconClipboard : Theme.iconGrid
                            size: Theme.fontSizeSm
                            color: root.gridViewMode ? Theme.primary : Theme.textSecondary
                        }

                        MouseArea {
                            id: viewModeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                let curIdx = root.gridViewMode ? appGrid.currentIndex : appList.currentIndex;
                                root.gridViewMode = !root.gridViewMode;
                                root.saveLauncherState();
                                appList.currentIndex = Math.max(0, curIdx);
                                appGrid.currentIndex = Math.max(0, curIdx);
                                searchInput.forceActiveFocus();
                            }
                        }
                    }

                    // launcher studio gear button
                    Rectangle {
                        width: 30
                        height: 30
                        radius: root.showLauncherStudio ? Theme.radiusMd : Theme.radiusPill
                        color: root.showLauncherStudio
                            ? Theme.primary_overlay
                            : (studioBtnMouse.containsMouse ? Theme.widgetHover : Theme.widgetBg)
                        border.color: root.showLauncherStudio ? Theme.alpha(Theme.primary, 0.5) : Theme.widgetBorder
                        border.width: 1

                        Icon {
                            anchors.centerIn: parent
                            source: Theme.iconSliders
                            size: Theme.fontSizeSm
                            color: root.showLauncherStudio ? Theme.primary : Theme.textSecondary
                        }

                        MouseArea {
                            id: studioBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.showLauncherStudio = !root.showLauncherStudio;
                                searchInput.forceActiveFocus();
                            }
                        }
                    }
                }
            }

            // collapsible launcher studio panel (follow the user, not the shell!)
            Rectangle {
                visible: root.showLauncherStudio && !root.showCategoryManager
                Layout.fillWidth: true
                implicitHeight: studioCol.implicitHeight + 20
                radius: Theme.radiusLg
                color: Theme.cardBg
                border.color: Theme.alpha(Theme.primary, 0.45)
                border.width: 1

                ColumnLayout {
                    id: studioCol
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: root.fmtText("sort:")
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textSecondary
                        }

                        Repeater {
                            model: [
                                { id: "smart",  lbl: "smart" },
                                { id: "recent", lbl: "recent" },
                                { id: "alpha",  lbl: "a-z" }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool sel: root.sortMode === modelData.id
                                Layout.fillWidth: true
                                height: 24
                                radius: sel ? Theme.radiusSm : Theme.radiusPill
                                color: sel ? Theme.primary_overlay : Theme.widgetBg
                                border.color: sel ? Theme.primary : Theme.widgetBorder
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: root.fmtText(modelData.lbl)
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: sel ? Theme.fontWeightBold : Theme.fontWeightMedium
                                    color: sel ? Theme.primary : Theme.textSecondary
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.sortMode = modelData.id;
                                        root.saveLauncherState();
                                        searchInput.forceActiveFocus();
                                    }
                                }
                            }
                        }

                        Text {
                            text: root.fmtText("case:")
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textSecondary
                        }

                        Repeater {
                            model: [
                                { id: "lower",  lbl: "abc" },
                                { id: "normal", lbl: "Abc" },
                                { id: "upper",  lbl: "ABC" }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool sel: root.textCase === modelData.id
                                width: 38
                                height: 24
                                radius: sel ? Theme.radiusSm : Theme.radiusPill
                                color: sel ? Theme.primary_overlay : Theme.widgetBg
                                border.color: sel ? Theme.primary : Theme.widgetBorder
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.lbl
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: sel ? Theme.fontWeightBold : Theme.fontWeightMedium
                                    color: sel ? Theme.primary : Theme.textSecondary
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.textCase = modelData.id;
                                        root.saveLauncherState();
                                        searchInput.forceActiveFocus();
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: root.fmtText("sub:")
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textSecondary
                        }

                        Repeater {
                            model: [
                                { id: "desc", lbl: "desc" },
                                { id: "exec", lbl: "binary" },
                                { id: "hide", lbl: "none" }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool sel: root.subtitleMode === modelData.id
                                Layout.fillWidth: true
                                height: 24
                                radius: sel ? Theme.radiusSm : Theme.radiusPill
                                color: sel ? Theme.primary_overlay : Theme.widgetBg
                                border.color: sel ? Theme.primary : Theme.widgetBorder
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: root.fmtText(modelData.lbl)
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: sel ? Theme.fontWeightBold : Theme.fontWeightMedium
                                    color: sel ? Theme.primary : Theme.textSecondary
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.subtitleMode = modelData.id;
                                        root.saveLauncherState();
                                        searchInput.forceActiveFocus();
                                    }
                                }
                            }
                        }

                        Text {
                            text: root.fmtText("grid:")
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textSecondary
                        }

                        Repeater {
                            model: [3, 4, 5]
                            delegate: Rectangle {
                                required property int modelData
                                readonly property bool sel: root.gridColumns === modelData
                                width: 28
                                height: 24
                                radius: sel ? Theme.radiusSm : Theme.radiusPill
                                color: sel ? Theme.primary_overlay : Theme.widgetBg
                                border.color: sel ? Theme.primary : Theme.widgetBorder
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData + "c"
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: sel ? Theme.fontWeightBold : Theme.fontWeightMedium
                                    color: sel ? Theme.primary : Theme.textSecondary
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.gridColumns = modelData;
                                        root.saveLauncherState();
                                        searchInput.forceActiveFocus();
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Rectangle {
                            Layout.fillWidth: true
                            height: 24
                            radius: Theme.radiusPill
                            color: root.autoDesktopCats ? Theme.primary_overlay : Theme.widgetBg
                            border.color: root.autoDesktopCats ? Theme.primary : Theme.widgetBorder
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: root.fmtText("auto categories: " + (root.autoDesktopCats ? "on" : "off"))
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeXs
                                font.weight: Theme.fontWeightDemiBold
                                color: root.autoDesktopCats ? Theme.primary : Theme.textSecondary
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.autoDesktopCats = !root.autoDesktopCats;
                                    if (!root.autoDesktopCats && root.activeCategory.startsWith("auto:")) {
                                        root.activeCategory = "all";
                                    }
                                    root.saveLauncherState();
                                    searchInput.forceActiveFocus();
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 24
                            radius: Theme.radiusPill
                            color: root.launcherWide ? Theme.primary_overlay : Theme.widgetBg
                            border.color: root.launcherWide ? Theme.primary : Theme.widgetBorder
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: root.fmtText("wide card: " + (root.launcherWide ? "on" : "off"))
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeXs
                                font.weight: Theme.fontWeightDemiBold
                                color: root.launcherWide ? Theme.primary : Theme.textSecondary
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.launcherWide = !root.launcherWide;
                                    root.saveLauncherState();
                                    searchInput.forceActiveFocus();
                                }
                            }
                        }

                        Rectangle {
                            implicitWidth: clearHistTxt.implicitWidth + 16
                            height: 24
                            radius: Theme.radiusPill
                            color: Theme.widgetBg
                            border.color: Theme.widgetBorder
                            border.width: 1

                            Text {
                                id: clearHistTxt
                                anchors.centerIn: parent
                                text: root.fmtText("reset stats")
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.textSecondary
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.usageMap = ({});
                                    root.saveLauncherState();
                                    searchInput.forceActiveFocus();
                                }
                            }
                        }
                    }
                }
            }

            // category filter pills & custom category studio button
            RowLayout {
                visible: !root.showCategoryManager
                Layout.fillWidth: true
                spacing: 6

                Flickable {
                    id: catFlick
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    contentWidth: categoryRow.implicitWidth
                    contentHeight: 30
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    WheelHandler {
                        orientation: Qt.Vertical
                        onWheel: (event) => {
                            const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                            const maxX = Math.max(0, catFlick.contentWidth - catFlick.width);
                            catFlick.contentX = Math.max(0, Math.min(maxX, catFlick.contentX - delta * 0.7));
                            event.accepted = true;
                        }
                    }

                    Row {
                        id: categoryRow
                        spacing: 6

                        Repeater {
                            model: root.categoryList
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool isSelected: root.activeCategory === modelData.id
                                height: 28
                                width: Math.max(44, chipLayout.implicitWidth + 20)
                                radius: isSelected ? Theme.radiusMd : Theme.radiusPill
                                color: isSelected
                                    ? Theme.primary_overlay
                                    : (catChipMouse.containsMouse ? Theme.pillHover : Theme.pillBg)
                                border.color: isSelected
                                    ? Theme.alpha(Theme.primary, 0.65)
                                    : (catChipMouse.containsMouse ? Theme.alpha(Theme.primary, 0.35) : Theme.pillBorder)
                                border.width: (isSelected || catChipMouse.containsMouse || Theme.pillBorder.a > 0) ? 1 : 0

                                Behavior on radius { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
                                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
                                Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                RowLayout {
                                    id: chipLayout
                                    anchors.centerIn: parent
                                    spacing: 5
                                    Icon {
                                        source: modelData.icon
                                        size: Theme.fontSizeXs
                                        color: isSelected ? Theme.primary : Theme.textSecondary
                                    }
                                    Text {
                                        text: modelData.label
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: isSelected ? Theme.fontWeightBold : Theme.fontWeightMedium
                                        color: isSelected ? Theme.primary : Theme.textSecondary
                                    }
                                }

                                MouseArea {
                                    id: catChipMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.activeCategory = modelData.id;
                                        root.resetSelection();
                                        searchInput.forceActiveFocus();
                                    }
                                }
                            }
                        }
                    }
                }

                // custom category manager button
                Rectangle {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 28
                    radius: Theme.radiusPill
                    color: manageHover.containsMouse ? Theme.widgetHover : Theme.widgetBg
                    border.color: manageHover.containsMouse ? Theme.alpha(Theme.primary, 0.45) : Theme.widgetBorder
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSm
                        font.weight: Theme.fontWeightBold
                        color: manageHover.containsMouse ? Theme.primary : Theme.textSecondary
                    }

                    MouseArea {
                        id: manageHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.showCategoryManager = true;
                            root.activeManagingCatId = "";
                        }
                    }
                }
            }

            Rectangle {
                visible: !root.showCategoryManager
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.popupDividerHeight
                color: Theme.widgetBorder
            }

            // inline calculator hero card
            Rectangle {
                id: calcCard
                visible: !root.showCategoryManager && root.calcResult !== null
                Layout.fillWidth: true
                Layout.preferredHeight: 54
                radius: Theme.radiusLg
                color: Theme.blend(Theme.cardBg, Theme.primary, 0.14)
                border.color: Theme.alpha(Theme.primary, 0.5)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        radius: Theme.radiusMd
                        color: Theme.primary

                        Text {
                            text: "="
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeLg
                            font.weight: Theme.fontWeightBold
                            color: Theme.on_primary
                            anchors.centerIn: parent
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            text: root.calcResult ?? ""
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeLg
                            font.weight: Theme.fontWeightBold
                            color: Theme.textPrimary
                        }

                        Text {
                            text: root.fmtText("press enter or click to copy to clipboard")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.primary
                        }
                    }

                    Rectangle {
                        height: 26
                        implicitWidth: copyBadgeTxt.implicitWidth + 16
                        radius: Theme.radiusPill
                        color: Theme.primary

                        Text {
                            id: copyBadgeTxt
                            anchors.centerIn: parent
                            text: root.fmtText("copy ↵")
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: Theme.fontWeightBold
                            color: Theme.on_primary
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Quickshell.execDetached(["wl-copy", "--", root.calcResult]);
                        root.open = false;
                    }
                }
            }

            // inline zsh command runner / web search card
            Rectangle {
                id: cmdCard
                visible: !root.showCategoryManager && (
                    root.isWebSearch ||
                    (root.isCommand && root.cleanCommand.length > 0) ||
                    (!root.isWindowMode && !root.isActionMode && root.filteredApps.length === 0 && root.calcResult === null && root.cleanQuery.length > 0 && (Settings?.launcherCommandEnabled ?? true))
                )
                Layout.fillWidth: true
                Layout.preferredHeight: 54
                radius: Theme.radiusLg
                color: Theme.blend(Theme.cardBg, root.isWebSearch ? Theme.primary : Theme.tertiary, 0.12)
                border.color: Theme.alpha(root.isWebSearch ? Theme.primary : Theme.tertiary, 0.5)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        radius: Theme.radiusMd
                        color: root.isWebSearch ? Theme.primary_overlay : Theme.tertiary_overlay
                        border.color: Theme.alpha(root.isWebSearch ? Theme.primary : Theme.tertiary, 0.45)
                        border.width: 1

                        Icon {
                            visible: root.isWebSearch
                            source: Theme.iconGlobe
                            size: Theme.fontSizeSm
                            color: Theme.primary
                            anchors.centerIn: parent
                        }
                        Text {
                            visible: !root.isWebSearch
                            text: ">_"
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSm
                            font.weight: Theme.fontWeightBold
                            color: Theme.tertiary
                            anchors.centerIn: parent
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            text: root.isWebSearch ? root.cleanWebQuery : (root.isCommand ? root.cleanCommand : root.cleanQuery)
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSm
                            font.weight: Theme.fontWeightBold
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: root.fmtText(root.isWebSearch ? "search the web in default browser" : ("run detached in " + root.userShell.replace(/^.*\//, "")))
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            color: root.isWebSearch ? Theme.primary : Theme.tertiary
                        }
                    }

                    Rectangle {
                        height: 26
                        implicitWidth: runBadgeTxt.implicitWidth + 16
                        radius: Theme.radiusPill
                        color: root.isWebSearch ? Theme.primary : Theme.tertiary

                        Text {
                            id: runBadgeTxt
                            anchors.centerIn: parent
                            text: root.fmtText(root.isWebSearch ? "web ↵" : "exec ↵")
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: Theme.fontWeightBold
                            color: root.isWebSearch ? Theme.on_primary : Theme.on_tertiary
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.isWebSearch) {
                            Quickshell.execDetached(["xdg-open", "https://duckduckgo.com/?q=" + encodeURIComponent(root.cleanWebQuery)]);
                        } else {
                            let cmd = root.isCommand ? root.cleanCommand : root.cleanQuery;
                            Quickshell.execDetached([root.userShell, "-c", cmd]);
                        }
                        root.open = false;
                    }
                }
            }

            // main viewport: Apps (List / Bento Grid), Windows (@), or Quick Actions (:)
            Item {
                visible: !root.showCategoryManager
                Layout.fillWidth: true
                Layout.fillHeight: true

                // mode A: ":" quick system actions list
                ListView {
                    id: actionList
                    anchors.fill: parent
                    clip: true
                    spacing: 5
                    visible: root.isActionMode
                    model: root.filteredQuickActions

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool isSelected: actionList.currentIndex === index

                        width: actionList.width
                        height: 50
                        radius: isSelected ? Theme.radiusLg : Theme.radiusMd
                        color: isSelected ? Theme.blend(Theme.cardBg, Theme.primary, 0.15) : Theme.cardBg
                        border.color: isSelected ? Theme.primary : Theme.cardBorder
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 12

                            Rectangle {
                                width: 32; height: 32
                                radius: Theme.radiusSm
                                color: Theme.primary_overlay

                                Icon {
                                    anchors.centerIn: parent
                                    source: modelData.icon
                                    size: Theme.fontSizeMd
                                    color: Theme.primary
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    text: root.fmtText(modelData.name)
                                    font.family: Theme.fontDisplay
                                    font.pixelSize: Theme.fontSizeSm
                                    font.weight: Theme.fontWeightBold
                                    color: Theme.textPrimary
                                }
                                Text {
                                    text: root.fmtText(modelData.desc)
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeXs
                                    color: Theme.textSecondary
                                }
                            }

                            Text {
                                text: ":" + modelData.id
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.primary
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: actionList.currentIndex = index
                            onClicked: {
                                Quickshell.execDetached(modelData.cmd);
                                root.open = false;
                            }
                        }
                    }
                }

                // mode B: "@" active hyprland window switcher
                ListView {
                    id: winList
                    anchors.fill: parent
                    clip: true
                    spacing: 5
                    visible: root.isWindowMode && !root.isActionMode
                    model: root.filteredWindows

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool isSelected: winList.currentIndex === index
                        readonly property string winClass: modelData.lastIpcObject?.class || modelData.lastIpcObject?.initialClass || "app"
                        readonly property string wsName: modelData.workspace?.name || String(modelData.lastIpcObject?.workspace?.id ?? "")

                        width: winList.width
                        height: 52
                        radius: isSelected ? Theme.radiusLg : Theme.radiusMd
                        color: isSelected ? Theme.blend(Theme.cardBg, Theme.primary, 0.15) : (winMouse.containsMouse ? Theme.widgetHover : "transparent")
                        border.color: isSelected ? Theme.alpha(Theme.primary, 0.55) : Theme.cardBorder
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 12

                            Rectangle {
                                width: 34; height: 34
                                radius: Theme.radiusMd
                                color: Theme.widgetBg

                                IconImage {
                                    anchors.centerIn: parent
                                    width: 22; height: 22
                                    source: Theme.resolveAppIcon(parent.parent.parent.winClass)
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: root.fmtText(modelData.title || parent.parent.winClass)
                                    font.family: Theme.fontDisplay
                                    font.pixelSize: Theme.fontSizeSm
                                    font.weight: isSelected ? Theme.fontWeightBold : Theme.fontWeightDemiBold
                                    color: isSelected ? Theme.primary : Theme.textPrimary
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: root.fmtText(parent.parent.winClass)
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeXs
                                    color: Theme.textSecondary
                                }
                            }

                            Rectangle {
                                visible: parent.parent.wsName !== ""
                                height: 20
                                implicitWidth: wsTxt.implicitWidth + 12
                                radius: Theme.radiusPill
                                color: Theme.primary_overlay

                                Text {
                                    id: wsTxt
                                    anchors.centerIn: parent
                                    text: root.fmtText("ws " + parent.parent.parent.wsName)
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: Theme.fontWeightBold
                                    color: Theme.primary
                                }
                            }
                        }

                        MouseArea {
                            id: winMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: winList.currentIndex = index
                            onClicked: root.focusHyprlandWindow(modelData)
                        }
                    }
                }

                // mode C1: Expressive List View
                ListView {
                    id: appList
                    anchors.fill: parent
                    anchors.rightMargin: 6
                    clip: true
                    spacing: 5
                    boundsBehavior: Flickable.StopAtBounds
                    keyNavigationWraps: true
                    visible: !root.isWindowMode && !root.isActionMode && !root.gridViewMode && appList.count > 0

                    model: ScriptModel {
                        objectProp: "id"
                        values: root.filteredApps
                    }

                    delegate: Rectangle {
                        id: appDelegate
                        required property var modelData
                        required property int index

                        readonly property bool isSelected: appList.currentIndex === index
                        readonly property bool isHovered: mouseArea.containsMouse
                        readonly property bool isPinned: root.isAppPinned(modelData)
                        readonly property int useCount: root.getAppUsageCount(modelData)
                        readonly property bool hasActions: (modelData?.actions?.length ?? 0) > 0

                        width: appList.width
                        implicitHeight: root.rowHeightPx
                        radius: isSelected ? Theme.radiusLg : Theme.radiusMd
                        color: isSelected
                            ? Theme.blend(Theme.cardBg, Theme.primary, 0.15)
                            : (isHovered ? Theme.widgetHover : "transparent")
                        border.color: isSelected
                            ? Theme.alpha(Theme.primary, 0.55)
                            : (isHovered ? Theme.widgetBorder : "transparent")
                        border.width: 1

                        Behavior on radius { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
                        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
                        Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.leftMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3
                            height: appDelegate.isSelected ? 22 : 0
                            radius: Theme.radiusPill
                            color: Theme.primary

                            Behavior on height { NumberAnimation { duration: Theme.expressiveFast; easing.type: Theme.animExpressiveEasing } }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: appDelegate.isSelected ? 14 : 10
                            anchors.rightMargin: 10
                            spacing: 12

                            Behavior on anchors.leftMargin { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }

                            Rectangle {
                                Layout.preferredWidth: root.rowDensity === "compact" ? 32 : 38
                                Layout.preferredHeight: root.rowDensity === "compact" ? 32 : 38
                                radius: Theme.radiusMd
                                color: appDelegate.isSelected ? Theme.primary_overlay : Theme.widgetBg
                                border.color: appDelegate.isSelected
                                    ? Theme.alpha(Theme.primary, 0.4)
                                    : (Theme.isGlass ? Theme.glassHighlight : Theme.cardBorder)
                                border.width: 1

                                IconImage {
                                    anchors.centerIn: parent
                                    width: root.rowDensity === "compact" ? 20 : 24
                                    height: root.rowDensity === "compact" ? 20 : 24
                                    source: root.resolveIconSource(modelData)
                                    scale: (appDelegate.isSelected || appDelegate.isHovered) ? 1.08 : 1.0

                                    Behavior on scale { NumberAnimation { duration: Theme.expressiveFast; easing.type: Theme.animExpressiveEasing } }
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
                                        text: root.fmtText(modelData?.name ?? "")
                                        font.family: Theme.fontDisplay
                                        font.pixelSize: Theme.fontSizeSm
                                        font.weight: appDelegate.isSelected ? Theme.fontWeightBold : Theme.fontWeightDemiBold
                                        color: appDelegate.isSelected ? Theme.primary : Theme.textPrimary
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    // terminal indicator badge if app.runInTerminal is true
                                    Rectangle {
                                        visible: Boolean(modelData?.runInTerminal)
                                        height: 16
                                        implicitWidth: termBadgeTxt.implicitWidth + 8
                                        radius: Theme.radiusPill
                                        color: Theme.tertiary_overlay

                                        Text {
                                            id: termBadgeTxt
                                            anchors.centerIn: parent
                                            text: "tty"
                                            font.family: Theme.fontMono
                                            font.pixelSize: 9
                                            font.weight: Theme.fontWeightBold
                                            color: Theme.tertiary
                                        }
                                    }

                                    // custom category tags
                                    Row {
                                        spacing: 4
                                        Repeater {
                                            model: root.getAppCategories(modelData)
                                            delegate: Rectangle {
                                                required property var modelData
                                                height: 18
                                                width: tagText.implicitWidth + 10
                                                radius: Theme.radiusPill
                                                color: Theme.pillBg
                                                border.color: Theme.pillBorder
                                                border.width: 1

                                                Text {
                                                    id: tagText
                                                    anchors.centerIn: parent
                                                    text: modelData.name
                                                    font.family: Theme.fontMono
                                                    font.pixelSize: Theme.fontSizeXs
                                                    color: Theme.textSecondary
                                                }
                                            }
                                        }
                                    }
                                }

                                Text {
                                    visible: root.subtitleMode !== "hide" && text !== ""
                                    text: {
                                        if (root.subtitleMode === "exec") {
                                            return (modelData?.execString || "").replace(/%[fFuUdDnNickvm]/g, "").trim();
                                        }
                                        return root.fmtText(modelData?.genericName || modelData?.comment || "");
                                    }
                                    font.family: root.subtitleMode === "exec" ? Theme.fontMono : Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeXs
                                    color: Theme.textSecondary
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            // pin / favorite button
                            Rectangle {
                                visible: appDelegate.isPinned || appDelegate.isHovered || appDelegate.isSelected
                                width: 26
                                height: 26
                                radius: Theme.radiusPill
                                color: pinMouse.containsMouse ? Theme.primary_overlay : "transparent"

                                Icon {
                                    anchors.centerIn: parent
                                    source: Theme.iconHeart
                                    size: Theme.fontSizeXs
                                    color: appDelegate.isPinned ? Theme.primary : Theme.textSecondary
                                    opacity: appDelegate.isPinned ? 1.0 : 0.55
                                }

                                MouseArea {
                                    id: pinMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.togglePinApp(appDelegate.modelData);
                                        searchInput.forceActiveFocus();
                                    }
                                }
                            }

                            // actions & context menu button ("•••")
                            Rectangle {
                                visible: appDelegate.isHovered || appDelegate.isSelected
                                width: 26
                                height: 26
                                radius: Theme.radiusPill
                                color: actMenuMouse.containsMouse ? Theme.widgetActive : Theme.widgetBg
                                border.color: appDelegate.hasActions ? Theme.alpha(Theme.primary, 0.4) : Theme.widgetBorder
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: "•••"
                                    font.family: Theme.fontMono
                                    font.pixelSize: 9
                                    font.weight: Theme.fontWeightBold
                                    color: actMenuMouse.containsMouse ? Theme.primary : Theme.textSecondary
                                }

                                MouseArea {
                                    id: actMenuMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.categoryAssignApp = appDelegate.modelData;
                                        searchInput.forceActiveFocus();
                                    }
                                }
                            }

                            // squishy launch pill on selected row
                            Rectangle {
                                visible: appDelegate.isSelected
                                implicitWidth: launchRow.implicitWidth + 14
                                implicitHeight: 24
                                radius: Theme.radiusPill
                                color: Theme.primary

                                RowLayout {
                                    id: launchRow
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        text: root.fmtText("open")
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightBold
                                        color: Theme.on_primary
                                    }

                                    Text {
                                        text: "↵"
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightBold
                                        color: Theme.on_primary
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            anchors.rightMargin: (appDelegate.isPinned || appDelegate.isHovered || appDelegate.isSelected) ? 72 : 0
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            cursorShape: Qt.PointingHandCursor
                            onEntered: appList.currentIndex = index
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.LeftButton) {
                                    appList.currentIndex = index;
                                    root.executeApp(modelData, Boolean(mouse.modifiers & Qt.ShiftModifier), false);
                                } else if (mouse.button === Qt.RightButton) {
                                    root.categoryAssignApp = modelData;
                                } else if (mouse.button === Qt.MiddleButton) {
                                    root.togglePinApp(modelData);
                                }
                            }
                        }
                    }
                }

                // mode C2: Bento Icon Grid View (user-configurable 3, 4, or 5 columns)
                GridView {
                    id: appGrid
                    anchors.fill: parent
                    anchors.rightMargin: 6
                    clip: true
                    cellWidth: Math.floor(width / Math.max(3, root.gridColumns))
                    cellHeight: 96
                    boundsBehavior: Flickable.StopAtBounds
                    keyNavigationWraps: true
                    visible: !root.isWindowMode && !root.isActionMode && root.gridViewMode && appGrid.count > 0

                    model: ScriptModel {
                        objectProp: "id"
                        values: root.filteredApps
                    }

                    delegate: Item {
                        id: gridCell
                        required property var modelData
                        required property int index

                        readonly property bool isSelected: appGrid.currentIndex === index
                        readonly property bool isHovered: gridMouse.containsMouse
                        readonly property bool isPinned: root.isAppPinned(modelData)

                        width: appGrid.cellWidth
                        height: appGrid.cellHeight

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 4
                            radius: gridCell.isSelected ? Theme.radiusLg : Theme.radiusMd
                            color: gridCell.isSelected
                                ? Theme.blend(Theme.cardBg, Theme.primary, 0.16)
                                : (gridCell.isHovered ? Theme.widgetHover : Theme.cardBg)
                            border.color: gridCell.isSelected
                                ? Theme.alpha(Theme.primary, 0.65)
                                : (gridCell.isHovered ? Theme.alpha(Theme.primary, 0.3) : Theme.cardBorder)
                            border.width: 1

                            Behavior on radius { NumberAnimation { duration: Theme.animFast } }
                            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
                            Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                            Icon {
                                visible: gridCell.isPinned
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 6
                                source: Theme.iconHeart
                                size: 9
                                color: Theme.primary
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 6

                                Rectangle {
                                    Layout.alignment: Qt.AlignHCenter
                                    width: 42
                                    height: 42
                                    radius: Theme.radiusMd
                                    color: gridCell.isSelected ? Theme.primary_overlay : Theme.widgetBg
                                    border.color: Theme.isGlass ? Theme.glassHighlight : Theme.widgetBorder
                                    border.width: 1

                                    IconImage {
                                        anchors.centerIn: parent
                                        width: 28
                                        height: 28
                                        source: root.resolveIconSource(gridCell.modelData)
                                        scale: (gridCell.isSelected || gridCell.isHovered) ? 1.1 : 1.0
                                        Behavior on scale { NumberAnimation { duration: Theme.expressiveFast; easing.type: Theme.animExpressiveEasing } }
                                    }
                                }

                                Text {
                                    text: root.fmtText(gridCell.modelData?.name ?? "")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: gridCell.isSelected ? Theme.fontWeightBold : Theme.fontWeightMedium
                                    color: gridCell.isSelected ? Theme.primary : Theme.textPrimary
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            MouseArea {
                                id: gridMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                cursorShape: Qt.PointingHandCursor
                                onEntered: appGrid.currentIndex = gridCell.index
                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.LeftButton) {
                                        appGrid.currentIndex = gridCell.index;
                                        root.executeApp(gridCell.modelData, Boolean(mouse.modifiers & Qt.ShiftModifier), false);
                                    } else if (mouse.button === Qt.RightButton) {
                                        root.categoryAssignApp = gridCell.modelData;
                                    } else if (mouse.button === Qt.MiddleButton) {
                                        root.togglePinApp(gridCell.modelData);
                                    }
                                }
                            }
                        }
                    }
                }

                // sleek scrollbar indicator
                Rectangle {
                    readonly property Flickable activeFlick: root.isActionMode
                        ? actionList
                        : (root.isWindowMode ? winList : (root.gridViewMode ? appGrid : appList))
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 3
                    radius: 2
                    color: "transparent"
                    visible: activeFlick.visible && activeFlick.visibleArea.heightRatio < 1.0

                    Rectangle {
                        width: parent.width
                        readonly property real trackH: parent.height
                        readonly property real thumbH: Math.max(24, Math.min(trackH, parent.activeFlick.visibleArea.heightRatio * trackH))
                        height: thumbH
                        y: Math.max(0, Math.min(trackH - thumbH, parent.activeFlick.visibleArea.yPosition * trackH))
                        radius: 2
                        color: Theme.primary
                        opacity: 0.7
                    }
                }

                // empty state card
                Rectangle {
                    anchors.fill: parent
                    visible: !root.isActionMode && !root.isWindowMode && root.filteredApps.length === 0 && root.calcResult === null && !cmdCard.visible
                    radius: Theme.radiusLg
                    color: Theme.cardBg
                    border.color: Theme.cardBorder
                    border.width: 1

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            visible: Theme.iconSet === "kaomoji"
                            text: Theme.kaoShrug
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeTitle
                            color: Theme.textSecondary
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Icon {
                            visible: Theme.iconSet !== "kaomoji"
                            source: Theme.iconSearch
                            size: Theme.fontSizeTitle
                            color: Theme.textSecondary
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: root.fmtText(root.activeCategory !== "all" ? "no apps in this category" : "no matching applications")
                            font.family: Theme.fontDisplay
                            font.pixelSize: Theme.fontSizeSm
                            font.weight: Theme.fontWeightBold
                            color: Theme.textPrimary
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: root.fmtText("tip: prefix > for zsh, @ for windows, : for actions, ? for web")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textSecondary
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }

            // footer status & shortcut hints
            RowLayout {
                visible: !root.showCategoryManager
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    height: 20
                    implicitWidth: countTxt.implicitWidth + 12
                    radius: Theme.radiusPill
                    color: Theme.pillBg
                    border.color: Theme.pillBorder
                    border.width: Theme.pillBorder.a > 0 ? 1 : 0

                    Text {
                        id: countTxt
                        anchors.centerIn: parent
                        text: root.fmtText(
                            root.isWindowMode
                                ? (root.filteredWindows.length + " windows")
                                : (root.isActionMode
                                    ? (root.filteredQuickActions.length + " actions")
                                    : (root.filteredApps.length + " apps"))
                        )
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeXs
                        font.weight: Theme.fontWeightBold
                        color: Theme.primary
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: root.fmtText("↵ open  •  ⇧↵ tty  •  alt+↵/r-click actions  •  ^p pin")
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeXs
                    color: Theme.textSecondary
                    opacity: 0.78
                }
            }

            // custom category manager view
            ColumnLayout {
                visible: root.showCategoryManager
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Theme.popupSpacing

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        radius: Theme.radiusPill
                        color: managerBackHover.containsMouse ? Theme.widgetHover : Theme.widgetBg
                        border.color: Theme.widgetBorder
                        border.width: 1

                        Icon {
                            anchors.centerIn: parent
                            source: Theme.iconChevronLeft
                            size: Theme.fontSizeSm
                            color: Theme.textPrimary
                        }

                        MouseArea {
                            id: managerBackHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.activeManagingCatId !== "") {
                                    root.activeManagingCatId = "";
                                } else {
                                    root.showCategoryManager = false;
                                }
                            }
                        }
                    }

                    Text {
                        text: root.fmtText(root.activeManagingCatId !== "" ? ("assign apps: " + root.getActiveCatName()) : "category studio")
                        font.family: Theme.fontDisplay
                        font.pixelSize: Theme.fontSizeMd
                        font.weight: Theme.fontWeightBold
                        color: Theme.textPrimary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        Layout.preferredWidth: 58
                        Layout.preferredHeight: 28
                        radius: Theme.radiusPill
                        color: doneHover.containsMouse
                            ? Theme.stateHover(Theme.primary, Theme.on_primary)
                            : Theme.primary

                        Text {
                            anchors.centerIn: parent
                            text: root.fmtText("done")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: Theme.fontWeightBold
                            color: Theme.on_primary
                        }

                        MouseArea {
                            id: doneHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.activeManagingCatId = "";
                                root.showCategoryManager = false;
                                searchInput.forceActiveFocus();
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.popupDividerHeight
                    color: Theme.widgetBorder
                }

                ColumnLayout {
                    visible: root.activeManagingCatId === ""
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Theme.popupSpacing

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 92
                        radius: Theme.radiusLg
                        color: Theme.cardBg
                        border.color: Theme.cardBorder
                        border.width: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 32
                                    radius: Theme.radiusMd
                                    color: Theme.widgetBg
                                    border.color: newCatInput.activeFocus ? Theme.primary : Theme.widgetBorder
                                    border.width: 1

                                    TextInput {
                                        id: newCatInput
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        verticalAlignment: TextInput.AlignVCenter
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeXs
                                        color: Theme.textPrimary
                                        selectByMouse: true

                                        Text {
                                            text: root.fmtText("new category name (e.g. work,rice,music)...")
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeXs
                                            color: Theme.on_surface_disabled
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: !newCatInput.text && !newCatInput.inputMethodComposing
                                        }

                                        onAccepted: {
                                            if (newCatInput.text.trim().length > 0 && Settings?.addLauncherCategory) {
                                                Settings.addLauncherCategory(newCatInput.text.trim(), root.newCategoryIcon);
                                                newCatInput.text = "";
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    readonly property bool canAdd: newCatInput.text.trim().length > 0
                                    Layout.preferredWidth: 66
                                    Layout.preferredHeight: 32
                                    radius: Theme.radiusPill
                                    color: canAdd ? Theme.primary : Theme.widgetBg
                                    border.color: canAdd ? "transparent" : Theme.widgetBorder
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.fmtText("+ add")
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightBold
                                        color: parent.canAdd ? Theme.on_primary : Theme.textSecondary
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: parent.canAdd ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: {
                                            if (parent.canAdd && Settings?.addLauncherCategory) {
                                                Settings.addLauncherCategory(newCatInput.text.trim(), root.newCategoryIcon);
                                                newCatInput.text = "";
                                            }
                                        }
                                    }
                                }
                            }

                            Flickable {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 28
                                contentWidth: iconRow.implicitWidth
                                contentHeight: 28
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds

                                Row {
                                    id: iconRow
                                    spacing: 6

                                    Repeater {
                                        model: root.availableIcons
                                        delegate: Rectangle {
                                            required property var modelData
                                            readonly property bool isCurrent: root.newCategoryIcon === modelData.key
                                            width: 30
                                            height: 26
                                            radius: isCurrent ? Theme.radiusMd : Theme.radiusPill
                                            color: isCurrent
                                                ? Theme.primary_overlay
                                                : (iconHover.containsMouse ? Theme.widgetHover : Theme.widgetBg)
                                            border.color: isCurrent ? Theme.primary : Theme.widgetBorder
                                            border.width: 1

                                            Icon {
                                                anchors.centerIn: parent
                                                source: modelData.icon
                                                size: Theme.fontSizeXs
                                                color: isCurrent ? Theme.primary : Theme.textSecondary
                                            }

                                            MouseArea {
                                                id: iconHover
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.newCategoryIcon = modelData.key
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ListView {
                        id: catManageList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 6
                        boundsBehavior: Flickable.StopAtBounds
                        model: Settings?.launcherCustomCategories ?? []

                        delegate: Rectangle {
                            required property var modelData
                            width: catManageList.width
                            implicitHeight: 48
                            radius: Theme.radiusMd
                            color: Theme.cardBg
                            border.color: Theme.cardBorder
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 10
                                spacing: 10

                                Rectangle {
                                    width: 30
                                    height: 30
                                    radius: Theme.radiusSm
                                    color: Theme.primary_overlay

                                    Icon {
                                        anchors.centerIn: parent
                                        source: root.resolveCategoryIcon(modelData.icon)
                                        size: Theme.fontSizeSm
                                        color: Theme.primary
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        text: root.fmtText(modelData.name || "")
                                        font.family: Theme.fontDisplay
                                        font.pixelSize: Theme.fontSizeSm
                                        font.weight: Theme.fontWeightBold
                                        color: Theme.textPrimary
                                    }

                                    Text {
                                        text: root.fmtText((modelData.appIds ? modelData.appIds.length : 0) + " apps assigned")
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeXs
                                        color: Theme.textSecondary
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: 88
                                    Layout.preferredHeight: 28
                                    radius: Theme.radiusPill
                                    color: manageAppsHover.containsMouse ? Theme.primary_overlay : Theme.widgetBg
                                    border.color: manageAppsHover.containsMouse ? Theme.primary : Theme.widgetBorder
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.fmtText("assign apps")
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightBold
                                        color: manageAppsHover.containsMouse ? Theme.primary : Theme.textPrimary
                                    }

                                    MouseArea {
                                        id: manageAppsHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.activeManagingCatId = modelData.id;
                                            root.categoryAppFilter = "";
                                        }
                                    }
                                }

                                IconButton {
                                    icon: Theme.iconTrash
                                    iconSize: Theme.fontSizeXs
                                    tooltip: "delete category"
                                    onClicked: {
                                        if (Settings?.removeLauncherCategory) {
                                            Settings.removeLauncherCategory(modelData.id);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    visible: root.activeManagingCatId !== ""
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        color: Theme.pillBg
                        radius: Theme.radiusPill
                        border.color: catAppFilterInput.activeFocus ? Theme.primary : Theme.pillBorder
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 8

                            Icon {
                                source: Theme.iconSearch
                                size: Theme.fontSizeSm
                                color: catAppFilterInput.activeFocus ? Theme.primary : Theme.textSecondary
                            }

                            TextInput {
                                id: catAppFilterInput
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                verticalAlignment: TextInput.AlignVCenter
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.textPrimary
                                selectByMouse: true

                                Text {
                                    text: root.fmtText("filter apps to assign...")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeXs
                                    color: Theme.on_surface_disabled
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: !catAppFilterInput.text && !catAppFilterInput.inputMethodComposing
                                }

                                onTextChanged: root.categoryAppFilter = text.trim().toLowerCase()
                            }
                        }
                    }

                    ListView {
                        id: catAppPickList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 4
                        boundsBehavior: Flickable.StopAtBounds

                        model: {
                            let q = root.categoryAppFilter;
                            let apps = [...(DesktopEntries?.applications?.values ?? [])].filter(a => a && a.name && !a.noDisplay);
                            if (q) {
                                apps = apps.filter(a => {
                                    let n = (a.name || "").toLowerCase();
                                    let g = (a.genericName || "").toLowerCase();
                                    return n.includes(q) || g.includes(q);
                                });
                            }
                            return apps.sort((a, b) => (a.name || "").localeCompare(b.name || ""));
                        }

                        delegate: Rectangle {
                            required property var modelData
                            width: catAppPickList.width
                            implicitHeight: 44
                            radius: Theme.radiusMd
                            color: isChecked
                                ? Theme.primary_overlay
                                : (rowHover.containsMouse ? Theme.widgetHover : Theme.cardBg)
                            border.color: isChecked ? Theme.alpha(Theme.primary, 0.5) : Theme.cardBorder
                            border.width: 1

                            readonly property bool isChecked: {
                                let custom = Settings?.launcherCustomCategories ?? [];
                                let cat = custom.find(c => c && c.id === root.activeManagingCatId);
                                if (!cat || !cat.appIds) return false;
                                let aid = (modelData.id || "").toLowerCase();
                                let aname = (modelData.name || "").toLowerCase();
                                let assigned = cat.appIds.map(x => String(x).toLowerCase());
                                return assigned.includes(aid) || assigned.includes(aname);
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 12
                                spacing: 10

                                Rectangle {
                                    Layout.preferredWidth: 30
                                    Layout.preferredHeight: 30
                                    radius: Theme.radiusSm
                                    color: Theme.widgetBg

                                    IconImage {
                                        anchors.centerIn: parent
                                        width: 20
                                        height: 20
                                        source: root.resolveIconSource(modelData)
                                    }
                                }

                                Text {
                                    text: root.fmtText(modelData?.name ?? "")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSm
                                    font.weight: isChecked ? Theme.fontWeightBold : Theme.fontWeightMedium
                                    color: isChecked ? Theme.primary : Theme.textPrimary
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Rectangle {
                                    Layout.preferredWidth: 22
                                    Layout.preferredHeight: 22
                                    radius: Theme.radiusSm
                                    color: isChecked ? Theme.primary : "transparent"
                                    border.color: isChecked ? Theme.primary : Theme.widgetBorder
                                    border.width: 1

                                    Icon {
                                        anchors.centerIn: parent
                                        visible: isChecked
                                        source: Theme.iconCheck
                                        size: Theme.fontSizeXs
                                        color: Theme.on_primary
                                    }
                                }
                            }

                            MouseArea {
                                id: rowHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (Settings?.toggleAppInLauncherCategory) {
                                        Settings.toggleAppInLauncherCategory(root.activeManagingCatId, modelData.id || modelData.name);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // rich right-click / Alt+Enter app actions & category sheet
        Rectangle {
            id: modalBackdrop
            anchors.fill: parent
            color: Theme.alpha(Theme.scrim, 0.65)
            visible: root.categoryAssignApp !== null
            radius: Theme.popupRadius
            z: 100

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    root.categoryAssignApp = null;
                    searchInput.forceActiveFocus();
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(390, parent.width - 28)
                height: Math.min(440, parent.height - 28)
                radius: Theme.radiusLg
                color: Theme.popupBg
                border.color: Theme.alpha(Theme.primary, 0.55)
                border.width: 1

                MouseArea {
                    anchors.fill: parent
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            width: 34; height: 34
                            radius: Theme.radiusMd
                            color: Theme.widgetBg

                            Loader {
                                anchors.centerIn: parent
                                width: 22; height: 22
                                active: Boolean(root.categoryAssignApp)
                                sourceComponent: IconImage {
                                    anchors.fill: parent
                                    source: root.resolveIconSource(root.categoryAssignApp)
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                text: root.fmtText(root.categoryAssignApp?.name ?? "")
                                font.family: Theme.fontDisplay
                                font.pixelSize: Theme.fontSizeSm
                                font.weight: Theme.fontWeightBold
                                color: Theme.textPrimary
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: (root.categoryAssignApp?.id ?? "")
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.textSecondary
                                elide: Text.ElideMiddle
                                Layout.fillWidth: true
                            }
                        }

                        IconButton {
                            icon: Theme.iconClose
                            iconSize: Theme.fontSizeXs
                            tooltip: "close"
                            onClicked: {
                                root.categoryAssignApp = null;
                                searchInput.forceActiveFocus();
                            }
                        }
                    }

                    // quick launch options row (Terminal, dGPU, Copy Exec, Pin)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: [
                                { id: "term", lbl: "run in tty", icon: Theme.iconTerminal },
                                { id: "dgpu", lbl: "dgpu",       icon: Theme.iconFlame },
                                { id: "copy", lbl: "copy cmd",   icon: Theme.iconCopy },
                                { id: "pin",  lbl: root.isAppPinned(root.categoryAssignApp) ? "unpin" : "pin", icon: Theme.iconHeart }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                height: 28
                                radius: Theme.radiusMd
                                color: qActMouse.containsMouse ? Theme.primary_overlay : Theme.widgetBg
                                border.color: qActMouse.containsMouse ? Theme.primary : Theme.widgetBorder
                                border.width: 1

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Icon {
                                        source: modelData.icon
                                        size: Theme.fontSizeXs
                                        color: Theme.primary
                                    }
                                    Text {
                                        text: root.fmtText(modelData.lbl)
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightDemiBold
                                        color: Theme.textPrimary
                                    }
                                }

                                MouseArea {
                                    id: qActMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        let app = root.categoryAssignApp;
                                        if (!app) return;
                                        if (modelData.id === "term") {
                                            root.categoryAssignApp = null;
                                            root.executeApp(app, true, false);
                                        } else if (modelData.id === "dgpu") {
                                            root.categoryAssignApp = null;
                                            root.executeApp(app, false, true);
                                        } else if (modelData.id === "copy") {
                                            Quickshell.execDetached(["wl-copy", "--", app.execString || app.id || app.name]);
                                            root.categoryAssignApp = null;
                                        } else if (modelData.id === "pin") {
                                            root.togglePinApp(app);
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // native .desktop quick actions (New Private Window, New Window, etc.)
                    ColumnLayout {
                        visible: (root.categoryAssignApp?.actions?.length ?? 0) > 0
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: root.fmtText("app actions")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: Theme.fontWeightBold
                            color: Theme.textSecondary
                        }

                        Repeater {
                            model: root.categoryAssignApp?.actions ?? []
                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                height: 32
                                radius: Theme.radiusMd
                                color: dActMouse.containsMouse ? Theme.widgetHover : Theme.widgetBg
                                border.color: dActMouse.containsMouse ? Theme.alpha(Theme.primary, 0.45) : Theme.widgetBorder
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 8

                                    Icon {
                                        source: Theme.iconChevronRight
                                        size: Theme.fontSizeXs
                                        color: Theme.primary
                                    }

                                    Text {
                                        text: root.fmtText(modelData.name || modelData.id || "action")
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightMedium
                                        color: Theme.textPrimary
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: dActMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData.execute) modelData.execute();
                                        root.categoryAssignApp = null;
                                        root.open = false;
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.popupDividerHeight
                        color: Theme.widgetBorder
                    }

                    Text {
                        text: root.fmtText("custom categories")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXs
                        font.weight: Theme.fontWeightBold
                        color: Theme.textSecondary
                    }

                    Text {
                        visible: (Settings?.launcherCustomCategories ?? []).length === 0
                        text: root.fmtText("no custom categories created yet. click + on the category bar to create one.")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXs
                        color: Theme.textSecondary
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    ListView {
                        visible: (Settings?.launcherCustomCategories ?? []).length > 0
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 5
                        model: Settings?.launcherCustomCategories ?? []

                        delegate: Rectangle {
                            required property var modelData
                            width: parent.width
                            height: 36
                            radius: Theme.radiusMd
                            color: isAssigned
                                ? Theme.primary_overlay
                                : (modalCatHover.containsMouse ? Theme.widgetHover : Theme.widgetBg)
                            border.color: isAssigned ? Theme.alpha(Theme.primary, 0.5) : Theme.widgetBorder
                            border.width: 1

                            readonly property bool isAssigned: {
                                if (!root.categoryAssignApp || !modelData || !modelData.appIds) return false;
                                let aid = (root.categoryAssignApp.id || "").toLowerCase();
                                let aname = (root.categoryAssignApp.name || "").toLowerCase();
                                let assigned = modelData.appIds.map(x => String(x).toLowerCase());
                                return assigned.includes(aid) || assigned.includes(aname);
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 8

                                Icon {
                                    source: root.resolveCategoryIcon(modelData.icon)
                                    size: Theme.fontSizeSm
                                    color: Theme.primary
                                }

                                Text {
                                    text: root.fmtText(modelData.name || "")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: isAssigned ? Theme.fontWeightBold : Theme.fontWeightMedium
                                    color: isAssigned ? Theme.primary : Theme.textPrimary
                                    Layout.fillWidth: true
                                }

                                Rectangle {
                                    Layout.preferredWidth: 18
                                    Layout.preferredHeight: 18
                                    radius: Theme.radiusSm
                                    color: isAssigned ? Theme.primary : "transparent"
                                    border.color: isAssigned ? Theme.primary : Theme.widgetBorder
                                    border.width: 1

                                    Icon {
                                        anchors.centerIn: parent
                                        visible: isAssigned
                                        source: Theme.iconCheck
                                        size: Theme.fontSizeXs
                                        color: Theme.on_primary
                                    }
                                }
                            }

                            MouseArea {
                                id: modalCatHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.categoryAssignApp && Settings?.toggleAppInLauncherCategory) {
                                        Settings.toggleAppInLauncherCategory(modelData.id, root.categoryAssignApp.id || root.categoryAssignApp.name);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
