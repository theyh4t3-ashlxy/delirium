// LockPowerDock.qml
import QtQuick
import QtQuick.Layouts
import ".."
import Quickshell

RowLayout {
    id: dockRoot

    property var root: null
    property var lockSurface: null

    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.margins: 36
    anchors.bottomMargin: (lockSurface?.entered && !root?.zenMode && root?.showPowerDock) ? 36 : 12
    opacity: (lockSurface?.entered && !root?.zenMode && root?.showPowerDock) ? 1.0 : 0.0
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

        readonly property bool isArmed: lockSurface?.pendingPowerAction === pRoot.actionId

        height: 40
        implicitWidth: isArmed ? (pRow.implicitWidth + 28) : 40
        radius: isArmed ? (root?.uiRadiusMd ?? Theme.radiusMd) : (root?.uiRadiusPill ?? Theme.radiusPill)
        color: isArmed
            ? (pMouse.pressed ? Theme.statePress(Theme.error, Theme.on_error) : Theme.error)
            : (pMouse.pressed ? (root?.uiWidgetActive ?? Theme.widgetActive) : (pMouse.containsMouse ? (root?.uiPillHover ?? Theme.pillHover) : (root?.uiPillBg ?? Theme.pillBg)))
        border.color: isArmed
            ? Theme.error
            : (pMouse.containsMouse ? Theme.alpha(root?.uiAccent ?? Theme.accent, 0.55) : (root?.uiPillBorder ?? "transparent"))
        border.width: (isArmed || pMouse.containsMouse || (root?.uiPillBorder?.a ?? 0) > 0) ? 1 : 0

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
                font.variableAxes: Theme.iconAxes
                font.pixelSize: Theme.fontSizeMd
                color: pRoot.isArmed ? Theme.on_error : (pMouse.containsMouse ? (root?.uiAccent ?? Theme.accent) : (root?.uiTextPrimary ?? Theme.on_surface))
            }

            Text {
                visible: pRoot.isArmed
                text: root ? root.fmtText("confirm " + pRoot.label + "?") : ("confirm " + pRoot.label + "?")
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
            onClicked: {
                if (lockSurface) lockSurface.requestPowerAction(pRoot.actionId, pRoot.command);
            }
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
        visible: root?.allowLogoutOnLock ?? true
        actionId: "logout"
        icon: Theme.iconLogout
        label: "log out"
        command: [
            "sh", "-c",
            "hyprshutdown 2>/dev/null || uwsm stop 2>/dev/null || hyprctl dispatch 'hl.dsp.exit()' 2>/dev/null || hyprctl dispatch exit"
        ]
    }
}
