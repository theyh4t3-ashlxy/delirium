// BarStudio.qml
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

    cardWidth: Math.min(1160, Math.max(780, (root.screen?.width ?? 1920) - 48))
    cardHeight: Math.min(680, Math.max(520, (root.screen?.height ?? 1080) - Theme.barHeight - 32))
    open: false

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
        "quickSettings":  { name: "quick settings",    icon: Theme.iconSettings,    desc: "system & appearance toggles" },
        "powerMenu":      { name: "power menu",        icon: Theme.iconPower,       desc: "lock, logout & power off" },
        "dynamicNotch":   { name: "dynamic notch",     icon: Theme.iconSparkles,    desc: "reactive island carousel (clock, calendar & timer)" },
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
            } else {
                root.open = false;
            }
        }
    }

    onOpenChanged: {
        if (!open) {
            if (isDragging) cancelDrag();
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

    function getModuleInfo(modId) {
        let b = (typeof PresetService !== "undefined" && PresetService?.getBlockInfo) ? PresetService.getBlockInfo(modId) : null;
        if (b) return b;
        if (modId === "layoutSwitcher") return root.moduleCatalog["layout"];
        if (modId === "notch") return root.moduleCatalog["dynamicNotch"];
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
            case "dynamicNotch": case "notch": return Settings.showDynamicNotch ?? true;
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
            case "dynamicNotch": case "notch": Settings.showDynamicNotch = visible; break;
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
            if (root.isDragging) {
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
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: Theme.radiusMd
                color: Theme.primary_overlay
                border.color: Theme.alpha(Theme.primary, 0.35)
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: Theme.iconSparkles
                    font.family: Theme.fontIcon
                    font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeSm : Theme.fontSizeLg
                    color: Theme.primary
                }
            }

            ColumnLayout {
                spacing: 1
                Text {
                    text: "bar layout studio"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMd
                    font.weight: Font.Bold
                    color: Theme.on_surface
                }
                Text {
                    text: Theme.getFlavor("system", "drag cards or click arrows to hot-reorder panels on your status bar")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeXs
                    color: Theme.on_surface_variant
                }
            }

            Row {
                spacing: 6
                Layout.alignment: Qt.AlignVCenter

                Text {
                    text: "preset:"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeXs
                    color: Theme.on_surface_variant
                    anchors.verticalCenter: parent.verticalCenter
                }

                Repeater {
                    model: (typeof PresetService !== "undefined" ? PresetService?.availablePresets : null) ?? []
                    delegate: Rectangle {
                        required property var modelData
                        height: 24
                        implicitWidth: pText.implicitWidth + 14
                        radius: Theme.radiusPill
                        readonly property bool isCurrent: PresetService?.activePresetName === modelData.id
                        color: isCurrent ? Theme.primary : (pMouse.containsMouse ? Theme.pillHover : Theme.pillBg)
                        border.color: isCurrent ? Theme.primary : Theme.pillBorder
                        border.width: (border.color === "transparent" || border.color.a === 0) ? 0 : 1

                        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                        Text {
                            id: pText
                            anchors.centerIn: parent
                            text: modelData.name
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: isCurrent ? Font.Bold : Font.Normal
                            color: isCurrent ? Theme.on_primary : Theme.on_surface
                        }

                        MouseArea {
                            id: pMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: PresetService?.applyPresetById(modelData.id)
                        }
                    }
                }

                Rectangle {
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
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "save preset"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: Font.DemiBold
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
                            let name = "custom_" + Math.floor(Date.now() / 1000);
                            PresetService?.exportCurrentAsPreset(name);
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                Layout.preferredHeight: 28
                Layout.preferredWidth: resetRow.implicitWidth + 18
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
                        font.pixelSize: Theme.fontSizeXs
                        color: Theme.on_surface
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "reset layout"
                        font.family: Theme.fontFamily
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
                        root.saveSettings();
                    }
                }
            }

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

        // live mini screen preview (now actually using ConcaveCorner instead of leaving the import hanging)
        Rectangle {
            id: barPreviewMock
            Layout.fillWidth: true
            Layout.preferredHeight: 88
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
            readonly property bool isFloating: (Settings?.barFloating ?? false) || Theme.isBento

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

                // miniature concave scoops on the bar edges when docked
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
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.on_surface_variant
                        }

                        Repeater {
                            model: [
                                { pos: "top", label: "top ↑" },
                                { pos: "bottom", label: "bottom ↓" },
                                { pos: "left", label: "left ←" },
                                { pos: "right", label: "right →" }
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
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: isCurrent ? Font.Bold : Font.Normal
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

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.popupSpacing

            ZoneColumn {
                id: leftColZone
                Layout.fillWidth: true
                Layout.fillHeight: true
                zoneId: "left"
                zoneTitle: root.barPreviewMock?.isVertical ? "top modules" : "left modules"
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
                zoneTitle: root.barPreviewMock?.isVertical ? "bottom modules" : "right modules"
                modulesList: Settings?.barModulesRight ?? []
            }
        }

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
                    font.pixelSize: Theme.fontSizeXs
                    font.weight: Font.DemiBold
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
                                        font.pixelSize: Theme.fontSizeXs
                                        color: Theme.primary
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: parent.parent.info.name
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeXs
                                        color: Theme.on_surface
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: "+left"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Font.Bold
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
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Font.Bold
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
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Font.Bold
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
                    font.pixelSize: Theme.fontSizeSm
                    font.weight: Font.Bold
                    color: zoneRoot.isOverThisZone ? Theme.primary : Theme.on_surface
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: zoneRoot.getActiveCount() + "/" + zoneRoot.modulesList.length + " active"
                    font.family: Theme.fontMono
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
                                font.pixelSize: Theme.fontSizeSm
                                font.weight: Font.Bold
                                color: zoneRoot.isOverThisZone ? Theme.primary : Theme.on_surface_variant
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "drag cards across or use unassigned tray"
                                font.family: Theme.fontFamily
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
                    font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeXs : Theme.fontSizeSm
                    color: dragGhost.ghostColor
                }
            }

            Text {
                text: dragGhost.info?.name ?? root.draggedModId
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSm
                font.weight: Font.DemiBold
                color: Theme.on_surface
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }
    }
}
