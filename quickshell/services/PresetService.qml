// PresetService.qml
pragma Singleton
import QtQuick
import ".."
import "../theme/confFormat.mjs" as ConfFmt
import "../theme/styleEngine.mjs" as StyleEngine
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property string catalogPath: decodeURIComponent(Qt.resolvedUrl("../presets/catalog.conf").toString().replace(/^file:\/\//, ""))
    readonly property string presetsDir: decodeURIComponent(Qt.resolvedUrl("../presets").toString().replace(/^file:\/\//, ""))
    readonly property string writeScript: decodeURIComponent(Qt.resolvedUrl("../scripts/write-file.zsh").toString().replace(/^file:\/\//, ""))
    readonly property string presetsScript: decodeURIComponent(Qt.resolvedUrl("../scripts/presets.py").toString().replace(/^file:\/\//, ""))
    readonly property string userPresetsDir: {
        let xdgState = Quickshell.env("XDG_STATE_HOME");
        let base = (xdgState && xdgState.trim() !== "") ? xdgState.trim() : (Quickshell.env("HOME") + "/.local/state");
        return base + "/quickshell/presets";
    }

    readonly property var _builtinIds: ["solid", "glass", "frosted", "translucent", "tinted", "outlined", "oled", "monochrome", "islands"]
    readonly property var _legacyPresetAliases: ({
        "default": "solid",
        "island": "islands",
        "clusters": "islands",
        "tactile": "outlined",
        "minimal": "translucent"
    })

    property var catalog: ({})
    property var blockMap: ({})
    property var availablePresets: [
        { id: "solid",       name: "solid",       desc: "docked opaque clusters with continuous bar scoops",        barStyle: "solid",       barFloating: false, barGrouping: "clusters", barWidgetChrome: "grouped",   isBuiltin: true },
        { id: "glass",       name: "glass",       desc: "floating smoked glass clusters with dot dividers",         barStyle: "glass",       barFloating: true,  barGrouping: "clusters", barWidgetChrome: "grouped",   isBuiltin: true },
        { id: "frosted",     name: "frosted",     desc: "docked higher-density frosted zone pills",                 barStyle: "frosted",     barFloating: false, barGrouping: "zones",    barWidgetChrome: "pills",     isBuiltin: true },
        { id: "translucent", name: "translucent", desc: "slim floating translucent strip with borderless widgets",  barStyle: "translucent", barFloating: true,  barGrouping: "none",     barWidgetChrome: "ghost",     isBuiltin: true },
        { id: "tinted",      name: "tinted",      desc: "floating accent-washed zones with full-pill buttons",      barStyle: "tinted",      barFloating: true,  barGrouping: "zones",    barWidgetChrome: "pills",     isBuiltin: true },
        { id: "outlined",    name: "outlined",    desc: "crisp docked high-contrast frame with underline indicators",barStyle: "outlined",    barFloating: false, barGrouping: "clusters", barWidgetChrome: "underline", isBuiltin: true },
        { id: "oled",        name: "oled",        desc: "high-contrast monochrome black dock with ghost controls",  barStyle: "oled",        barFloating: false, barGrouping: "none",     barWidgetChrome: "ghost",     isBuiltin: true },
        { id: "monochrome",  name: "monochrome",  desc: "flat tonal dock with subtle underline indicators",         barStyle: "monochrome",  barFloating: false, barGrouping: "clusters", barWidgetChrome: "underline", isBuiltin: true },
        { id: "islands",     name: "islands",     desc: "detached zone capsules with wide floating spacing",        barStyle: "islands",     barFloating: true,  barGrouping: "zones",    barWidgetChrome: "grouped",   isBuiltin: true }
    ]
    property var presetDataMap: ({})
    property string activePresetName: "custom"
    property bool _applyingPreset: false

    function markCustomIfManual() {
        if (!root._applyingPreset && root.activePresetName !== "custom") {
            root.activePresetName = "custom";
        }
    }

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

    property Process listProc: Process {
        command: ["python3", root.presetsScript, "list", root.presetsDir, root.userPresetsDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const rawOut = text || "";
                const recs = ConfFmt.parseRecords(rawOut, "preset");
                if (!recs || recs.length === 0) return;

                let list = [];
                let dataMap = {};
                for (let i = 0; i < recs.length; i++) {
                    const r = recs[i];
                    if (!r || !r.id) continue;
                    const parsed = root.parseConf(r.raw || "");
                    dataMap[r.id] = parsed;
                    list.push({
                        id: r.id,
                        name: r.name || r.id,
                        desc: r.desc || "",
                        barStyle: StyleEngine.normalizeBarStyle(r.barStyle || parsed.barStyle || "solid"),
                        barFloating: r.barFloating === "true" || parsed.barFloating === true,
                        barGrouping: r.barGrouping || parsed.barGrouping || "clusters",
                        barWidgetChrome: r.barWidgetChrome || parsed.barWidgetChrome || "grouped",
                        cornerStyle: r.cornerStyle || parsed.cornerStyle || "continuous-bezier",
                        isBuiltin: r.isBuiltin === "true"
                    });
                }
                root.presetDataMap = dataMap;
                root.availablePresets = list;
            }
        }
    }

    property Process deleteProc: Process {
        onExited: root.refreshPresets()
    }

    function resolvePresetId(presetId) {
        let id = String(presetId || "").trim().toLowerCase();
        return root._legacyPresetAliases[id] ?? id;
    }

    function getPresetData(presetId) {
        let id = resolvePresetId(presetId);
        if (root.presetDataMap && root.presetDataMap[id]) {
            return root.presetDataMap[id];
        }
        return null;
    }

    function refreshPresets() {
        if (listProc.running) listProc.running = false;
        listProc.running = true;
    }

    function applyPresetById(presetId) {
        let id = resolvePresetId(presetId);
        let data = getPresetData(id);
        if (data) {
            applyPreset(data, id);
            return true;
        }
        return false;
    }

    function applyPreset(presetData, presetName) {
        if (!presetData || typeof Settings === "undefined" || !Settings) return false;

        root._applyingPreset = true;
        try {
            if (presetData.barPosition !== undefined) Settings.barPosition = presetData.barPosition;
            if (presetData.barFloating !== undefined) Settings.barFloating = Boolean(presetData.barFloating);
            if (presetData.barMargin !== undefined) Settings.barMargin = Number(presetData.barMargin);
            if (presetData.barHeight !== undefined) Settings.barHeight = Number(presetData.barHeight);
            if (presetData.barRadius !== undefined) Settings.barRadius = Number(presetData.barRadius);
            if (presetData.barOpacity !== undefined) Settings.barOpacity = Number(presetData.barOpacity);
            if (presetData.barStyle !== undefined) Settings.barStyle = StyleEngine.normalizeBarStyle(presetData.barStyle);
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
            if (presetData.scoopRadius !== undefined) Settings.scoopRadius = Number(presetData.scoopRadius);
            if (presetData.scoopBorderEnabled !== undefined) Settings.scoopBorderEnabled = Boolean(presetData.scoopBorderEnabled);
            if (presetData.scoopBorderWidth !== undefined) Settings.scoopBorderWidth = Number(presetData.scoopBorderWidth);
            if (presetData.widgetRadius !== undefined) Settings.widgetRadius = Number(presetData.widgetRadius);
            if (presetData.widgetSpacing !== undefined) Settings.widgetSpacing = Number(presetData.widgetSpacing);
            if (presetData.widgetPaddingH !== undefined) Settings.widgetPaddingH = Number(presetData.widgetPaddingH);
            if (presetData.widgetPaddingV !== undefined) Settings.widgetPaddingV = Number(presetData.widgetPaddingV);
            if (presetData.paddingScale !== undefined) Settings.paddingScale = presetData.paddingScale;

            if (presetName) root.activePresetName = presetName;
            if (Settings.save) Settings.save();
        } finally {
            root._applyingPreset = false;
        }
        return true;
    }

    function exportCurrentAsPreset(rawName, customDesc) {
        let display = String(rawName || "").trim();
        if (!display) return false;

        let slug = display.toLowerCase().replace(/[^a-z0-9_-]+/g, "_").replace(/^_+|_+$/g, "");
        if (!slug) slug = "preset_" + Math.floor(Date.now() / 1000);
        if (root._builtinIds.indexOf(slug) !== -1) {
            slug = slug + "_custom";
        }

        let safeName = display.replace(/["\n\r]/g, "");
        let mat = StyleEngine.normalizeBarStyle(Settings?.barStyle ?? "solid");
        let grp = Settings?.barGrouping ?? "clusters";
        let floating = Boolean(Settings?.barFloating ?? false);
        let autoDesc = (customDesc && String(customDesc).trim() !== "")
            ? String(customDesc).trim().replace(/["\n\r]/g, "")
            : (mat + " · " + (floating ? "floating" : "docked") + " · " + grp);

        let lines = [
            'name="' + safeName + '"',
            'desc="' + autoDesc + '"',
            'barPosition="' + (Settings?.barPosition ?? "top") + '"',
            'barFloating=' + floating,
            'barMargin=' + (Settings?.barMargin ?? 0),
            'barHeight=' + (Settings?.barHeight ?? 34),
            'barRadius=' + (Settings?.barRadius ?? 0),
            'barOpacity=' + (Settings?.barOpacity ?? 1.0),
            'barStyle="' + mat + '"',
            'barGrouping="' + grp + '"',
            'barWidgetChrome="' + (Settings?.barWidgetChrome ?? "grouped") + '"',
            'barDividers="' + (Settings?.barDividers ?? "line") + '"',
            'barIslandMode=' + (Settings?.barIslandMode ?? true),
            'bentoGap=' + (Settings?.bentoGap ?? 8),
            'bentoHoverLift=' + (Settings?.bentoHoverLift ?? true),
            "barModulesLeft=" + ConfFmt.serializeList(Settings?.barModulesLeft ?? []),
            "barModulesCenter=" + ConfFmt.serializeList(Settings?.barModulesCenter ?? []),
            "barModulesRight=" + ConfFmt.serializeList(Settings?.barModulesRight ?? []),
            'cornerStyle="' + (Settings?.cornerStyle ?? "continuous-bezier") + '"',
            'scoopRadius=' + (Settings?.scoopRadius ?? 16),
            'scoopBorderEnabled=' + (Settings?.scoopBorderEnabled ?? false),
            'scoopBorderWidth=' + (Settings?.scoopBorderWidth ?? 2),
            'widgetRadius=' + (Settings?.widgetRadius ?? 8),
            'widgetSpacing=' + (Settings?.widgetSpacing ?? 4),
            'widgetPaddingH=' + (Settings?.widgetPaddingH ?? 8),
            'widgetPaddingV=' + (Settings?.widgetPaddingV ?? 4),
            'paddingScale="' + (Settings?.paddingScale ?? "cozy") + '"'
        ];
        let confStr = lines.join("\n") + "\n";
        let targetFile = root.userPresetsDir + "/" + slug + ".conf";

        let nextMap = Object.assign({}, root.presetDataMap);
        nextMap[slug] = parseConf(confStr);
        root.presetDataMap = nextMap;

        let nextList = (root.availablePresets || []).filter(p => p.id !== slug);
        nextList.push({
            id: slug,
            name: safeName,
            desc: autoDesc,
            barStyle: mat,
            barFloating: floating,
            barGrouping: grp,
            barWidgetChrome: Settings?.barWidgetChrome ?? "grouped",
            cornerStyle: Settings?.cornerStyle ?? "continuous-bezier",
            isBuiltin: false
        });
        root.availablePresets = nextList;
        root.activePresetName = slug;

        Quickshell.execDetached([
            root.writeScript,
            targetFile,
            confStr
        ]);
        refreshDelayTimer.restart();
        return true;
    }

    function deleteUserPreset(presetId) {
        let id = String(presetId || "").trim();
        if (!id || root._builtinIds.indexOf(id) !== -1) return false;

        let nextMap = Object.assign({}, root.presetDataMap);
        delete nextMap[id];
        root.presetDataMap = nextMap;
        root.availablePresets = (root.availablePresets || []).filter(p => p.id !== id);
        if (root.activePresetName === id) {
            root.activePresetName = "custom";
        }

        if (deleteProc.running) deleteProc.running = false;
        deleteProc.command = ["python3", root.presetsScript, "delete", root.userPresetsDir, id];
        deleteProc.running = true;
        return true;
    }

    property Timer refreshDelayTimer: Timer {
        interval: 250
        repeat: false
        onTriggered: root.refreshPresets()
    }

    property Connections settingsTracker: Connections {
        target: typeof Settings !== "undefined" ? Settings : null
        function onBarPositionChanged() { root.markCustomIfManual(); }
        function onBarFloatingChanged() { root.markCustomIfManual(); }
        function onBarMarginChanged() { root.markCustomIfManual(); }
        function onBarHeightChanged() { root.markCustomIfManual(); }
        function onBarRadiusChanged() { root.markCustomIfManual(); }
        function onBarOpacityChanged() { root.markCustomIfManual(); }
        function onBarStyleChanged() { root.markCustomIfManual(); }
        function onBarGroupingChanged() { root.markCustomIfManual(); }
        function onBarWidgetChromeChanged() { root.markCustomIfManual(); }
        function onBarDividersChanged() { root.markCustomIfManual(); }
        function onBarIslandModeChanged() { root.markCustomIfManual(); }
        function onBentoGapChanged() { root.markCustomIfManual(); }
        function onBentoHoverLiftChanged() { root.markCustomIfManual(); }
        function onBarModulesLeftChanged() { root.markCustomIfManual(); }
        function onBarModulesCenterChanged() { root.markCustomIfManual(); }
        function onBarModulesRightChanged() { root.markCustomIfManual(); }
        function onScoopRadiusChanged() { root.markCustomIfManual(); }
        function onWidgetRadiusChanged() { root.markCustomIfManual(); }
        function onWidgetSpacingChanged() { root.markCustomIfManual(); }
        function onWidgetPaddingHChanged() { root.markCustomIfManual(); }
        function onWidgetPaddingVChanged() { root.markCustomIfManual(); }
        function onPaddingScaleChanged() { root.markCustomIfManual(); }
    }

    Component.onCompleted: {
        loadCatalog();
        refreshPresets();
    }
}
