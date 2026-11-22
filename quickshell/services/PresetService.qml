pragma Singleton
import QtQuick
import ".."
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property string catalogPath: decodeURIComponent(Qt.resolvedUrl("../presets/catalog.conf").toString().replace(/^file:\/\//, ""))
    readonly property string presetsDir: decodeURIComponent(Qt.resolvedUrl("../presets").toString().replace(/^file:\/\//, ""))
    readonly property string writeScript: decodeURIComponent(Qt.resolvedUrl("../scripts/write-file.zsh").toString().replace(/^file:\/\//, ""))
    readonly property string userPresetsDir: {
        let xdgState = Quickshell.env("XDG_STATE_HOME");
        let base = (xdgState && xdgState.trim() !== "") ? xdgState.trim() : (Quickshell.env("HOME") + "/.local/state");
        return base + "/quickshell/presets";
    }

    property var catalog: ({})
    property var blockMap: ({})
    property var availablePresets: []
    property string activePresetName: "custom"

    // Dynamic Theme category accent colors
    function getCategoryColor(category) {
        if (typeof Theme !== "undefined" && Theme) {
            switch (category) {
                case "navigation": return Theme.primary;
                case "status":     return Theme.secondary;
                case "island":     return Theme.tertiary;
                case "system":     return Theme.primary;
                case "controls":   return Theme.secondary;
                case "sensors":    return Theme.tertiary;
                case "audio":      return Theme.primary;
                case "tools":      return Theme.secondary;
                default:           return Theme.primary;
            }
        }
        return "#a8d292";
    }

    function getBlockInfo(blockId) {
        if (!blockId) return null;
        let b = root.blockMap[blockId];
        if (b) return b;
        return {
            id: blockId,
            type: "widget",
            category: "tools",
            name: blockId,
            icon: Theme?.iconGrid ?? "view-grid",
            desc: "custom widget",
            color: root.getCategoryColor("tools")
        };
    }

    property FileView catalogFile: FileView {
        path: root.catalogPath
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: root.loadCatalog()
    }

    function parseConf(str) {
        if (!str || str.trim() === "") return {};
        let lines = str.split("\n");
        let data = {};
        for (let i = 0; i < lines.length; i++) {
            let line = lines[i].trim();
            if (line === "" || line.startsWith("#")) continue;
            let eqIdx = line.indexOf("=");
            if (eqIdx !== -1) {
                let key = line.substring(0, eqIdx).trim();
                let val = line.substring(eqIdx + 1).trim();
                if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
                    val = val.substring(1, val.length - 1);
                }
                if (val === "true") {
                    val = true;
                } else if (val === "false") {
                    val = false;
                } else if (/^-?\d+(\.\d+)?$/.test(val)) {
                    val = Number(val);
                } else if (val.startsWith("[") && val.endsWith("]")) {
                    try { val = JSON.parse(val); } catch(e) {}
                }
                data[key] = val;
            }
        }
        return data;
    }

    function loadCatalog() {
        try {
            let str = catalogFile.text();
            if (!str || str.trim() === "") return;

            if (str.trim().startsWith("{")) {
                let data = JSON.parse(str);
                root.catalog = data;
                let blocks = data.blocks || {};
                let map = {};
                for (let k in blocks) {
                    let item = blocks[k];
                    map[k] = {
                        id: k,
                        type: item.type || "widget",
                        category: item.category || "tools",
                        name: item.name || k,
                        icon: item.icon || "view-grid",
                        desc: item.desc || "",
                        color: root.getCategoryColor(item.category || "tools")
                    };
                }
                root.blockMap = map;
                return;
            }

            let lines = str.split("\n");
            let map = {};
            for (let i = 0; i < lines.length; i++) {
                let line = lines[i].trim();
                if (line === "" || line.startsWith("#")) continue;
                let eqIdx = line.indexOf("=");
                if (eqIdx !== -1) {
                    let fullKey = line.substring(0, eqIdx).trim();
                    let val = line.substring(eqIdx + 1).trim();
                    if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
                        val = val.substring(1, val.length - 1);
                    }
                    let dotIdx = fullKey.indexOf(".");
                    if (dotIdx !== -1) {
                        let id = fullKey.substring(0, dotIdx);
                        let prop = fullKey.substring(dotIdx + 1);
                        if (!map[id]) {
                            map[id] = { id: id, type: "widget", category: "tools", name: id, icon: "view-grid", desc: "" };
                        }
                        map[id][prop] = val;
                    }
                }
            }
            for (let id in map) {
                map[id].color = root.getCategoryColor(map[id].category || "tools");
            }
            root.blockMap = map;
        } catch (e) {
            console.warn("PresetService: failed to parse catalog: " + e);
        }
    }

    // Built-in presets reader (.conf native)
    property FileView defaultPresetFile: FileView {
        path: root.presetsDir + "/default.conf"
        blockLoading: true
        watchChanges: false
        printErrors: false
    }

    property FileView minimalPresetFile: FileView {
        path: root.presetsDir + "/minimal.conf"
        blockLoading: true
        watchChanges: false
        printErrors: false
    }

    property FileView islandPresetFile: FileView {
        path: root.presetsDir + "/island.conf"
        blockLoading: true
        watchChanges: false
        printErrors: false
    }

    property FileView dynamicPresetFile: FileView {
        path: ""
        blockLoading: true
        watchChanges: false
        printErrors: false
    }

    property Process presetScanProc: Process {
        id: presetScanProc
        command: ["sh", "-c", 'for d in "$@"; do [ -d "$d" ] && find "$d" -maxdepth 1 -name "*.conf" ! -name "catalog.conf"; done', "sh", root.userPresetsDir, root.presetsDir]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let out = (text || "").trim();
                let list = [];
                let seen = {};

                if (out) {
                    let lines = out.split("\n");
                    for (let i = 0; i < lines.length; i++) {
                        let fullPath = lines[i].trim();
                        if (!fullPath || !fullPath.endsWith(".conf")) continue;
                        let filename = fullPath.substring(fullPath.lastIndexOf("/") + 1);
                        let id = filename.replace(/\.conf$/, "");
                        if (id === "catalog" || seen[id]) continue;
                        seen[id] = true;
                        let isBuiltin = fullPath.startsWith(root.presetsDir);
                        list.push({
                            id: id,
                            name: id,
                            path: fullPath,
                            desc: isBuiltin ? "built-in preset" : "user custom preset",
                            isBuiltin: isBuiltin
                        });
                    }
                }

                let builtins = [
                    { id: "default", name: "default", desc: "standard balanced bar", isBuiltin: true, path: root.presetsDir + "/default.conf" },
                    { id: "minimal", name: "minimal", desc: "clean floating dock", isBuiltin: true, path: root.presetsDir + "/minimal.conf" },
                    { id: "island",  name: "island",  desc: "dynamic notch centered", isBuiltin: true, path: root.presetsDir + "/island.conf" }
                ];
                for (let bIdx = 0; bIdx < builtins.length; bIdx++) {
                    let b = builtins[bIdx];
                    if (!seen[b.id]) {
                        seen[b.id] = true;
                        list.push(b);
                    }
                }
                root.availablePresets = list;
            }
        }
    }

    function getPresetData(presetId) {
        try {
            let item = (root.availablePresets || []).find(p => p && p.id === presetId);
            let userPath = root.userPresetsDir + "/" + presetId + ".conf";
            let path = (item && !item.isBuiltin) ? item.path : userPath;
            dynamicPresetFile.path = path;
            dynamicPresetFile.reload();
            let t = dynamicPresetFile.text();

            if (!t || t.trim() === "") {
                let builtinPath = (item && item.isBuiltin) ? item.path : (root.presetsDir + "/" + presetId + ".conf");
                if (path !== builtinPath) {
                    dynamicPresetFile.path = builtinPath;
                    dynamicPresetFile.reload();
                    t = dynamicPresetFile.text();
                }
            }

            if (!t || t.trim() === "") {
                if (presetId === "default") t = defaultPresetFile.text();
                else if (presetId === "minimal") t = minimalPresetFile.text();
                else if (presetId === "island") t = islandPresetFile.text();
            }

            if (t && t.trim() !== "") {
                if (t.trim().startsWith("{")) {
                    return JSON.parse(t);
                }
                return parseConf(t);
            }
        } catch (e) {
            console.warn("PresetService: error parsing preset " + presetId + ": " + e);
        }
        return null;
    }

    function refreshPresets() {
        if (!root.availablePresets || root.availablePresets.length === 0) {
            root.availablePresets = [
                { id: "default", name: "default", desc: "standard balanced bar", isBuiltin: true, path: root.presetsDir + "/default.conf" },
                { id: "minimal", name: "minimal", desc: "clean floating dock", isBuiltin: true, path: root.presetsDir + "/minimal.conf" },
                { id: "island",  name: "island",  desc: "dynamic notch centered", isBuiltin: true, path: root.presetsDir + "/island.conf" }
            ];
        }
        if (!presetScanProc.running) {
            presetScanProc.running = true;
        }
    }

    function applyPresetById(presetId) {
        let data = getPresetData(presetId);
        if (data) {
            applyPreset(data, presetId);
            return true;
        }
        return false;
    }

    function applyPreset(presetData, presetName) {
        if (!presetData) return false;

        // Bar layout & geometry
        if (presetData.barPosition !== undefined) Settings.barPosition = presetData.barPosition;
        if (presetData.barFloating !== undefined) Settings.barFloating = Boolean(presetData.barFloating);
        if (presetData.barMargin !== undefined) Settings.barMargin = Number(presetData.barMargin);
        if (presetData.barHeight !== undefined) Settings.barHeight = Number(presetData.barHeight);
        if (presetData.barStyle !== undefined) Settings.barStyle = presetData.barStyle;
        if (presetData.barRadius !== undefined) Settings.barRadius = Number(presetData.barRadius);
        if (presetData.barOpacity !== undefined) Settings.barOpacity = Number(presetData.barOpacity);
        if (presetData.barIslandMode !== undefined) Settings.barIslandMode = Boolean(presetData.barIslandMode);
        if (presetData.bentoGap !== undefined) Settings.bentoGap = Number(presetData.bentoGap);
        if (presetData.bentoHoverLift !== undefined) Settings.bentoHoverLift = Boolean(presetData.bentoHoverLift);

        // Modules placement & visibilities
        if (presetData.barModulesLeft !== undefined) Settings.barModulesLeft = presetData.barModulesLeft;
        if (presetData.barModulesCenter !== undefined) Settings.barModulesCenter = presetData.barModulesCenter;
        if (presetData.barModulesRight !== undefined) Settings.barModulesRight = presetData.barModulesRight;
        if (presetData.showWorkspaces !== undefined) Settings.showWorkspaces = Boolean(presetData.showWorkspaces);
        if (presetData.showLayoutSwitcher !== undefined) Settings.showLayoutSwitcher = Boolean(presetData.showLayoutSwitcher);
        if (presetData.showWindowTitle !== undefined) Settings.showWindowTitle = Boolean(presetData.showWindowTitle);
        if (presetData.showClock !== undefined) Settings.showClock = Boolean(presetData.showClock);
        if (presetData.showBattery !== undefined) Settings.showBattery = Boolean(presetData.showBattery);
        if (presetData.showSystemTray !== undefined) Settings.showSystemTray = Boolean(presetData.showSystemTray);
        if (presetData.showVolume !== undefined) Settings.showVolume = Boolean(presetData.showVolume);
        if (presetData.showMedia !== undefined) Settings.showMedia = Boolean(presetData.showMedia);
        if (presetData.showNotifications !== undefined) Settings.showNotifications = Boolean(presetData.showNotifications);
        if (presetData.showLauncher !== undefined) Settings.showLauncher = Boolean(presetData.showLauncher);
        if (presetData.showPowerMenu !== undefined) Settings.showPowerMenu = Boolean(presetData.showPowerMenu);
        if (presetData.showNetwork !== undefined) Settings.showNetwork = Boolean(presetData.showNetwork);
        if (presetData.showBluetooth !== undefined) Settings.showBluetooth = Boolean(presetData.showBluetooth);
        if (presetData.showClipboard !== undefined) Settings.showClipboard = Boolean(presetData.showClipboard);
        if (presetData.showIdleInhibitor !== undefined) Settings.showIdleInhibitor = Boolean(presetData.showIdleInhibitor);
        if (presetData.showScreenCapture !== undefined) Settings.showScreenCapture = Boolean(presetData.showScreenCapture);
        if (presetData.showDynamicNotch !== undefined) Settings.showDynamicNotch = Boolean(presetData.showDynamicNotch);

        // Styling & Granular
        if (presetData.cornerStyle !== undefined) Settings.cornerStyle = presetData.cornerStyle;
        if (presetData.notificationCornerStyle !== undefined) Settings.notificationCornerStyle = presetData.notificationCornerStyle;
        if (presetData.scoopRadius !== undefined) Settings.scoopRadius = Number(presetData.scoopRadius);
        if (presetData.widgetRadius !== undefined) Settings.widgetRadius = Number(presetData.widgetRadius);
        if (presetData.popupRadius !== undefined) Settings.popupRadius = Number(presetData.popupRadius);
        if (presetData.widgetSpacing !== undefined) Settings.widgetSpacing = Number(presetData.widgetSpacing);
        if (presetData.widgetPaddingH !== undefined) Settings.widgetPaddingH = Number(presetData.widgetPaddingH);
        if (presetData.widgetPaddingV !== undefined) Settings.widgetPaddingV = Number(presetData.widgetPaddingV);
        if (presetData.paddingScale !== undefined) Settings.paddingScale = presetData.paddingScale;
        if (presetData.globalRounding !== undefined) Settings.globalRounding = Number(presetData.globalRounding);
        if (presetData.cardOpacity !== undefined) Settings.cardOpacity = Number(presetData.cardOpacity);
        if (presetData.surfaceOpacity !== undefined) Settings.surfaceOpacity = Number(presetData.surfaceOpacity);
        if (presetData.glassmorphismLevel !== undefined) Settings.glassmorphismLevel = Number(presetData.glassmorphismLevel);
        if (presetData.adaptiveTransparency !== undefined) Settings.adaptiveTransparency = Boolean(presetData.adaptiveTransparency);

        // Animation & Fonts
        if (presetData.animCurve !== undefined) Settings.animCurve = presetData.animCurve;
        if (presetData.animEasingType !== undefined) Settings.animEasingType = presetData.animEasingType;
        if (presetData.animDurationFast !== undefined) Settings.animDurationFast = Number(presetData.animDurationFast);
        if (presetData.animDurationNormal !== undefined) Settings.animDurationNormal = Number(presetData.animDurationNormal);
        if (presetData.animDurationSlow !== undefined) Settings.animDurationSlow = Number(presetData.animDurationSlow);
        if (presetData.fontFamily !== undefined) Settings.fontFamily = presetData.fontFamily;
        if (presetData.fontScale !== undefined) Settings.fontScale = Number(presetData.fontScale);

        // Theming
        if (presetData.matugenMode !== undefined) Settings.matugenMode = presetData.matugenMode;
        if (presetData.matugenScheme !== undefined) Settings.matugenScheme = presetData.matugenScheme;
        if (presetData.customColorsEnabled !== undefined) Settings.customColorsEnabled = Boolean(presetData.customColorsEnabled);

        // Nested JSON backward compatibility
        if (presetData.bar) {
            if (presetData.bar.position !== undefined) Settings.barPosition = presetData.bar.position;
            if (presetData.bar.floating !== undefined) Settings.barFloating = presetData.bar.floating;
            if (presetData.bar.margin !== undefined) Settings.barMargin = presetData.bar.margin;
            if (presetData.bar.height !== undefined) Settings.barHeight = presetData.bar.height;
            if (presetData.bar.style !== undefined) Settings.barStyle = presetData.bar.style;
        }
        if (presetData.zones) {
            if (presetData.zones.left) Settings.barModulesLeft = presetData.zones.left;
            if (presetData.zones.center) Settings.barModulesCenter = presetData.zones.center;
            if (presetData.zones.right) Settings.barModulesRight = presetData.zones.right;
        }
        if (presetData.styling) {
            if (presetData.styling.cornerStyle) Settings.cornerStyle = presetData.styling.cornerStyle;
            if (presetData.styling.notificationCornerStyle) Settings.notificationCornerStyle = presetData.styling.notificationCornerStyle;
            if (presetData.styling.scoopRadius) Settings.scoopRadius = presetData.styling.scoopRadius;
            if (presetData.styling.widgetRadius) Settings.widgetRadius = presetData.styling.widgetRadius;
        }

        if (presetName) root.activePresetName = presetName;
        Settings.save();
        return true;
    }

    function exportCurrentAsPreset(name) {
        if (!name || name.trim() === "") return false;
        let cleanName = name.trim().toLowerCase().replace(/[^a-z0-9_-]/g, "_");
        let lines = [
            'name="' + cleanName + '"',
            'barPosition="' + (Settings?.barPosition ?? "top") + '"',
            'barFloating=' + (Settings?.barFloating ?? false),
            'barMargin=' + (Settings?.barMargin ?? 0),
            'barHeight=' + (Settings?.barHeight ?? 32),
            'barStyle="' + (Settings?.barStyle ?? "regular") + '"',
            'barRadius=' + (Settings?.barRadius ?? 0),
            'barOpacity=' + (Settings?.barOpacity ?? 1.0),
            'barIslandMode=' + (Settings?.barIslandMode ?? true),
            'bentoGap=' + (Settings?.bentoGap ?? 8),
            'bentoHoverLift=' + (Settings?.bentoHoverLift ?? true),
            "barModulesLeft='" + JSON.stringify(Settings?.barModulesLeft ?? []) + "'",
            "barModulesCenter='" + JSON.stringify(Settings?.barModulesCenter ?? []) + "'",
            "barModulesRight='" + JSON.stringify(Settings?.barModulesRight ?? []) + "'",
            'showWorkspaces=' + (Settings?.showWorkspaces ?? true),
            'showLayoutSwitcher=' + (Settings?.showLayoutSwitcher ?? true),
            'showWindowTitle=' + (Settings?.showWindowTitle ?? true),
            'showClock=' + (Settings?.showClock ?? true),
            'showBattery=' + (Settings?.showBattery ?? true),
            'showSystemTray=' + (Settings?.showSystemTray ?? true),
            'showVolume=' + (Settings?.showVolume ?? true),
            'showMedia=' + (Settings?.showMedia ?? true),
            'showNotifications=' + (Settings?.showNotifications ?? true),
            'showLauncher=' + (Settings?.showLauncher ?? true),
            'showPowerMenu=' + (Settings?.showPowerMenu ?? true),
            'showNetwork=' + (Settings?.showNetwork ?? true),
            'showBluetooth=' + (Settings?.showBluetooth ?? true),
            'showClipboard=' + (Settings?.showClipboard ?? true),
            'showIdleInhibitor=' + (Settings?.showIdleInhibitor ?? true),
            'showScreenCapture=' + (Settings?.showScreenCapture ?? true),
            'showDynamicNotch=' + (Settings?.showDynamicNotch ?? true),
            'cornerStyle="' + (Settings?.cornerStyle ?? "continuous-bezier") + '"',
            'notificationCornerStyle="' + (Settings?.notificationCornerStyle ?? "concave") + '"',
            'scoopRadius=' + (Settings?.scoopRadius ?? 16),
            'widgetRadius=' + (Settings?.widgetRadius ?? 6),
            'popupRadius=' + (Settings?.popupRadius ?? 8),
            'widgetSpacing=' + (Settings?.widgetSpacing ?? 4),
            'widgetPaddingH=' + (Settings?.widgetPaddingH ?? 8),
            'widgetPaddingV=' + (Settings?.widgetPaddingV ?? 4),
            'paddingScale="' + (Settings?.paddingScale ?? "cozy") + '"',
            'globalRounding=' + (Settings?.globalRounding ?? 8),
            'cardOpacity=' + (Settings?.cardOpacity ?? 0.95),
            'surfaceOpacity=' + (Settings?.surfaceOpacity ?? 0.90),
            'glassmorphismLevel=' + (Settings?.glassmorphismLevel ?? 0.85),
            'adaptiveTransparency=' + (Settings?.adaptiveTransparency ?? true),
            'animCurve="' + (Settings?.animCurve ?? "cubic") + '"',
            'animEasingType="' + (Settings?.animEasingType ?? "out") + '"',
            'animDurationFast=' + (Settings?.animDurationFast ?? 120),
            'animDurationNormal=' + (Settings?.animDurationNormal ?? 200),
            'animDurationSlow=' + (Settings?.animDurationSlow ?? 350),
            'fontFamily="' + (Settings?.fontFamily ?? "Noto Sans") + '"',
            'fontScale=' + (Settings?.fontScale ?? 1.0),
            'matugenMode="' + (Settings?.matugenMode ?? "dark") + '"',
            'matugenScheme="' + (Settings?.matugenScheme ?? "scheme-tonal-spot") + '"',
            'customColorsEnabled=' + (Settings?.customColorsEnabled ?? false)
        ];
        let confStr = lines.join("\n") + "\n";
        let targetFile = root.userPresetsDir + "/" + cleanName + ".conf";
        Quickshell.execDetached(["mkdir", "-p", root.userPresetsDir]);
        Quickshell.execDetached([
            root.writeScript,
            targetFile,
            confStr
        ]);
        root.activePresetName = cleanName;
        let itemIndex = (root.availablePresets || []).findIndex(p => p && p.id === cleanName);
        let newItem = {
            id: cleanName,
            name: cleanName,
            path: targetFile,
            desc: "user custom preset",
            isBuiltin: false
        };
        let updated = (root.availablePresets || []).slice();
        if (itemIndex >= 0) {
            updated[itemIndex] = newItem;
        } else {
            updated.push(newItem);
        }
        root.availablePresets = updated;
        root.refreshPresets();
        return true;
    }

    Component.onCompleted: {
        loadCatalog();
        refreshPresets();
    }
}
