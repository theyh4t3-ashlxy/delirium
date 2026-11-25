import QtQuick
import QtQuick.Layouts
import ".."
import "../controls"
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

BarPill {
    id: root

    active: popup.open
    hovered: pwrMouse.containsMouse
    pressed: pwrMouse.pressed
    activeBg: Theme.error_overlay
    activeBorder: Theme.error
    implicitWidth: (Theme?.isVertical ?? false) ? pillSize : (pwrRow.implicitWidth + 24)

    Row {
        id: pwrRow
        anchors.centerIn: parent
        spacing: 4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Theme.iconPower ?? "\uF8C7"
            font.family: Theme.fontIcon
            font.variableAxes: Theme.iconAxes
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
        wantsFocus: true
        screen: root.barScreen
        cardWidth: 420
        cardHeight: Math.max(Theme.popupMinHeight, Math.min(Theme.popupMaxHeight, powerContentLayout.implicitHeight + (Theme.popupPadding * 2)))

        property string pendingAction: ""
        property int confirmCountdown: 0
        property int selectedIndex: -1

        readonly property var actionModel: [
            { key: "lock",      label: "lock",      sub: "", icon: Theme.iconLock ?? "\uE899",      span: 2, confirm: false, role: "primary" },
            { key: "suspend",   label: "sleep",     sub: "", icon: Theme.iconSuspend ?? "\uF159",   span: 2, confirm: false, role: "primary" },
            { key: "hibernate", label: "hibernate", sub: "", icon: Theme.iconHibernate ?? "\uE046", span: 2, confirm: true,  role: "warn" },
            { key: "logout",    label: "log out",   sub: "", icon: Theme.iconLogout ?? "\uE9BA",    span: 3, confirm: true,  role: "warn" },
            { key: "reboot",    label: "restart",   sub: "", icon: Theme.iconReboot ?? "\uF053",    span: 3, confirm: true,  role: "warn" },
            { key: "poweroff",  label: "shut down", sub: Theme.getVibe(Theme.kaoSleepy + " goodnight", "power off machine", "power off machine"), icon: Theme.iconPower ?? "\uF8C7", span: 6, confirm: true, role: "error" }
        ]

        onOpenChanged: {
            if (!open) {
                confirmTimer.stop();
                pendingAction = "";
                confirmCountdown = 0;
                selectedIndex = -1;
            } else {
                powerKeyItem.forceActiveFocus();
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

            Item {
                id: powerKeyItem
                focus: popup.open
                width: 0
                height: 0

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        if (popup.pendingAction !== "") {
                            confirmTimer.stop();
                            popup.pendingAction = "";
                            popup.confirmCountdown = 0;
                        } else {
                            popup.open = false;
                        }
                        event.accepted = true;
                        return;
                    }
                    let count = popup.actionModel.length;
                    if (event.key === Qt.Key_Right || event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                        popup.selectedIndex = (popup.selectedIndex + 1) % count;
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
                        popup.selectedIndex = (popup.selectedIndex - 1 + count) % count;
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                        if (popup.selectedIndex >= 0 && popup.selectedIndex < count) {
                            let item = popup.actionModel[popup.selectedIndex];
                            popup.triggerAction(item.key, item.confirm);
                            event.accepted = true;
                        }
                    } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_6) {
                        let idx = event.key - Qt.Key_1;
                        popup.selectedIndex = idx;
                        let item = popup.actionModel[idx];
                        popup.triggerAction(item.key, item.confirm);
                        event.accepted = true;
                    }
                }
            }

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
                        text: Theme.iconPower ?? "\uF8C7"
                        font.family: Theme.fontIcon
                        font.variableAxes: Theme.iconAxes
                        font.pixelSize: Theme.fontSizeMd
                        color: Theme.error
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "session & power"
                        font.family: Theme.fontDisplay
                        font.variableAxes: Theme.displayAxes
                        font.pixelSize: Theme.fontSizeMd
                        font.weight: Theme.fontWeightBold
                        color: Theme.on_surface
                    }

                    Text {
                        Layout.fillWidth: true
                        text: Theme.getFlavor(
                            "system",
                            Theme.getVibe(Theme.kaoChaos + " choose your destiny", "keys 1-6 or arrows • enter to confirm", "keys 1-6 or arrows • enter to confirm")
                        )
                        font.family: Theme.fontFamily
                        font.variableAxes: Theme.sansAxes
                        font.weight: Theme.fontWeightRegular
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

            GridLayout {
                Layout.fillWidth: true
                columns: 6
                rowSpacing: Theme.popupCardGap + 2
                columnSpacing: Theme.popupCardGap + 2

                Repeater {
                    model: popup.actionModel

                    delegate: Rectangle {
                        id: actionCard
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        Layout.columnSpan: modelData.span
                        Layout.preferredWidth: modelData.span
                        implicitHeight: modelData.span === 6 ? 62 : 66
                        radius: Theme.radiusMd

                        readonly property bool isConfirming: popup.pendingAction === modelData.key
                        readonly property bool isKeyFocus: popup.selectedIndex === index
                        readonly property bool isError: modelData.role === "error"
                        readonly property bool isWarn: modelData.role === "warn"

                        readonly property color accentColor: isError ? Theme.error : (isWarn ? Theme.warn : Theme.primary)
                        readonly property color confirmBg: isError ? Theme.error_container : Theme.warn_container
                        readonly property color confirmFg: isError ? Theme.on_error_container : Theme.on_warn_container

                        readonly property color baseBg: {
                            if (isConfirming) return confirmBg;
                            if (cardMouse.containsMouse || isKeyFocus) return isError ? Theme.error_overlay : Theme.pillHover;
                            return Theme.cardBg;
                        }

                        color: cardMouse.pressed ? Theme.statePress(baseBg, accentColor) : baseBg
                        border.color: (isConfirming || cardMouse.containsMouse || isKeyFocus) ? accentColor : Theme.cardBorder
                        border.width: (isConfirming || isKeyFocus) ? 1.5 : 1

                        scale: cardMouse.pressed ? 0.97 : 1.0

                        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
                        Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
                        Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }

                        // key number badge
                        Text {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 6
                            text: String(actionCard.index + 1)
                            font.family: Theme.fontMono
                            font.variableAxes: Theme.monoAxes
                            font.pixelSize: 9
                            color: actionCard.isConfirming ? actionCard.confirmFg : Theme.on_surface_disabled
                        }

                        ColumnLayout {
                            visible: actionCard.modelData.span < 6
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                text: actionCard.modelData.icon
                                font.family: Theme.fontIcon
                                font.variableAxes: Theme.iconAxes
                                font.pixelSize: Theme.fontSizeXl
                                color: actionCard.isConfirming ? actionCard.confirmFg : actionCard.accentColor
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: actionCard.isConfirming
                                    ? ("sure? (" + popup.confirmCountdown + "s)")
                                    : actionCard.modelData.label
                                font.family: Theme.fontFamily
                                font.variableAxes: Theme.sansAxes
                                font.pixelSize: Theme.fontSizeXs
                                font.weight: Theme.fontWeightBold
                                color: actionCard.isConfirming ? actionCard.confirmFg : Theme.on_surface
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }

                        RowLayout {
                            visible: actionCard.modelData.span >= 6
                            anchors.centerIn: parent
                            spacing: 10

                            Text {
                                text: actionCard.modelData.icon
                                font.family: Theme.fontIcon
                                font.variableAxes: Theme.iconAxes
                                font.pixelSize: Theme.fontSizeTitle
                                color: actionCard.isConfirming ? actionCard.confirmFg : actionCard.accentColor
                            }

                            ColumnLayout {
                                spacing: 2

                                Text {
                                    text: actionCard.isConfirming
                                        ? ("click or press enter to confirm (" + popup.confirmCountdown + "s)")
                                        : actionCard.modelData.label
                                    font.family: Theme.fontFamily
                                    font.variableAxes: Theme.sansAxes
                                    font.pixelSize: Theme.fontSizeSm
                                    font.weight: Theme.fontWeightBold
                                    color: actionCard.isConfirming ? actionCard.confirmFg : Theme.on_surface
                                }

                                Text {
                                    text: actionCard.modelData.sub
                                    font.family: Theme.fontFamily
                                    font.variableAxes: Theme.sansAxes
                                    font.weight: Theme.fontWeightRegular
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
                            onClicked: {
                                popup.selectedIndex = actionCard.index;
                                popup.triggerAction(actionCard.modelData.key, actionCard.modelData.confirm);
                            }
                        }
                    }
                }
            }
        }
    }
}
