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
            icon: Theme?.iconGrid ?? "\uE9B0",
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
                        icon: item.icon || "\uE9B0",
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
                            map[id] = { id: id, type: "widget", category: "tools", name: id, icon: "\uE9B0", desc: "" };
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

    function getPresetData(presetId) {
        try {
            let t = "";
            if (presetId === "default") t = defaultPresetFile.text();
            else if (presetId === "minimal") t = minimalPresetFile.text();
            else if (presetId === "island") t = islandPresetFile.text();

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
        root.availablePresets = [
            { id: "default", name: "default", desc: "standard balanced bar", isBuiltin: true },
            { id: "minimal", name: "minimal", desc: "clean floating dock", isBuiltin: true },
            { id: "island",  name: "island",  desc: "dynamic notch centered", isBuiltin: true }
        ];
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

        // Native .conf flat properties
        if (presetData.barPosition !== undefined) Settings.barPosition = presetData.barPosition;
        if (presetData.barFloating !== undefined) Settings.barFloating = Boolean(presetData.barFloating);
        if (presetData.barMargin !== undefined) Settings.barMargin = Number(presetData.barMargin);
        if (presetData.barHeight !== undefined) Settings.barHeight = Number(presetData.barHeight);
        if (presetData.barStyle !== undefined) Settings.barStyle = presetData.barStyle;
        if (presetData.barModulesLeft !== undefined) Settings.barModulesLeft = presetData.barModulesLeft;
        if (presetData.barModulesCenter !== undefined) Settings.barModulesCenter = presetData.barModulesCenter;
        if (presetData.barModulesRight !== undefined) Settings.barModulesRight = presetData.barModulesRight;
        if (presetData.cornerStyle !== undefined) Settings.cornerStyle = presetData.cornerStyle;
        if (presetData.notificationCornerStyle !== undefined) Settings.notificationCornerStyle = presetData.notificationCornerStyle;
        if (presetData.scoopRadius !== undefined) Settings.scoopRadius = Number(presetData.scoopRadius);
        if (presetData.widgetRadius !== undefined) Settings.widgetRadius = Number(presetData.widgetRadius);

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
            "barModulesLeft='" + JSON.stringify(Settings?.barModulesLeft ?? []) + "'",
            "barModulesCenter='" + JSON.stringify(Settings?.barModulesCenter ?? []) + "'",
            "barModulesRight='" + JSON.stringify(Settings?.barModulesRight ?? []) + "'",
            'cornerStyle="' + (Settings?.cornerStyle ?? "continuous-bezier") + '"',
            'notificationCornerStyle="' + (Settings?.notificationCornerStyle ?? "concave") + '"',
            'scoopRadius=' + (Settings?.scoopRadius ?? 16),
            'widgetRadius=' + (Settings?.widgetRadius ?? 6)
        ];
        let confStr = lines.join("\n") + "\n";
        let targetFile = root.userPresetsDir + "/" + cleanName + ".conf";
        Quickshell.execDetached([
            root.writeScript,
            targetFile,
            confStr
        ]);
        root.activePresetName = cleanName;
        root.refreshPresets();
        return true;
    }

    Component.onCompleted: {
        loadCatalog();
        refreshPresets();
    }
}
