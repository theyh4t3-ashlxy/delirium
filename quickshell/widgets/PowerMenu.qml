import QtQuick
import QtQuick.Layouts
import ".."
import "../controls"
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Rectangle {
    id: root

    property var barScreen: null
    property var barMonitor: null

    implicitWidth: (Theme?.isVertical ?? false) ? ((Theme?.barHeight ?? 48) - 8) : (pwrRow.implicitWidth + 24)
    implicitHeight: (Theme?.barHeight ?? 48) - 8
    radius: Theme.radiusPill
    color: popup.open
        ? Theme.error_overlay
        : (pwrMouse.containsMouse ? Theme.pillHover : Theme.pillBg)
    border.color: popup.open ? Theme.error : Theme.pillBorder
    border.width: (popup.open || (Theme?.pillBorder ?? "transparent") !== "transparent") ? 1 : 0

    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
    Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

    Row {
        id: pwrRow
        anchors.centerIn: parent
        spacing: 4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Theme.iconPower ?? "󰐥"
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontSizeMd
            color: popup.open ? Theme.error : Theme.on_surface
        }
    }

    function syncAnchor() {
        let pos = root.mapToItem(null, 0, 0);
        if (!pos) return;
        popup.targetRelativeX = pos.x + (root.width / 2);
        popup.targetRelativeY = pos.y + (root.height / 2);
    }

    HoverFlyoutHandler {
        popup: popup
        mouseArea: pwrMouse
        updatePos: () => root.syncAnchor()
    }

    MouseArea {
        id: pwrMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.syncAnchor();
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
        function onRequestPowerMenuToggle() {
            root.syncAnchor();
            popup.open = !popup.open;
        }
        function onRequestPowerMenuOpen() {
            root.syncAnchor();
            popup.open = true;
        }
        function onRequestPowerMenuClose() {
            popup.open = false;
        }
    }

    PopupPanel {
        id: popup
        screen: root.barScreen
        cardWidth: 420
        cardHeight: Math.max(Theme.popupMinHeight, Math.min(Theme.popupMaxHeight, powerContentLayout.implicitHeight + (Theme.popupPadding * 2)))

        property string pendingAction: ""
        property int confirmCountdown: 0

        onOpenChanged: {
            // dont let confirming state haunt us next time it opens
            if (!open) {
                confirmTimer.stop();
                pendingAction = "";
                confirmCountdown = 0;
            }
        }

        Timer {
            id: confirmTimer
            interval: 1000
            repeat: true
            onTriggered: {
                if (popup.confirmCountdown > 1) {
                    popup.confirmCountdown -= 1;
                } else {
                    popup.pendingAction = "";
                    popup.confirmCountdown = 0;
                    confirmTimer.stop();
                }
            }
        }

        readonly property string sessionScriptPath: decodeURIComponent(Qt.resolvedUrl("../scripts/session.py").toString().replace(/^file:\/\//, ""))

        function executeSessionAction(actionKey: string) {
            // if session.py still calls legacy `hyprctl dispatch exit`, lua mode will ignore it
            if (actionKey === "logout" && (Hyprland?.usingLua ?? false)) {
                Hyprland.dispatch("hl.dsp.exit()");
            }
            Quickshell.execDetached(["python3", sessionScriptPath, actionKey]);
        }

        function triggerAction(actionKey: string, needsConfirm: bool) {
            if (needsConfirm) {
                if (popup.pendingAction === actionKey) {
                    confirmTimer.stop();
                    popup.pendingAction = "";
                    popup.confirmCountdown = 0;
                    popup.open = false;
                    executeSessionAction(actionKey);
                } else {
                    popup.pendingAction = actionKey;
                    popup.confirmCountdown = 3;
                    confirmTimer.restart();
                }
            } else {
                popup.open = false;
                executeSessionAction(actionKey);
            }
        }

        content: ColumnLayout {
            id: powerContentLayout
            anchors.fill: parent
            spacing: Theme.popupSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    radius: Theme.radiusSm
                    color: Theme.error_overlay
                    border.color: Theme.alpha(Theme.error, 0.35)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: Theme.iconPower ?? "󰐥"
                        font.family: Theme.fontIcon
                        font.pixelSize: Theme.fontSizeMd
                        color: Theme.error
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "session & power"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMd
                        font.weight: Theme.fontWeightBold
                        color: Theme.on_surface
                    }

                    Text {
                        Layout.fillWidth: true
                        text: Theme.getFlavor(
                            "system",
                            Theme.getVibe(Theme.kaoChaos + " choose your destiny", "manage desktop session", "manage desktop session")
                        )
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXs
                        color: Theme.on_surface_variant
                        elide: Text.ElideRight
                    }
                }

                IconButton {
                    icon: Theme.iconClose ?? "✕"
                    iconSize: Theme.fontSizeSm
                    tooltip: "close menu"
                    onClicked: popup.open = false
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: Theme.popupDividerHeight
                color: Theme.cardBorder
            }

            /*
            five ways to abandon your current workflow, driven by one repeater
            so we don't have 200 lines of copy-pasted rectangles
            */
            GridLayout {
                Layout.fillWidth: true
                columns: 3
                rowSpacing: Theme.popupCardGap + 2
                columnSpacing: Theme.popupCardGap + 2

                Repeater {
                    model: [
                        {
                            key: "lock",
                            label: "lock",
                            sub: "",
                            icon: Theme.iconLock ?? "󰌾",
                            span: 1,
                            confirm: false,
                            role: "primary"
                        },
                        {
                            key: "suspend",
                            label: "sleep",
                            sub: "",
                            icon: Theme.iconSuspend ?? "󰤄",
                            span: 1,
                            confirm: false,
                            role: "primary"
                        },
                        {
                            key: "logout",
                            label: "log out",
                            sub: "",
                            icon: Theme.iconLogout ?? "󰍃",
                            span: 1,
                            // confirm logout too so one slip of the mouse doesn't vaporize unsaved work
                            confirm: true,
                            role: "warn"
                        },
                        {
                            key: "reboot",
                            label: "restart",
                            sub: "",
                            icon: Theme.iconReboot ?? "󰑐",
                            span: 1,
                            confirm: true,
                            role: "warn"
                        },
                        {
                            key: "poweroff",
                            label: "shut down",
                            sub: Theme.getVibe(Theme.kaoSleepy + " goodnight", "power off machine", "power off machine"),
                            icon: Theme.iconPower ?? "󰐥",
                            span: 2,
                            confirm: true,
                            role: "error"
                        }
                    ]

                    delegate: Rectangle {
                        id: actionCard
                        required property var modelData

                        // keeps the 2:1 column ratio intact so countdown text doesnt reshape the grid
                        Layout.fillWidth: true
                        Layout.columnSpan: modelData.span
                        Layout.preferredWidth: modelData.span
                        implicitHeight: 68
                        radius: Theme.radiusMd

                        readonly property bool isConfirming: popup.pendingAction === modelData.key
                        readonly property bool isError: modelData.role === "error"
                        readonly property bool isWarn: modelData.role === "warn"

                        readonly property color accentColor: isError ? Theme.error : (isWarn ? Theme.warn : Theme.primary)
                        readonly property color confirmBg: isError ? Theme.error_container : Theme.warn_container
                        readonly property color confirmFg: isError ? Theme.on_error_container : Theme.on_warn_container

                        readonly property color baseBg: {
                            if (isConfirming) return confirmBg;
                            if (cardMouse.containsMouse) return isError ? Theme.error_overlay : Theme.pillHover;
                            return Theme.cardBg;
                        }

                        color: cardMouse.pressed ? Theme.statePress(baseBg, accentColor) : baseBg
                        border.color: isConfirming || cardMouse.containsMouse ? accentColor : Theme.cardBorder
                        border.width: isConfirming ? 1.5 : 1

                        scale: cardMouse.pressed ? 0.97 : 1.0

                        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
                        Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
                        Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }

                        // single-column vertical card layout (lock, sleep, logout, restart)
                        ColumnLayout {
                            visible: actionCard.modelData.span === 1
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                text: actionCard.modelData.icon
                                font.family: Theme.fontIcon
                                font.pixelSize: Theme.fontSizeTitle
                                color: actionCard.isConfirming ? actionCard.confirmFg : actionCard.accentColor
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: actionCard.isConfirming
                                    ? ("sure? (" + popup.confirmCountdown + "s)")
                                    : actionCard.modelData.label
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeXs
                                font.weight: Theme.fontWeightBold
                                color: actionCard.isConfirming ? actionCard.confirmFg : Theme.on_surface
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }

                        // wide two-column layout for shut down
                        RowLayout {
                            visible: actionCard.modelData.span > 1
                            anchors.centerIn: parent
                            spacing: 10

                            Text {
                                text: actionCard.modelData.icon
                                font.family: Theme.fontIcon
                                font.pixelSize: Theme.fontSizeTitle + 2
                                color: actionCard.isConfirming ? actionCard.confirmFg : actionCard.accentColor
                            }

                            ColumnLayout {
                                spacing: 2

                                Text {
                                    text: actionCard.isConfirming
                                        ? ("click to confirm (" + popup.confirmCountdown + "s)")
                                        : actionCard.modelData.label
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSm
                                    font.weight: Theme.fontWeightBold
                                    color: actionCard.isConfirming ? actionCard.confirmFg : Theme.on_surface
                                }

                                Text {
                                    text: actionCard.modelData.sub
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeXs
                                    color: actionCard.isConfirming ? actionCard.confirmFg : Theme.on_surface_variant
                                }
                            }
                        }

                        MouseArea {
                            id: cardMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: popup.triggerAction(actionCard.modelData.key, actionCard.modelData.confirm)
                        }
                    }
                }
            }
        }
    }
}
