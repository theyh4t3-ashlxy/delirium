import QtQuick
import ".."
import "../controls"
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

BarPill {
    id: cafRoot

    active: !IdleService.enabled
    hovered: cafMouse.containsMouse
    pressed: cafMouse.pressed
    activeBorder: Theme.alpha(Theme.primary, 0.55)
    implicitWidth: Theme.isVertical ? pillSize : cafRow.implicitWidth + 24

    function toggleInhibit() {
        IdleService.enabled = !IdleService.enabled;
    }

    Row {
        id: cafRow
        anchors.centerIn: parent
        spacing: 4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Theme.iconCoffee
            font.family: Theme.fontIcon
            font.variableAxes: Theme.iconAxes
            font.pixelSize: Theme.fontSizeMd
            color: cafRoot.active ? Theme.primary : Theme.on_surface
        }
    }

    IdlePopup {
        id: cafPopup
        screen: cafRoot.barScreen
    }

    function syncAnchor() {
        let pt = cafRoot.mapToItem(null, 0, 0);
        if (!pt) return;
        if (Theme.isVertical) {
            cafPopup.targetRelativeY = pt.y + (cafRoot.height / 2);
        } else {
            cafPopup.targetRelativeX = pt.x + (cafRoot.width / 2);
        }
    }

    HoverFlyoutHandler {
        id: idleHoverHandler
        popup: cafPopup
        mouseArea: cafMouse
        updatePos: () => cafRoot.syncAnchor()
    }

    MouseArea {
        id: cafMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                idleHoverHandler.handlePillClick();
            } else {
                cafRoot.toggleInhibit();
            }
        }
    }

    Connections {
        target: Settings
        function onRequestIdleToggle() {
            if (!cafRoot.barScreen || Quickshell.screens.length <= 1 || (cafRoot.barMonitor && Hyprland.focusedMonitor && cafRoot.barMonitor.id === Hyprland.focusedMonitor.id)) {
                cafRoot.syncAnchor();
                cafPopup.open = !cafPopup.open;
            }
        }
    }
}
