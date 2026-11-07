import QtQuick
import QtQuick.Layouts
import ".."
import "../controls"
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland

PopupPanel {
    id: root

    cardWidth: 380
    cardHeight: Math.max(Theme.popupMinHeight, Math.min(Theme.popupMaxHeight, winContentLayout.implicitHeight + (Theme.popupPadding * 2)))
    property alias contentWidth: root.cardWidth
    property alias contentHeight: root.cardHeight

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
        if (open) Hyprland.refreshToplevels();
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
                    font.pixelSize: Theme.fontSizeXs
                    color: Theme.on_surface_variant
                }

                Text {
                    Layout.fillWidth: true
                    text: (root.winTitle.length > 0
                        ? root.winTitle
                        : Theme.getFlavor("system", "no window focused")).toLowerCase()
                    font.family: Theme.fontFamily
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
                            font.pixelSize: Theme.fontSizeSm
                            color: actionBtn.fgColor
                        }

                        Text {
                            text: actionBtn.modelData.label
                            font.family: Theme.fontFamily
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
    }
}
