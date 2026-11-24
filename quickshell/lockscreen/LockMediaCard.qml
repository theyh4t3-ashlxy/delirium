// LockMediaCard.qml
import QtQuick
import QtQuick.Layouts
import ".."
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris

ClippingRectangle {
    id: mediaBlock

    required property var lockRoot
    required property var surface
    required property var centerStage
    property var lockPeakMonitor: null

                            width: parent.width
                            y: centerStage.blockY("media")
                            implicitHeight: mediaCardCol.implicitHeight + 24
                            height: implicitHeight
                            radius: lockRoot.uiRadiusLg
                            color: Theme.blend(lockRoot.uiCardBg, surface.artAccent, surface.playerIsPlaying ? 0.14 : 0.04)
                            border.color: surface.playerIsPlaying ? Theme.alpha(surface.artAccent, 0.45) : lockRoot.uiCardBorder
                            border.width: 1
                            visible: lockRoot.showMediaCard
                                && surface.activePlayer !== null
                                && ((surface.activePlayer?.trackTitle ?? "") !== "" || surface.playerIsPlaying)

                            Behavior on y { NumberAnimation { duration: Theme.expressiveDefault; easing.type: Theme.animEasingEntrance } }
                            Behavior on color { ColorAnimation { duration: Theme.animSlow; easing.type: Theme.animColorEasing } }
                            Behavior on border.color { ColorAnimation { duration: Theme.animSlow; easing.type: Theme.animColorEasing } }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.NoButton
                                onWheel: (wheel) => {
                                    if (surface.activePlayer && (surface.activePlayer.volumeSupported ?? true)) {
                                        let delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                                        let cur = (surface.activePlayer.volume !== undefined && !isNaN(surface.activePlayer.volume))
                                            ? surface.activePlayer.volume
                                            : 1.0;
                                        let next = Math.max(0.0, Math.min(1.0, cur + delta));
                                        surface.activePlayer.volume = next;
                                        surface.showVolumeToast("vol " + Math.round(next * 100) + "%");
                                    } else {
                                        surface.adjustSystemVolume(wheel.angleDelta.y > 0 ? 0.05 : -0.05);
                                    }
                                }
                            }

                            RowLayout {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                height: 42
                                spacing: 3
                                visible: lockRoot.showMediaVisualizer
                                opacity: surface.playerIsPlaying ? (lockRoot.isLight ? 0.28 : 0.22) : 0.06

                                Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }

                                Repeater {
                                    model: 24
                                    Rectangle {
                                        required property int index
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignBottom
                                        radius: 2

                                        readonly property real env: {
                                            let norm = index / 23.0;
                                            return Math.sin(norm * Math.PI) * 0.72 + 0.28;
                                        }

                                        readonly property real chPeak: {
                                            let pList = (lockPeakMonitor.peaks && lockPeakMonitor.peaks.length > 0) ? lockPeakMonitor.peaks : [];
                                            if (pList.length >= 2) {
                                                let mix = index / 23.0;
                                                return (pList[0] * (1.0 - mix)) + (pList[1] * mix);
                                            }
                                            return lockPeakMonitor.peak ?? 0;
                                        }

                                        height: {
                                            if (!surface.playerIsPlaying) return 3;
                                            let p = chPeak;
                                            let ripple = Math.sin((index * 0.65) + lockRoot.wavePhase) * 0.3 + Math.cos((index * 1.2) - lockRoot.wavePhase * 0.7) * 0.2;
                                            if (p > 0.008) {
                                                let target = (p * env * 36) + (Math.abs(ripple) * 12 * Math.min(1.0, p * 3.5));
                                                return Math.max(3, Math.min(40, Math.round(target)));
                                            }
                                            return Math.max(3, Math.round(3 + Math.abs(ripple) * 5));
                                        }

                                        color: chPeak > 0.55 ? Theme.tertiary : surface.artAccent

                                        Behavior on height {
                                            NumberAnimation { duration: 75; easing.type: Theme.animColorEasing }
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                id: mediaCardCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.margins: 12
                                spacing: 10

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 12

                                    ClippingRectangle {
                                        Layout.preferredWidth: 56
                                        Layout.preferredHeight: 56
                                        radius: lockRoot.uiRadiusMd
                                        color: lockRoot.uiWidgetBg
                                        border.color: lockRoot.uiCardBorder
                                        border.width: 1

                                        Image {
                                            anchors.fill: parent
                                            source: surface.coverArtUrl
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            visible: status === Image.Ready && source != ""
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: Theme.iconSet === "kaomoji" ? Theme.kaoMusic : Theme.iconMusic
                                            font.family: Theme.fontIcon
                                            font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeSm : Theme.fontSizeLg
                                            color: surface.artAccent
                                            visible: surface.coverArtUrl === ""
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: 2

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 6

                                            Text {
                                                text: lockRoot.fmtText(surface.activePlayer?.trackTitle || "Unknown Track")
                                                font.family: Theme.fontDisplay
                                                font.pixelSize: Theme.fontSizeSm
                                                font.weight: Theme.fontWeightBold
                                                color: lockRoot.uiTextPrimary
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }

                                            Rectangle {
                                                visible: surface.volumeHudVisible || surface.playerList.length > 1
                                                height: 20
                                                implicitWidth: mediaBadgeTxt.implicitWidth + 12
                                                radius: lockRoot.uiRadiusPill
                                                color: surface.volumeHudVisible ? lockRoot.uiAccentOverlay : lockRoot.uiPillBg
                                                border.color: Theme.alpha(surface.artAccent, 0.45)
                                                border.width: 1

                                                Text {
                                                    id: mediaBadgeTxt
                                                    anchors.centerIn: parent
                                                    text: surface.volumeHudVisible
                                                        ? surface.volumeHudLabel
                                                        : lockRoot.fmtText((surface.activePlayer?.identity || "player") + " " + (surface.currentPlayerIdx + 1) + "/" + surface.playerList.length)
                                                    font.family: Theme.fontMono
                                                    font.pixelSize: Theme.fontSizeXs
                                                    font.weight: Theme.fontWeightBold
                                                    color: surface.artAccent
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    enabled: surface.playerList.length > 1
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        lockRoot.manualPlayerIndex = (surface.currentPlayerIdx + 1) % surface.playerList.length;
                                                        surface.claimSurfaceFocus();
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            text: lockRoot.fmtText(surface.activePlayer?.trackArtist || "Unknown Artist")
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeXs
                                            font.weight: Theme.fontWeightDemiBold
                                            color: surface.artAccent
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                            Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.animColorEasing } }
                                        }
                                    }

                                    IconButton {
                                        icon: Theme.iconPrev
                                        iconSize: Theme.fontSizeSm
                                        tooltip: "previous"
                                        enabled: surface.activePlayer?.canGoPrevious ?? false
                                        onClicked: {
                                            surface.activePlayer?.previous();
                                            surface.claimSurfaceFocus();
                                        }
                                    }

                                    Rectangle {
                                        width: surface.playerIsPlaying ? 44 : 36
                                        height: 36
                                        radius: surface.playerIsPlaying ? lockRoot.uiRadiusMd : lockRoot.uiRadiusPill
                                        color: lockPlayMouse.pressed
                                            ? Theme.statePress(surface.artAccent, lockRoot.uiOnAccent)
                                            : (lockPlayMouse.containsMouse
                                                ? Theme.stateHover(surface.artAccent, lockRoot.uiOnAccent)
                                                : surface.artAccent)

                                        Behavior on width { NumberAnimation { duration: Theme.expressiveFast; easing.type: Theme.animExpressiveEasing } }
                                        Behavior on radius { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.animEasing } }
                                        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: surface.playerIsPlaying ? Theme.iconPause : Theme.iconPlay
                                            font.family: Theme.fontIcon
                                            font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeXs : Theme.fontSizeMd
                                            font.weight: Theme.fontWeightBold
                                            color: lockRoot.uiOnAccent
                                        }

                                        MouseArea {
                                            id: lockPlayMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                surface.activePlayer?.togglePlaying();
                                                surface.claimSurfaceFocus();
                                            }
                                        }
                                    }

                                    IconButton {
                                        icon: Theme.iconNext
                                        iconSize: Theme.fontSizeSm
                                        tooltip: "next"
                                        enabled: surface.activePlayer?.canGoNext ?? false
                                        onClicked: {
                                            surface.activePlayer?.next();
                                            surface.claimSurfaceFocus();
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    visible: lockRoot.showMediaVisualizer && (surface.activePlayer?.length ?? 0) > 0

                                    Text {
                                        text: lockRoot.formatTime(surface.trackPosition)
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeXs
                                        color: lockRoot.uiTextSecondary
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 14

                                        readonly property real progRatio: {
                                            let len = surface.activePlayer?.length ?? 0;
                                            if (len <= 0) return 0;
                                            return Math.max(0.0, Math.min(1.0, surface.trackPosition / len));
                                        }

                                        function seekToMouse(mx: real) {
                                            let len = surface.activePlayer?.length ?? 0;
                                            if (len > 0 && surface.activePlayer) {
                                                let pos = Math.max(0, Math.min(len, (mx / Math.max(1, width)) * len));
                                                surface.trackPosition = pos;
                                                surface.activePlayer.position = pos;
                                            }
                                        }

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            height: seekMouse.pressed ? 9 : (seekMouse.containsMouse ? 7 : 5)
                                            radius: lockRoot.uiRadiusPill
                                            color: Theme.alpha(lockRoot.uiTextPrimary, lockRoot.isLight ? 0.16 : 0.14)

                                            Behavior on height { NumberAnimation { duration: Theme.animFast } }

                                            Rectangle {
                                                anchors.left: parent.left
                                                anchors.top: parent.top
                                                anchors.bottom: parent.bottom
                                                width: parent.width * parent.parent.progRatio
                                                radius: lockRoot.uiRadiusPill
                                                color: surface.artAccent
                                            }
                                        }

                                        MouseArea {
                                            id: seekMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            enabled: (surface.activePlayer?.canSeek ?? true) && (surface.activePlayer?.length ?? 0) > 0
                                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            onPressed: (mouse) => parent.seekToMouse(mouse.x)
                                            onPositionChanged: (mouse) => {
                                                if (pressed) parent.seekToMouse(mouse.x);
                                            }
                                            onReleased: surface.claimSurfaceFocus()
                                        }
                                    }

                                    Text {
                                        text: lockRoot.formatTime(surface.activePlayer?.length ?? 0)
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeXs
                                        color: lockRoot.uiTextSecondary
                                    }
                                }
                            }
                        }

                        /*
                        password input pill:
                        stays visible: true even in zenMode (only opacity: 0) and uses readOnly instead of enabled: false
                        so pwInput never drops activeFocus or eats your first character!
                        */
                        ColumnLayout {
