// LockSessionPill.qml
import QtQuick
import QtQuick.Layouts
import ".."
import Quickshell

Rectangle {
    id: pillRoot

    required property var lockRoot
    required property var surface
    required property var sessionLock

    anchors.top: parent.top
    anchors.left: parent.left
    anchors.margins: 32
    anchors.topMargin: (surface.entered && !lockRoot.zenMode) ? 32 : 12
    opacity: (surface.entered && !lockRoot.zenMode) ? 1.0 : 0.0
    visible: lockRoot.showUserPill && opacity > 0.01
    height: 36
    implicitWidth: userRow.implicitWidth + 24
    radius: lockRoot.uiRadiusPill
    color: lockRoot.uiPillBg
    border.color: lockRoot.failedAttempts > 0 ? Theme.alpha(Theme.error, 0.65) : lockRoot.uiPillBorder
    border.width: (lockRoot.failedAttempts > 0 || lockRoot.uiPillBorder.a > 0) ? 1 : 0

    Behavior on anchors.topMargin { NumberAnimation { duration: Theme.expressiveDefault; easing.type: Theme.animEasingEntrance } }
    Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

    RowLayout {
        id: userRow
        anchors.centerIn: parent
        spacing: 8

        Text {
            text: sessionLock?.secure ? (Theme.iconDistro ?? Theme.iconUser) : Theme.iconShield
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontSizeMd
            color: lockRoot.uiAccent
        }

        Text {
            text: lockRoot.fmtText(lockRoot.currentUser)
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSm
            font.weight: Theme.fontWeightDemiBold
            color: lockRoot.uiTextPrimary
        }

        Text {
            text: "• " + lockRoot.lockedDurationText
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeXs
            color: lockRoot.uiTextSecondary
        }

        Rectangle {
            visible: lockRoot.failedAttempts > 0
            height: 20
            implicitWidth: failBadgeTxt.implicitWidth + 12
            radius: lockRoot.uiRadiusPill
            color: Theme.error_overlay
            border.color: Theme.alpha(Theme.error, 0.55)
            border.width: 1

            Text {
                id: failBadgeTxt
                anchors.centerIn: parent
                text: lockRoot.fmtText(lockRoot.failedAttempts + (lockRoot.failedAttempts === 1 ? " failed try" : " failed tries"))
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeXs
                font.weight: Theme.fontWeightBold
                color: Theme.error
            }
        }
    }
}
