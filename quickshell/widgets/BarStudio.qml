// BarStudio.qml — full-featured bar studio: layout & presets, bar style & geometry, widget options, motion lab
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."
import "../controls"
import "../corners"
import "../services"

PopupPanel {
    id: root

    required property var modelData
    screen: modelData

    cardWidth: Math.min(1160, Math.max(820, (root.screen?.width ?? 1920) - 48))
    cardHeight: Math.min(720, Math.max(540, (root.screen?.height ?? 1080) - Theme.barHeight - 32))
    open: false

    property string activeTab: (Settings?.barStudioTab && ["layout", "style", "widgets", "motion"].indexOf(Settings.barStudioTab) !== -1)
        ? Settings.barStudioTab
        : "layout"
    property bool showSavePresetInput: false
    property string hoveredPresetDesc: ""

    property bool isDragging: false
    property string draggedModId: ""
    property string dragSourceZone: ""
    property int dragSourceIndex: -1
    property real ghostX: 0
    property real ghostY: 0
    property real ghostW: 240
    property real dragOffsetX: 0
    property real dragOffsetY: 0
    property string hoverZoneId: ""
    property int hoverIndex: -1

    readonly property string activeTabSubtitle: ({
        layout:  "arrange zone modules, dock edge, and material presets",
        style:   "surface material, opacity, spacing, floating islands, and bar scoops",
        widgets: "clock formatting, active window pill, workspace rail, and media equalizer",
        motion:  "animation timing, easing curves, and interactive physics playground"
    })[root.activeTab] || ""

    readonly property string activePresetDesc: {
        const list = (typeof PresetService !== "undefined" ? PresetService?.availablePresets : null) ?? [];
        const activeId = PresetService?.activePresetName ?? "";
        for (let i = 0; i < list.length; i++) {
            if (list[i].id === activeId && list[i].desc) return list[i].desc;
        }
        return "";
    }

    onActiveTabChanged: {
        if (Settings && Settings.barStudioTab !== root.activeTab) {
            Settings.barStudioTab = root.activeTab;
        }
        if (root.activeTab !== "layout" && root.isDragging) {
            root.cancelDrag();
        }
        if (root.activeTab === "style" && styleTab) styleTab.resetScroll();
        else if (root.activeTab === "widgets" && widgetsTab) widgetsTab.resetScroll();
        else if (root.activeTab === "motion" && motionTab) motionTab.resetScroll();
    }

    readonly property var moduleCatalog: ({
        "launcher":       { name: "app launcher",      icon: Theme.iconDistro,      desc: "application search & grid" },
        "wallpaper":      { name: "wallpaper browser", icon: Theme.iconWallpaper,   desc: "awww & mpvpaper selector" },
        "workspaces":     { name: "workspaces",        icon: Theme.iconWorkspaces,  desc: "hyprland workspace dots" },
        "layout":         { name: "layout switcher",   icon: Theme.iconGrid,        desc: "tiling layout & orientation" },
        "windowTitle":    { name: "active window",     icon: Theme.iconSparkles,    desc: "focused window title badge" },
        "clock":          { name: "clock & date",      icon: Theme.iconClock,       desc: "time, date & calendar" },
        "media":          { name: "media player",      icon: Theme.iconMusic,       desc: "mpris music controls" },
        "quickNotes":     { name: "quick notes",       icon: Theme.iconEdit,        desc: "floating scratchpad notes" },
        "clipboard":      { name: "clipboard manager", icon: Theme.iconClipboard,   desc: "cliphist history & sync" },
        "idleInhibitor":  { name: "idle inhibitor",    icon: Theme.iconCoffee,      desc: "stay awake toggle" },
        "notifications":  { name: "notifications",     icon: Theme.iconBell,        desc: "alert center & toast log" },
        "systemTray":     { name: "system tray",       icon: Theme.iconTray,        desc: "statusnotifier tray icons" },
        "bluetooth":      { name: "bluetooth",         icon: Theme.iconBluetooth,   desc: "bluetooth devices & scan" },
        "network":        { name: "network status",    icon: Theme.iconWifi,        desc: "wifi & ethernet monitor" },
        "volume":         { name: "volume & sink",     icon: Theme.iconVolHigh,     desc: "pipewire audio controls" },
        "battery":        { name: "battery & power",   icon: Theme.iconBatFull,     desc: "upower level & charging" },
        "quickSettings":  { name: "quick settings",    icon: Theme.iconSettings,    desc: "system & global settings" },
        "powerMenu":      { name: "power menu",        icon: Theme.iconPower,       desc: "lock, logout & power off" },
        "screenCapture":  { name: "screen capture",    icon: Theme.iconCamera,      desc: "screenshot & screen recording" }
    })

    readonly property var unassignedModules: {
        const assigned = new Set([
            ...(Settings?.barModulesLeft ?? []),
            ...(Settings?.barModulesCenter ?? []),
            ...(Settings?.barModulesRight ?? [])
        ]);
        const keys = (typeof PresetService !== "undefined" && PresetService?.blockMap && Object.keys(PresetService.blockMap).length > 0)
            ? Object.keys(PresetService.blockMap)
            : Object.keys(root.moduleCatalog);
        return keys.filter(id => !assigned.has(id));
    }

    Component.onCompleted: {
        if (Settings?.showBarStudio) {
            const focused = Hyprland?.focusedMonitor?.name;
            if (!focused || !root.screen || root.screen?.name === focused) {
                root.open = true;
            }
        }
    }

    Connections {
        target: Settings

        function onShowBarStudioChanged() {
            if (Settings?.showBarStudio) {
                const focused = Hyprland?.focusedMonitor?.name;
                root.open = (!focused || !root.screen || root.screen?.name === focused);
                if (typeof PresetService !== "undefined" && PresetService?.refreshPresets) {
                    PresetService.refreshPresets();
                }
            } else {
                root.open = false;
            }
        }

        function onBarStudioTabChanged() {
            const t = Settings?.barStudioTab;
            if (t && ["layout", "style", "widgets", "motion"].indexOf(t) !== -1 && root.activeTab !== t) {
                root.activeTab = t;
            }
        }
    }

    onOpenChanged: {
        if (!open) {
            if (isDragging) cancelDrag();
            root.showSavePresetInput = false;
            if (Settings?.showBarStudio) {
                const focused = Hyprland?.focusedMonitor?.name;
                if (!focused || !root.screen || root.screen?.name === focused) {
                    Settings.showBarStudio = false;
                }
            }
        }
    }

    function saveSettings() {
        if (Settings?.save) Settings.save();
    }

    function commitSavePreset() {
        const typed = presetNameInput.text.trim();
        if (!typed) return;
        PresetService?.exportCurrentAsPreset(typed);
        presetNameInput.text = "";
        root.showSavePresetInput = false;
    }

    function getModuleInfo(modId) {
        let b = (typeof PresetService !== "undefined" && PresetService?.getBlockInfo) ? PresetService.getBlockInfo(modId) : null;
        if (b) return b;
        if (modId === "layoutSwitcher") return root.moduleCatalog["layout"];
        if (modId === "capture") return root.moduleCatalog["screenCapture"];
        return root.moduleCatalog[modId] ?? {
            name: modId,
            icon: Theme.iconGrid,
            desc: "custom widget",
            color: Theme.primary
        };
    }

    // synced 1:1 with StatusBar.qml so modules don't pretend to be visible when they're not
    function isModuleVisible(modId) {
        if (!Settings) return true;
        switch (modId) {
            case "launcher": return Settings.showLauncher ?? true;
            case "wallpaper": return Settings.showWallpaper ?? true;
            case "workspaces": return Settings.showWorkspaces ?? true;
            case "layout": case "layoutSwitcher": return Settings.showLayoutSwitcher ?? true;
            case "windowTitle": return Settings.showWindowTitle ?? true;
            case "clock": return Settings.showClock ?? true;
            case "media": return Settings.showMedia ?? true;
            case "quickNotes": return Settings.showQuickNotes ?? true;
            case "clipboard": return Settings.showClipboard ?? true;
            case "idleInhibitor": return Settings.showIdleInhibitor ?? true;
            case "notifications": return Settings.showNotifications ?? true;
            case "systemTray": return Settings.showSystemTray ?? true;
            case "bluetooth": return Settings.showBluetooth ?? true;
            case "network": return Settings.showNetwork ?? true;
            case "volume": return Settings.showVolume ?? true;
            case "battery": return Settings.showBattery ?? true;
            case "quickSettings": return Settings.showQuickSettings ?? true;
            case "powerMenu": return Settings.showPowerMenu ?? true;
            case "screenCapture": case "capture": return Settings.showScreenCapture ?? true;
            default: return true;
        }
    }

    function toggleModuleVisibility(modId) {
        if (!Settings) return;
        setModuleVisibility(modId, !isModuleVisible(modId));
    }

    function setModuleVisibility(modId, visible) {
        if (!Settings) return;
        switch (modId) {
            case "launcher": Settings.showLauncher = visible; break;
            case "wallpaper": Settings.showWallpaper = visible; break;
            case "workspaces": Settings.showWorkspaces = visible; break;
            case "layout": case "layoutSwitcher": Settings.showLayoutSwitcher = visible; break;
            case "windowTitle": Settings.showWindowTitle = visible; break;
            case "clock": Settings.showClock = visible; break;
            case "media": Settings.showMedia = visible; break;
            case "quickNotes": Settings.showQuickNotes = visible; break;
            case "clipboard": Settings.showClipboard = visible; break;
            case "screenCapture": case "capture": Settings.showScreenCapture = visible; break;
            case "idleInhibitor": Settings.showIdleInhibitor = visible; break;
            case "notifications": Settings.showNotifications = visible; break;
            case "systemTray": Settings.showSystemTray = visible; break;
            case "bluetooth": Settings.showBluetooth = visible; break;
            case "network": Settings.showNetwork = visible; break;
            case "volume": Settings.showVolume = visible; break;
            case "battery": Settings.showBattery = visible; break;
            case "quickSettings": Settings.showQuickSettings = visible; break;
            case "powerMenu": Settings.showPowerMenu = visible; break;
        }
        saveSettings();
    }

    function getZoneList(z) {
        if (!Settings) return [];
        if (z === "left") return (Settings.barModulesLeft ?? []).slice();
        if (z === "center") return (Settings.barModulesCenter ?? []).slice();
        if (z === "right") return (Settings.barModulesRight ?? []).slice();
        return [];
    }

    function setZoneList(z, arr) {
        if (!Settings) return;
        if (z === "left") Settings.barModulesLeft = arr;
        else if (z === "center") Settings.barModulesCenter = arr;
        else if (z === "right") Settings.barModulesRight = arr;
        saveSettings();
    }

    function syncGhostPos(globalX, globalY) {
        const host = dragGhost.parent;
        const localPt = host ? host.mapFromItem(null, globalX, globalY) : { x: globalX, y: globalY };
        ghostX = localPt.x - dragOffsetX;
        ghostY = localPt.y - dragOffsetY;
    }

    function startDrag(zoneId, index, modId, cardItem, mouseX, mouseY) {
        isDragging = true;
        draggedModId = modId;
        dragSourceZone = zoneId;
        dragSourceIndex = index;
        ghostW = cardItem.width;
        dragOffsetX = mouseX;
        dragOffsetY = mouseY;

        const p = cardItem.mapToItem(null, mouseX, mouseY);
        syncGhostPos(p.x, p.y);
        updateHoverTarget(p.x, p.y);
    }

    function updateDrag(globalX, globalY) {
        syncGhostPos(globalX, globalY);
        updateHoverTarget(globalX, globalY);
    }

    function updateHoverTarget(globalX, globalY) {
        const zones = [leftColZone, centerColZone, rightColZone];
        let foundZone = null;

        for (let i = 0; i < zones.length; ++i) {
            const z = zones[i];
            const p = z.mapFromItem(null, globalX, globalY);
            if (p.x >= -6 && p.x <= z.width + 6 && p.y >= -12 && p.y <= z.height + 12) {
                foundZone = z;
                break;
            }
        }

        if (!foundZone) {
            hoverZoneId = "";
            hoverIndex = -1;
            return;
        }

        hoverZoneId = foundZone.zoneId;
        hoverIndex = foundZone.getDropIndex(globalY);
    }

    function finishDrag() {
        if (!isDragging) return;

        const fromZ = dragSourceZone;
        const fromIdx = dragSourceIndex;
        const toZ = hoverZoneId;
        const toIdx = hoverIndex;

        cancelDrag();

        if (!toZ || toIdx < 0) return;
        reorderModule(fromZ, fromIdx, toZ, toIdx);
    }

    function cancelDrag() {
        isDragging = false;
        draggedModId = "";
        dragSourceZone = "";
        dragSourceIndex = -1;
        hoverZoneId = "";
        hoverIndex = -1;
    }

    function reorderModule(fromZone, fromIdx, toZone, toIdx) {
        const src = getZoneList(fromZone);
        if (fromIdx < 0 || fromIdx >= src.length) return;
        const item = src[fromIdx];

        if (fromZone === toZone) {
            const dest = (toIdx > fromIdx) ? (toIdx - 1) : toIdx;
            if (dest === fromIdx) return;
            src.splice(fromIdx, 1);
            src.splice(Math.max(0, Math.min(src.length, dest)), 0, item);
            setZoneList(fromZone, src);
        } else {
            src.splice(fromIdx, 1);
            const dst = getZoneList(toZone);
            dst.splice(Math.max(0, Math.min(dst.length, toIdx)), 0, item);
            setZoneList(fromZone, src);
            setZoneList(toZone, dst);
        }
    }

    function moveModuleStep(zoneId, index, delta) {
        const list = getZoneList(zoneId);
        const targetIdx = index + delta;
        if (targetIdx < 0 || targetIdx >= list.length) return;
        const item = list.splice(index, 1)[0];
        list.splice(targetIdx, 0, item);
        setZoneList(zoneId, list);
    }

    function transferModule(fromZone, index, targetZone) {
        if (fromZone === targetZone) return;
        const src = getZoneList(fromZone);
        if (index < 0 || index >= src.length) return;
        const item = src.splice(index, 1)[0];
        const dst = getZoneList(targetZone);
        dst.push(item);
        setZoneList(fromZone, src);
        setZoneList(targetZone, dst);
    }

    function removeModule(zoneId, index) {
        const list = getZoneList(zoneId);
        if (index < 0 || index >= list.length) return;
        const modId = list.splice(index, 1)[0];
        setZoneList(zoneId, list);
        setModuleVisibility(modId, false);
    }

    function addModuleToZone(modId, targetZone) {
        const list = getZoneList(targetZone);
        if (list.includes(modId)) return;
        list.push(modId);
        setZoneList(targetZone, list);
        setModuleVisibility(modId, true);
    }

    content: ColumnLayout {
        id: contentRoot
        anchors.fill: parent
        spacing: Theme.popupSpacing
        focus: true

        Keys.onEscapePressed: (event) => {
            if (root.showSavePresetInput) {
                root.showSavePresetInput = false;
                presetNameInput.text = "";
                event.accepted = true;
            } else if (root.isDragging) {
                root.cancelDrag();
                event.accepted = true;
            } else if (root.open) {
                if (Settings) Settings.showBarStudio = false;
                root.open = false;
                event.accepted = true;
            }
        }

        // header row
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: Theme.radiusMd
                color: Theme.primary_overlay
                border.color: Theme.alpha(Theme.primary, 0.35)
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: Theme.iconGrid
                    font.family: Theme.fontIcon
                    font.variableAxes: Theme.iconAxes
                    font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeSm : Theme.fontSizeLg
                    color: Theme.primary
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                RowLayout {
                    spacing: 8
                    Text {
                        text: "bar layout studio"
                        font.family: Theme.fontDisplay
                        font.variableAxes: Theme.displayAxes
                        font.pixelSize: Theme.fontSizeMd
                        font.weight: Theme.fontWeightBold
                        color: Theme.on_surface
                    }

                    Rectangle {
                        height: 20
                        implicitWidth: matTag.implicitWidth + 12
                        radius: Theme.radiusPill
                        color: Theme.primary_overlay
                        border.color: Theme.alpha(Theme.primary, 0.35)
                        border.width: 1

                        Text {
                            id: matTag
                            anchors.centerIn: parent
                            text: Theme.barStyle + " · " + ((Settings?.barFloating || Theme.isIslands) ? "floating" : "docked")
                            font.family: Theme.fontMono
                            font.variableAxes: Theme.monoAxes
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: Theme.monoWeightBold
                            color: Theme.primary
                        }
                    }
                }

                Text {
                    text: root.activeTabSubtitle
                    font.family: Theme.fontFamily
                    font.variableAxes: Theme.sansAxes
                    font.weight: Theme.fontWeightRegular
                    font.pixelSize: Theme.fontSizeXs
                    color: Theme.on_surface_variant
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            // open global settings button
            Rectangle {
                Layout.preferredHeight: 28
                Layout.preferredWidth: openSetRow.implicitWidth + 16
                radius: Theme.radiusPill
                color: openSetMouse.containsMouse ? Theme.primary_overlay : Theme.pillBg
                border.color: openSetMouse.containsMouse ? Theme.primary : Theme.widgetBorder
                border.width: 1

                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                Row {
                    id: openSetRow
                    anchors.centerIn: parent
                    spacing: 5
                    Text {
                        visible: !Theme.isTextIconSet
                        text: Theme.iconSettings
                        font.family: Theme.fontIcon
                        font.variableAxes: Theme.iconAxes
                        font.pixelSize: Theme.fontSizeXs
                        color: openSetMouse.containsMouse ? Theme.primary : Theme.on_surface
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "settings"
                        font.family: Theme.fontFamily
                        font.variableAxes: Theme.sansAxes
                        font.weight: Theme.fontWeightRegular
                        font.pixelSize: Theme.fontSizeXs
                        color: openSetMouse.containsMouse ? Theme.primary : Theme.on_surface
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: openSetMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (Settings) Settings.showBarStudio = false;
                        root.open = false;
                        if (Settings?.requestQuickSettingsOpen) Settings.requestQuickSettingsOpen();
                    }
                }
            }

            // reset bar defaults button
            Rectangle {
                Layout.preferredHeight: 28
                Layout.preferredWidth: resetRow.implicitWidth + 16
                radius: Theme.radiusPill
                color: resetMouse.pressed ? Theme.widgetActive : (resetMouse.containsMouse ? Theme.pillHover : Theme.pillBg)
                border.color: Theme.widgetBorder
                border.width: 1

                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                Row {
                    id: resetRow
                    anchors.centerIn: parent
                    spacing: 5
                    Text {
                        visible: !Theme.isTextIconSet
                        text: Theme.iconRefresh
                        font.family: Theme.fontIcon
                        font.variableAxes: Theme.iconAxes
                        font.pixelSize: Theme.fontSizeXs
                        color: Theme.on_surface
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "reset bar"
                        font.family: Theme.fontFamily
                        font.variableAxes: Theme.sansAxes
                        font.weight: Theme.fontWeightRegular
                        font.pixelSize: Theme.fontSizeXs
                        color: Theme.on_surface
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: resetMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (Settings?.resetBarLayout) Settings.resetBarLayout();
                        if (typeof PresetService !== "undefined" && PresetService) {
                            PresetService.activePresetName = "solid";
                        }
                        root.saveSettings();
                    }
                }
            }

            // reload shell button
            Rectangle {
                Layout.preferredHeight: 28
                Layout.preferredWidth: reloadShellRow.implicitWidth + 16
                radius: Theme.radiusPill
                color: reloadShellMouse.containsMouse ? Theme.primary_overlay : Theme.pillBg
                border.color: reloadShellMouse.containsMouse ? Theme.primary : Theme.widgetBorder
                border.width: 1

                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                Row {
                    id: reloadShellRow
                    anchors.centerIn: parent
                    spacing: 5
                    Text {
                        visible: !Theme.isTextIconSet
                        text: Theme.iconRefresh
                        font.family: Theme.fontIcon
                        font.variableAxes: Theme.iconAxes
                        font.pixelSize: Theme.fontSizeXs
                        color: reloadShellMouse.containsMouse ? Theme.primary : Theme.on_surface
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "reload shell"
                        font.family: Theme.fontFamily
                        font.variableAxes: Theme.sansAxes
                        font.weight: Theme.fontWeightRegular
                        font.pixelSize: Theme.fontSizeXs
                        color: reloadShellMouse.containsMouse ? Theme.primary : Theme.on_surface
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: reloadShellMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (Settings) Settings.showBarStudio = false;
                        root.open = false;
                        Quickshell.execDetached([(Quickshell.env("HOME") || "") + "/.local/bin/cli", "shell", "restart"]);
                    }
                }
            }

            // close button
            Rectangle {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: Theme.radiusPill
                color: closeMouse.containsMouse ? Theme.error_overlay : Theme.pillBg
                border.color: closeMouse.containsMouse ? Theme.error : Theme.widgetBorder
                border.width: 1

                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                Text {
                    anchors.centerIn: parent
                    text: Theme.iconClose
                    font.family: Theme.fontIcon
                    font.variableAxes: Theme.iconAxes
                    font.pixelSize: Theme.fontSizeXs
                    color: closeMouse.containsMouse ? Theme.error : Theme.on_surface
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (Settings) Settings.showBarStudio = false;
                        root.open = false;
                    }
                }
            }
        }

        // tab bar
        Flickable {
            id: tabFlick
            Layout.fillWidth: true
            height: 32
            contentWidth: tabRow.implicitWidth
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            WheelHandler {
                orientation: Qt.Vertical
                onWheel: (event) => {
                    const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                    const targetX = tabFlick.contentX - (delta * 0.8);
                    const maxX = Math.max(0, tabFlick.contentWidth - tabFlick.width);
                    tabFlick.contentX = Math.max(0, Math.min(maxX, targetX));
                    event.accepted = true;
                }
            }

            RowLayout {
                id: tabRow
                spacing: 6
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: [
                        { id: "layout",  label: "layout",     icon: Theme.iconGrid },
                        { id: "style",   label: "bar style",  icon: Theme.iconPalette },
                        { id: "widgets", label: "widgets",    icon: Theme.iconClock },
                        { id: "motion",  label: "motion lab", icon: Theme.iconFlame }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool isSelected: root.activeTab === modelData.id
                        height: 30
                        width: tabItemRow.implicitWidth + 22
                        radius: isSelected ? Theme.radiusMd : Theme.radiusPill
                        color: isSelected
                            ? Theme.primary_overlay
                            : (tabMouse.containsMouse ? Theme.pillHover : Theme.pillBg)
                        border.color: isSelected ? Theme.primary : Theme.pillBorder
                        border.width: (isSelected || Theme.pillBorder.a > 0) ? 1 : 0

                        Behavior on radius { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
                        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
                        Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                        RowLayout {
                            id: tabItemRow
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                visible: !Theme.isTextIconSet
                                text: modelData.icon
                                font.family: Theme.fontIcon
                                font.variableAxes: Theme.iconAxes
                                font.pixelSize: Theme.fontSizeSm
                                color: isSelected ? Theme.primary : Theme.textSecondary
                            }

                            Text {
                                text: modelData.label
                                font.family: Theme.fontFamily
                                font.variableAxes: Theme.sansAxes
                                font.pixelSize: Theme.fontSizeSm
                                font.weight: isSelected ? Theme.fontWeightBold : Theme.fontWeightMedium
                                color: isSelected ? Theme.primary : Theme.textSecondary
                            }
                        }

                        MouseArea {
                            id: tabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activeTab = modelData.id
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: Theme.popupDividerHeight
            color: Theme.widgetBorder
        }

        // tab container
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // TAB 1: LAYOUT (presets, mini preview + dock edge, 3-zone drag & drop, unassigned tray)
            ColumnLayout {
                anchors.fill: parent
                visible: root.activeTab === "layout"
                spacing: Theme.popupSpacing

                // Presets bar (material presets + user-saved presets w/ typed naming + delete)
                Rectangle {
                    id: presetBarCard
                    Layout.fillWidth: true
                    implicitHeight: presetCol.implicitHeight + 16
                    radius: Theme.radiusMd
                    color: Theme.cardBg
                    border.color: Theme.cardBorder
                    border.width: 1

                    Rectangle {
                        visible: Theme.isGlass
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: Theme.glassHighlight
                    }

                    ColumnLayout {
                        id: presetCol
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "presets"
                                font.family: Theme.fontDisplay
                                font.variableAxes: Theme.displayAxes
                                font.pixelSize: Theme.fontSizeXs
                                font.weight: Theme.fontWeightBold
                                color: Theme.textPrimary
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.hoveredPresetDesc !== ""
                                    ? root.hoveredPresetDesc
                                    : (root.activePresetDesc !== ""
                                        ? root.activePresetDesc
                                        : ("active: " + (PresetService?.activePresetName ?? "custom") + " · built from bar materials"))
                                font.family: Theme.fontFamily
                                font.variableAxes: Theme.sansAxes
                                font.weight: Theme.fontWeightRegular
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.textSecondary
                                elide: Text.ElideRight
                            }

                            // Inline preset name prompt OR "save as preset" button
                            RowLayout {
                                visible: root.showSavePresetInput
                                spacing: 5

                                Rectangle {
                                    width: 170
                                    height: 24
                                    radius: Theme.radiusSm
                                    color: Theme.widgetBg
                                    border.color: presetNameInput.activeFocus ? Theme.primary : Theme.widgetBorder
                                    border.width: 1

                                    Text {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        verticalAlignment: Text.AlignVCenter
                                        visible: presetNameInput.text === "" && !presetNameInput.activeFocus
                                        text: "type preset name..."
                                        font.family: Theme.fontFamily
                                        font.variableAxes: Theme.sansAxes
                                        font.weight: Theme.fontWeightRegular
                                        font.pixelSize: Theme.fontSizeXs
                                        color: Theme.textSecondary
                                    }

                                    TextInput {
                                        id: presetNameInput
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        verticalAlignment: TextInput.AlignVCenter
                                        font.family: Theme.fontFamily
                                        font.variableAxes: Theme.sansAxes
                                        font.weight: Theme.fontWeightRegular
                                        font.pixelSize: Theme.fontSizeXs
                                        color: Theme.textPrimary
                                        clip: true
                                        Keys.onReturnPressed: root.commitSavePreset()
                                        Keys.onEscapePressed: {
                                            presetNameInput.text = "";
                                            root.showSavePresetInput = false;
                                        }
                                    }
                                }

                                Rectangle {
                                    height: 24
                                    implicitWidth: confirmSaveTxt.implicitWidth + 14
                                    radius: Theme.radiusPill
                                    readonly property bool canSave: presetNameInput.text.trim().length > 0
                                    color: canSave ? Theme.primary : Theme.widgetBg
                                    opacity: canSave ? 1.0 : 0.55

                                    Text {
                                        id: confirmSaveTxt
                                        anchors.centerIn: parent
                                        text: "save"
                                        font.family: Theme.fontFamily
                                        font.variableAxes: Theme.sansAxes
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightBold
                                        color: parent.canSave ? Theme.on_primary : Theme.textSecondary
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: parent.canSave ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: if (parent.canSave) root.commitSavePreset()
                                    }
                                }

                                Rectangle {
                                    height: 24
                                    width: 24
                                    radius: Theme.radiusPill
                                    color: cancelSaveMouse.containsMouse ? Theme.error_overlay : Theme.widgetBg
                                    border.color: cancelSaveMouse.containsMouse ? Theme.error : Theme.widgetBorder
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: Theme.iconClose
                                        font.family: Theme.fontIcon
                                        font.variableAxes: Theme.iconAxes
                                        font.pixelSize: 10
                                        color: cancelSaveMouse.containsMouse ? Theme.error : Theme.textSecondary
                                    }

                                    MouseArea {
                                        id: cancelSaveMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            presetNameInput.text = "";
                                            root.showSavePresetInput = false;
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                visible: !root.showSavePresetInput
                                height: 24
                                implicitWidth: saveRow.implicitWidth + 14
                                radius: Theme.radiusPill
                                color: saveMouse.containsMouse ? Theme.primary_overlay : "transparent"
                                border.color: saveMouse.containsMouse ? Theme.primary : Theme.widgetBorder
                                border.width: 1

                                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                Row {
                                    id: saveRow
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        visible: !Theme.isTextIconSet
                                        text: Theme.iconSave
                                        font.family: Theme.fontIcon
                                        font.variableAxes: Theme.iconAxes
                                        font.pixelSize: Theme.fontSizeXs
                                        color: Theme.primary
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: "save preset"
                                        font.family: Theme.fontFamily
                                        font.variableAxes: Theme.sansAxes
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightDemiBold
                                        color: Theme.primary
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: saveMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.showSavePresetInput = true;
                                        presetNameInput.forceActiveFocus();
                                    }
                                }
                            }
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: 6

                            Repeater {
                                model: (typeof PresetService !== "undefined" ? PresetService?.availablePresets : null) ?? []
                                delegate: Rectangle {
                                    required property var modelData
                                    readonly property bool isCurrent: PresetService?.activePresetName === modelData.id
                                    readonly property bool isUserPreset: !modelData.isBuiltin
                                    height: 24
                                    implicitWidth: pPillRow.implicitWidth + 14
                                    radius: Theme.radiusPill
                                    color: isCurrent ? Theme.primary : (pMouse.containsMouse ? Theme.pillHover : Theme.pillBg)
                                    border.color: isCurrent ? Theme.primary : (isUserPreset ? Theme.alpha(Theme.secondary, 0.55) : Theme.pillBorder)
                                    border.width: (border.color === "transparent" || border.color.a === 0) ? 0 : 1

                                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                    MouseArea {
                                        id: pMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: root.hoveredPresetDesc = (modelData.name + ": " + (modelData.desc || ""))
                                        onExited: root.hoveredPresetDesc = ""
                                        onClicked: PresetService?.applyPresetById(modelData.id)
                                    }

                                    Row {
                                        id: pPillRow
                                        anchors.centerIn: parent
                                        spacing: 5

                                        Rectangle {
                                            visible: isUserPreset
                                            width: 5
                                            height: 5
                                            radius: 2.5
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: isCurrent ? Theme.on_primary : Theme.secondary
                                        }

                                        Text {
                                            text: modelData.name
                                            font.family: Theme.fontFamily
                                            font.variableAxes: Theme.sansAxes
                                            font.pixelSize: Theme.fontSizeXs
                                            font.weight: isCurrent ? Theme.fontWeightBold : Theme.fontWeightRegular
                                            color: isCurrent ? Theme.on_primary : Theme.on_surface
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Rectangle {
                                            visible: isUserPreset
                                            width: 14
                                            height: 14
                                            radius: 7
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: delMouse.containsMouse
                                                ? (isCurrent ? Theme.alpha(Theme.on_primary, 0.25) : Theme.error_overlay)
                                                : "transparent"

                                            Text {
                                                anchors.centerIn: parent
                                                text: "×"
                                                font.family: Theme.fontFamily
                                                font.variableAxes: Theme.sansAxes
                                                font.pixelSize: 10
                                                font.weight: Theme.fontWeightBold
                                                color: delMouse.containsMouse
                                                    ? (isCurrent ? Theme.on_primary : Theme.error)
                                                    : (isCurrent ? Theme.on_primary : Theme.textSecondary)
                                            }

                                            MouseArea {
                                                id: delMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: (mouse) => {
                                                    mouse.accepted = true;
                                                    PresetService?.deleteUserPreset(modelData.id);
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // live mini screen preview
                Rectangle {
                    id: barPreviewMock
                    Layout.fillWidth: true
                    Layout.preferredHeight: 82
                    color: Theme.cardBg
                    radius: Theme.radiusMd
                    border.color: Theme.cardBorder
                    border.width: 1
                    clip: true

                    readonly property string barPos: Settings?.barPosition ?? "top"
                    readonly property bool isTop: barPos === "up" || barPos === "top"
                    readonly property bool isBottom: barPos === "down" || barPos === "bottom"
                    readonly property bool isLeft: barPos === "left"
                    readonly property bool isRight: barPos === "right"
                    readonly property bool isVertical: isLeft || isRight
                    readonly property bool isFloating: (Settings?.barFloating ?? false) || Theme.isIslands

                    Rectangle {
                        visible: Theme.isGlass
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: Theme.glassHighlight
                    }

                    Rectangle {
                        id: screenMock
                        anchors.fill: parent
                        anchors.margins: 7
                        color: Theme.background
                        radius: Theme.radiusSm
                        border.color: Theme.widgetBorder
                        border.width: 1
                        clip: true

                        Rectangle {
                            id: mockBar
                            anchors.left: !barPreviewMock.isRight ? parent.left : undefined
                            anchors.right: !barPreviewMock.isLeft ? parent.right : undefined
                            anchors.top: !barPreviewMock.isBottom ? parent.top : undefined
                            anchors.bottom: !barPreviewMock.isTop ? parent.bottom : undefined
                            anchors.margins: barPreviewMock.isFloating ? 4 : 0
                            width: barPreviewMock.isVertical ? 24 : (parent.width - (barPreviewMock.isFloating ? 8 : 0))
                            height: barPreviewMock.isVertical ? (parent.height - (barPreviewMock.isFloating ? 8 : 0)) : 22
                            radius: barPreviewMock.isFloating ? Theme.radiusSm : 0
                            color: Theme.cornerFill
                            border.color: barPreviewMock.isFloating ? Theme.barBorderColor : "transparent"
                            border.width: barPreviewMock.isFloating ? 1 : 0
                            z: 2

                            component MiniModulePill: Rectangle {
                                required property string modelData
                                readonly property var info: root.getModuleInfo(modelData)
                                readonly property bool isVis: root.isModuleVisible(modelData)
                                readonly property bool isGhostTarget: root.isDragging && root.draggedModId === modelData
                                readonly property color bColor: info?.color ?? Theme.primary

                                height: barPreviewMock.isVertical ? 14 : 13
                                width: barPreviewMock.isVertical ? 14 : Math.max(14, mText.implicitWidth + 6)
                                radius: Theme.radiusXs
                                color: isGhostTarget ? Theme.on_surface : (isVis ? bColor : Theme.widgetBg)
                                border.color: isGhostTarget ? Theme.primary : "transparent"
                                border.width: 1

                                Text {
                                    id: mText
                                    anchors.centerIn: parent
                                    text: parent.info.icon
                                    font.family: Theme.fontIcon
                                    font.variableAxes: Theme.iconAxes
                                    font.pixelSize: 8
                                    color: parent.isGhostTarget ? Theme.surface : (parent.isVis ? Theme.on_primary : Theme.on_surface_disabled)
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 3
                                spacing: 3
                                visible: !barPreviewMock.isVertical

                                Repeater {
                                    model: Settings?.barModulesLeft ?? []
                                    MiniModulePill {}
                                }

                                Item { Layout.fillWidth: true }

                                Repeater {
                                    model: Settings?.barModulesCenter ?? []
                                    MiniModulePill {}
                                }

                                Item { Layout.fillWidth: true }

                                Repeater {
                                    model: Settings?.barModulesRight ?? []
                                    MiniModulePill {}
                                }
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 3
                                spacing: 3
                                visible: barPreviewMock.isVertical

                                Repeater {
                                    model: Settings?.barModulesLeft ?? []
                                    MiniModulePill {}
                                }

                                Item { Layout.fillHeight: true }

                                Repeater {
                                    model: Settings?.barModulesCenter ?? []
                                    MiniModulePill {}
                                }

                                Item { Layout.fillHeight: true }

                                Repeater {
                                    model: Settings?.barModulesRight ?? []
                                    MiniModulePill {}
                                }
                            }
                        }

                        ConcaveCorner {
                            visible: !barPreviewMock.isFloating && Theme.screenFrameDocked
                            radius: 8
                            fillColor: Theme.cornerFill
                            x: barPreviewMock.isLeft ? mockBar.width : (barPreviewMock.isRight ? (screenMock.width - mockBar.width - width) : 0)
                            y: barPreviewMock.isTop ? mockBar.height : (barPreviewMock.isBottom ? (screenMock.height - mockBar.height - height) : 0)
                            flipX: barPreviewMock.isRight
                            flipY: barPreviewMock.isBottom
                            z: 2
                        }

                        ConcaveCorner {
                            visible: !barPreviewMock.isFloating && Theme.screenFrameDocked
                            radius: 8
                            fillColor: Theme.cornerFill
                            x: barPreviewMock.isLeft ? mockBar.width : (barPreviewMock.isRight ? (screenMock.width - mockBar.width - width) : (screenMock.width - width))
                            y: barPreviewMock.isTop ? mockBar.height : (barPreviewMock.isBottom ? (screenMock.height - mockBar.height - height) : (screenMock.height - height))
                            flipX: !barPreviewMock.isLeft
                            flipY: !barPreviewMock.isTop
                            z: 2
                        }

                        Rectangle {
                            anchors.left: barPreviewMock.isLeft ? mockBar.right : parent.left
                            anchors.right: barPreviewMock.isRight ? mockBar.left : parent.right
                            anchors.top: barPreviewMock.isTop ? mockBar.bottom : parent.top
                            anchors.bottom: barPreviewMock.isBottom ? mockBar.top : parent.bottom
                            anchors.margins: 6
                            color: Theme.widgetBg
                            radius: Theme.radiusSm
                            border.color: Theme.widgetBorder
                            border.width: 1

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8

                                Text {
                                    text: "dock position:"
                                    font.family: Theme.fontFamily
                                    font.variableAxes: Theme.sansAxes
                                    font.weight: Theme.fontWeightRegular
                                    font.pixelSize: Theme.fontSizeXs
                                    color: Theme.on_surface_variant
                                }

                                Repeater {
                                    model: [
                                        { pos: "top",    label: "top ↑" },
                                        { pos: "bottom", label: "bottom ↓" },
                                        { pos: "left",   label: "left ←" },
                                        { pos: "right",  label: "right →" }
                                    ]

                                    delegate: Rectangle {
                                        required property var modelData
                                        height: 22
                                        implicitWidth: dockText.implicitWidth + 12
                                        radius: Theme.radiusPill
                                        readonly property bool isCurrent: (Settings?.barPosition === modelData.pos)
                                            || (modelData.pos === "top" && Settings?.barPosition === "up")
                                            || (modelData.pos === "bottom" && Settings?.barPosition === "down")
                                        color: isCurrent ? Theme.primary : (dockMouse.containsMouse ? Theme.pillHover : Theme.pillBg)
                                        border.color: isCurrent ? Theme.primary : Theme.pillBorder
                                        border.width: (border.color === "transparent" || border.color.a === 0) ? 0 : 1

                                        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                        Text {
                                            id: dockText
                                            anchors.centerIn: parent
                                            text: modelData.label
                                            font.family: Theme.fontFamily
                                            font.variableAxes: Theme.sansAxes
                                            font.pixelSize: Theme.fontSizeXs
                                            font.weight: isCurrent ? Theme.fontWeightBold : Theme.fontWeightRegular
                                            color: isCurrent ? Theme.on_primary : Theme.on_surface
                                        }

                                        MouseArea {
                                            id: dockMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (Settings) {
                                                    Settings.barPosition = modelData.pos;
                                                    root.saveSettings();
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // 3-zone drag-drop board
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Theme.popupSpacing

                    ZoneColumn {
                        id: leftColZone
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        zoneId: "left"
                        zoneTitle: barPreviewMock.isVertical ? "top modules" : "left modules"
                        modulesList: Settings?.barModulesLeft ?? []
                    }

                    ZoneColumn {
                        id: centerColZone
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        zoneId: "center"
                        zoneTitle: "center modules"
                        modulesList: Settings?.barModulesCenter ?? []
                    }

                    ZoneColumn {
                        id: rightColZone
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        zoneId: "right"
                        zoneTitle: barPreviewMock.isVertical ? "bottom modules" : "right modules"
                        modulesList: Settings?.barModulesRight ?? []
                    }
                }

                // unassigned tray
                Rectangle {
                    id: unassignedTray
                    visible: root.unassignedModules.length > 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    color: Theme.cardBg
                    radius: Theme.radiusSm
                    border.color: Theme.cardBorder
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Text {
                            text: "unassigned (" + root.unassignedModules.length + "):"
                            font.family: Theme.fontFamily
                            font.variableAxes: Theme.sansAxes
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: Theme.fontWeightDemiBold
                            color: Theme.on_surface_variant
                        }

                        Flickable {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            contentWidth: unassignedRow.implicitWidth
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            Row {
                                id: unassignedRow
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                Repeater {
                                    model: root.unassignedModules

                                    delegate: Rectangle {
                                        required property string modelData
                                        readonly property var info: root.getModuleInfo(modelData)

                                        height: 24
                                        implicitWidth: pillRow.implicitWidth + 12
                                        radius: Theme.radiusPill
                                        color: Theme.pillBg
                                        border.color: Theme.pillBorder
                                        border.width: (border.color === "transparent" || border.color.a === 0) ? 0 : 1

                                        Row {
                                            id: pillRow
                                            anchors.centerIn: parent
                                            spacing: 5

                                            Text {
                                                visible: !Theme.isTextIconSet
                                                text: parent.parent.info.icon
                                                font.family: Theme.fontIcon
                                                font.variableAxes: Theme.iconAxes
                                                font.pixelSize: Theme.fontSizeXs
                                                color: Theme.primary
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Text {
                                                text: parent.parent.info.name
                                                font.family: Theme.fontFamily
                                                font.variableAxes: Theme.sansAxes
                                                font.weight: Theme.fontWeightRegular
                                                font.pixelSize: Theme.fontSizeXs
                                                color: Theme.on_surface
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Text {
                                                text: "+left"
                                                font.family: Theme.fontFamily
                                                font.variableAxes: Theme.sansAxes
                                                font.pixelSize: Theme.fontSizeXs
                                                font.weight: Theme.fontWeightBold
                                                color: leftAddMouse.containsMouse ? Theme.primary : Theme.on_surface_variant
                                                anchors.verticalCenter: parent.verticalCenter

                                                MouseArea {
                                                    id: leftAddMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.addModuleToZone(modelData, "left")
                                                }
                                            }

                                            Text {
                                                text: "+center"
                                                font.family: Theme.fontFamily
                                                font.variableAxes: Theme.sansAxes
                                                font.pixelSize: Theme.fontSizeXs
                                                font.weight: Theme.fontWeightBold
                                                color: centerAddMouse.containsMouse ? Theme.primary : Theme.on_surface_variant
                                                anchors.verticalCenter: parent.verticalCenter

                                                MouseArea {
                                                    id: centerAddMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.addModuleToZone(modelData, "center")
                                                }
                                            }

                                            Text {
                                                text: "+right"
                                                font.family: Theme.fontFamily
                                                font.variableAxes: Theme.sansAxes
                                                font.pixelSize: Theme.fontSizeXs
                                                font.weight: Theme.fontWeightBold
                                                color: rightAddMouse.containsMouse ? Theme.primary : Theme.on_surface_variant
                                                anchors.verticalCenter: parent.verticalCenter

                                                MouseArea {
                                                    id: rightAddMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.addModuleToZone(modelData, "right")
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

            // TAB 2: BAR STYLE & GEOMETRY
            BarStudioStyleTab {
                id: styleTab
                anchors.fill: parent
                visible: root.activeTab === "style"
            }

            // TAB 3: BAR WIDGETS (clock, workspaces, window title, media)
            BarStudioWidgetsTab {
                id: widgetsTab
                anchors.fill: parent
                visible: root.activeTab === "widgets"
            }

            // TAB 4: MOTION LAB (merged MotionSandbox + timing/easing curves)
            BarStudioMotionTab {
                id: motionTab
                anchors.fill: parent
                visible: root.activeTab === "motion"
                activeTabOpen: root.open && root.activeTab === "motion"
            }
        }
    }

    component ZoneColumn: Rectangle {
        id: zoneRoot
        required property string zoneId
        required property string zoneTitle
        required property var modulesList

        readonly property bool isOverThisZone: root.isDragging && root.hoverZoneId === zoneRoot.zoneId

        radius: Theme.radiusMd
        color: isOverThisZone ? Theme.widgetHover : Theme.cardBg
        border.color: isOverThisZone ? Theme.primary : Theme.cardBorder
        border.width: isOverThisZone ? 2 : 1
        clip: true

        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
        Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

        Rectangle {
            visible: Theme.isGlass
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Theme.glassHighlight
        }

        function getActiveCount() {
            const list = zoneRoot.modulesList ?? [];
            let count = 0;
            for (let i = 0; i < list.length; ++i) {
                if (root.isModuleVisible(list[i])) count++;
            }
            return count;
        }

        function getDropIndex(globalY) {
            const list = zoneRoot.modulesList;
            if (!list || list.length === 0) return 0;
            const p = moduleCol.mapFromItem(null, 0, globalY);
            const idx = Math.round((p.y - 19) / 44);
            return Math.max(0, Math.min(list.length, idx));
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: zoneRoot.zoneTitle
                    font.family: Theme.fontFamily
                    font.variableAxes: Theme.sansAxes
                    font.pixelSize: Theme.fontSizeSm
                    font.weight: Theme.fontWeightBold
                    color: zoneRoot.isOverThisZone ? Theme.primary : Theme.on_surface
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: zoneRoot.getActiveCount() + "/" + zoneRoot.modulesList.length + " active"
                    font.family: Theme.fontMono
                    font.variableAxes: Theme.monoAxes
                    font.weight: Theme.monoWeightRegular
                    font.pixelSize: Theme.fontSizeXs
                    color: Theme.on_surface_variant
                }
            }

            Flickable {
                id: flickable
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                interactive: !root.isDragging
                contentHeight: Math.max(height, moduleCol.implicitHeight + 10)
                contentWidth: width
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: moduleCol
                    width: flickable.width
                    spacing: 0

                    Repeater {
                        model: zoneRoot.modulesList

                        delegate: Column {
                            id: cardColWrap
                            required property string modelData
                            required property int index
                            readonly property var info: root.getModuleInfo(modelData)
                            readonly property bool isVisible: root.isModuleVisible(modelData)
                            readonly property bool isThisDragged: root.isDragging && root.draggedModId === modelData
                            readonly property bool isNoOpTarget: zoneRoot.zoneId === root.dragSourceZone && (root.hoverIndex === root.dragSourceIndex || root.hoverIndex === root.dragSourceIndex + 1)
                            readonly property bool showDropBefore: zoneRoot.isOverThisZone && root.hoverIndex === index && !isNoOpTarget

                            width: moduleCol.width
                            spacing: 0

                            Rectangle {
                                width: parent.width
                                height: cardColWrap.showDropBefore ? 6 : 0
                                color: "transparent"
                                visible: height > 0

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.width - 8
                                    height: 3
                                    radius: 1.5
                                    color: Theme.primary
                                }
                            }

                            ScratchBlock {
                                id: card
                                width: parent.width
                                blockId: cardColWrap.modelData
                                zoneId: zoneRoot.zoneId
                                index: cardColWrap.index
                                isDragged: cardColWrap.isThisDragged
                                isVisibleInBar: cardColWrap.isVisible

                                onDragStarted: (mx, my) => {
                                    root.startDrag(zoneRoot.zoneId, cardColWrap.index, cardColWrap.modelData, card, mx, my);
                                }
                                onDragUpdated: (gx, gy) => {
                                    root.updateDrag(gx, gy);
                                }
                                onDragFinished: {
                                    root.finishDrag();
                                }
                                onDragCanceled: {
                                    root.cancelDrag();
                                }
                                onShiftZoneRequested: (targetZone) => {
                                    root.transferModule(zoneRoot.zoneId, cardColWrap.index, targetZone);
                                }
                                onMoveStepRequested: (delta) => {
                                    root.moveModuleStep(zoneRoot.zoneId, cardColWrap.index, delta);
                                }
                                onVisibilityToggled: {
                                    root.toggleModuleVisibility(cardColWrap.modelData);
                                }
                                onRemoveRequested: {
                                    root.removeModule(zoneRoot.zoneId, cardColWrap.index);
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: (zoneRoot.isOverThisZone && cardColWrap.index === zoneRoot.modulesList.length - 1 && root.hoverIndex >= zoneRoot.modulesList.length && !cardColWrap.isNoOpTarget) ? 6 : 0
                                color: "transparent"
                                visible: height > 0

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.width - 8
                                    height: 3
                                    radius: 1.5
                                    color: Theme.primary
                                }
                            }

                            Item {
                                width: parent.width
                                height: 6
                            }
                        }
                    }

                    Rectangle {
                        visible: zoneRoot.modulesList.length === 0
                        width: parent.width
                        height: 64
                        radius: Theme.radiusSm
                        color: zoneRoot.isOverThisZone ? Theme.primary_overlay : "transparent"
                        border.color: zoneRoot.isOverThisZone ? Theme.primary : Theme.widgetBorder
                        border.width: 1

                        Column {
                            anchors.centerIn: parent
                            spacing: 2
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: zoneRoot.isOverThisZone ? "drop module here" : "empty zone"
                                font.family: Theme.fontFamily
                                font.variableAxes: Theme.sansAxes
                                font.pixelSize: Theme.fontSizeSm
                                font.weight: Theme.fontWeightBold
                                color: zoneRoot.isOverThisZone ? Theme.primary : Theme.on_surface_variant
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "drag cards across or use unassigned tray"
                                font.family: Theme.fontFamily
                                font.variableAxes: Theme.sansAxes
                                font.weight: Theme.fontWeightRegular
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.on_surface_disabled
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: dragGhost
        visible: root.isDragging
        x: root.ghostX
        y: root.ghostY
        width: root.ghostW
        height: Theme.popupCardHeight
        radius: Theme.radiusSm
        readonly property var info: root.getModuleInfo(root.draggedModId)
        readonly property color ghostColor: info?.color ?? Theme.primary
        color: Theme.cardBg
        border.color: Theme.primary
        border.width: 1.5
        z: 99999
        opacity: 0.95
        scale: 1.04

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 4
            width: 3
            radius: 1.5
            color: dragGhost.ghostColor
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 8
            spacing: 8

            Text {
                text: "⠿"
                font.family: Theme.fontFamily
                font.variableAxes: Theme.sansAxes
                font.weight: Theme.fontWeightRegular
                font.pixelSize: Theme.fontSizeMd
                color: Theme.on_surface_variant
            }

            Rectangle {
                Layout.preferredWidth: Theme.popupCardIconSize
                Layout.preferredHeight: Theme.popupCardIconSize
                radius: Theme.radiusSm
                color: Theme.alpha(dragGhost.ghostColor, 0.15)
                border.color: Theme.alpha(dragGhost.ghostColor, 0.35)
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: dragGhost.info?.icon ?? Theme.iconGrid
                    font.family: Theme.fontIcon
                    font.variableAxes: Theme.iconAxes
                    font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeXs : Theme.fontSizeSm
                    color: dragGhost.ghostColor
                }
            }

            Text {
                text: dragGhost.info?.name ?? root.draggedModId
                font.family: Theme.fontFamily
                font.variableAxes: Theme.sansAxes
                font.pixelSize: Theme.fontSizeSm
                font.weight: Theme.fontWeightDemiBold
                color: Theme.on_surface
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }
    }
}
