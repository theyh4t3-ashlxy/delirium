import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import ".."
import "../controls"
import "../services"
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Rectangle {
    id: root

    property var barScreen: null
    property var barMonitor: null

    // actual built-in hyprland 0.54+ layout names (scrolling, not scroller)
    property string currentLayout: "dwindle"
    property int numWindows: 0
    property var availableLayouts: ["dwindle", "master", "scrolling", "monocle"]

    readonly property var layoutDefinitions: [
        {
            id: "dwindle",
            title: "dwindle layout",
            badge: "binary tree",
            icon: "⊞",
            desc: "arranges windows like a binary tree, dynamically splitting space as windows open."
        },
        {
            id: "master",
            title: "master layout",
            badge: "master + stack",
            icon: "◫",
            desc: "keeps a primary master window alongside stacked side windows."
        },
        {
            id: "scrolling",
            title: "scrolling layout",
            badge: "infinite tape",
            icon: "↔",
            desc: "places windows on an infinitely scrolling horizontal tape, great for ultrawides."
        },
        {
            id: "monocle",
            title: "monocle layout",
            badge: "deck stack",
            icon: "󰊓",
            desc: "stretches the focused window across the workspace and stacks the rest behind it."
        }
    ]

    implicitWidth: {
        if (Theme?.isVertical ?? false) return (Theme?.barHeight ?? 32) - 8;
        return (lMouse.containsMouse || popup.open)
            ? Math.max(38, pillRow.implicitWidth + 20)
            : Math.max(34, pillRow.implicitWidth + 14);
    }
    implicitHeight: (Theme?.isVertical ?? false) ? Math.max(36, pillCol.implicitHeight + 12) : ((Theme?.barHeight ?? 32) - 8)
    radius: Theme?.radiusPill ?? 999
    color: popup.open
        ? (Theme?.primary_overlay ?? "#33ffffff")
        : (lMouse.containsMouse ? (Theme?.pillHover ?? "#22ffffff") : (Theme?.pillBg ?? "#11ffffff"))
    border.color: (Theme?.isCyberNeon ?? false) ? (Theme?.primary ?? "#00ffff") : (Theme?.pillBorder ?? "transparent")
    border.width: ((Theme?.isCyberNeon ?? false) || ((Theme?.pillBorder ?? "transparent") !== "transparent")) ? 1 : 0
    visible: Settings?.showLayoutSwitcher ?? true

    Behavior on color { ColorAnimation { duration: Theme?.animFast ?? 120; easing.type: Theme?.animColorEasing ?? Easing.OutQuad } }
    Behavior on border.color { ColorAnimation { duration: Theme?.animFast ?? 120; easing.type: Theme?.animColorEasing ?? Easing.OutQuad } }
    Behavior on implicitWidth {
        NumberAnimation {
            duration: Theme?.animFast ?? 120
            easing.type: Theme?.animEasing ?? Easing.OutQuad
        }
    }

    scale: (Settings?.bentoHoverLift ?? true) && lMouse.containsMouse && !popup.open ? 1.02 : 1.0
    Behavior on scale {
        NumberAnimation {
            duration: Theme?.animFast ?? 120
            easing.type: Theme?.animEasing ?? Easing.OutQuad
        }
    }

    // normalize any old "scroller" configs to "scrolling" so nothing gets stuck
    function normalizeLayoutName(layout: string): string {
        let l = (layout || "").trim().toLowerCase();
        if (l === "scroller" || l === "scroll") return "scrolling";
        return l;
    }

    function getLayoutIcon(layout: string): string {
        let l = normalizeLayoutName(layout);
        if (l === "dwindle") return "⊞";
        if (l === "master") return "◫";
        if (l === "scrolling") return "↔";
        if (l === "monocle") return "󰊓";
        return "";
    }

    function getLayoutLabel(layout: string): string {
        let l = normalizeLayoutName(layout);
        if (l === "dwindle") return "dwindle";
        if (l === "master") return "master";
        if (l === "scrolling") return "scroll";
        if (l === "monocle") return "monocle";
        return l !== "" ? l : "layout";
    }

    /*
    ask hyprctl what the workspace is actually doing instead of trusting
    our own optimistic state
    */
    Process {
        id: queryProc
        command: ["hyprctl", "-j", "activeworkspace"]
        running: false
        stdout: StdioCollector {
            id: collector
            onStreamFinished: {
                try {
                    let obj = JSON.parse(collector.text);
                    if (obj) {
                        if (obj.windows !== undefined) {
                            root.numWindows = obj.windows;
                        }
                        if (obj.tiledLayout) {
                            root.currentLayout = root.normalizeLayoutName(obj.tiledLayout);
                        }
                    }
                } catch (e) {}
            }
        }
    }

    Timer {
        id: debounceTimer
        interval: 60
        repeat: false
        onTriggered: {
            if (!queryProc.running) queryProc.running = true;
        }
    }

    function refreshLayout() {
        debounceTimer.restart();
    }

    Component.onCompleted: refreshLayout()

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            let n = event?.name ?? "";
            if (n === "workspace" ||
                n === "workspacev2" ||
                n === "focusedmon" ||
                n === "focusedmonv2" ||
                n === "fullscreen" ||
                n === "openwindow" ||
                n === "closewindow" ||
                n === "configreloaded") {
                root.refreshLayout();
            }
        }
    }

    Timer {
        interval: 3500
        running: true
        repeat: true
        onTriggered: root.refreshLayout()
    }

    /*
    shove the new layout into both general.layout and the active workspace rule
    so per-workspace rules don't silently ignore us
    */
    Process {
        id: setProc
        running: false
        stdout: StdioCollector {
            id: setOut
            onStreamFinished: {
                let out = (setOut.text || "").toLowerCase();
                if (out.includes("error") || out.includes("unknown") || out.includes("invalid")) {
                    legacyProc.command = ["hyprctl", "keyword", "general:layout", root.currentLayout];
                    legacyProc.running = true;
                } else {
                    root.refreshLayout();
                }
            }
        }
    }

    Process {
        id: legacyProc
        running: false
        onExited: root.refreshLayout()
    }

    function applyLayout(layoutName: string) {
        let target = normalizeLayoutName(layoutName);
        if (!target) return;

        root.currentLayout = target;

        if (setProc.running) setProc.running = false;
        if (legacyProc.running) legacyProc.running = false;

        let safeTarget = target.replace(/[^a-z0-9_:-]/gi, "");
        if (!safeTarget) return;

        if (Hyprland?.usingLua ?? true) {
            let luaCode = `
                hl.config({ general = { layout = "${safeTarget}" } })
                local ws = hl.get_active_special_workspace() or hl.get_active_workspace()
                if ws then
                    local sel = ws.special and tostring(ws.name) or (ws.id > 0 and tostring(ws.id) or ("name:" .. tostring(ws.name)))
                    hl.workspace_rule({ workspace = sel, layout = "${safeTarget}" })
                end
            `.trim().replace(/\s+/g, " ");
            setProc.command = ["hyprctl", "eval", luaCode];
            setProc.running = true;
        } else {
            legacyProc.command = ["hyprctl", "keyword", "general:layout", safeTarget];
            legacyProc.running = true;
        }
    }

    function addCustomLayout(layoutName: string) {
        let clean = normalizeLayoutName(layoutName);
        if (!clean) return;
        if (!availableLayouts.includes(clean)) {
            availableLayouts = [...availableLayouts, clean];
        }
        applyLayout(clean);
    }

    function cycleNextLayout() {
        let idx = availableLayouts.indexOf(root.currentLayout);
        if (idx === -1) idx = 0;
        let nextIdx = (idx + 1) % availableLayouts.length;
        applyLayout(availableLayouts[nextIdx]);
    }

    function cyclePrevLayout() {
        let idx = availableLayouts.indexOf(root.currentLayout);
        if (idx === -1) idx = 0;
        let prevIdx = (idx - 1 + availableLayouts.length) % availableLayouts.length;
        applyLayout(availableLayouts[prevIdx]);
    }

    function updatePosition() {
        let pt = root.mapToItem(null, 0, 0);
        let barFloats = Settings?.barFloating ?? false;
        let barMarg = barFloats ? ((Settings?.barMargin > 0) ? Settings.barMargin : 8) : 0;
        if (pt && pt.x !== undefined && root.visible) {
            popup.targetRelativeX = pt.x + (root.width / 2) + barMarg;
            popup.targetRelativeY = pt.y + (root.height / 2);
        } else {
            popup.targetRelativeX = 0;
            popup.targetRelativeY = 0;
        }
    }

    Row {
        id: pillRow
        visible: !(Theme?.isVertical ?? false)
        anchors.centerIn: parent
        spacing: 6

        Text {
            id: iconText
            anchors.verticalCenter: parent.verticalCenter
            text: root.getLayoutIcon(root.currentLayout)
            font.family: Theme?.fontMono ?? "monospace"
            font.pixelSize: Theme?.fontSizeMd ?? 13
            font.weight: Theme?.fontWeightBold ?? Font.Bold
            color: popup.open ? Theme.primary : Theme.on_surface
        }

        Text {
            id: labelText
            anchors.verticalCenter: parent.verticalCenter
            text: root.getLayoutLabel(root.currentLayout)
            font.family: Theme?.fontFamily ?? "sans-serif"
            font.pixelSize: Theme?.fontSizeXs ?? 10
            font.weight: Theme?.fontWeightMedium ?? Font.Medium
            color: popup.open ? Theme.primary : Theme.on_surface_variant
        }

        Text {
            id: countText
            visible: root.numWindows > 0
            anchors.verticalCenter: parent.verticalCenter
            text: root.numWindows.toString()
            font.family: Theme?.fontMono ?? "monospace"
            font.pixelSize: Theme?.fontSizeXs ?? 9
            font.weight: Theme?.fontWeightDemiBold ?? Font.DemiBold
            color: Theme?.primary ?? "#00ffff"
            opacity: 0.85
        }
    }

    Column {
        id: pillCol
        visible: Theme?.isVertical ?? false
        anchors.centerIn: parent
        spacing: 2

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.getLayoutIcon(root.currentLayout)
            font.family: Theme?.fontMono ?? "monospace"
            font.pixelSize: Theme?.fontSizeSm ?? 12
            font.weight: Theme?.fontWeightBold ?? Font.Bold
            color: popup.open ? Theme.primary : Theme.on_surface
        }

        Text {
            visible: root.numWindows > 0
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.numWindows.toString()
            font.family: Theme?.fontMono ?? "monospace"
            font.pixelSize: Theme?.fontSizeXs ?? 9
            font.weight: Theme?.fontWeightDemiBold ?? Font.DemiBold
            color: Theme?.primary ?? "#00ffff"
        }
    }

    HoverFlyoutHandler {
        popup: popup
        mouseArea: lMouse
        updatePos: () => root.updatePosition()
    }

    MouseArea {
        id: lMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor

        onWheel: (wheel) => {
            if (wheel.angleDelta.y > 0) {
                root.cyclePrevLayout();
            } else if (wheel.angleDelta.y < 0) {
                root.cycleNextLayout();
            }
        }

        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                root.cycleNextLayout();
            } else if (mouse.button === Qt.RightButton || mouse.button === Qt.MiddleButton) {
                root.updatePosition();
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
    }

    Connections {
        target: Settings
        function onRequestLayoutSwitcherToggle() {
            root.updatePosition();
            popup.open = !popup.open;
        }
        function onRequestLayoutSwitcherOpen() {
            root.updatePosition();
            popup.open = true;
        }
        function onRequestLayoutSwitcherClose() {
            popup.open = false;
        }
    }

    PopupPanel {
        id: popup
        panelWidth: 360
        panelHeight: 460
        screen: root.barScreen

        onOpenChanged: {
            if (open) root.refreshLayout();
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme?.popupPadding ?? 14
            spacing: Theme?.popupSpacing ?? 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    width: 32
                    height: 32
                    radius: Theme?.radiusSm ?? 8
                    color: Theme?.primary_overlay ?? "#33ffffff"

                    Text {
                        anchors.centerIn: parent
                        text: root.getLayoutIcon(root.currentLayout)
                        font.family: Theme?.fontMono ?? "monospace"
                        font.pixelSize: Theme?.fontSizeLg ?? 15
                        font.weight: Theme?.fontWeightBold ?? Font.Bold
                        color: Theme.primary
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: "window tiling layouts"
                        font.family: Theme?.fontFamily ?? "sans-serif"
                        font.pixelSize: Theme?.fontSizeSm ?? 12
                        font.weight: Theme?.fontWeightBold ?? Font.Bold
                        color: Theme.on_surface
                    }

                    Text {
                        text: "switch tiling engine or eval custom lua layout"
                        font.family: Theme?.fontFamily ?? "sans-serif"
                        font.pixelSize: Theme?.fontSizeXs ?? 10
                        color: Theme.on_surface_variant
                    }
                }

                Rectangle {
                    width: 26
                    height: 26
                    radius: Theme?.radiusPill ?? 999
                    color: closeMouse.containsMouse ? (Theme?.pillHover ?? "#33ffffff") : "transparent"

                    Behavior on color { ColorAnimation { duration: Theme?.animFast ?? 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: Theme?.iconClose ?? "✕"
                        font.family: Theme?.fontIcon ?? "sans-serif"
                        font.pixelSize: Theme?.fontSizeSm ?? 11
                        color: Theme.on_surface_variant
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: popup.open = false
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: Theme?.popupDividerHeight ?? 1
                color: Theme?.cardBorder ?? Qt.rgba(1, 1, 1, 0.08)
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                ColumnLayout {
                    width: ScrollView.view ? ScrollView.view.availableWidth : parent.width
                    spacing: Theme?.popupCardGap ?? 8

                    Repeater {
                        model: root.layoutDefinitions

                        delegate: Rectangle {
                            id: layoutCard
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: cardCol.implicitHeight + 16
                            radius: Theme?.radiusSm ?? 8

                            readonly property bool isCurrent: root.currentLayout === modelData.id
                            color: isCurrent
                                ? (Theme?.primary_overlay ?? "#33ffffff")
                                : (cardMouse.pressed
                                    ? Theme.statePress(Theme.cardBg, Theme.on_surface)
                                    : (cardMouse.containsMouse ? (Theme?.pillHover ?? "#22ffffff") : (Theme?.cardBg ?? "#11ffffff")))
                            border.color: isCurrent ? Theme.primary : (Theme?.cardBorder ?? Qt.rgba(1, 1, 1, 0.06))
                            border.width: isCurrent ? 1.5 : 1

                            Behavior on color { ColorAnimation { duration: Theme?.animFast ?? 120; easing.type: Theme?.animColorEasing ?? Easing.OutQuad } }
                            Behavior on border.color { ColorAnimation { duration: Theme?.animFast ?? 120; easing.type: Theme?.animColorEasing ?? Easing.OutQuad } }

                            ColumnLayout {
                                id: cardCol
                                anchors.fill: parent
                                anchors.margins: Theme?.popupCardPadding ?? 10
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: layoutCard.modelData.icon
                                        font.family: Theme?.fontMono ?? "monospace"
                                        font.pixelSize: Theme?.fontSizeLg ?? 15
                                        font.weight: Theme?.fontWeightBold ?? Font.Bold
                                        color: layoutCard.isCurrent ? Theme.primary : Theme.on_surface
                                    }

                                    Text {
                                        text: layoutCard.modelData.title
                                        font.family: Theme?.fontFamily ?? "sans-serif"
                                        font.pixelSize: Theme?.fontSizeSm ?? 12
                                        font.weight: Theme?.fontWeightDemiBold ?? Font.DemiBold
                                        color: layoutCard.isCurrent ? Theme.primary : Theme.on_surface
                                    }

                                    Rectangle {
                                        implicitWidth: badgeText.implicitWidth + 10
                                        height: 18
                                        radius: Theme?.radiusPill ?? 999
                                        color: layoutCard.isCurrent
                                            ? (Theme?.alpha ? Theme.alpha(Theme.primary, 0.2) : Qt.rgba(0, 1, 1, 0.2))
                                            : (Theme?.pillBg ?? "#22ffffff")

                                        Text {
                                            id: badgeText
                                            anchors.centerIn: parent
                                            text: layoutCard.modelData.badge
                                            font.family: Theme?.fontFamily ?? "sans-serif"
                                            font.pixelSize: Theme?.fontSizeXs ?? 9
                                            font.weight: Theme?.fontWeightMedium ?? Font.Medium
                                            color: layoutCard.isCurrent ? Theme.primary : Theme.on_surface_variant
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    Text {
                                        visible: layoutCard.isCurrent
                                        text: Theme?.iconCheck ?? "✓"
                                        font.family: Theme?.fontIcon ?? "sans-serif"
                                        font.pixelSize: Theme?.fontSizeSm ?? 12
                                        font.weight: Theme?.fontWeightBold ?? Font.Bold
                                        color: Theme.primary
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: layoutCard.modelData.desc
                                    font.family: Theme?.fontFamily ?? "sans-serif"
                                    font.pixelSize: Theme?.fontSizeXs ?? 10
                                    color: Theme.on_surface_variant
                                    wrapMode: Text.Wrap
                                    lineHeight: 1.15
                                }
                            }

                            MouseArea {
                                id: cardMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.applyLayout(layoutCard.modelData.id);
                                    popup.open = false;
                                }
                            }
                        }
                    }

                    // escape hatch for people running custom lua layout generators
                    Rectangle {
                        id: customCard
                        Layout.fillWidth: true
                        implicitHeight: customCol.implicitHeight + 16
                        radius: Theme?.radiusSm ?? 8

                        readonly property bool isCustomActive: !root.layoutDefinitions.some(d => d.id === root.currentLayout)
                        color: isCustomActive
                            ? (Theme?.primary_overlay ?? "#33ffffff")
                            : (Theme?.cardBg ?? "#11ffffff")
                        border.color: isCustomActive ? Theme.primary : (Theme?.cardBorder ?? Qt.rgba(1, 1, 1, 0.06))
                        border.width: isCustomActive ? 1.5 : 1

                        ColumnLayout {
                            id: customCol
                            anchors.fill: parent
                            anchors.margins: Theme?.popupCardPadding ?? 10
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: ""
                                    font.family: Theme?.fontMono ?? "monospace"
                                    font.pixelSize: Theme?.fontSizeMd ?? 13
                                    font.weight: Theme?.fontWeightBold ?? Font.Bold
                                    color: Theme.primary
                                }

                                Text {
                                    text: "custom lua layout"
                                    font.family: Theme?.fontFamily ?? "sans-serif"
                                    font.pixelSize: Theme?.fontSizeSm ?? 12
                                    font.weight: Theme?.fontWeightDemiBold ?? Font.DemiBold
                                    color: Theme.on_surface
                                }

                                Rectangle {
                                    implicitWidth: luaBadge.implicitWidth + 10
                                    height: 18
                                    radius: Theme?.radiusPill ?? 999
                                    color: customCard.isCustomActive
                                        ? (Theme?.alpha ? Theme.alpha(Theme.primary, 0.2) : Qt.rgba(0, 1, 1, 0.2))
                                        : (Theme?.pillBg ?? "#22ffffff")

                                    Text {
                                        id: luaBadge
                                        anchors.centerIn: parent
                                        text: "lua engine"
                                        font.family: Theme?.fontFamily ?? "sans-serif"
                                        font.pixelSize: Theme?.fontSizeXs ?? 9
                                        font.weight: Theme?.fontWeightMedium ?? Font.Medium
                                        color: customCard.isCustomActive ? Theme.primary : Theme.on_surface_variant
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    visible: customCard.isCustomActive
                                    text: Theme?.iconCheck ?? "✓"
                                    font.family: Theme?.fontIcon ?? "sans-serif"
                                    font.pixelSize: Theme?.fontSizeSm ?? 12
                                    font.weight: Theme?.fontWeightBold ?? Font.Bold
                                    color: Theme.primary
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "passes a custom layout or plugin name into hyprctl eval."
                                font.family: Theme?.fontFamily ?? "sans-serif"
                                font.pixelSize: Theme?.fontSizeXs ?? 10
                                color: Theme.on_surface_variant
                                wrapMode: Text.Wrap
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 28
                                    radius: Theme?.radiusXs ?? 4
                                    color: Theme?.pillBg ?? "#22ffffff"
                                    border.color: luaInput.activeFocus ? Theme.primary : (Theme?.pillBorder ?? "transparent")
                                    border.width: 1

                                    TextInput {
                                        id: luaInput
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        verticalAlignment: TextInput.AlignVCenter
                                        font.family: Theme?.fontMono ?? "monospace"
                                        font.pixelSize: Theme?.fontSizeSm ?? 11
                                        color: Theme.on_surface
                                        clip: true
                                        text: ""

                                        function submit() {
                                            if (luaInput.text.trim() !== "") {
                                                root.addCustomLayout(luaInput.text);
                                                popup.open = false;
                                                luaInput.text = "";
                                            }
                                        }

                                        Text {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "enter custom layout name..."
                                            font.family: Theme?.fontFamily ?? "sans-serif"
                                            font.pixelSize: Theme?.fontSizeXs ?? 10
                                            color: Theme.on_surface_variant
                                            opacity: 0.6
                                            visible: luaInput.text === "" && !luaInput.activeFocus
                                        }

                                        onAccepted: submit()
                                    }
                                }

                                Rectangle {
                                    width: applyBtnText.implicitWidth + 16
                                    height: 28
                                    radius: Theme?.radiusXs ?? 4
                                    color: applyMouse.containsMouse ? (Theme?.primary_overlay ?? "#33ffffff") : (Theme?.pillBg ?? "#22ffffff")
                                    border.color: Theme.primary
                                    border.width: 1

                                    Behavior on color { ColorAnimation { duration: Theme?.animFast ?? 120 } }

                                    Text {
                                        id: applyBtnText
                                        anchors.centerIn: parent
                                        text: "apply"
                                        font.family: Theme?.fontFamily ?? "sans-serif"
                                        font.pixelSize: Theme?.fontSizeXs ?? 10
                                        font.weight: Theme?.fontWeightBold ?? Font.Bold
                                        color: Theme.primary
                                    }

                                    MouseArea {
                                        id: applyMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: luaInput.submit()
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
