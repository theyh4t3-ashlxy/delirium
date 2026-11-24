// LockStatusBar.qml
import QtQuick
import QtQuick.Layouts
import ".."
import "../controls"
import Quickshell
import Quickshell.Services.UPower

Rectangle {
    id: statusBar

    property var root: null
    property var lockSurface: null
    property var cornerHover: null
    property var burstAnim: null

    anchors.top: parent.top
    anchors.right: parent.right
    anchors.margins: 32
    anchors.topMargin: (lockSurface?.entered && !root?.zenMode) ? 32 : 12
    opacity: (lockSurface?.entered && !root?.zenMode && (
        (root?.showStatusBar ?? true)
        || lockSurface?.optionsOpen
        || (cornerHover && cornerHover.containsMouse)
        || barHoverDetect.containsMouse
    )) ? 1.0 : 0.0
    visible: opacity > 0.01
    height: 36
    implicitWidth: statusRow.implicitWidth + 22
    radius: root?.uiRadiusPill ?? Theme.radiusSm
    color: lockSurface?.optionsOpen ? (root?.uiWidgetActive ?? Theme.surface) : (root?.uiPillBg ?? Theme.surface)
    border.color: lockSurface?.optionsOpen ? Theme.alpha(root?.uiAccent ?? Theme.accent, 0.55) : (root?.uiPillBorder ?? "transparent")
    border.width: (lockSurface?.optionsOpen || (root?.uiPillBorder?.a ?? 0) > 0) ? 1 : 0

    Behavior on anchors.topMargin { NumberAnimation { duration: Theme.expressiveDefault; easing.type: Theme.animEasingEntrance } }
    Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
    Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

    MouseArea {
        id: barHoverDetect
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    RowLayout {
        id: statusRow
        anchors.centerIn: parent
        spacing: 12

        Rectangle {
            visible: (root?.kbLayoutShort ?? "") !== ""
            height: 22
            implicitWidth: kbRow.implicitWidth + 12
            radius: root?.uiRadiusPill ?? Theme.radiusSm
            color: kbMouse.containsMouse ? (root?.uiWidgetHover ?? Theme.surface) : (root?.uiWidgetBg ?? Theme.surface)
            border.color: root?.uiWidgetBorder ?? "transparent"
            border.width: 1

            RowLayout {
                id: kbRow
                anchors.centerIn: parent
                spacing: 4

                Text {
                    text: Theme.iconKeyboard
                    font.family: Theme.fontIcon
                    font.variableAxes: Theme.iconAxes
                    font.pixelSize: Theme.fontSizeXs
                    color: root?.uiAccent ?? Theme.accent
                }
                Text {
                    text: root ? root.fmtText(root.kbLayoutShort) : ""
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeXs
                    font.weight: Theme.fontWeightBold
                    color: root?.uiTextPrimary ?? Theme.on_surface
                }
            }

            MouseArea {
                id: kbMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root?.switchKeyboardLayout) root.switchKeyboardLayout();
                    if (lockSurface?.claimSurfaceFocus) lockSurface.claimSurfaceFocus();
                }
            }
        }

        Item {
            visible: (root?.showSystemVol ?? true) && (root?.defaultSink !== null && root?.defaultSink !== undefined)
            implicitWidth: sysVolRow.implicitWidth
            implicitHeight: sysVolRow.implicitHeight

            readonly property real sinkVol: root?.defaultSink?.audio?.volume ?? 0.0
            readonly property bool sinkMuted: root?.defaultSink?.audio?.muted ?? false

            RowLayout {
                id: sysVolRow
                anchors.centerIn: parent
                spacing: 5

                Text {
                    text: Theme.getVolumeIcon(parent.parent.sinkVol, parent.parent.sinkMuted)
                    font.family: Theme.fontIcon
                    font.variableAxes: Theme.iconAxes
                    font.pixelSize: Theme.fontSizeMd
                    color: parent.parent.sinkMuted ? Theme.error : (root?.uiAccent ?? Theme.accent)
                }

                Text {
                    text: root ? root.fmtText(parent.parent.sinkMuted ? "mute" : (Math.round(parent.parent.sinkVol * 100) + "%")) : (parent.parent.sinkMuted ? "mute" : (Math.round(parent.parent.sinkVol * 100) + "%"))
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeXs
                    font.weight: Theme.fontWeightMedium
                    color: root?.uiTextPrimary ?? Theme.on_surface
                }
            }

            MouseArea {
                id: sysVolMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (lockSurface?.toggleSystemMute) lockSurface.toggleSystemMute();
                    if (lockSurface?.claimSurfaceFocus) lockSurface.claimSurfaceFocus();
                }
                onWheel: (wheel) => {
                    if (lockSurface?.adjustSystemVolume) {
                        lockSurface.adjustSystemVolume(wheel.angleDelta.y > 0 ? 0.05 : -0.05);
                    }
                }
            }
        }

        RowLayout {
            spacing: 6

            Text {
                text: Theme.getWifiIcon(
                    (typeof NetworkService !== "undefined" ? NetworkService?.signalStrength : 100) ?? 100,
                    (typeof NetworkService !== "undefined" ? NetworkService?.isConnected : false) ?? false,
                    (typeof NetworkService !== "undefined" ? NetworkService?.isWiredConnected : false) ?? false
                )
                font.family: Theme.fontIcon
                font.variableAxes: Theme.iconAxes
                font.pixelSize: Theme.fontSizeMd
                color: ((typeof NetworkService !== "undefined" && NetworkService?.isConnected) ?? false)
                    ? (root?.uiAccent ?? Theme.accent)
                    : (root?.uiTextSecondary ?? Theme.on_surface_variant)
            }

            Text {
                property string rawNetLabel: ((typeof NetworkService !== "undefined" && NetworkService?.isWiredConnected) ?? false)
                    ? "wired"
                    : ((typeof NetworkService !== "undefined" ? NetworkService?.activeSsid : "") || (((typeof NetworkService !== "undefined" && NetworkService?.isConnected) ?? false) ? "online" : "offline"))
                text: root ? root.fmtText(rawNetLabel) : rawNetLabel
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXs
                font.weight: Theme.fontWeightMedium
                color: root?.uiTextPrimary ?? Theme.on_surface
            }
        }

        Item {
            visible: UPower.displayDevice?.isPresent ?? false
            implicitWidth: batRow.implicitWidth
            implicitHeight: batRow.implicitHeight

            readonly property int batPct: {
                let p = UPower.displayDevice?.percentage ?? 1.0;
                return Math.min(100, Math.max(0, Math.round(p * 100)));
            }
            readonly property int batState: UPower.displayDevice?.state ?? 0
            readonly property bool isCharging: batState === UPowerDeviceState.Charging || batState === UPowerDeviceState.FullyCharged
            readonly property bool isLow: batPct <= 20 && !isCharging
            readonly property string etaStr: root ? root.formatBatteryEta() : ""

            RowLayout {
                id: batRow
                anchors.centerIn: parent
                spacing: 5

                Text {
                    text: Theme.getBatteryIcon(parent.parent.batPct, parent.parent.isCharging, !(UPower?.onBattery ?? true), false)
                    font.family: Theme.fontIcon
                    font.variableAxes: Theme.iconAxes
                    font.pixelSize: Theme.fontSizeMd
                    color: parent.parent.isLow ? Theme.error : (parent.parent.isCharging ? (root?.uiAccent ?? Theme.accent) : (root?.uiTextPrimary ?? Theme.on_surface))
                }

                Text {
                    text: parent.parent.batPct + "%" + (batHover.containsMouse && parent.parent.etaStr !== "" ? (" (" + parent.parent.etaStr + ")") : "")
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeXs
                    font.weight: Theme.fontWeightMedium
                    color: root?.uiTextPrimary ?? Theme.on_surface
                }
            }

            MouseArea {
                id: batHover
                anchors.fill: parent
                hoverEnabled: true
            }
        }

        IconButton {
            icon: (root?.isLight ?? false) ? Theme.iconSun : Theme.iconMoon
            iconSize: Theme.fontSizeSm
            iconColor: root?.uiTextPrimary ?? Theme.on_surface
            tooltip: (root?.isLight ?? false) ? "switch to dark mode" : "switch to light mode"
            onClicked: {
                if (root) {
                    root.backdropMode = root.isLight ? "dark" : "light";
                    if (root.saveSandbox) root.saveSandbox();
                }
                if (lockSurface?.claimSurfaceFocus) lockSurface.claimSurfaceFocus();
            }
        }

        IconButton {
            icon: Theme.iconEyeOff
            iconSize: Theme.fontSizeSm
            iconColor: root?.uiTextPrimary ?? Theme.on_surface
            tooltip: "zen screensaver mode (tab)"
            onClicked: {
                if (lockSurface) lockSurface.optionsOpen = false;
                if (root) root.zenMode = true;
                if (lockSurface?.claimSurfaceFocus) lockSurface.claimSurfaceFocus();
            }
        }

        IconButton {
            icon: Theme.iconSparkles
            iconSize: Theme.fontSizeSm
            iconColor: root?.uiTextPrimary ?? Theme.on_surface
            tooltip: (root?.studioLocked ?? false) ? "studio is locked" : "surprise me! (randomize)"
            enabled: !(root?.studioLocked ?? false)
            onClicked: {
                if (burstAnim) burstAnim.restart();
                if (root?.surpriseMe) root.surpriseMe();
                if (lockSurface?.claimSurfaceFocus) lockSurface.claimSurfaceFocus();
            }
        }

        IconButton {
            icon: Theme.iconSliders
            iconSize: Theme.fontSizeSm
            iconColor: root?.uiTextPrimary ?? Theme.on_surface
            tooltip: "lock screen studio"
            highlighted: lockSurface?.optionsOpen ?? false
            onClicked: {
                if (lockSurface) lockSurface.optionsOpen = !lockSurface.optionsOpen;
                if (lockSurface?.claimSurfaceFocus) lockSurface.claimSurfaceFocus();
            }
        }
    }
}
