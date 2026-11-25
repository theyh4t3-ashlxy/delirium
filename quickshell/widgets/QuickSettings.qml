// QuickSettings.qml
import QtQuick
import QtQuick.Layouts
import ".."
import "../controls"
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland

BarPill {
    id: root

    readonly property bool isFloatingBar: (Settings?.barFloating ?? false) || Theme.isBento
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

    property string activeTab: "layout"
    property string fontTarget: "sans"
    property string fontSearchQuery: ""
    property bool showResetConfirm: false
    property string activeShell: "quickshell"
    property bool fontsLoaded: false
    property var allFonts: []

    readonly property string userHome: Quickshell.env("HOME") || ""
    readonly property string cacheDir: Quickshell.env("XDG_CACHE_HOME") || (userHome + "/.cache")
    readonly property string configDir: Quickshell.env("XDG_CONFIG_HOME") || (userHome + "/.config")

    function saveSettings() {
        if (Settings?.save) Settings.save();
    }

    // only query system fonts when the user actually opens the appearance tab
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
    }

    readonly property bool usingMaterialIcons: Settings.iconSet === "material"
        || Settings.iconSet === "material-rounded"
        || Settings.iconSet === "rounded"
        || Settings.iconSet === "material-outlined"
        || Settings.iconSet === "outlined"
        || Settings.iconSet === "material-sharp"
        || Settings.iconSet === "sharp"

    readonly property string activeTabTitle: ({
        layout: "bar & geometry",
        style: "appearance",
        behavior: "behavior",
        keybinds: "keybinds",
        advanced: "system"
    })[root.activeTab] || "settings"

    readonly property string activeTabSubtitle: ({
        layout: "bar dimensions, floating islands, and studio launcher",
        style: "materials, concave scoops, and typography",
        behavior: "clock formats, idle timing, and motion physics",
        keybinds: "view and manage your shell shortcuts",
        advanced: "shell profiles, network aliases, and recovery"
    })[root.activeTab] || ""

    onActiveTabChanged: {
        if (root.activeTab === "style") root.ensureFontsLoaded();
        if (root.activeTab === "layout" && flickLayout) flickLayout.contentY = 0;
        else if (root.activeTab === "style" && flickStyle) flickStyle.contentY = 0;
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
        if (!fontSearchQuery || fontSearchQuery.trim() === "") return allFonts;
        const q = fontSearchQuery.trim().toLowerCase();
        return allFonts.filter(f => f && f.toLowerCase().includes(q));
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

    component CategoryHeader: ColumnLayout {
        id: catHdr
        property string title: ""
        property string icon: ""
        property string subtitle: ""

        Layout.fillWidth: true
        Layout.topMargin: 8
        Layout.bottomMargin: 2
        spacing: 3

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                visible: catHdr.icon !== ""
                width: 24
                height: 24
                radius: Theme.radiusSm
                color: Theme.primary_overlay
                border.color: Theme.alpha(Theme.primary, 0.35)
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: catHdr.icon
                    font.family: Theme.fontIcon
                    font.variableAxes: Theme.iconAxes
                    font.pixelSize: Theme.fontSizeXs
                    color: Theme.primary
                }
            }

            Text {
                text: catHdr.title
                font.family: Theme.fontDisplay
                font.pixelSize: Theme.fontSizeSm
                font.weight: Theme.fontWeightBold
                color: Theme.textPrimary
                Layout.alignment: Qt.AlignVCenter
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.widgetBorder
                Layout.alignment: Qt.AlignVCenter
            }
        }

        Text {
            visible: catHdr.subtitle !== ""
            text: catHdr.subtitle
            Layout.leftMargin: catHdr.icon !== "" ? 32 : 0
            Layout.fillWidth: true
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeXs
            color: Theme.textSecondary
            wrapMode: Text.Wrap
        }
    }

    component SettingCard: Rectangle {
        default property alias content: cardCol.data
        Layout.fillWidth: true
        width: parent ? parent.width : undefined
        implicitHeight: cardCol.implicitHeight + (Theme.widgetPaddingV * 2) + 12
        radius: Theme.radiusMd
        color: Theme.cardBg
        border.color: Theme.cardBorder
        border.width: Theme.popupBorderWidth
        clip: true

        Rectangle {
            visible: Theme.isGlass
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Theme.glassHighlight
        }

        Column {
            id: cardCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: Theme.widgetPaddingH + 2
            anchors.rightMargin: Theme.widgetPaddingH + 2
            anchors.topMargin: Theme.widgetPaddingV + 6
            spacing: 6
        }
    }

    component RowDivider: Rectangle {
        width: parent ? parent.width - 12 : 0
        anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
        height: 1
        color: Theme.widgetBorder
    }

    component ToggleRow: Rectangle {
        id: trRoot
        property string icon: ""
        property string title: ""
        property string subtitle: ""
        property bool checked: false
        signal toggled()

        width: parent ? parent.width : 0
        implicitHeight: subtitle !== "" ? 46 : 36
        height: implicitHeight
        radius: Theme.radiusSm
        color: trMouse.containsMouse ? Theme.widgetHover : "transparent"

        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

        Rectangle {
            id: trIcon
            visible: trRoot.icon !== ""
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 28
            height: 28
            radius: Theme.radiusSm
            color: trRoot.checked ? Theme.primary_overlay : Theme.widgetBg
            border.color: trRoot.checked ? Theme.alpha(Theme.primary, 0.4) : Theme.widgetBorder
            border.width: 1

            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

            Text {
                anchors.centerIn: parent
                text: trRoot.icon
                font.family: Theme.fontIcon
                font.variableAxes: Theme.iconAxes
                font.pixelSize: Theme.fontSizeXs
                color: trRoot.checked ? Theme.primary : Theme.textSecondary
            }
        }

        ToggleSwitch {
            id: trSwitch
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            enabled: false
            checked: trRoot.checked

            Binding {
                target: trSwitch
                property: "checked"
                value: trRoot.checked
            }
        }

        Column {
            anchors.left: trIcon.visible ? trIcon.right : parent.left
            anchors.leftMargin: trIcon.visible ? 10 : 6
            anchors.right: trSwitch.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                text: trRoot.title
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSm
                font.weight: trRoot.checked ? Theme.fontWeightDemiBold : Theme.fontWeightMedium
                color: Theme.textPrimary
                elide: Text.ElideRight
            }

            Text {
                visible: trRoot.subtitle !== ""
                width: parent.width
                text: trRoot.subtitle
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXs
                color: Theme.textSecondary
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: trMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: trRoot.toggled()
        }
    }

    component ChoiceRow: ColumnLayout {
        id: crRoot
        property string title: ""
        property var model: []
        property var currentValue
        property int buttonHeight: 28
        signal selected(var value)

        width: parent ? parent.width : 0
        implicitWidth: width
        Layout.fillWidth: true
        spacing: 5

        Text {
            visible: crRoot.title !== ""
            text: crRoot.title
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeXs
            font.weight: Theme.fontWeightDemiBold
            color: Theme.textSecondary
        }

        GridLayout {
            Layout.fillWidth: true
            columns: crRoot.model.length >= 6 ? 3 : Math.max(1, crRoot.model.length)
            columnSpacing: 5
            rowSpacing: 5

            Repeater {
                model: crRoot.model

                delegate: Rectangle {
                    required property var modelData
                    readonly property var itemVal: modelData && typeof modelData === "object"
                        ? (modelData.value !== undefined ? modelData.value : modelData)
                        : modelData
                    readonly property string itemText: modelData && typeof modelData === "object" && modelData.label !== undefined
                        ? String(modelData.label)
                        : (typeof modelData === "number" ? (modelData === 0 ? "none" : modelData + "px") : String(modelData || ""))
                    readonly property bool isSelected: (typeof crRoot.currentValue === "number" && typeof itemVal === "number" && !Number.isInteger(itemVal))
                        ? Math.abs(crRoot.currentValue - itemVal) < 0.04
                        : crRoot.currentValue === itemVal

                    Layout.fillWidth: true
                    Layout.preferredHeight: crRoot.buttonHeight
                    radius: isSelected ? Theme.radiusMd : Theme.radiusPill
                    color: isSelected
                        ? Theme.primary_overlay
                        : (crMouse.pressed ? Theme.widgetActive : (crMouse.containsMouse ? Theme.widgetHover : Theme.widgetBg))
                    border.color: isSelected
                        ? Theme.alpha(Theme.primary, 0.65)
                        : (crMouse.containsMouse ? Theme.alpha(Theme.primary, 0.35) : Theme.widgetBorder)
                    border.width: 1

                    Behavior on radius { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
                    Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                    Text {
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, Math.max(0, parent.width - 10))
                        text: itemText
                        horizontalAlignment: Text.AlignHCenter
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXs
                        font.weight: isSelected ? Theme.fontWeightBold : Theme.fontWeightMedium
                        color: isSelected ? Theme.primary : Theme.textSecondary
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: crMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            crRoot.selected(itemVal);
                            root.saveSettings();
                        }
                    }
                }
            }
        }
    }

    component SliderRow: ColumnLayout {
        id: slRoot
        property string title: ""
        property real from: 0
        property real to: 100
        property real value: 0
        property real stepSize: 1
        property string suffix: "px"
        property var formatter: null
        signal moved(real val)

        width: parent ? parent.width : 0
        implicitWidth: width
        Layout.fillWidth: true
        spacing: 5

        readonly property string displayText: slRoot.formatter
            ? slRoot.formatter(slRoot.value)
            : ((Math.round(slRoot.value * 100) / 100) + slRoot.suffix)

        readonly property real ratio: slRoot.to > slRoot.from
            ? Math.max(0.0, Math.min(1.0, (slRoot.value - slRoot.from) / (slRoot.to - slRoot.from)))
            : 0.0

        function commitRatio(r) {
            const t = Math.max(0.0, Math.min(1.0, r));
            let raw = slRoot.from + t * (slRoot.to - slRoot.from);
            if (slRoot.stepSize > 0) raw = Math.round(raw / slRoot.stepSize) * slRoot.stepSize;
            raw = Math.max(slRoot.from, Math.min(slRoot.to, raw));
            if (Math.abs(raw - slRoot.value) > 1e-6) {
                slRoot.moved(raw);
                root.saveSettings();
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                visible: slRoot.title !== ""
                text: slRoot.title
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXs
                font.weight: Theme.fontWeightDemiBold
                color: Theme.textSecondary
                Layout.fillWidth: true
            }

            Rectangle {
                height: 18
                implicitWidth: valBadge.implicitWidth + 10
                radius: Theme.radiusPill
                color: dragArea.pressed ? Theme.primary_overlay : Theme.widgetBg
                border.color: dragArea.pressed ? Theme.alpha(Theme.primary, 0.5) : Theme.widgetBorder
                border.width: 1

                Text {
                    id: valBadge
                    anchors.centerIn: parent
                    text: slRoot.displayText
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
                id: track
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: dragArea.pressed ? 14 : (dragArea.containsMouse ? 11 : 8)
                radius: Theme.radiusPill
                color: Theme.widgetBg
                border.color: dragArea.containsMouse ? Theme.alpha(Theme.primary, 0.35) : Theme.widgetBorder
                border.width: 1

                Behavior on height { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
                Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Math.max(parent.height, parent.width * slRoot.ratio)
                    radius: Theme.radiusPill
                    color: dragArea.pressed
                        ? Theme.statePress(Theme.primary, Theme.on_primary)
                        : (dragArea.containsMouse ? Theme.stateHover(Theme.primary, Theme.on_primary) : Theme.primary)

                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }
            }

            Rectangle {
                width: dragArea.pressed ? 6 : 4
                height: dragArea.pressed ? 20 : (dragArea.containsMouse ? 17 : 14)
                radius: Theme.radiusPill
                color: Theme.on_surface
                anchors.verticalCenter: parent.verticalCenter
                x: Math.max(0, Math.min(parent.width - width, (parent.width * slRoot.ratio) - (width / 2)))

                Behavior on width { NumberAnimation { duration: Theme.animFast } }
                Behavior on height { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animExpressiveEasing } }
            }

            MouseArea {
                id: dragArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                preventStealing: true

                onPressed: (mouse) => slRoot.commitRatio(mouse.x / width)
                onPositionChanged: (mouse) => {
                    if (pressed) slRoot.commitRatio(mouse.x / width);
                }
                onWheel: (wheel) => {
                    let dir = wheel.angleDelta.y > 0 ? 1 : -1;
                    let step = slRoot.stepSize > 0 ? slRoot.stepSize : ((slRoot.to - slRoot.from) * 0.05);
                    let next = Math.max(slRoot.from, Math.min(slRoot.to, slRoot.value + dir * step));
                    if (Math.abs(next - slRoot.value) > 1e-6) {
                        slRoot.moved(next);
                        root.saveSettings();
                    }
                }
            }
        }
    }

    component ChoiceGrid: ColumnLayout {
        id: cgRoot
        property string title: ""
        property int columns: 2
        property var model: []
        property var currentValue
        property int buttonHeight: 28
        signal selected(var value)

        width: parent ? parent.width : 0
        implicitWidth: width
        Layout.fillWidth: true
        spacing: 5

        Text {
            visible: cgRoot.title !== ""
            text: cgRoot.title
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeXs
            font.weight: Theme.fontWeightDemiBold
            color: Theme.textSecondary
        }

        Grid {
            id: choiceGrid
            width: parent.width
            Layout.fillWidth: true
            columns: Math.max(1, cgRoot.columns)
            rowSpacing: 6
            columnSpacing: 6

            Repeater {
                model: cgRoot.model

                delegate: Rectangle {
                    required property var modelData
                    readonly property var itemVal: modelData && typeof modelData === "object"
                        ? (modelData.value !== undefined ? modelData.value : (modelData.id !== undefined ? modelData.id : modelData))
                        : modelData
                    readonly property string itemText: modelData && typeof modelData === "object" && modelData.label !== undefined
                        ? String(modelData.label)
                        : String(modelData || "")
                    readonly property bool isSelected: (typeof cgRoot.currentValue === "number" && typeof itemVal === "number" && !Number.isInteger(itemVal))
                        ? Math.abs(cgRoot.currentValue - itemVal) < 0.04
                        : cgRoot.currentValue === itemVal

                    width: Math.max(1, (choiceGrid.width - choiceGrid.columnSpacing * (choiceGrid.columns - 1)) / choiceGrid.columns)
                    height: cgRoot.buttonHeight
                    radius: isSelected ? Theme.radiusMd : Theme.radiusSm
                    color: isSelected
                        ? Theme.primary_overlay
                        : (cgMouse.containsMouse ? Theme.widgetHover : Theme.widgetBg)
                    border.color: isSelected
                        ? Theme.alpha(Theme.primary, 0.65)
                        : (cgMouse.containsMouse ? Theme.alpha(Theme.primary, 0.35) : Theme.widgetBorder)
                    border.width: 1

                    Behavior on radius { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
                    Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: itemText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXs
                        font.weight: isSelected ? Theme.fontWeightBold : Theme.fontWeightMedium
                        color: isSelected ? Theme.primary : Theme.textSecondary
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: cgMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            cgRoot.selected(itemVal);
                            root.saveSettings();
                        }
                    }
                }
            }
        }
    }

    component TabScrollTrack: Rectangle {
        id: stRoot
        required property Flickable target
        anchors.right: target ? target.right : undefined
        anchors.top: target ? target.top : undefined
        anchors.bottom: target ? target.bottom : undefined
        anchors.margins: 2
        width: 4
        radius: 2
        color: "transparent"
        visible: target ? (target.visible && target.visibleArea.heightRatio < 1.0) : false

        Rectangle {
            width: parent.width
            readonly property real trackH: stRoot.height
            readonly property real thumbH: Math.max(20, Math.min(trackH, (stRoot.target ? stRoot.target.visibleArea.heightRatio : 1) * trackH))
            height: thumbH
            y: Math.max(0, Math.min(trackH - thumbH, (stRoot.target ? stRoot.target.visibleArea.yPosition : 0) * trackH))
            radius: 2
            color: Theme.primary
            opacity: 0.75
        }
    }

    // bar pill content (expands on hover like ScreenCapture, Bluetooth, and NetworkStatus)
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
            font.pixelSize: Theme.fontSizeSm
            font.weight: Font.Medium
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
                spacing: 10

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
                        text: "settings & studio"
                        font.family: Theme.fontDisplay
                        font.pixelSize: Theme.fontSizeMd
                        font.weight: Theme.fontWeightBold
                        color: Theme.textPrimary
                    }

                    Text {
                        text: root.activeTabTitle + "  •  " + root.activeTabSubtitle
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXs
                        color: Theme.textSecondary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    height: 22
                    implicitWidth: saveBadgeRow.implicitWidth + 14
                    radius: Theme.radiusPill
                    color: Theme.primary_overlay
                    border.color: Theme.primary
                    border.width: 1

                    RowLayout {
                        id: saveBadgeRow
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            visible: !Theme.isTextIconSet
                            text: Theme.iconCheck
                            font.family: Theme.fontIcon
                            font.variableAxes: Theme.iconAxes
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.primary
                        }

                        Text {
                            text: "live"
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: Theme.fontWeightBold
                            color: Theme.primary
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

            // horizontal tab bar
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
                            { id: "layout", label: "bar", icon: Theme.iconGrid },
                            { id: "style", label: "appearance", icon: Theme.iconSparkles },
                            { id: "behavior", label: "behavior", icon: Theme.iconFlame },
                            { id: "keybinds", label: "keybinds", icon: Theme.iconKeyboard },
                            { id: "advanced", label: "system", icon: Theme.iconSliders }
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

                // 1. bar & geometry tab (module lists nuked since BarStudio owns module placement now)
                Flickable {
                    id: flickLayout
                    anchors.fill: parent
                    visible: root.activeTab === "layout"
                    clip: true
                    contentWidth: width
                    contentHeight: layoutCol.implicitHeight + 28
                    boundsBehavior: Flickable.StopAtBounds

                    WheelHandler {
                        orientation: Qt.Vertical
                        target: parent
                    }

                    ColumnLayout {
                        id: layoutCol
                        width: parent.width
                        spacing: Theme.popupSpacing

                        // bar layout studio launcher card (closes quick settings so they don't stack on top of each other)
                        SettingCard {
                            RowLayout {
                                width: parent.width
                                spacing: 10

                                Rectangle {
                                    width: 38
                                    height: 38
                                    radius: Theme.radiusMd
                                    color: Settings.showBarStudio ? Theme.primary : Theme.primary_overlay
                                    border.color: Theme.alpha(Theme.primary, 0.4)
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: Theme.iconSparkles
                                        font.family: Theme.fontIcon
                                        font.variableAxes: Theme.iconAxes
                                        font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeXs : Theme.fontSizeMd
                                        color: Settings.showBarStudio ? Theme.on_primary : Theme.primary
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        text: "bar layout studio"
                                        font.family: Theme.fontDisplay
                                        font.pixelSize: Theme.fontSizeSm
                                        font.weight: Theme.fontWeightBold
                                        color: Theme.textPrimary
                                    }

                                    Text {
                                        text: "drag & drop modules, switch zones, toggle visibility, or load presets"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeXs
                                        color: Theme.textSecondary
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                Rectangle {
                                    height: 30
                                    implicitWidth: studioQuickTxt.implicitWidth + 20
                                    radius: Theme.radiusPill
                                    color: studioBtnMouse.containsMouse
                                        ? Theme.stateHover(Theme.primary, Theme.on_primary)
                                        : Theme.primary

                                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                    Text {
                                        id: studioQuickTxt
                                        anchors.centerIn: parent
                                        text: "open studio"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightBold
                                        color: Theme.on_primary
                                    }

                                    MouseArea {
                                        id: studioBtnMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            popup.open = false;
                                            Settings.showBarStudio = true;
                                        }
                                    }
                                }
                            }
                        }

                        CategoryHeader {
                            title: "bar geometry & spacing"
                            subtitle: "screen edge, thickness, padding density, and corner rounding"
                            icon: Theme.iconGrid
                        }

                        SettingCard {
                            ChoiceRow {
                                title: "screen placement"
                                model: [
                                    { label: "top", value: "top" },
                                    { label: "bottom", value: "bottom" },
                                    { label: "left", value: "left" },
                                    { label: "right", value: "right" }
                                ]
                                currentValue: Settings.barPosition === "up" ? "top" : (Settings.barPosition === "down" ? "bottom" : Settings.barPosition)
                                onSelected: (val) => Settings.barPosition = val
                            }

                            ChoiceRow {
                                title: "padding density scale (Theme.paddingScale)"
                                model: [
                                    { label: "compact (0.8x)", value: "compact" },
                                    { label: "cozy (1.0x)", value: "cozy" },
                                    { label: "comfortable (1.25x)", value: "comfortable" }
                                ]
                                currentValue: Settings.paddingScale || "cozy"
                                onSelected: (val) => Settings.paddingScale = val
                            }

                            RowDivider {}

                            SliderRow {
                                title: "bar thickness"
                                from: 24
                                to: 56
                                stepSize: 2
                                suffix: "px"
                                value: Settings.barHeight
                                onMoved: (val) => Settings.barHeight = val
                            }

                            SliderRow {
                                title: "widget spacing"
                                from: 0
                                to: 16
                                stepSize: 1
                                suffix: "px"
                                value: Settings.widgetSpacing
                                onMoved: (val) => Settings.widgetSpacing = val
                            }

                            SliderRow {
                                title: "widget horizontal padding"
                                from: 2
                                to: 18
                                stepSize: 1
                                suffix: "px"
                                value: Settings.widgetPaddingH
                                onMoved: (val) => Settings.widgetPaddingH = val
                            }

                            RowDivider {}

                            ChoiceRow {
                                title: "widget corner radius"
                                model: [
                                    { label: "sharp", value: 0 },
                                    { label: "2px", value: 2 },
                                    { label: "4px", value: 4 },
                                    { label: "8px", value: 8 },
                                    { label: "pill", value: 9999 }
                                ]
                                currentValue: Settings.widgetRadius
                                onSelected: (val) => Settings.widgetRadius = val
                            }

                            SliderRow {
                                title: "popup corner radius"
                                from: 0
                                to: 28
                                stepSize: 2
                                suffix: "px"
                                value: Settings.popupRadius
                                onMoved: (val) => Settings.popupRadius = val
                            }
                        }

                        CategoryHeader {
                            title: "bar layout, grouping & chrome"
                            subtitle: "configure floating islands, module clusters, dividers, and widget framing"
                            icon: Theme.iconExpand
                        }

                        SettingCard {
                            ChoiceRow {
                                title: "module grouping"
                                model: [
                                    { label: "clusters", value: "clusters" },
                                    { label: "3 zones", value: "zones" },
                                    { label: "none", value: "none" }
                                ]
                                currentValue: Settings.barGrouping || "clusters"
                                onSelected: (val) => Settings.barGrouping = val
                            }

                            ChoiceRow {
                                title: "widget chrome style"
                                model: [
                                    { label: "grouped", value: "grouped" },
                                    { label: "ghost", value: "ghost" },
                                    { label: "underline", value: "underline" },
                                    { label: "pills", value: "pills" }
                                ]
                                currentValue: Settings.barWidgetChrome || "grouped"
                                onSelected: (val) => Settings.barWidgetChrome = val
                            }

                            ChoiceRow {
                                title: "cluster dividers"
                                model: [
                                    { label: "hairline", value: "line" },
                                    { label: "dot", value: "dot" },
                                    { label: "none", value: "none" }
                                ]
                                currentValue: Settings.barDividers || "line"
                                onSelected: (val) => Settings.barDividers = val
                            }

                            RowDivider {}

                            ToggleRow {
                                icon: Theme.iconExpand
                                title: "floating bar"
                                subtitle: "detach status bar from screen edge"
                                checked: Settings.barFloating
                                onToggled: {
                                    Settings.barFloating = !Settings.barFloating;
                                    root.saveSettings();
                                }
                            }

                            RowDivider { visible: Settings.barFloating || Theme.isBento }

                            ToggleRow {
                                visible: Settings.barFloating || Theme.isBento
                                icon: Theme.iconGrid
                                title: "bento island split"
                                subtitle: "split left, center, and right zones into floating capsules"
                                checked: Settings.barIslandMode ?? true
                                onToggled: {
                                    Settings.barIslandMode = !(Settings.barIslandMode ?? true);
                                    root.saveSettings();
                                }
                            }

                            ToggleRow {
                                visible: Settings.barFloating || Theme.isBento
                                icon: Theme.iconSparkles
                                title: "bento island hover lift"
                                subtitle: "elevate capsules slightly when hovered"
                                checked: Settings.bentoHoverLift ?? true
                                onToggled: {
                                    Settings.bentoHoverLift = !(Settings.bentoHoverLift ?? true);
                                    root.saveSettings();
                                }
                            }

                            SliderRow {
                                visible: Settings.barFloating || Theme.isBento
                                title: "floating bar corner radius"
                                from: 0
                                to: 24
                                stepSize: 2
                                suffix: "px"
                                value: Settings.barRadius
                                onMoved: (v) => Settings.barRadius = v
                            }

                            SliderRow {
                                visible: Settings.barFloating || Theme.isBento
                                title: "floating screen margin"
                                from: 0
                                to: 32
                                stepSize: 2
                                suffix: "px"
                                value: Settings.barMargin
                                onMoved: (v) => Settings.barMargin = v
                            }
                        }

                        CategoryHeader {
                            title: "window title"
                            subtitle: "configure active window pill sizing and app icon"
                            icon: Theme.iconSparkles
                        }

                        SettingCard {
                            ChoiceRow {
                                title: "window title width mode"
                                model: [
                                    { label: "auto fit", value: "auto" },
                                    { label: "fill space", value: "fill" },
                                    { label: "compact", value: "compact" }
                                ]
                                currentValue: Settings.windowTitleMode || "auto"
                                onSelected: (val) => Settings.windowTitleMode = val
                            }

                            ToggleRow {
                                icon: Theme.iconEye
                                title: "app icon in window title"
                                subtitle: "resolve desktop entry icon next to active window title"
                                checked: Settings.windowTitleShowIcon ?? true
                                onToggled: {
                                    Settings.windowTitleShowIcon = !(Settings.windowTitleShowIcon ?? true);
                                    root.saveSettings();
                                }
                            }
                        }
                    }
                }
                TabScrollTrack { target: flickLayout }

                // 2. appearance & style tab
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
                            title: "surface & material"
                            subtitle: "bar shader preset, adaptive opacity, and surface glass"
                            icon: Theme.iconSparkles
                        }

                        SettingCard {
                            ChoiceGrid {
                                columns: 3
                                buttonHeight: 32
                                title: "bar material preset"
                                model: [
                                    { label: "regular", value: "regular" },
                                    { label: "frosted glass", value: "glass" },
                                    { label: "glass frost", value: "glass-frost" },
                                    { label: "pure black", value: "pure-black" },
                                    { label: "cyber neon", value: "cyber-neon" },
                                    { label: "bento", value: "bento-floating" },
                                    { label: "translucent", value: "translucent" },
                                    { label: "accent glow", value: "accent-glow" },
                                    { label: "monochrome", value: "monochrome" }
                                ]
                                currentValue: Settings.barStyle
                                onSelected: (val) => Settings.barStyle = val
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

                            SliderRow {
                                title: "bar background opacity"
                                from: 0.3
                                to: 1.0
                                stepSize: 0.05
                                value: Settings.barOpacity
                                formatter: (v) => Math.round(v * 100) + "%"
                                onMoved: (val) => Settings.barOpacity = val
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
                        }

                        CollapsibleSection {
                            Layout.fillWidth: true
                            title: "screen corners, scoops & frame"
                            subtitle: "concave fillets, curvature math & border strokes"
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
                                    { label: "pure black", value: "pure-black" }
                                ]
                                currentValue: Settings.cornerColorMode
                                onSelected: (val) => Settings.cornerColorMode = val
                            }

                            SliderRow {
                                title: "bar scoop radius"
                                from: 0
                                to: 32
                                stepSize: 2
                                suffix: "px"
                                value: Settings.scoopRadius
                                onMoved: (val) => Settings.scoopRadius = val
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
                                title: "scoop border width"
                                from: 1
                                to: 6
                                stepSize: 1
                                suffix: "px"
                                value: Settings.scoopBorderWidth
                                onMoved: (val) => Settings.scoopBorderWidth = val
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
                                    icon: Theme.iconSparkles
                                    title: "scoop border outlines"
                                    subtitle: "draw continuous stroke along concave curves"
                                    checked: Settings.scoopBorderEnabled
                                    onToggled: {
                                        Settings.scoopBorderEnabled = !Settings.scoopBorderEnabled;
                                        root.saveSettings();
                                    }
                                }
                                RowDivider {}
                                ToggleRow {
                                    icon: Theme.iconGrid
                                    title: "docked frame & scoops"
                                    subtitle: "anchor shell fillets directly to screen bounds"
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
                                onToggled: Settings.materialFilled = !Settings.materialFilled
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

                            ChoiceRow {
                                title: "font weight"
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
                        }

                        CollapsibleSection {
                            Layout.fillWidth: true
                            title: "system font browser"
                            subtitle: "swap interface or monospace font families"
                            icon: Theme.iconSearch
                            badge: root.fontTarget === "sans" ? Settings.fontFamily : Settings.fontMono

                            RowLayout {
                                width: parent.width
                                spacing: 6

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 32
                                    radius: root.fontTarget === "sans" ? Theme.radiusMd : Theme.radiusPill
                                    color: root.fontTarget === "sans" ? Theme.primary_overlay : Theme.widgetBg
                                    border.color: root.fontTarget === "sans" ? Theme.primary : Theme.widgetBorder
                                    border.width: 1

                                    Text {
                                        text: "sans: " + Settings.fontFamily
                                        font.family: Settings.fontFamily
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightBold
                                        color: root.fontTarget === "sans" ? Theme.primary : Theme.textSecondary
                                        anchors.centerIn: parent
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
                                    height: 32
                                    radius: root.fontTarget === "mono" ? Theme.radiusMd : Theme.radiusPill
                                    color: root.fontTarget === "mono" ? Theme.primary_overlay : Theme.widgetBg
                                    border.color: root.fontTarget === "mono" ? Theme.primary : Theme.widgetBorder
                                    border.width: 1

                                    Text {
                                        text: "mono: " + Settings.fontMono
                                        font.family: Settings.fontMono
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightBold
                                        color: root.fontTarget === "mono" ? Theme.primary : Theme.textSecondary
                                        anchors.centerIn: parent
                                        elide: Text.ElideRight
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.fontTarget = "mono"
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 36
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
                                            font.pixelSize: Theme.fontSizeXs
                                            color: Theme.textSecondary
                                        }

                                        TextInput {
                                            id: fontSearchInput
                                            anchors.fill: parent
                                            verticalAlignment: TextInput.AlignVCenter
                                            font.family: Theme.fontFamily
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
                                width: parent.width
                                height: 170
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
                                        readonly property bool isCurrent: (root.fontTarget === "sans" && Settings.fontFamily === modelData)
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

                                            // keep iconCheck in Theme.fontIcon so random system fonts don't render it as a box
                                            Text {
                                                visible: isCurrent && !Theme.isTextIconSet
                                                text: Theme.iconCheck
                                                font.family: Theme.fontIcon
                                                font.variableAxes: Theme.iconAxes
                                                font.pixelSize: Theme.fontSizeXs
                                                color: Theme.primary
                                            }

                                            Text {
                                                text: isCurrent ? "active" : "123 abc"
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

                // 3. behavior, lock screen studio & clock tab
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
                            title: "bar clock & workspaces"
                            icon: Theme.iconClock
                        }

                        SettingCard {
                            ChoiceRow {
                                title: "bar clock format"
                                model: [
                                    { label: "24h", value: "HH:mm" },
                                    { label: "12h", value: "h:mm ap" },
                                    { label: "24h + sec", value: "HH:mm:ss" },
                                    { label: "12h + sec", value: "h:mm:ss ap" }
                                ]
                                currentValue: Settings.clockFormat
                                onSelected: (value) => {
                                    Settings.clockFormat = value;
                                    let is12 = /ap/i.test(value);
                                    let hasSec = /:ss/i.test(value);
                                    Settings.clockMilitary = !is12;
                                    Settings.clock24h = !is12;
                                    Settings.clockShowSeconds = hasSec;
                                }
                            }

                            ChoiceRow {
                                title: "bar date format"
                                model: [
                                    { label: "hidden", value: "none" },
                                    { label: "short", value: "ddd, MMM d" },
                                    { label: "full", value: "MMM d, yyyy" },
                                    { label: "iso", value: "yyyy-MM-dd" }
                                ]
                                currentValue: !Settings.showBarDate ? "none" : Settings.dateFormat
                                onSelected: (value) => {
                                    if (value === "none") {
                                        Settings.showBarDate = false;
                                    } else {
                                        Settings.dateFormat = value;
                                        Settings.showBarDate = true;
                                    }
                                }
                            }

                            ChoiceRow {
                                title: "workspace capacity"
                                model: [
                                    { label: "5", value: 5 },
                                    { label: "8", value: 8 },
                                    { label: "10", value: 10 },
                                    { label: "12", value: 12 },
                                    { label: "16", value: 16 }
                                ]
                                currentValue: Settings.workspaceCount
                                onSelected: (value) => Settings.workspaceCount = value
                            }
                        }

                        CategoryHeader {
                            title: "motion & interaction"
                            subtitle: "animation speed, easing curves, workspace trail, and flyouts"
                            icon: Theme.iconFlame
                        }

                        SettingCard {
                            ChoiceGrid {
                                columns: 3
                                buttonHeight: 30
                                title: "animation speed preset"
                                model: [
                                    { label: "hyprland", value: "hyprland" },
                                    { label: "snappy", value: "snappy" },
                                    { label: "hyper", value: "hyper" },
                                    { label: "normal", value: "normal" },
                                    { label: "chill", value: "chill" },
                                    { label: "instant", value: "instant" }
                                ]
                                currentValue: Settings.animSpeed
                                onSelected: (val) => Settings.animSpeed = val
                            }

                            ChoiceRow {
                                title: "easing curve profile (Theme.animCurve)"
                                model: [
                                    { label: "cubic", value: "cubic" },
                                    { label: "hyprland", value: "hyprland" },
                                    { label: "snappy", value: "snappy" },
                                    { label: "expressive", value: "expressive" },
                                    { label: "linear", value: "linear" }
                                ]
                                currentValue: Settings.animCurve || "cubic"
                                onSelected: (val) => Settings.animCurve = val
                            }

                            RowDivider {}

                            ChoiceRow {
                                title: "workspace indicator motion"
                                model: [
                                    { label: "smooth slide", value: "slide" },
                                    { label: "fluid trail", value: "fluid-trail" },
                                    { label: "discrete", value: "discrete" }
                                ]
                                currentValue: Settings.workspaceMode
                                onSelected: (value) => Settings.workspaceMode = value
                            }

                            SliderRow {
                                visible: Settings.workspaceMode === "fluid-trail"
                                title: "workspace trail duration"
                                from: 120
                                to: 400
                                stepSize: 10
                                suffix: "ms"
                                value: Settings.workspaceTrailDuration
                                onMoved: (val) => Settings.workspaceTrailDuration = val
                            }

                            RowDivider {}

                            ToggleRow {
                                icon: Theme.iconEye
                                title: "hover to open flyouts"
                                subtitle: "hover over bar pills to open popups"
                                checked: Settings.hoverToOpen
                                onToggled: {
                                    Settings.hoverToOpen = !Settings.hoverToOpen;
                                    root.saveSettings();
                                }
                            }

                            ToggleRow {
                                icon: Theme.iconEyeOff
                                title: "hover auto-close"
                                subtitle: "dismiss popup when cursor leaves"
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
                        }

                        CategoryHeader {
                            title: "audio, notifications & flavor"
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

                            RowDivider {}

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
                            RowDivider {}
                            ChoiceRow {
                                title: "shell flavor text"
                                model: [
                                    { label: "actions", value: "actions" },
                                    { label: "quotes", value: "quotes" },
                                    { label: "hyprland", value: "hyprland" },
                                    { label: "off", value: "off" }
                                ]
                                currentValue: Settings.flavorMode ?? "actions"
                                onSelected: (value) => {
                                    Settings.flavorMode = value;
                                    root.saveSettings();
                                }
                            }
                            RowDivider {}
                            ToggleRow {
                                icon: Theme.iconSparkles
                                title: "motion sandbox playground"
                                subtitle: "open interactive physics playground on screen edge"
                                checked: Settings.showMotionSandbox
                                onToggled: {
                                    Settings.showMotionSandbox = !Settings.showMotionSandbox;
                                    root.saveSettings();
                                }
                            }
                        }
                    }
                }
                TabScrollTrack { target: flickBehavior }

                // 5. system & recovery tab
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
                                                    font.pixelSize: Theme.fontSizeSm
                                                    font.weight: Theme.fontWeightBold
                                                    color: Theme.textPrimary
                                                }

                                                Text {
                                                    text: modelData.desc + "  •  " + modelData.path
                                                    font.family: Theme.fontMono
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
                                                font.pixelSize: Theme.fontSizeSm
                                                font.weight: Theme.fontWeightBold
                                                color: Theme.textPrimary
                                            }

                                            Text {
                                                text: "(" + modelData + ")"
                                                font.family: Theme.fontMono
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
                                            font.pixelSize: Theme.fontSizeSm
                                            font.weight: Theme.fontWeightBold
                                            color: Theme.textPrimary
                                        }

                                        Text {
                                            text: "wipe all tweaks and restore stock defaults"
                                            font.family: Theme.fontFamily
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

                // 6. keybinds tab
                Item {
                    id: tabKeybinds
                    anchors.fill: parent
                    visible: root.activeTab === "keybinds"

                    KeybindsPreview {
                        anchors.fill: parent
                        anchors.margins: 4
                    }
                }
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
                    font.pixelSize: Theme.fontSizeXs
                    color: Theme.textSecondary
                    Layout.fillWidth: true
                }

                Text {
                    text: "esc  close"
                    font.family: Theme.fontMono
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
                    font.pixelSize: Theme.fontSizeLg
                    font.weight: Theme.fontWeightBold
                    color: Theme.textPrimary
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: "are you sure? this will wipe every tweak and revert everything back to stock defaults."
                    font.family: Theme.fontFamily
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
