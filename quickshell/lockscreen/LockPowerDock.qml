// LockPowerDock.qml
import QtQuick
import QtQuick.Layouts
import ".."
import Quickshell

RowLayout {
    id: dockRoot

    required property var lockRoot
    required property var surface

    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.margins: 36
    anchors.bottomMargin: (surface.entered && !lockRoot.zenMode && lockRoot.showPowerDock) ? 36 : 12
    opacity: (surface.entered && !lockRoot.zenMode && lockRoot.showPowerDock) ? 1.0 : 0.0
    visible: opacity > 0.01
    spacing: 12

    Behavior on anchors.bottomMargin { NumberAnimation { duration: Theme.expressiveDefault; easing.type: Theme.animEasingEntrance } }
    Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }

    component PowerPill: Rectangle {
        id: pRoot
        property string actionId: ""
        property string icon: ""
        property string label: ""
        property var command: []

        readonly property bool isArmed: surface.pendingPowerAction === pRoot.actionId

        height: 40
        implicitWidth: isArmed ? (pRow.implicitWidth + 28) : 40
        radius: isArmed ? lockRoot.uiRadiusMd : lockRoot.uiRadiusPill
        color: isArmed
            ? (pMouse.pressed ? Theme.statePress(Theme.error, Theme.on_error) : Theme.error)
            : (pMouse.pressed ? lockRoot.uiWidgetActive : (pMouse.containsMouse ? lockRoot.uiPillHover : lockRoot.uiPillBg))
        border.color: isArmed
            ? Theme.error
            : (pMouse.containsMouse ? Theme.alpha(lockRoot.uiAccent, 0.55) : lockRoot.uiPillBorder)
        border.width: (isArmed || pMouse.containsMouse || lockRoot.uiPillBorder.a > 0) ? 1 : 0

        Behavior on implicitWidth { NumberAnimation { duration: Theme.expressiveFast; easing.type: Theme.animExpressiveEasing } }
        Behavior on radius { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.animEasing } }
        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
        Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

        RowLayout {
            id: pRow
            anchors.centerIn: parent
            spacing: 6

            Text {
                text: pRoot.isArmed ? Theme.iconFlame : pRoot.icon
                font.family: Theme.fontIcon
                font.pixelSize: Theme.fontSizeMd
                color: pRoot.isArmed ? Theme.on_error : (pMouse.containsMouse ? lockRoot.uiAccent : lockRoot.uiTextPrimary)
            }

            Text {
                visible: pRoot.isArmed
                text: lockRoot.fmtText("confirm " + pRoot.label + "?")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXs
                font.weight: Theme.fontWeightBold
                color: Theme.on_error
            }
        }

        MouseArea {
            id: pMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: surface.requestPowerAction(pRoot.actionId, pRoot.command)
        }
    }

    PowerPill {
        actionId: "poweroff"
        icon: Theme.iconPower
        label: "shut down"
        command: ["systemctl", "poweroff"]
    }

    PowerPill {
        actionId: "reboot"
        icon: Theme.iconReboot
        label: "restart"
        command: ["systemctl", "reboot"]
    }

    PowerPill {
        actionId: "suspend"
        icon: Theme.iconSuspend
        label: "sleep"
        command: ["systemctl", "suspend"]
    }

    PowerPill {
        visible: lockRoot.allowLogoutOnLock
        actionId: "logout"
        icon: Theme.iconLogout
        label: "log out"
        command: [
            "sh", "-c",
            "hyprshutdown 2>/dev/null || uwsm stop 2>/dev/null || hyprctl dispatch 'hl.dsp.exit()' 2>/dev/null || hyprctl dispatch exit"
        ]
    }
}
