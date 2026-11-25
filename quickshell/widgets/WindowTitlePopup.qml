import QtQuick
import QtQuick.Layouts
import ".."
import "../controls"
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland

PopupPanel {
    id: root

    wantsFocus: true
    cardWidth: 410
    cardHeight: Math.max(Theme.popupMinHeight, Math.min(Theme.popupMaxHeight ?? 600, winContentLayout.implicitHeight + (Theme.popupPadding * 2)))
    property alias contentWidth: root.cardWidth
    property alias contentHeight: root.cardHeight
    property string filterQuery: ""

    readonly property var activeTop: Hyprland.activeToplevel
    readonly property string winTitle: (activeTop?.title ?? activeTop?.wayland?.title ?? "").trim()
    readonly property string winClass: {
        if (!activeTop) return "";
        let ipc = activeTop.lastIpcObject;
        let c = ipc ? (ipc["class"] || ipc.initialClass || "") : "";
        if (!c && activeTop.wayland) c = activeTop.wayland.appId;
        if (!c && activeTop.handle) c = activeTop.handle.appId;
        return (c || "").trim();
    }

    readonly property bool isWindowFloating: Boolean(activeTop?.lastIpcObject?.floating ?? false)
    readonly property bool isFullscreen: Boolean(activeTop?.wayland?.fullscreen ?? activeTop?.lastIpcObject?.fullscreen ?? false)
    readonly property bool isPinned: Boolean(activeTop?.lastIpcObject?.pinned ?? false)
    readonly property int activeWinWsId: activeTop?.workspace?.id ?? activeTop?.lastIpcObject?.workspace?.id ?? -1

    readonly property var allToplevels: Hyprland.toplevels?.values ?? []
    readonly property var filteredToplevels: {
        let list = [];
        let q = root.filterQuery.trim().toLowerCase();
        for (let i = 0; i < allToplevels.length; i++) {
            let t = allToplevels[i];
            if (!t) continue;
            let ttl = (t.title ?? t.wayland?.title ?? "").toLowerCase();
            let cls = (t.lastIpcObject?.class || t.lastIpcObject?.initialClass || t.wayland?.appId || "").toLowerCase();
            if (q === "" || ttl.includes(q) || cls.includes(q)) {
                list.push(t);
            }
        }
        return list;
    }

    function normalizeAddr(w) {
        let addr = w?.address || w?.lastIpcObject?.address || "";
        if (!addr) return "";
        return addr.startsWith("0x") ? addr : ("0x" + addr);
    }

    function focusWindow(w) {
        if (!w) return;
        let addr = normalizeAddr(w);
        if (Hyprland?.usingLua && addr) {
            Hyprland.dispatch(`hl.dsp.focus({ window = "${addr}" })`);
        } else if (addr) {
            Hyprland.dispatch("focuswindow address:" + addr);
        } else if (w.activate) {
            w.activate();
        }
        root.pinned = false;
        root.open = false;
    }

    function closeToplevel(w) {
        if (!w) return;
        if (w.wayland && typeof w.wayland.close === "function") {
            w.wayland.close();
            Hyprland.refreshToplevels();
            return;
        }
        let addr = normalizeAddr(w);
        if (!addr) return;
        if (Hyprland?.usingLua) {
            Hyprland.dispatch(`hl.dsp.focus({ window = "${addr}" })`);
            Hyprland.dispatch("hl.dsp.window.close()");
        } else {
            Hyprland.dispatch("closewindow address:" + addr);
        }
        Hyprland.refreshToplevels();
    }

    function moveActiveToWorkspace(wsId: int, follow: bool) {
        if (!root.activeTop) return;
        if (Hyprland?.usingLua) {
            Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${wsId}, follow = ${follow ? "true" : "false"} })`);
        } else {
            Hyprland.dispatch((follow ? "movetoworkspace " : "movetoworkspacesilent ") + wsId);
        }
        Hyprland.refreshToplevels();
    }

    /*
    hyprland 0.55+ switched to lua so sending legacy strings when usingLua is true
    just gets eaten by the void. also hl.dsp.window.kill() murders the whole pid
    tree, so we use close() unless we want all 40 browser tabs to evaporate
    */
    function dispatchWindowAction(action: string) {
        let lua = Boolean(Hyprland?.usingLua);
        if (action === "float") {
            if (lua) Hyprland.dispatch("hl.dsp.window.float({ action = 'toggle' })");
            else if (Settings?.dispatchToggleFloat) Settings.dispatchToggleFloat();
            else Hyprland.dispatch("togglefloating");
        } else if (action === "fullscreen") {
            if (lua) Hyprland.dispatch("hl.dsp.window.fullscreen()");
            else if (Settings?.dispatchToggleFullscreen) Settings.dispatchToggleFullscreen();
            else Hyprland.dispatch("fullscreen 0");
        } else if (action === "pin") {
            if (lua) Hyprland.dispatch("hl.dsp.window.pin()");
            else if (Settings?.dispatchPinWindow) Settings.dispatchPinWindow();
            else Hyprland.dispatch("pin");
        } else if (action === "close") {
            if (lua) Hyprland.dispatch("hl.dsp.window.close()");
            else if (Settings?.dispatchCloseWindow) Settings.dispatchCloseWindow();
            else Hyprland.dispatch("killactive");
        }
        Hyprland.refreshToplevels();
    }

    onOpenChanged: {
        if (open) {
            root.filterQuery = "";
            winSearchInput.text = "";
            Hyprland.refreshToplevels();
        }
    }

    // force quickshell to actually update lastIpcObject when window state mutates
    Connections {
        target: Hyprland
        enabled: root.open
        function onRawEvent(event) {
            let n = event?.name ?? "";
            if (n === "changefloatingmode" || n === "fullscreen" || n === "pin" || n === "activewindow" || n === "windowtitlev2") {
                Hyprland.refreshToplevels();
            }
        }
    }

    content: ColumnLayout {
        id: winContentLayout
        anchors.fill: parent
        spacing: Theme.popupSpacing

        // top bar with the app icon and whatever identity crisis the window is having
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.popupSpacing

            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: Theme.radiusSm
                color: Theme.cardBg
                border.color: Theme.cardBorder
                border.width: 1

                IconImage {
                    id: popupAppIcon
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    source: Theme.resolveAppIcon ? Theme.resolveAppIcon(root.winClass) : ""
                    visible: source !== "" && status !== Image.Error
                }

                Text {
                    anchors.centerIn: parent
                    text: root.activeTop ? (Theme.iconTerminal ?? "") : (Theme.iconDistro ?? Theme.iconArch ?? "desktop")
                    font.family: Theme.fontIcon
                    font.variableAxes: Theme.iconAxes
                    font.pixelSize: Theme.fontSizeMd
                    color: Theme.primary
                    visible: !popupAppIcon.visible
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: (root.winClass.length > 0 ? root.winClass : "desktop").toLowerCase()
                    font.family: Theme.fontFamily
                    font.variableAxes: Theme.sansAxes
                    font.pixelSize: Theme.fontSizeMd
                    font.weight: Theme.fontWeightBold
                    color: Theme.on_surface
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: root.activeTop
                        ? (root.isPinned ? "pinned & floating" : "focused window")
                        : Theme.getVibe(Theme.kaoEmpty, "no active window", "no active window")
                    font.family: Theme.fontFamily
                    font.variableAxes: Theme.sansAxes
                    font.weight: Theme.fontWeightRegular
                    font.pixelSize: Theme.fontSizeXs
                    color: Theme.on_surface_variant
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                visible: root.activeTop !== null
                height: 22
                implicitWidth: statusText.implicitWidth + 14
                radius: Theme.radiusPill
                color: root.isWindowFloating ? Theme.secondary_container : Theme.pillBg
                border.color: root.isWindowFloating ? "transparent" : Theme.pillBorder
                border.width: root.isWindowFloating ? 0 : 1

                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                Text {
                    id: statusText
                    anchors.centerIn: parent
                    text: root.isPinned ? "pinned" : (root.isWindowFloating ? "floating" : "tiled")
                    font.family: Theme.fontFamily
                    font.variableAxes: Theme.sansAxes
                    font.pixelSize: Theme.fontSizeXs
                    font.weight: Theme.fontWeightMedium
                    color: root.isWindowFloating ? Theme.on_secondary_container : Theme.on_surface_variant
                }
            }
        }

        // box holding the actual title or an existential crisis quote if staring at wallpaper
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Math.max(66, titleCol.implicitHeight + (Theme.popupCardPadding * 2) + 4)
            radius: Theme.radiusMd
            color: Theme.cardBg
            border.color: Theme.cardBorder
            border.width: 1

            ColumnLayout {
                id: titleCol
                anchors.fill: parent
                anchors.margins: Theme.popupCardPadding + 2
                spacing: 4

                Text {
                    text: root.activeTop ? "window title" : "status"
                    font.family: Theme.fontFamily
                    font.variableAxes: Theme.sansAxes
                    font.weight: Theme.fontWeightRegular
                    font.pixelSize: Theme.fontSizeXs
                    color: Theme.on_surface_variant
                }

                Text {
                    Layout.fillWidth: true
                    text: (root.winTitle.length > 0
                        ? root.winTitle
                        : Theme.getFlavor("system", "no window focused")).toLowerCase()
                    font.family: Theme.fontFamily
                    font.variableAxes: Theme.sansAxes
                    font.pixelSize: Theme.fontSizeSm
                    font.weight: Theme.fontWeightMedium
                    color: root.activeTop ? Theme.on_surface : Theme.on_surface_variant
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }
        }

        // four buttons to bully the active window into submission
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.popupCardGap

            Repeater {
                model: [
                    {
                        key: "float",
                        label: "float",
                        icon: Theme.iconCrop,
                        active: root.isWindowFloating,
                        danger: false,
                        enabled: root.activeTop !== null
                    },
                    {
                        key: "fullscreen",
                        label: "fullscreen",
                        icon: Theme.iconExpand,
                        active: root.isFullscreen,
                        danger: false,
                        enabled: root.activeTop !== null
                    },
                    {
                        key: "pin",
                        label: "pin",
                        icon: Theme.iconHeart,
                        active: root.isPinned,
                        danger: false,
                        // hyprland silently ignores pinning tiled windows anyway
                        enabled: root.activeTop !== null && root.isWindowFloating
                    },
                    {
                        key: "close",
                        label: "kill",
                        icon: Theme.iconClose,
                        active: false,
                        danger: true,
                        enabled: root.activeTop !== null
                    }
                ]

                delegate: Rectangle {
                    id: actionBtn
                    required property var modelData

                    Layout.fillWidth: true
                    height: Theme.popupActionHeight + 4
                    radius: Theme.radiusSm
                    opacity: modelData.enabled ? 1.0 : 0.42

                    readonly property color baseBg: {
                        if (modelData.danger) return Theme.error_container;
                        if (modelData.active) return Theme.primary;
                        return Theme.pillBg;
                    }
                    readonly property color fgColor: {
                        if (modelData.danger) return Theme.on_error_container;
                        if (modelData.active) return Theme.on_primary;
                        return Theme.on_surface;
                    }

                    color: {
                        if (!modelData.enabled) return baseBg;
                        if (btnMouse.pressed) return Theme.statePress(baseBg, fgColor);
                        if (btnMouse.containsMouse) return ( !modelData.danger && !modelData.active ) ? Theme.pillHover : Theme.stateHover(baseBg, fgColor);
                        return baseBg;
                    }

                    border.color: (modelData.danger || modelData.active) ? "transparent" : Theme.pillBorder
                    border.width: (modelData.danger || modelData.active || border.color === "transparent") ? 0 : 1

                    scale: (btnMouse.pressed && modelData.enabled) ? 0.96 : 1.0

                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
                    Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
                    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            visible: !Theme.isTextIconSet
                            text: actionBtn.modelData.icon
                            font.family: Theme.fontIcon
                            font.variableAxes: Theme.iconAxes
                            font.pixelSize: Theme.fontSizeSm
                            color: actionBtn.fgColor
                        }

                        Text {
                            text: actionBtn.modelData.label
                            font.family: Theme.fontFamily
                            font.variableAxes: Theme.sansAxes
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: actionBtn.modelData.danger ? Theme.fontWeightBold : Theme.fontWeightMedium
                            color: actionBtn.fgColor
                        }
                    }

                    MouseArea {
                        id: btnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: actionBtn.modelData.enabled
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                        onClicked: {
                            root.dispatchWindowAction(actionBtn.modelData.key);
                            if (actionBtn.modelData.key === "close") {
                                root.open = false;
                            }
                        }
                    }
                }
            }
        }

        // quick workspace mover (left-click: send silently, right-click: send & follow)
        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            visible: root.activeTop !== null

            Text {
                text: "ws:"
                font.family: Theme.fontMono
                font.variableAxes: Theme.monoAxes
                font.pixelSize: 10
                font.weight: Theme.monoWeightBold
                color: Theme.on_surface_variant
            }

            Repeater {
                model: [1, 2, 3, 4, 5, 6, 7, 8, 9]

                delegate: Rectangle {
                    required property int modelData
                    readonly property bool isCurWs: root.activeWinWsId === modelData
                    Layout.fillWidth: true
                    height: 24
                    radius: Theme.radiusSm
                    color: isCurWs
                        ? Theme.primary
                        : (wsMoveMouse.containsMouse ? Theme.primary_overlay : Theme.pillBg)
                    border.color: isCurWs ? Theme.primary : Theme.pillBorder
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        font.family: Theme.fontMono
                        font.variableAxes: Theme.monoAxes
                        font.pixelSize: 10
                        font.weight: isCurWs ? Theme.monoWeightBold : Theme.monoWeightMedium
                        color: isCurWs ? Theme.on_primary : Theme.on_surface
                    }

                    MouseArea {
                        id: wsMoveMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: (mouse) => root.moveActiveToWorkspace(modelData, mouse.button === Qt.RightButton)
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.cardBorder
        }

        // open windows switcher & killer
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: "open windows (" + root.filteredToplevels.length + ")"
                font.family: Theme.fontFamily
                font.variableAxes: Theme.sansAxes
                font.pixelSize: Theme.fontSizeXs
                font.weight: Theme.fontWeightBold
                color: Theme.primary
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "mid-click: close"
                font.family: Theme.fontMono
                font.variableAxes: Theme.monoAxes
                font.weight: Theme.monoWeightRegular
                font.pixelSize: 9
                color: Theme.on_surface_variant
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 30
            radius: Theme.radiusSm
            color: Theme.surface_container_highest
            border.color: winSearchInput.activeFocus ? Theme.primary : Theme.widgetBorder
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 6

                Text {
                    text: Theme.iconSearch
                    font.family: Theme.fontIcon
                    font.variableAxes: Theme.iconAxes
                    font.pixelSize: Theme.fontSizeXs
                    color: winSearchInput.activeFocus ? Theme.primary : Theme.on_surface_variant
                }

                TextInput {
                    id: winSearchInput
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Theme.fontFamily
                    font.variableAxes: Theme.sansAxes
                    font.weight: Theme.fontWeightRegular
                    font.pixelSize: Theme.fontSizeXs
                    color: Theme.on_surface
                    selectByMouse: true
                    onTextChanged: root.filterQuery = text

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: "filter open windows..."
                        font: parent.font
                        color: Theme.on_surface_disabled
                        visible: parent.text.length === 0
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (root.filteredToplevels.length > 0) {
                                root.focusWindow(root.filteredToplevels[0]);
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Escape) {
                            root.open = false;
                            event.accepted = true;
                        }
                    }
                }
            }
        }

        Flickable {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(180, Math.max(38, winListCol.implicitHeight))
            contentWidth: width
            contentHeight: winListCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: winListCol
                width: parent.width
                spacing: 4

                Text {
                    visible: root.filteredToplevels.length === 0
                    text: "no matching windows"
                    font.family: Theme.fontFamily
                    font.variableAxes: Theme.sansAxes
                    font.weight: Theme.fontWeightRegular
                    font.pixelSize: Theme.fontSizeXs
                    color: Theme.on_surface_variant
                    Layout.alignment: Qt.AlignHCenter
                }

                Repeater {
                    model: root.filteredToplevels

                    delegate: Rectangle {
                        id: wRow
                        required property var modelData
                        readonly property string wClass: (modelData?.lastIpcObject?.class || modelData?.lastIpcObject?.initialClass || modelData?.wayland?.appId || "").trim()
                        readonly property string wTitle: (modelData?.title ?? modelData?.wayland?.title ?? wClass ?? "window").trim()
                        readonly property int wWs: modelData?.workspace?.id ?? modelData?.lastIpcObject?.workspace?.id ?? 0
                        readonly property bool isFocused: modelData === root.activeTop

                        Layout.fillWidth: true
                        height: 34
                        radius: Theme.radiusSm
                        color: isFocused
                            ? Theme.primary_overlay
                            : (rowMouse.containsMouse ? Theme.pillHover : Theme.cardBg)
                        border.color: isFocused ? Theme.primary : Theme.cardBorder
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.MiddleButton) {
                                    root.closeToplevel(wRow.modelData);
                                } else {
                                    root.focusWindow(wRow.modelData);
                                }
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 6
                            spacing: 8

                            IconImage {
                                id: rIcon
                                width: 16
                                height: 16
                                source: Theme.resolveAppIcon ? Theme.resolveAppIcon(wRow.wClass) : ""
                                visible: source !== "" && status !== Image.Error
                            }

                            Text {
                                visible: !rIcon.visible
                                text: Theme.iconTerminal
                                font.family: Theme.fontIcon
                                font.variableAxes: Theme.iconAxes
                                font.pixelSize: 13
                                color: Theme.primary
                            }

                            Text {
                                text: wRow.wTitle.toLowerCase()
                                font.family: Theme.fontFamily
                                font.variableAxes: Theme.sansAxes
                                font.pixelSize: Theme.fontSizeXs
                                font.weight: wRow.isFocused ? Theme.fontWeightBold : Theme.fontWeightRegular
                                color: wRow.isFocused ? Theme.primary : Theme.on_surface
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                visible: wRow.wWs > 0
                                height: 18
                                implicitWidth: wsBadgeTxt.implicitWidth + 8
                                radius: Theme.radiusPill
                                color: Theme.surface_container_highest

                                Text {
                                    id: wsBadgeTxt
                                    anchors.centerIn: parent
                                    text: "ws " + wRow.wWs
                                    font.family: Theme.fontMono
                                    font.variableAxes: Theme.monoAxes
                                    font.weight: Theme.monoWeightRegular
                                    font.pixelSize: 9
                                    color: Theme.on_surface_variant
                                }
                            }

                            Rectangle {
                                width: 20
                                height: 20
                                radius: Theme.radiusSm
                                color: closeWinMouse.containsMouse ? Theme.error_overlay : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: Theme.iconClose
                                    font.family: Theme.fontIcon
                                    font.variableAxes: Theme.iconAxes
                                    font.pixelSize: 11
                                    color: closeWinMouse.containsMouse ? Theme.error : Theme.on_surface_variant
                                }

                                MouseArea {
                                    id: closeWinMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.closeToplevel(wRow.modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
