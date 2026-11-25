pragma Singleton
import QtQuick
import ".."
import "../theme/confFormat.mjs" as ConfFmt
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

    function resolveBlockIcon(iconOrKey, blockId) {
        if (typeof Theme === "undefined" || !Theme) return "\uE9B0";
        const table = {
            workspaces: Theme.iconWorkspaces,
            layout: Theme.iconGrid,
            grid: Theme.iconGrid,
            windowTitle: Theme.iconSparkles,
            sparkles: Theme.iconSparkles,
            clock: Theme.iconClock,
            quickSettings: Theme.iconSettings,
            settings: Theme.iconSettings,
            battery: Theme.iconBatFull,
            batFull: Theme.iconBatFull,
            network: Theme.iconWifi,
            wifi: Theme.iconWifi,
            bluetooth: Theme.iconBluetooth,
            volume: Theme.iconVolHigh,
            volHigh: Theme.iconVolHigh,
            media: Theme.iconMusic,
            music: Theme.iconMusic,
            clipboard: Theme.iconClipboard,
            quickNotes: Theme.iconEdit,
            edit: Theme.iconEdit,
            idleInhibitor: Theme.iconCoffee,
            coffee: Theme.iconCoffee,
            notifications: Theme.iconBell,
            bell: Theme.iconBell,
            systemTray: Theme.iconTray,
            tray: Theme.iconTray,
            powerMenu: Theme.iconPower,
            power: Theme.iconPower,
            launcher: Theme.iconDistro,
            distro: Theme.iconDistro,
            wallpaper: Theme.iconWallpaper,
            screenCapture: Theme.iconCamera,
            camera: Theme.iconCamera
        };
        return table[iconOrKey] ?? table[blockId] ?? iconOrKey ?? Theme.iconGrid;
    }

    function getBlockInfo(blockId) {
        if (!blockId) return null;
        let b = root.blockMap[blockId];
        if (b) {
            return {
                id: b.id,
                type: b.type,
                category: b.category,
                name: b.name,
                icon: resolveBlockIcon(b.icon, b.id),
                desc: b.desc,
                color: b.color
            };
        }
        return {
            id: blockId,
            type: "widget",
            category: "tools",
            name: blockId,
            icon: resolveBlockIcon("", blockId),
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
                } else if (key === "barModulesLeft" || key === "barModulesCenter" || key === "barModulesRight") {
                    val = ConfFmt.parseList(val);
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

    property FileView tactilePresetFile: FileView {
        path: root.presetsDir + "/tactile.conf"
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
            else if (presetId === "tactile") t = tactilePresetFile.text();

            if (t && t.trim() !== "") {
                return parseConf(t);
            }
        } catch (e) {
            console.warn("PresetService: error parsing preset " + presetId + ": " + e);
        }
        return null;
    }

    function refreshPresets() {
        root.availablePresets = [
            { id: "default", name: "default",  desc: "docked grouped clusters",  isBuiltin: true },
            { id: "island",  name: "clusters", desc: "floating glass clusters",  isBuiltin: true },
            { id: "tactile", name: "tactile",  desc: "underline hardware dock",  isBuiltin: true },
            { id: "minimal", name: "minimal",  desc: "borderless ghost hud",     isBuiltin: true }
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
        if (presetData.barRadius !== undefined) Settings.barRadius = Number(presetData.barRadius);
        if (presetData.barStyle !== undefined) Settings.barStyle = presetData.barStyle;
        if (presetData.barGrouping !== undefined) Settings.barGrouping = presetData.barGrouping;
        if (presetData.barWidgetChrome !== undefined) Settings.barWidgetChrome = presetData.barWidgetChrome;
        if (presetData.barDividers !== undefined) Settings.barDividers = presetData.barDividers;
        if (presetData.barIslandMode !== undefined) Settings.barIslandMode = Boolean(presetData.barIslandMode);
        if (presetData.bentoGap !== undefined) Settings.bentoGap = Number(presetData.bentoGap);
        if (presetData.bentoHoverLift !== undefined) Settings.bentoHoverLift = Boolean(presetData.bentoHoverLift);
        if (presetData.barModulesLeft !== undefined) Settings.barModulesLeft = Settings.normalizeZoneList(ConfFmt.parseList(presetData.barModulesLeft), false);
        if (presetData.barModulesCenter !== undefined) Settings.barModulesCenter = Settings.normalizeZoneList(ConfFmt.parseList(presetData.barModulesCenter), true);
        if (presetData.barModulesRight !== undefined) Settings.barModulesRight = Settings.normalizeZoneList(ConfFmt.parseList(presetData.barModulesRight), false);
        if (presetData.cornerStyle !== undefined) Settings.cornerStyle = presetData.cornerStyle;
        if (presetData.notificationCornerStyle !== undefined) Settings.notificationCornerStyle = presetData.notificationCornerStyle;
        if (presetData.scoopRadius !== undefined) Settings.scoopRadius = Number(presetData.scoopRadius);
        if (presetData.widgetRadius !== undefined) Settings.widgetRadius = Number(presetData.widgetRadius);
        if (presetData.widgetSpacing !== undefined) Settings.widgetSpacing = Number(presetData.widgetSpacing);
        if (presetData.widgetPaddingH !== undefined) Settings.widgetPaddingH = Number(presetData.widgetPaddingH);
        if (presetData.paddingScale !== undefined) Settings.paddingScale = presetData.paddingScale;
        if (presetData.flavorMode !== undefined) Settings.flavorMode = presetData.flavorMode;

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
            'barHeight=' + (Settings?.barHeight ?? 34),
            'barRadius=' + (Settings?.barRadius ?? 0),
            'barStyle="' + (Settings?.barStyle ?? "regular") + '"',
            'barGrouping="' + (Settings?.barGrouping ?? "clusters") + '"',
            'barWidgetChrome="' + (Settings?.barWidgetChrome ?? "grouped") + '"',
            'barDividers="' + (Settings?.barDividers ?? "line") + '"',
            'barIslandMode=' + (Settings?.barIslandMode ?? true),
            'bentoGap=' + (Settings?.bentoGap ?? 8),
            'bentoHoverLift=' + (Settings?.bentoHoverLift ?? true),
            "barModulesLeft=" + ConfFmt.serializeList(Settings?.barModulesLeft ?? []),
            "barModulesCenter=" + ConfFmt.serializeList(Settings?.barModulesCenter ?? []),
            "barModulesRight=" + ConfFmt.serializeList(Settings?.barModulesRight ?? []),
            'cornerStyle="' + (Settings?.cornerStyle ?? "continuous-bezier") + '"',
            'notificationCornerStyle="' + (Settings?.notificationCornerStyle ?? "concave") + '"',
            'scoopRadius=' + (Settings?.scoopRadius ?? 16),
            'widgetRadius=' + (Settings?.widgetRadius ?? 8),
            'widgetSpacing=' + (Settings?.widgetSpacing ?? 4),
            'widgetPaddingH=' + (Settings?.widgetPaddingH ?? 8),
            'paddingScale="' + (Settings?.paddingScale ?? "cozy") + '"',
            'flavorMode="' + (Settings?.flavorMode ?? "actions") + '"'
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
