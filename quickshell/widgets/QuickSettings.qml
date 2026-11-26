// QuickSettings.qml — global appearance (popups, screen frame, typography), behavior, keybinds & system
import QtQuick
import QtQuick.Layouts
import ".."
import "../controls"
import "../theme/styleEngine.mjs" as StyleEngine
import "../theme/confFormat.mjs" as ConfFmt
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland

BarPill {
    id: root

    readonly property bool isFloatingBar: (Settings?.barFloating ?? false) || Theme.isIslands
    readonly property int effectiveBarMargin: isFloatingBar ? ((Settings?.barMargin > 0) ? Settings.barMargin : 8) : 0

    active: popup.open
    hovered: qsMouse.containsMouse
    pressed: qsMouse.pressed
    implicitWidth: {
        if (Theme.isVertical) return pillSize;
        return (qsMouse.containsMouse || popup.open) ? (qsRow.implicitWidth + 20) : pillSize;
    }
    clip: true

    Behavior on implicitWidth { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }

    property string activeTab: "style"
    property string fontTarget: "sans"
    property string fontSearchQuery: ""
    property bool variableFontsOnly: false
    property bool showResetConfirm: false
    property string activeShell: "quickshell"
    property bool fontsLoaded: false
    property var allFonts: []
    property var fontMetaMap: ({})

    readonly property var _mergedSansSpec: {
        let a = Theme.sansVarAxes || ({});
        let d = Theme.displayVarAxes || ({});
        return Object.assign({}, d, a);
    }
    readonly property bool hasWdthAxis: _mergedSansSpec.wdth !== undefined
    readonly property bool hasRondAxis: _mergedSansSpec.ROND !== undefined
    readonly property bool hasSlantAxis: _mergedSansSpec.slnt !== undefined
    readonly property bool hasOpszAxis: _mergedSansSpec.opsz !== undefined
    readonly property bool hasMonoWghtAxis: (Theme.monoVarAxes || ({})).wght !== undefined
    readonly property bool hasMonoWdthAxis: (Theme.monoVarAxes || ({})).wdth !== undefined

    function axisLabelSummary(spec) {
        if (!spec) return "static";
        let keys = Object.keys(spec);
        return keys.length > 0 ? keys.join(" · ") : "static";
    }

    readonly property string userHome: Quickshell.env("HOME") || ""
    readonly property string cacheDir: Quickshell.env("XDG_CACHE_HOME") || (userHome + "/.cache")
    readonly property string configDir: Quickshell.env("XDG_CONFIG_HOME") || (userHome + "/.config")

    function saveSettings() {
        if (Settings?.save) Settings.save();
    }

    function fmtIdleSecs(sec) {
        const s = Math.max(0, Math.round(sec));
        if (s < 60) return s + "s";
        const m = Math.floor(s / 60);
        const rem = s % 60;
        return rem === 0 ? (m + "m") : (m + "m " + rem + "s");
    }

    function ensureFontsLoaded() {
        if (root.fontsLoaded) return;
        root.fontsLoaded = true;
        try {
            const raw = Qt.fontFamilies();
            if (raw && raw.length > 0) {
                root.allFonts = Array.from(raw).sort((a, b) => a.localeCompare(b, undefined, { sensitivity: "base" }));
            }
        } catch (e) {
            root.allFonts = [];
        }
        if (fontMetaProc.running) fontMetaProc.running = false;
        fontMetaProc.running = true;
    }

    Process {
        id: fontMetaProc
        command: ["python3", Theme.fontsScriptPath, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const recs = ConfFmt.parseRecords(text || "", "font");
                if (!recs || recs.length === 0) return;
                let map = {};
                for (let i = 0; i < recs.length; i++) {
                    let r = recs[i];
                    if (!r || !r.family) continue;
                    let axesStr = r.axes || "";
                    let tags = [];
                    if (axesStr) {
                        let parts = axesStr.split(";");
                        for (let j = 0; j < parts.length; j++) {
                            let tag = parts[j].split(":")[0];
                            if (tag) tags.push(tag);
                        }
                    }
                    map[r.family.trim().toLowerCase()] = {
                        isVar: r.isVar === "true" && tags.length > 0,
                        tags: tags.join(" ")
                    };
                }
                root.fontMetaMap = map;
            }
        }
    }

    readonly property bool usingMaterialIcons: Settings.iconSet === "material"
        || Settings.iconSet === "material-rounded"
        || Settings.iconSet === "rounded"
        || Settings.iconSet === "material-outlined"
        || Settings.iconSet === "outlined"
        || Settings.iconSet === "material-sharp"
        || Settings.iconSet === "sharp"

    readonly property string activeTabTitle: ({
        style: "appearance",
        behavior: "behavior",
        keybinds: "keybinds",
        advanced: "system"
    })[root.activeTab] || "settings"

    readonly property string activeTabSubtitle: ({
        style: "popups, screen frame, typography, and icons",
        behavior: "flyouts, audio & alerts, idle timers, and flavor",
        keybinds: "view and manage your shell shortcuts",
        advanced: "shell profiles, network aliases, and recovery"
    })[root.activeTab] || ""

    onActiveTabChanged: {
        if (root.activeTab === "style") root.ensureFontsLoaded();
        if (root.activeTab === "style" && flickStyle) flickStyle.contentY = 0;
        else if (root.activeTab === "behavior" && flickBehavior) flickBehavior.contentY = 0;
        else if (root.activeTab === "advanced" && flickAdvanced) flickAdvanced.contentY = 0;
    }

    FileView {
        id: shellWatcher
        printErrors: false
        path: root.cacheDir + "/current_shell"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const s = text().trim();
            if (s === "brain_shell" || s === "quickshell") {
                root.activeShell = s;
            } else if (s === "oxytocin") {
                root.activeShell = "brain_shell";
                switchProc.switchShell("brain_shell");
            }
        }
    }

    Process {
        id: switchProc
        function switchShell(target) {
            if (!target) return;
            if (running) running = false;
            command = [root.userHome + "/.local/bin/cli", "shell", target];
            running = true;
        }
        function restartCurrent() {
            Quickshell.execDetached([root.userHome + "/.local/bin/cli", "shell", "restart"]);
        }
        onExited: shellWatcher.reload()
    }

    readonly property var filteredFonts: {
        const q = (fontSearchQuery || "").trim().toLowerCase();
        const varOnly = root.variableFontsOnly;
        const meta = root.fontMetaMap;
        return allFonts.filter(f => {
            if (!f) return false;
            if (q && !f.toLowerCase().includes(q)) return false;
            if (varOnly) {
                const m = meta[f.toLowerCase()];
                if (!m || !m.isVar) return false;
            }
            return true;
        });
    }

    function isTargetMonitorActive() {
        return !root.barScreen
            || Quickshell.screens.length <= 1
            || (root.barMonitor && Hyprland.focusedMonitor && root.barMonitor.id === Hyprland.focusedMonitor.id);
    }

    function updatePopupPos() {
        const p = root.mapToItem(null, 0, 0);
        if (p && root.visible) {
            if (Theme.isVertical) {
                popup.targetRelativeX = 0;
                popup.targetRelativeY = p.y + (root.implicitHeight / 2) + root.effectiveBarMargin;
            } else {
                popup.targetRelativeX = p.x + (root.implicitWidth / 2) + root.effectiveBarMargin;
                popup.targetRelativeY = 0;
            }
        } else {
            popup.targetRelativeX = 0;
            popup.targetRelativeY = 0;
        }
    }

    // bar pill content
    Row {
        id: qsRow
        anchors.centerIn: parent
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Theme.iconSettings
            font.family: Theme.fontIcon
            font.variableAxes: Theme.iconAxes
            font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeXs : Theme.fontSizeSm
            color: popup.open || qsMouse.containsMouse ? Theme.primary : Theme.textPrimary

            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: !Theme.isVertical && (qsMouse.containsMouse || popup.open)
            text: "settings"
            font.family: Theme.fontFamily
            font.variableAxes: Theme.sansAxes
            font.pixelSize: Theme.fontSizeSm
            font.weight: Theme.fontWeightMedium
            color: Theme.textPrimary
        }
    }

    HoverFlyoutHandler {
        popup: popup
        mouseArea: qsMouse
        updatePos: () => root.updatePopupPos()
    }

    // left click opens settings, right click opens Bar Layout Studio, middle click reloads shell
    MouseArea {
        id: qsMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            if (mouse.button === Qt.MiddleButton) {
                popup.open = false;
                switchProc.restartCurrent();
                return;
            }
            if (mouse.button === Qt.RightButton) {
                popup.open = false;
                if (Settings) Settings.showBarStudio = !Settings.showBarStudio;
                return;
            }
            root.updatePopupPos();
            if (!popup.open) {
                popup.pinned = true;
                popup.open = true;
            } else if (!popup.pinned) {
                popup.pinned = true;
            } else {
                popup.pinned = false;
                popup.open = false;
            }
        }
    }

    Connections {
        target: Settings
        function onRequestQuickSettingsToggle() {
            if (root.isTargetMonitorActive()) {
                root.updatePopupPos();
                popup.open = !popup.open;
            }
        }
        function onRequestQuickSettingsOpen() {
            if (root.isTargetMonitorActive()) {
                root.updatePopupPos();
                popup.open = true;
            }
        }
        function onRequestQuickSettingsClose() {
            popup.open = false;
        }
        function onRequestKeybindsToggle() {
            if (root.isTargetMonitorActive()) {
                root.updatePopupPos();
                if (!popup.open) {
                    root.activeTab = "keybinds";
                    popup.open = true;
                } else if (root.activeTab === "keybinds") {
                    popup.open = false;
                } else {
                    root.activeTab = "keybinds";
                }
            }
        }
        function onRequestKeybindsOpen() {
            if (root.isTargetMonitorActive()) {
                root.updatePopupPos();
                root.activeTab = "keybinds";
                popup.open = true;
            }
        }
        function onRequestKeybindsClose() {
            if (root.activeTab === "keybinds") {
                popup.open = false;
            }
        }
    }

    PopupPanel {
        id: popup
        screen: root.barScreen
        wantsFocus: true
        keyboardFocusMode: WlrKeyboardFocus.OnDemand
        cardWidth: Theme.popupWidth
        cardHeight: Theme.popupHeight
        onOpenChanged: {
            if (open && root.activeTab === "style") {
                root.ensureFontsLoaded();
            }
        }

        content: ColumnLayout {
            anchors.fill: parent
            spacing: Theme.popupSpacing

            // top header
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    width: 36
                    height: 36
                    radius: Theme.radiusMd
                    color: Theme.primary_overlay
                    border.color: Theme.alpha(Theme.primary, 0.35)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: Theme.iconSettings
                        font.family: Theme.fontIcon
                        font.variableAxes: Theme.iconAxes
                        font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeSm : Theme.fontSizeLg
                        color: Theme.primary
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: "settings"
                        font.family: Theme.fontDisplay
                        font.variableAxes: Theme.displayAxes
                        font.pixelSize: Theme.fontSizeMd
                        font.weight: Theme.fontWeightBold
                        color: Theme.textPrimary
                    }

                    Text {
                        text: root.activeTabTitle + "  •  " + root.activeTabSubtitle
                        font.family: Theme.fontFamily
                        font.variableAxes: Theme.sansAxes
                        font.weight: Theme.fontWeightRegular
                        font.pixelSize: Theme.fontSizeXs
                        color: Theme.textSecondary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                // jump straight to Bar Layout Studio
                Rectangle {
                    height: 26
                    implicitWidth: studioLinkRow.implicitWidth + 14
                    radius: Theme.radiusPill
                    color: studioLinkMouse.containsMouse ? Theme.primary : Theme.primary_overlay
                    border.color: Theme.primary
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                    Row {
                        id: studioLinkRow
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            visible: !Theme.isTextIconSet
                            text: Theme.iconGrid
                            font.family: Theme.fontIcon
                            font.variableAxes: Theme.iconAxes
                            font.pixelSize: Theme.fontSizeXs
                            color: studioLinkMouse.containsMouse ? Theme.on_primary : Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "bar studio"
                            font.family: Theme.fontFamily
                            font.variableAxes: Theme.sansAxes
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: Theme.fontWeightBold
                            color: studioLinkMouse.containsMouse ? Theme.on_primary : Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: studioLinkMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            popup.open = false;
                            if (Settings) Settings.showBarStudio = true;
                        }
                    }
                }

                IconButton {
                    icon: Theme.iconRefresh
                    iconSize: Theme.fontSizeSm
                    tooltip: "reload shell"
                    onClicked: {
                        popup.open = false;
                        switchProc.restartCurrent();
                    }
                }

                IconButton {
                    icon: Theme.iconClose
                    iconSize: Theme.fontSizeSm
                    tooltip: "close"
                    onClicked: popup.open = false
                }
            }

            // horizontal tab bar (bar tab removed; bar settings now live in Bar Layout Studio)
            Flickable {
                id: tabFlick
                Layout.fillWidth: true
                height: 34
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
                            { id: "style",    label: "appearance", icon: Theme.iconSparkles },
                            { id: "behavior", label: "behavior",   icon: Theme.iconFlame },
                            { id: "keybinds", label: "keybinds",   icon: Theme.iconKeyboard },
                            { id: "advanced", label: "system",     icon: Theme.iconSliders }
                        ]

                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool isSelected: root.activeTab === modelData.id
                            height: 30
                            width: tabItemRow.implicitWidth + 20
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

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // 1. appearance tab (popups, screen frame, typography, font browser)
                Flickable {
                    id: flickStyle
                    anchors.fill: parent
                    visible: root.activeTab === "style"
                    clip: true
                    contentWidth: width
                    contentHeight: styleCol.implicitHeight + 28
                    boundsBehavior: Flickable.StopAtBounds

                    WheelHandler {
                        orientation: Qt.Vertical
                        target: parent
                    }

                    ColumnLayout {
                        id: styleCol
                        width: parent.width
                        spacing: Theme.popupSpacing

                        CategoryHeader {
                            title: "popups & surfaces"
                            subtitle: "global popup geometry, opacity, borders, and adaptive alpha"
                            icon: Theme.iconSparkles
                        }

                        SettingCard {
                            SliderRow {
                                title: "popup corner radius"
                                from: 0
                                to: 28
                                stepSize: 2
                                suffix: "px"
                                value: Settings.popupRadius
                                onMoved: (val) => Settings.popupRadius = val
                            }

                            SliderRow {
                                title: "popup background opacity"
                                from: 0.5
                                to: 1.0
                                stepSize: 0.05
                                value: Settings.popupOpacity
                                formatter: (v) => Math.round(v * 100) + "%"
                                onMoved: (val) => Settings.popupOpacity = val
                            }

                            ChoiceRow {
                                title: "popup border width"
                                model: [
                                    { label: "none", value: 0 },
                                    { label: "1px", value: 1 },
                                    { label: "2px", value: 2 },
                                    { label: "3px", value: 3 }
                                ]
                                currentValue: Settings.popupBorderWidth
                                onSelected: (val) => Settings.popupBorderWidth = val
                            }

                            RowDivider {}

                            ToggleRow {
                                icon: Theme.iconWallpaper
                                title: "adaptive wallpaper transparency"
                                subtitle: "boost surface alpha automatically when wallpaper vibrancy is high"
                                checked: Settings.adaptiveTransparency ?? true
                                onToggled: {
                                    Settings.adaptiveTransparency = !(Settings.adaptiveTransparency ?? true);
                                    root.saveSettings();
                                }
                            }
                        }

                        CollapsibleSection {
                            Layout.fillWidth: true
                            title: "screen frame & corners"
                            subtitle: "screen-edge concave fillets, curvature math & border frame"
                            icon: Theme.iconGrid
                            badge: Settings.screenCornerRadius + "px"

                            Dropdown {
                                width: parent.width
                                label: "screen corner fillets"
                                icon: Theme.iconSparkles
                                model: [
                                    { label: "all (workspace)", value: "all" },
                                    { label: "monitor edges", value: "monitor" },
                                    { label: "bar opposite", value: "opposite" },
                                    { label: "disabled", value: "none" },
                                    { label: "top only", value: "top" },
                                    { label: "bottom only", value: "bottom" },
                                    { label: "left only", value: "left" },
                                    { label: "right only", value: "right" }
                                ]
                                currentValue: Settings.screenCornerMode
                                onSelected: (val) => {
                                    Settings.screenCornerMode = val;
                                    root.saveSettings();
                                }
                            }

                            Dropdown {
                                width: parent.width
                                label: "corner curvature style"
                                icon: Theme.iconSparkles
                                model: [
                                    { label: "g2 continuous", value: "continuous-bezier" },
                                    { label: "cubic circle", value: "cubic" },
                                    { label: "squircle", value: "squircle" },
                                    { label: "hyperbolic", value: "hyperbolic" },
                                    { label: "stepped pixel", value: "stepped" },
                                    { label: "chamfer 45°", value: "chamfer" },
                                    { label: "flared", value: "flared" }
                                ]
                                currentValue: Settings.cornerStyle
                                onSelected: (val) => {
                                    Settings.cornerStyle = val;
                                    root.saveSettings();
                                }
                            }

                            ChoiceRow {
                                title: "corner color mode"
                                model: [
                                    { label: "bar match", value: "bar" },
                                    { label: "matugen", value: "theme" },
                                    { label: "accent", value: "accent" },
                                    { label: "oled", value: "oled" }
                                ]
                                currentValue: StyleEngine.normalizeCornerColorMode(Settings.cornerColorMode)
                                onSelected: (val) => Settings.cornerColorMode = val
                            }

                            SliderRow {
                                title: "screen corner radius"
                                from: 0
                                to: 40
                                stepSize: 2
                                suffix: "px"
                                value: Settings.screenCornerRadius
                                onMoved: (val) => Settings.screenCornerRadius = val
                            }

                            SliderRow {
                                title: "frame border width"
                                from: 0
                                to: 16
                                stepSize: 2
                                value: Settings.screenBorderWidth
                                formatter: (v) => v === 0 ? "none (corners only)" : (Math.round(v) + "px (full frame)")
                                onMoved: (val) => Settings.screenBorderWidth = val
                            }

                            SettingCard {
                                width: parent.width
                                ToggleRow {
                                    icon: Theme.iconGrid
                                    title: "docked screen frame"
                                    subtitle: "anchor perimeter border and screen corners to monitor bounds"
                                    checked: Settings.screenFrameDocked
                                    onToggled: {
                                        Settings.screenFrameDocked = !Settings.screenFrameDocked;
                                        root.saveSettings();
                                    }
                                }
                            }
                        }

                        CategoryHeader {
                            title: "typography & icon system"
                            subtitle: "font families, scale, weight, and icon pack"
                            icon: Theme.iconNote
                        }

                        SettingCard {
                            ChoiceGrid {
                                columns: 2
                                buttonHeight: 32
                                title: "icon pack"
                                model: [
                                    { label: "material", value: "material" },
                                    { label: "windows segoe", value: "windows" },
                                    { label: "(ﾉ◕ヮ◕)ﾉ kaomoji", value: "kaomoji" },
                                    { label: "plain text", value: "text" }
                                ]
                                currentValue: root.usingMaterialIcons ? "material" : Settings.iconSet
                                onSelected: (value) => {
                                    Settings.iconSet = value;
                                    if (value === "material" &&
                                        Settings.fontMaterial !== "Material Symbols Rounded" &&
                                        Settings.fontMaterial !== "Material Symbols Outlined" &&
                                        Settings.fontMaterial !== "Material Symbols Sharp") {
                                        Settings.fontMaterial = "Material Symbols Rounded";
                                    }
                                    Settings.vibeStyle = (value === "kaomoji" || value === "text") ? value : "icon";
                                }
                            }

                            RowDivider { visible: root.usingMaterialIcons }

                            ChoiceRow {
                                visible: root.usingMaterialIcons
                                title: "material variant"
                                model: [
                                    { label: "rounded", value: "Material Symbols Rounded" },
                                    { label: "outlined", value: "Material Symbols Outlined" },
                                    { label: "sharp", value: "Material Symbols Sharp" }
                                ]
                                currentValue: Settings.fontMaterial || "Material Symbols Rounded"
                                onSelected: (value) => {
                                    Settings.iconSet = "material";
                                    Settings.fontMaterial = value;
                                }
                            }

                            ToggleRow {
                                visible: root.usingMaterialIcons
                                icon: Theme.iconPalette
                                title: "solid material fill"
                                subtitle: "fill material symbols solid so sharp and rounded shapes pop"
                                checked: Settings.materialFilled
                                onToggled: {
                                    Settings.materialFilled = !Settings.materialFilled;
                                    root.saveSettings();
                                }
                            }

                            RowDivider {}

                            SliderRow {
                                title: "interface font scaling"
                                from: 0.8
                                to: 1.4
                                stepSize: 0.05
                                value: Settings.fontScale
                                formatter: (v) => Math.round(v * 100) + "%"
                                onMoved: (val) => Settings.fontScale = val
                            }

                            RowDivider {}

                            RowLayout {
                                width: parent.width
                                spacing: 6

                                Text {
                                    text: "variable font axes"
                                    font.family: Theme.fontFamily
                                    font.variableAxes: Theme.sansAxes
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: Theme.fontWeightDemiBold
                                    color: Theme.textSecondary
                                    Layout.fillWidth: true
                                }

                                Rectangle {
                                    height: 20
                                    implicitWidth: resetAxesTxt.implicitWidth + 12
                                    radius: Theme.radiusPill
                                    color: resetAxesMouse.containsMouse ? Theme.primary_overlay : Theme.widgetBg
                                    border.color: resetAxesMouse.containsMouse ? Theme.primary : Theme.widgetBorder
                                    border.width: 1

                                    Text {
                                        id: resetAxesTxt
                                        anchors.centerIn: parent
                                        text: "reset axes"
                                        font.family: Theme.fontFamily
                                        font.variableAxes: Theme.sansAxes
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightMedium
                                        color: resetAxesMouse.containsMouse ? Theme.primary : Theme.textSecondary
                                    }

                                    MouseArea {
                                        id: resetAxesMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Settings.resetFontAxes()
                                    }
                                }
                            }

                            // live specimen card showing sans, display, and mono variable rendering
                            Rectangle {
                                width: parent.width
                                implicitHeight: specimenCol.implicitHeight + 14
                                radius: Theme.radiusSm
                                color: Theme.widgetBg
                                border.color: Theme.widgetBorder
                                border.width: 1

                                ColumnLayout {
                                    id: specimenCol
                                    anchors.fill: parent
                                    anchors.margins: 7
                                    spacing: 3

                                    Text {
                                        Layout.fillWidth: true
                                        text: Settings.fontFamily + (Settings.fontDisplay !== "" ? (" + " + Settings.fontDisplay) : "") + "  [" + root.axisLabelSummary(root._mergedSansSpec) + "]"
                                        font.family: Theme.fontMono
                                        font.variableAxes: Theme.monoAxes
                                        font.weight: Theme.monoWeightRegular
                                        font.pixelSize: Theme.fontSizeXs
                                        color: Theme.primary
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: "display heading · " + Theme.fontDisplay.toLowerCase()
                                        font.family: Theme.fontDisplay
                                        font.variableAxes: Theme.displayAxes
                                        font.pixelSize: Theme.fontSizeLg
                                        font.weight: Theme.fontWeightBold
                                        color: Theme.textPrimary
                                        elide: Text.ElideRight
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Text {
                                            Layout.fillWidth: true
                                            text: "body text · wght " + Settings.fontWeightValue
                                            font.family: Theme.fontFamily
                                            font.variableAxes: Theme.sansAxes
                                            font.pixelSize: Theme.fontSizeSm
                                            font.weight: Theme.fontWeightRegular
                                            color: Theme.textSecondary
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            text: "01:23 mono " + Settings.fontMonoWeight
                                            font.family: Theme.fontMono
                                            font.variableAxes: Theme.monoAxes
                                            font.pixelSize: Theme.fontSizeXs
                                            font.weight: Theme.monoWeightMedium
                                            color: Theme.textSecondary
                                        }
                                    }
                                }
                            }

                            ChoiceRow {
                                title: "weight preset"
                                model: [
                                    { label: "light", value: "light" },
                                    { label: "regular", value: "regular" },
                                    { label: "medium", value: "medium" },
                                    { label: "demibold", value: "demibold" },
                                    { label: "bold", value: "bold" }
                                ]
                                currentValue: Settings.fontWeight
                                onSelected: (val) => Settings.fontWeight = val
                            }

                            SliderRow {
                                title: "base weight (wght)"
                                from: Theme._sansWghtMin
                                to: Theme._sansWghtMax
                                stepSize: 10
                                value: Settings.fontWeightValue
                                formatter: (v) => Math.round(v) + ""
                                onMoved: (val) => Settings.fontWeightValue = Math.round(val)
                            }

                            SliderRow {
                                visible: root.hasWdthAxis
                                title: "width stretch (wdth)"
                                from: root._mergedSansSpec.wdth ? root._mergedSansSpec.wdth.min : 75
                                to: root._mergedSansSpec.wdth ? root._mergedSansSpec.wdth.max : 150
                                stepSize: 2.5
                                value: Settings.fontWidth
                                formatter: (v) => Math.round(v) + "%"
                                onMoved: (val) => Settings.fontWidth = val
                            }

                            SliderRow {
                                visible: root.hasRondAxis
                                title: "corner roundness (ROND)"
                                from: root._mergedSansSpec.ROND ? root._mergedSansSpec.ROND.min : 0
                                to: root._mergedSansSpec.ROND ? root._mergedSansSpec.ROND.max : 100
                                stepSize: 5
                                value: Settings.fontRoundness
                                formatter: (v) => Math.round(v) + "%"
                                onMoved: (val) => Settings.fontRoundness = val
                            }

                            SliderRow {
                                visible: root.hasSlantAxis
                                title: "slant angle (slnt)"
                                from: root._mergedSansSpec.slnt ? root._mergedSansSpec.slnt.min : -10
                                to: root._mergedSansSpec.slnt ? root._mergedSansSpec.slnt.max : 0
                                stepSize: 0.5
                                value: Settings.fontSlant
                                formatter: (v) => (Math.round(v * 10) / 10) + "°"
                                onMoved: (val) => Settings.fontSlant = val
                            }

                            ToggleRow {
                                visible: root.hasOpszAxis
                                icon: Theme.iconEye
                                title: "auto optical size (opsz)"
                                subtitle: "adjust optical contrast automatically for small ui vs headings"
                                checked: Settings.fontOpticalAuto
                                onToggled: {
                                    Settings.fontOpticalAuto = !Settings.fontOpticalAuto;
                                    root.saveSettings();
                                }
                            }

                            SliderRow {
                                visible: root.hasOpszAxis && !Settings.fontOpticalAuto
                                title: "manual optical size (opsz)"
                                from: root._mergedSansSpec.opsz ? root._mergedSansSpec.opsz.min : 5
                                to: root._mergedSansSpec.opsz ? Math.min(72, root._mergedSansSpec.opsz.max) : 36
                                stepSize: 0.5
                                value: Settings.fontOpticalSize
                                formatter: (v) => (Math.round(v * 10) / 10) + "pt"
                                onMoved: (val) => Settings.fontOpticalSize = val
                            }

                            RowDivider { visible: root.hasMonoWghtAxis || root.hasMonoWdthAxis }

                            SliderRow {
                                visible: root.hasMonoWghtAxis
                                title: "mono weight (wght)"
                                from: Theme._monoWghtMin
                                to: Theme._monoWghtMax
                                stepSize: 25
                                value: Settings.fontMonoWeight
                                formatter: (v) => Math.round(v) + ""
                                onMoved: (val) => Settings.fontMonoWeight = Math.round(val)
                            }

                            SliderRow {
                                visible: root.hasMonoWdthAxis
                                title: "mono width (wdth)"
                                from: (Theme.monoVarAxes && Theme.monoVarAxes.wdth) ? Theme.monoVarAxes.wdth.min : 62.5
                                to: (Theme.monoVarAxes && Theme.monoVarAxes.wdth) ? Theme.monoVarAxes.wdth.max : 100
                                stepSize: 2.5
                                value: Settings.fontMonoWidth
                                formatter: (v) => Math.round(v) + "%"
                                onMoved: (val) => Settings.fontMonoWidth = val
                            }
                        }

                        CollapsibleSection {
                            Layout.fillWidth: true
                            title: "system font browser"
                            subtitle: "swap interface, display, or monospace families"
                            icon: Theme.iconSearch
                            badge: root.fontTarget === "sans" ? Settings.fontFamily : (root.fontTarget === "display" ? (Settings.fontDisplay || "same as sans") : Settings.fontMono)

                            RowLayout {
                                width: parent.width
                                spacing: 5

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 30
                                    radius: root.fontTarget === "sans" ? Theme.radiusMd : Theme.radiusPill
                                    color: root.fontTarget === "sans" ? Theme.primary_overlay : Theme.widgetBg
                                    border.color: root.fontTarget === "sans" ? Theme.primary : Theme.widgetBorder
                                    border.width: 1

                                    Text {
                                        width: parent.width - 10
                                        text: "sans: " + Settings.fontFamily
                                        font.family: Settings.fontFamily
                                        font.variableAxes: Theme.sansAxes
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightBold
                                        color: root.fontTarget === "sans" ? Theme.primary : Theme.textSecondary
                                        anchors.centerIn: parent
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.fontTarget = "sans"
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 30
                                    radius: root.fontTarget === "display" ? Theme.radiusMd : Theme.radiusPill
                                    color: root.fontTarget === "display" ? Theme.primary_overlay : Theme.widgetBg
                                    border.color: root.fontTarget === "display" ? Theme.primary : Theme.widgetBorder
                                    border.width: 1

                                    Text {
                                        width: parent.width - 10
                                        text: "display: " + (Settings.fontDisplay || "auto")
                                        font.family: Theme.fontDisplay
                                        font.variableAxes: Theme.displayAxes
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightBold
                                        color: root.fontTarget === "display" ? Theme.primary : Theme.textSecondary
                                        anchors.centerIn: parent
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.fontTarget = "display"
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 30
                                    radius: root.fontTarget === "mono" ? Theme.radiusMd : Theme.radiusPill
                                    color: root.fontTarget === "mono" ? Theme.primary_overlay : Theme.widgetBg
                                    border.color: root.fontTarget === "mono" ? Theme.primary : Theme.widgetBorder
                                    border.width: 1

                                    Text {
                                        width: parent.width - 10
                                        text: "mono: " + Settings.fontMono
                                        font.family: Settings.fontMono
                                        font.variableAxes: Theme.monoAxes
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.monoWeightBold
                                        color: root.fontTarget === "mono" ? Theme.primary : Theme.textSecondary
                                        anchors.centerIn: parent
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.fontTarget = "mono"
                                    }
                                }
                            }

                            RowLayout {
                                width: parent.width
                                spacing: 6

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 34
                                    color: Theme.widgetBg
                                    radius: Theme.radiusMd
                                    border.color: fontSearchInput.activeFocus ? Theme.primary : Theme.widgetBorder
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 8

                                        Text {
                                            text: Theme.iconSearch
                                            font.family: Theme.fontIcon
                                            font.variableAxes: Theme.iconAxes
                                            font.pixelSize: Theme.fontSizeSm
                                            color: fontSearchInput.activeFocus ? Theme.primary : Theme.textSecondary
                                        }

                                        Item {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true

                                            Text {
                                                anchors.fill: parent
                                                verticalAlignment: Text.AlignVCenter
                                                visible: fontSearchInput.text === "" && !fontSearchInput.activeFocus
                                                text: "filter " + root.allFonts.length + " installed fonts..."
                                                font.family: Theme.fontFamily
                                                font.variableAxes: Theme.sansAxes
                                                font.weight: Theme.fontWeightRegular
                                                font.pixelSize: Theme.fontSizeXs
                                                color: Theme.textSecondary
                                            }

                                            TextInput {
                                                id: fontSearchInput
                                                anchors.fill: parent
                                                verticalAlignment: TextInput.AlignVCenter
                                                font.family: Theme.fontFamily
                                                font.variableAxes: Theme.sansAxes
                                                font.weight: Theme.fontWeightRegular
                                                font.pixelSize: Theme.fontSizeXs
                                                color: Theme.textPrimary
                                                onTextChanged: root.fontSearchQuery = text
                                            }
                                        }

                                        IconButton {
                                            visible: fontSearchInput.text !== ""
                                            icon: Theme.iconClose
                                            iconSize: Theme.fontSizeXs
                                            tooltip: "clear search"
                                            onClicked: {
                                                fontSearchInput.text = "";
                                                root.fontSearchQuery = "";
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    height: 34
                                    implicitWidth: vfFilterTxt.implicitWidth + 16
                                    radius: Theme.radiusMd
                                    color: root.variableFontsOnly ? Theme.primary_overlay : Theme.widgetBg
                                    border.color: root.variableFontsOnly ? Theme.primary : Theme.widgetBorder
                                    border.width: 1

                                    Text {
                                        id: vfFilterTxt
                                        anchors.centerIn: parent
                                        text: "variable only"
                                        font.family: Theme.fontFamily
                                        font.variableAxes: Theme.sansAxes
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: root.variableFontsOnly ? Theme.fontWeightBold : Theme.fontWeightMedium
                                        color: root.variableFontsOnly ? Theme.primary : Theme.textSecondary
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.variableFontsOnly = !root.variableFontsOnly
                                    }
                                }

                                Rectangle {
                                    visible: root.fontTarget === "display" && Settings.fontDisplay !== ""
                                    height: 34
                                    implicitWidth: clrDispTxt.implicitWidth + 14
                                    radius: Theme.radiusMd
                                    color: clrDispMouse.containsMouse ? Theme.error_overlay : Theme.widgetBg
                                    border.color: clrDispMouse.containsMouse ? Theme.error : Theme.widgetBorder
                                    border.width: 1

                                    Text {
                                        id: clrDispTxt
                                        anchors.centerIn: parent
                                        text: "auto"
                                        font.family: Theme.fontFamily
                                        font.variableAxes: Theme.sansAxes
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightBold
                                        color: clrDispMouse.containsMouse ? Theme.error : Theme.textSecondary
                                    }

                                    MouseArea {
                                        id: clrDispMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            Settings.fontDisplay = "";
                                            root.saveSettings();
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 180
                                color: Theme.widgetBg
                                radius: Theme.radiusMd
                                border.color: Theme.widgetBorder
                                border.width: 1
                                clip: true

                                WheelHandler {
                                    target: fontListView
                                    onWheel: (event) => {
                                        fontListView.flick(0, event.angleDelta.y * 6);
                                        event.accepted = true;
                                    }
                                }

                                ListView {
                                    id: fontListView
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    model: root.filteredFonts
                                    boundsBehavior: Flickable.StopAtBounds

                                    delegate: Rectangle {
                                        required property string modelData
                                        width: fontListView.width
                                        height: 32
                                        radius: Theme.radiusSm
                                        readonly property var fMeta: root.fontMetaMap[modelData.toLowerCase()] ?? null
                                        readonly property bool isVarFont: Boolean(fMeta && fMeta.isVar)
                                        readonly property bool isCurrent: (root.fontTarget === "sans" && Settings.fontFamily === modelData)
                                            || (root.fontTarget === "display" && Settings.fontDisplay === modelData)
                                            || (root.fontTarget === "mono" && Settings.fontMono === modelData)
                                        color: isCurrent ? Theme.primary_overlay : (fItemMouse.containsMouse ? Theme.widgetHover : "transparent")

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 6

                                            Text {
                                                text: modelData.toLowerCase()
                                                font.family: modelData
                                                font.pixelSize: Theme.fontSizeSm
                                                font.weight: isCurrent ? Theme.fontWeightBold : Theme.fontWeightRegular
                                                color: isCurrent ? Theme.primary : Theme.textPrimary
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }

                                            Rectangle {
                                                visible: isVarFont
                                                height: 16
                                                implicitWidth: vfBadgeTxt.implicitWidth + 8
                                                radius: Theme.radiusPill
                                                color: Theme.alpha(Theme.primary, 0.14)
                                                border.color: Theme.alpha(Theme.primary, 0.35)
                                                border.width: 1

                                                Text {
                                                    id: vfBadgeTxt
                                                    anchors.centerIn: parent
                                                    text: "vf · " + (fMeta?.tags ?? "")
                                                    font.family: Theme.fontMono
                                                    font.pixelSize: 8
                                                    font.weight: Theme.monoWeightBold
                                                    color: Theme.primary
                                                }
                                            }

                                            Text {
                                                visible: isCurrent && !Theme.isTextIconSet
                                                text: Theme.iconCheck
                                                font.family: Theme.fontIcon
                                                font.variableAxes: Theme.iconAxes
                                                font.pixelSize: Theme.fontSizeXs
                                                color: Theme.primary
                                            }

                                            Text {
                                                text: isCurrent ? "active" : "123"
                                                font.family: modelData
                                                font.pixelSize: Theme.fontSizeXs
                                                color: isCurrent ? Theme.primary : Theme.textSecondary
                                            }
                                        }

                                        MouseArea {
                                            id: fItemMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (root.fontTarget === "sans") Settings.fontFamily = modelData;
                                                else if (root.fontTarget === "display") Settings.fontDisplay = modelData;
                                                else Settings.fontMono = modelData;
                                                root.saveSettings();
                                            }
                                        }
                                    }
                                }

                                TabScrollTrack { target: fontListView }
                            }
                        }
                    }
                }
                TabScrollTrack { target: flickStyle }

                // 2. behavior tab (hover flyouts, launcher features, audio & alerts, idle timers, flavor)
                Flickable {
                    id: flickBehavior
                    anchors.fill: parent
                    visible: root.activeTab === "behavior"
                    clip: true
                    contentWidth: width
                    contentHeight: behaviorCol.implicitHeight + 28
                    boundsBehavior: Flickable.StopAtBounds

                    WheelHandler {
                        orientation: Qt.Vertical
                        target: parent
                    }

                    ColumnLayout {
                        id: behaviorCol
                        width: parent.width
                        spacing: Theme.popupSpacing

                        CategoryHeader {
                            title: "flyout hover & launcher"
                            subtitle: "hover behavior for bar popups and app launcher utilities"
                            icon: Theme.iconEye
                        }

                        SettingCard {
                            ToggleRow {
                                icon: Theme.iconEye
                                title: "hover to open flyouts"
                                subtitle: "hover over bar pills to preview popups automatically"
                                checked: Settings.hoverToOpen
                                onToggled: {
                                    Settings.hoverToOpen = !Settings.hoverToOpen;
                                    root.saveSettings();
                                }
                            }

                            ToggleRow {
                                icon: Theme.iconEyeOff
                                title: "hover auto-close"
                                subtitle: "dismiss unpinned flyouts when cursor leaves"
                                checked: Settings.hoverAutoClose
                                onToggled: {
                                    Settings.hoverAutoClose = !Settings.hoverAutoClose;
                                    root.saveSettings();
                                }
                            }

                            SliderRow {
                                visible: Settings.hoverToOpen
                                title: "hover activation delay"
                                from: 80
                                to: 600
                                stepSize: 10
                                suffix: "ms"
                                value: Settings.hoverDelay
                                onMoved: (val) => Settings.hoverDelay = val
                            }

                            RowDivider {}

                            ToggleRow {
                                icon: Theme.iconSearch
                                title: "launcher inline calculator"
                                subtitle: "evaluate math expressions directly inside app search"
                                checked: Settings.launcherCalcEnabled
                                onToggled: {
                                    Settings.launcherCalcEnabled = !Settings.launcherCalcEnabled;
                                    root.saveSettings();
                                }
                            }

                            ToggleRow {
                                icon: Theme.iconTerminal
                                title: "launcher shell commands"
                                subtitle: "allow prefixing queries with > to run quick commands"
                                checked: Settings.launcherCommandEnabled
                                onToggled: {
                                    Settings.launcherCommandEnabled = !Settings.launcherCommandEnabled;
                                    root.saveSettings();
                                }
                            }
                        }

                        CategoryHeader {
                            title: "audio & notifications"
                            subtitle: "volume limits and toast popup layout"
                            icon: Theme.iconBell
                        }

                        SettingCard {
                            SliderRow {
                                title: "volume scroll step"
                                from: 1
                                to: 15
                                stepSize: 1
                                value: Settings.volumeStep
                                formatter: (v) => Math.round(v) + "%"
                                onMoved: (val) => Settings.volumeStep = val
                            }

                            SliderRow {
                                title: "max volume ceiling"
                                from: 100
                                to: 200
                                stepSize: 5
                                value: Settings.volumeMax
                                formatter: (v) => Math.round(v) + "%"
                                onMoved: (val) => Settings.volumeMax = val
                            }

                            RowDivider {}

                            ChoiceRow {
                                title: "toast auto-dismiss timeout"
                                model: [
                                    { label: "3s", value: 3000 },
                                    { label: "5s", value: 5000 },
                                    { label: "8s", value: 8000 },
                                    { label: "12s", value: 12000 },
                                    { label: "sticky", value: 0 }
                                ]
                                currentValue: Settings.notificationTimeout
                                onSelected: (value) => Settings.notificationTimeout = value
                            }

                            ChoiceRow {
                                title: "notification anchor edge"
                                model: [
                                    { label: "right", value: "right" },
                                    { label: "left", value: "left" },
                                    { label: "top", value: "top" },
                                    { label: "bottom", value: "bottom" }
                                ]
                                currentValue: Settings.notificationEdge || "right"
                                onSelected: (value) => Settings.notificationEdge = value
                            }

                            ChoiceRow {
                                title: "toast corner style"
                                model: [
                                    { label: "concave scoop", value: "concave" },
                                    { label: "rounded card", value: "rounded" }
                                ]
                                currentValue: Settings.notificationCornerStyle || "concave"
                                onSelected: (value) => Settings.notificationCornerStyle = value
                            }

                            ToggleRow {
                                icon: Theme.iconBellOff
                                title: "do not disturb"
                                subtitle: "suppress on-screen notification popups"
                                checked: Settings.dnd
                                onToggled: {
                                    Settings.dnd = !Settings.dnd;
                                    root.saveSettings();
                                }
                            }
                        }

                        CategoryHeader {
                            title: "idle & power timers"
                            subtitle: "screen dimming, automatic lock, display sleep, and suspend"
                            icon: Theme.iconCoffee
                        }

                        SettingCard {
                            ToggleRow {
                                icon: Theme.iconBrightness
                                title: "dim screen after inactivity"
                                checked: Settings.idleDimEnabled
                                onToggled: {
                                    Settings.idleDimEnabled = !Settings.idleDimEnabled;
                                    root.saveSettings();
                                }
                            }

                            SliderRow {
                                visible: Settings.idleDimEnabled
                                title: "dim delay"
                                from: 30
                                to: 600
                                stepSize: 30
                                value: Settings.idleDimSeconds
                                formatter: (v) => root.fmtIdleSecs(v)
                                onMoved: (val) => Settings.idleDimSeconds = val
                            }

                            RowDivider {}

                            ToggleRow {
                                icon: Theme.iconLock
                                title: "auto-lock session"
                                checked: Settings.idleLockEnabled
                                onToggled: {
                                    Settings.idleLockEnabled = !Settings.idleLockEnabled;
                                    root.saveSettings();
                                }
                            }

                            SliderRow {
                                visible: Settings.idleLockEnabled
                                title: "lock delay"
                                from: 60
                                to: 1800
                                stepSize: 30
                                value: Settings.idleLockSeconds
                                formatter: (v) => root.fmtIdleSecs(v)
                                onMoved: (val) => Settings.idleLockSeconds = val
                            }

                            RowDivider {}

                            ToggleRow {
                                icon: Theme.iconMoon
                                title: "turn display off (dpms)"
                                checked: Settings.idleDpmsEnabled
                                onToggled: {
                                    Settings.idleDpmsEnabled = !Settings.idleDpmsEnabled;
                                    root.saveSettings();
                                }
                            }

                            SliderRow {
                                visible: Settings.idleDpmsEnabled
                                title: "dpms delay"
                                from: 60
                                to: 1800
                                stepSize: 30
                                value: Settings.idleDpmsSeconds
                                formatter: (v) => root.fmtIdleSecs(v)
                                onMoved: (val) => Settings.idleDpmsSeconds = val
                            }

                            RowDivider {}

                            ToggleRow {
                                icon: Theme.iconSuspend
                                title: "suspend system"
                                checked: Settings.idleSuspendEnabled
                                onToggled: {
                                    Settings.idleSuspendEnabled = !Settings.idleSuspendEnabled;
                                    root.saveSettings();
                                }
                            }

                            SliderRow {
                                visible: Settings.idleSuspendEnabled
                                title: "suspend delay"
                                from: 120
                                to: 3600
                                stepSize: 60
                                value: Settings.idleSuspendSeconds
                                formatter: (v) => root.fmtIdleSecs(v)
                                onMoved: (val) => Settings.idleSuspendSeconds = val
                            }
                        }

                        CategoryHeader {
                            title: "shell flavor"
                            icon: Theme.iconSparkles
                        }

                        SettingCard {
                            ChoiceRow {
                                title: "shell flavor text"
                                model: [
                                    { label: "actions", value: "actions" },
                                    { label: "quotes", value: "quotes" },
                                    { label: "hyprland", value: "hyprland" },
                                    { label: "delirium", value: "delirium" },
                                    { label: "off", value: "off" }
                                ]
                                currentValue: Settings.flavorMode ?? "actions"
                                onSelected: (value) => {
                                    Settings.flavorMode = value;
                                    root.saveSettings();
                                }
                            }
                        }
                    }
                }
                TabScrollTrack { target: flickBehavior }

                // 3. keybinds tab
                Item {
                    id: tabKeybinds
                    anchors.fill: parent
                    visible: root.activeTab === "keybinds"

                    KeybindsPreview {
                        anchors.fill: parent
                        anchors.margins: 4
                    }
                }

                // 4. system & recovery tab
                Flickable {
                    id: flickAdvanced
                    anchors.fill: parent
                    visible: root.activeTab === "advanced"
                    clip: true
                    contentWidth: width
                    contentHeight: advancedCol.implicitHeight + 28
                    boundsBehavior: Flickable.StopAtBounds

                    WheelHandler {
                        orientation: Qt.Vertical
                        target: parent
                    }

                    ColumnLayout {
                        id: advancedCol
                        width: parent.width
                        spacing: Theme.popupSpacing

                        readonly property var aliasKeys: Object.keys(Settings.networkAliases || {})

                        CategoryHeader {
                            title: "shell profiles & process"
                            icon: Theme.iconTerminal
                        }

                        SettingCard {
                            Repeater {
                                model: [
                                    {
                                        id: "quickshell",
                                        name: "quickshell (native)",
                                        desc: "primary custom quickshell setup",
                                        path: "~/.config/quickshell",
                                        icon: Theme.iconSliders
                                    },
                                    {
                                        id: "brain_shell",
                                        name: "brain shell",
                                        desc: "material you shell with dynamic matugen theming",
                                        path: "~/.config/Brain_Shell",
                                        icon: Theme.iconSparkles
                                    }
                                ]

                                delegate: Column {
                                    required property var modelData
                                    required property int index
                                    width: parent.width

                                    RowDivider { visible: index > 0 }

                                    Rectangle {
                                        width: parent.width
                                        implicitHeight: 58
                                        radius: Theme.radiusSm
                                        color: root.activeShell === modelData.id
                                            ? Theme.primary_overlay
                                            : (shMouse.containsMouse ? Theme.widgetHover : "transparent")

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 12

                                            Rectangle {
                                                width: 36
                                                height: 36
                                                radius: Theme.radiusSm
                                                color: root.activeShell === modelData.id ? Theme.primary : Theme.widgetBg

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.icon
                                                    font.family: Theme.fontIcon
                                                    font.variableAxes: Theme.iconAxes
                                                    font.pixelSize: Theme.fontSizeSm
                                                    color: root.activeShell === modelData.id ? Theme.on_primary : Theme.textSecondary
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 1

                                                Text {
                                                    text: modelData.name
                                                    font.family: Theme.fontFamily
                                                    font.variableAxes: Theme.sansAxes
                                                    font.pixelSize: Theme.fontSizeSm
                                                    font.weight: Theme.fontWeightBold
                                                    color: Theme.textPrimary
                                                }

                                                Text {
                                                    text: modelData.desc + "  •  " + modelData.path
                                                    font.family: Theme.fontMono
                                                    font.variableAxes: Theme.monoAxes
                                                    font.weight: Theme.monoWeightRegular
                                                    font.pixelSize: Theme.fontSizeXs
                                                    color: Theme.textSecondary
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                            }

                                            Rectangle {
                                                height: 26
                                                width: 66
                                                radius: Theme.radiusPill
                                                color: root.activeShell === modelData.id ? Theme.primary : Theme.widgetBg
                                                border.color: root.activeShell === modelData.id ? "transparent" : Theme.widgetBorder
                                                border.width: 1

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: root.activeShell === modelData.id ? "active" : "switch"
                                                    font.family: Theme.fontFamily
                                                    font.variableAxes: Theme.sansAxes
                                                    font.pixelSize: Theme.fontSizeXs
                                                    font.weight: Theme.fontWeightBold
                                                    color: root.activeShell === modelData.id ? Theme.on_primary : Theme.textPrimary
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: shMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (root.activeShell !== modelData.id) {
                                                    root.activeShell = modelData.id;
                                                    switchProc.switchShell(modelData.id);
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            RowDivider {}

                            Rectangle {
                                width: parent.width
                                height: 38
                                radius: Theme.radiusMd
                                color: rstMouse.containsMouse ? Theme.primary_overlay : Theme.widgetBg
                                border.color: rstMouse.containsMouse ? Theme.primary : Theme.widgetBorder
                                border.width: 1

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 8

                                    Text {
                                        text: Theme.iconRefresh
                                        font.family: Theme.fontIcon
                                        font.variableAxes: Theme.iconAxes
                                        font.pixelSize: Theme.fontSizeSm
                                        color: Theme.primary
                                    }

                                    Text {
                                        text: switchProc.running ? "restarting shell..." : "restart active shell process"
                                        font.family: Theme.fontFamily
                                        font.variableAxes: Theme.sansAxes
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightBold
                                        color: Theme.textPrimary
                                    }
                                }

                                MouseArea {
                                    id: rstMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: !switchProc.running
                                    onClicked: switchProc.restartCurrent()
                                }
                            }
                        }

                        CategoryHeader {
                            title: "network aliases"
                            icon: Theme.iconWifi
                        }

                        SettingCard {
                            Rectangle {
                                width: parent.width
                                height: 34
                                color: "transparent"
                                visible: advancedCol.aliasKeys.length === 0

                                Text {
                                    anchors.centerIn: parent
                                    text: "no custom network aliases saved yet (rename in wi-fi menu)"
                                    font.family: Theme.fontFamily
                                    font.variableAxes: Theme.sansAxes
                                    font.weight: Theme.fontWeightRegular
                                    font.pixelSize: Theme.fontSizeXs
                                    color: Theme.textSecondary
                                }
                            }

                            Repeater {
                                model: advancedCol.aliasKeys

                                delegate: Column {
                                    required property string modelData
                                    required property int index
                                    width: parent.width

                                    RowDivider { visible: index > 0 }

                                    Rectangle {
                                        width: parent.width
                                        height: 38
                                        color: "transparent"

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 8
                                            spacing: 8

                                            Text {
                                                text: Theme.iconWifi
                                                font.family: Theme.fontIcon
                                                font.variableAxes: Theme.iconAxes
                                                font.pixelSize: Theme.fontSizeXs
                                                color: Theme.primary
                                            }

                                            Text {
                                                text: (Settings.networkAliases && Settings.networkAliases[modelData]) || ""
                                                font.family: Theme.fontFamily
                                                font.variableAxes: Theme.sansAxes
                                                font.pixelSize: Theme.fontSizeSm
                                                font.weight: Theme.fontWeightBold
                                                color: Theme.textPrimary
                                            }

                                            Text {
                                                text: "(" + modelData + ")"
                                                font.family: Theme.fontMono
                                                font.variableAxes: Theme.monoAxes
                                                font.weight: Theme.monoWeightRegular
                                                font.pixelSize: Theme.fontSizeXs
                                                color: Theme.textSecondary
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }

                                            IconButton {
                                                icon: Theme.iconTrash
                                                iconSize: Theme.fontSizeXs
                                                tooltip: "remove alias"
                                                onClicked: Settings.setNetworkAlias(modelData, "")
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        CategoryHeader {
                            title: "onboarding & recovery"
                            icon: Theme.iconSparkles
                        }

                        SettingCard {
                            ToggleRow {
                                icon: Theme.iconSparkles
                                title: "reopen welcome guide"
                                subtitle: "launch the onboarding & vibe calibration wizard"
                                checked: false
                                onToggled: {
                                    popup.open = false;
                                    Settings.requestWelcomeOpen();
                                }
                            }

                            RowDivider {}

                            Rectangle {
                                width: parent.width
                                height: 48
                                radius: Theme.radiusMd
                                color: nukeMouse.containsMouse ? Theme.error_overlay : Theme.widgetBg
                                border.color: nukeMouse.containsMouse ? Theme.error : Theme.widgetBorder
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 12

                                    Text {
                                        text: Theme.iconFlame
                                        font.family: Theme.fontIcon
                                        font.variableAxes: Theme.iconAxes
                                        font.pixelSize: Theme.fontSizeMd
                                        color: Theme.error
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            text: "reset all custom settings"
                                            font.family: Theme.fontFamily
                                            font.variableAxes: Theme.sansAxes
                                            font.pixelSize: Theme.fontSizeSm
                                            font.weight: Theme.fontWeightBold
                                            color: Theme.textPrimary
                                        }

                                        Text {
                                            text: "wipe all tweaks and restore stock defaults"
                                            font.family: Theme.fontFamily
                                            font.variableAxes: Theme.sansAxes
                                            font.weight: Theme.fontWeightRegular
                                            font.pixelSize: Theme.fontSizeXs
                                            color: Theme.textSecondary
                                        }
                                    }

                                    Rectangle {
                                        width: 58
                                        height: 26
                                        radius: Theme.radiusPill
                                        color: Theme.error

                                        Text {
                                            text: "nuke"
                                            font.family: Theme.fontFamily
                                            font.variableAxes: Theme.sansAxes
                                            font.pixelSize: Theme.fontSizeXs
                                            font.weight: Theme.fontWeightBold
                                            color: Theme.on_error
                                            anchors.centerIn: parent
                                        }
                                    }
                                }

                                MouseArea {
                                    id: nukeMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.showResetConfirm = true
                                }
                            }
                        }
                    }
                }
                TabScrollTrack { target: flickAdvanced }
            }

            // footer
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: Theme.iconCheck
                    font.family: Theme.fontIcon
                    font.variableAxes: Theme.iconAxes
                    font.pixelSize: Theme.fontSizeXs
                    color: Theme.primary
                }

                Text {
                    text: "changes apply immediately"
                    font.family: Theme.fontFamily
                    font.variableAxes: Theme.sansAxes
                    font.weight: Theme.fontWeightRegular
                    font.pixelSize: Theme.fontSizeXs
                    color: Theme.textSecondary
                    Layout.fillWidth: true
                }

                Text {
                    text: "esc  close"
                    font.family: Theme.fontMono
                    font.variableAxes: Theme.monoAxes
                    font.weight: Theme.monoWeightRegular
                    font.pixelSize: Theme.fontSizeXs
                    color: Theme.textSecondary
                    opacity: 0.75
                }
            }
        }

        // reset confirmation modal
        Rectangle {
            id: resetConfirmModal
            anchors.fill: parent
            color: Theme.alpha(Theme.background, 0.94)
            visible: root.showResetConfirm
            z: 999
            radius: Theme.popupRadius
            focus: visible

            Keys.onEscapePressed: root.showResetConfirm = false

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
            }

            ColumnLayout {
                anchors.centerIn: parent
                width: Math.min(parent.width - 48, 380)
                spacing: 16

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 56
                    height: 56
                    radius: Theme.radiusPill
                    color: Theme.error_overlay
                    border.color: Theme.error
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: Theme.iconFlame
                        font.family: Theme.fontIcon
                        font.variableAxes: Theme.iconAxes
                        font.pixelSize: Theme.fontSizeXl
                        color: Theme.error
                    }
                }

                Text {
                    text: "reset all custom settings?"
                    font.family: Theme.fontDisplay
                    font.variableAxes: Theme.displayAxes
                    font.pixelSize: Theme.fontSizeLg
                    font.weight: Theme.fontWeightBold
                    color: Theme.textPrimary
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: "are you sure? this will wipe every tweak and revert everything back to stock defaults."
                    font.family: Theme.fontFamily
                    font.variableAxes: Theme.sansAxes
                    font.weight: Theme.fontWeightRegular
                    font.pixelSize: Theme.fontSizeSm
                    color: Theme.textSecondary
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        Layout.fillWidth: true
                        height: 40
                        radius: Theme.radiusMd
                        color: cancelMouse.containsMouse ? Theme.widgetHover : Theme.widgetBg
                        border.color: Theme.widgetBorder
                        border.width: 1

                        Text {
                            text: "nevermind"
                            font.family: Theme.fontFamily
                            font.variableAxes: Theme.sansAxes
                            font.pixelSize: Theme.fontSizeSm
                            font.weight: Theme.fontWeightBold
                            color: Theme.textPrimary
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            id: cancelMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.showResetConfirm = false
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 40
                        radius: Theme.radiusMd
                        color: confirmMouse.containsMouse
                            ? Theme.stateHover(Theme.error, Theme.on_error)
                            : Theme.error

                        Text {
                            text: "reset everything"
                            font.family: Theme.fontFamily
                            font.variableAxes: Theme.sansAxes
                            font.pixelSize: Theme.fontSizeSm
                            font.weight: Theme.fontWeightBold
                            color: Theme.on_error
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            id: confirmMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Settings.resetToDefaults();
                                root.showResetConfirm = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
