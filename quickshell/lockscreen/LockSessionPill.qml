// LockSessionPill.qml
import QtQuick
import QtQuick.Layouts
import ".."
import Quickshell

Rectangle {
    id: pillRoot

    property var root: null
    property var lockSurface: null
    property var lock: null

    anchors.top: parent.top
    anchors.left: parent.left
    anchors.margins: 32
    anchors.topMargin: (lockSurface?.entered && !root?.zenMode) ? 32 : 12
    opacity: (lockSurface?.entered && !root?.zenMode) ? 1.0 : 0.0
    visible: (root?.showUserPill ?? true) && opacity > 0.01
    height: 36
    implicitWidth: userRow.implicitWidth + 24
    radius: root?.uiRadiusPill ?? Theme.radiusSm
    color: root?.uiPillBg ?? Theme.surface
    border.color: (root?.failedAttempts ?? 0) > 0 ? Theme.alpha(Theme.error, 0.65) : (root?.uiPillBorder ?? "transparent")
    border.width: ((root?.failedAttempts ?? 0) > 0 || (root?.uiPillBorder?.a ?? 0) > 0) ? 1 : 0

    Behavior on anchors.topMargin { NumberAnimation { duration: Theme.expressiveDefault; easing.type: Theme.animEasingEntrance } }
    Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

    RowLayout {
        id: userRow
        anchors.centerIn: parent
        spacing: 8

        Text {
            text: lock?.secure ? (Theme.iconDistro ?? Theme.iconUser) : Theme.iconShield
            font.family: Theme.fontIcon
            font.variableAxes: Theme.iconAxes
            font.pixelSize: Theme.fontSizeMd
            color: root?.uiAccent ?? Theme.accent
        }

        Text {
            text: root ? root.fmtText(root.currentUser) : ""
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSm
            font.weight: Theme.fontWeightDemiBold
            color: root?.uiTextPrimary ?? Theme.on_surface
        }

        Text {
            text: "• " + (root?.lockedDurationText ?? "")
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeXs
            color: root?.uiTextSecondary ?? Theme.on_surface_variant
        }

        Rectangle {
            visible: (root?.failedAttempts ?? 0) > 0
            height: 20
            implicitWidth: failBadgeTxt.implicitWidth + 12
            radius: root?.uiRadiusPill ?? Theme.radiusSm
            color: Theme.error_overlay
            border.color: Theme.alpha(Theme.error, 0.55)
            border.width: 1

            Text {
                id: failBadgeTxt
                anchors.centerIn: parent
                text: root ? root.fmtText(root.failedAttempts + (root.failedAttempts === 1 ? " failed try" : " failed tries")) : ""
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeXs
                font.weight: Theme.fontWeightBold
                color: Theme.error
            }
        }
    }
}
