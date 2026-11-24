// LockStatusBar.qml
import QtQuick
import QtQuick.Layouts
import ".."
import "../controls"
import Quickshell
import Quickshell.Services.UPower

Rectangle {
    id: statusBar

    required property var lockRoot
    required property var surface
    property var cornerRevealHover: null
    property var surpriseBurstAnim: null

    anchors.top: parent.top
    anchors.right: parent.right
    anchors.margins: 32
    anchors.topMargin: (surface.entered && !lockRoot.zenMode) ? 32 : 12
    opacity: (surface.entered && !lockRoot.zenMode && (lockRoot.showStatusBar || surface.optionsOpen || (cornerRevealHover && cornerRevealHover.containsMouse) || barHoverDetect.containsMouse)) ? 1.0 : 0.0
    visible: opacity > 0.01
    height: 36
    implicitWidth: statusRow.implicitWidth + 22
    radius: lockRoot.uiRadiusPill
    color: surface.optionsOpen ? lockRoot.uiWidgetActive : lockRoot.uiPillBg
    border.color: surface.optionsOpen ? Theme.alpha(lockRoot.uiAccent, 0.55) : lockRoot.uiPillBorder
    border.width: (surface.optionsOpen || lockRoot.uiPillBorder.a > 0) ? 1 : 0

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
            visible: lockRoot.kbLayoutShort !== ""
            height: 22
            implicitWidth: kbRow.implicitWidth + 12
            radius: lockRoot.uiRadiusPill
            color: kbMouse.containsMouse ? lockRoot.uiWidgetHover : lockRoot.uiWidgetBg
            border.color: lockRoot.uiWidgetBorder
            border.width: 1

            RowLayout {
                id: kbRow
                anchors.centerIn: parent
                spacing: 4

                Text {
                    text: Theme.iconKeyboard
                    font.family: Theme.fontIcon
                    font.pixelSize: Theme.fontSizeXs
                    color: lockRoot.uiAccent
                }
                Text {
                    text: lockRoot.fmtText(lockRoot.kbLayoutShort)
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeXs
                    font.weight: Theme.fontWeightBold
                    color: lockRoot.uiTextPrimary
                }
            }

            MouseArea {
                id: kbMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    lockRoot.switchKeyboardLayout();
                    surface.claimSurfaceFocus();
                }
            }
        }

        Item {
            visible: lockRoot.showSystemVol && lockRoot.defaultSink !== null
            implicitWidth: sysVolRow.implicitWidth
            implicitHeight: sysVolRow.implicitHeight

            readonly property real sinkVol: lockRoot.defaultSink?.audio?.volume ?? 0.0
            readonly property bool sinkMuted: lockRoot.defaultSink?.audio?.muted ?? false

            RowLayout {
                id: sysVolRow
                anchors.centerIn: parent
                spacing: 5

                Text {
                    text: Theme.getVolumeIcon(parent.parent.sinkVol, parent.parent.sinkMuted)
                    font.family: Theme.fontIcon
                    font.pixelSize: Theme.fontSizeMd
                    color: parent.parent.sinkMuted ? Theme.error : lockRoot.uiAccent
                }

                Text {
                    text: lockRoot.fmtText(parent.parent.sinkMuted ? "mute" : (Math.round(parent.parent.sinkVol * 100) + "%"))
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeXs
                    font.weight: Theme.fontWeightMedium
                    color: lockRoot.uiTextPrimary
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    surface.toggleSystemMute();
                    surface.claimSurfaceFocus();
                }
                onWheel: (wheel) => {
                    surface.adjustSystemVolume(wheel.angleDelta.y > 0 ? 0.05 : -0.05);
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
                font.pixelSize: Theme.fontSizeMd
                color: ((typeof NetworkService !== "undefined" && NetworkService?.isConnected) ?? false) ? lockRoot.uiAccent : lockRoot.uiTextSecondary
            }
            Text {
                text: lockRoot.fmtText(((typeof NetworkService !== "undefined" && NetworkService?.isWiredConnected) ?? false)
                    ? "wired"
                    : ((typeof NetworkService !== "undefined" ? NetworkService?.activeSsid : "") || (((typeof NetworkService !== "undefined" && NetworkService?.isConnected) ?? false) ? "online" : "offline"))
                )
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXs
                font.weight: Theme.fontWeightMedium
                color: lockRoot.uiTextPrimary
            }
        }

        Item {
            visible: UPower.displayDevice?.isPresent ?? false
            implicitWidth: batStatusRow.implicitWidth
            implicitHeight: batStatusRow.implicitHeight

            readonly property int batPct: {
                let p = UPower.displayDevice?.percentage ?? 1.0;
                return Math.min(100, Math.max(0, Math.round(p * 100)));
            }
            readonly property bool isCharging: UPower.displayDevice?.state === UPowerDeviceState.Charging
            readonly property string etaStr: lockRoot.formatBatteryEta()

            RowLayout {
                id: batStatusRow
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: Theme.getBatteryIcon(parent.parent.batPct, parent.parent.isCharging, !(UPower?.onBattery ?? true), false)
                    font.family: Theme.fontIcon
                    font.pixelSize: Theme.fontSizeMd
                    color: parent.parent.isCharging ? lockRoot.uiAccent : (parent.parent.batPct <= 20 ? Theme.error : lockRoot.uiTextPrimary)
                }
                Text {
                    text: parent.parent.batPct + "%" + (batHover.containsMouse && parent.parent.etaStr !== "" ? (" (" + parent.parent.etaStr + ")") : "")
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeXs
                    font.weight: Theme.fontWeightMedium
                    color: lockRoot.uiTextPrimary
                }
            }

            MouseArea {
                id: batHover
                anchors.fill: parent
                hoverEnabled: true
            }
        }

        IconButton {
            icon: lockRoot.isLight ? Theme.iconSun : Theme.iconMoon
            iconSize: Theme.fontSizeSm
            tooltip: lockRoot.isLight ? "switch to dark mode" : "switch to light mode"
            onClicked: {
                lockRoot.backdropMode = lockRoot.isLight ? "dark" : "light";
                lockRoot.saveSandbox();
                surface.claimSurfaceFocus();
            }
        }

        IconButton {
            icon: Theme.iconEyeOff
            iconSize: Theme.fontSizeSm
            tooltip: "zen screensaver mode (tab)"
            onClicked: {
                surface.optionsOpen = false;
                lockRoot.zenMode = true;
                surface.claimSurfaceFocus();
            }
        }

        IconButton {
            icon: Theme.iconSparkles
            iconSize: Theme.fontSizeSm
            tooltip: lockRoot.studioLocked ? "studio is locked" : "surprise me! (randomize)"
            enabled: !lockRoot.studioLocked
            onClicked: {
                if (surpriseBurstAnim) surpriseBurstAnim.restart();
                lockRoot.surpriseMe();
                surface.claimSurfaceFocus();
            }
        }

        IconButton {
            icon: Theme.iconSliders
            iconSize: Theme.fontSizeSm
            tooltip: "lock screen studio"
            highlighted: surface.optionsOpen
            onClicked: {
                surface.optionsOpen = !surface.optionsOpen;
                surface.claimSurfaceFocus();
            }
        }
    }
}
