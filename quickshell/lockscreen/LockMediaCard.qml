// LockMediaCard.qml
import QtQuick
import QtQuick.Layouts
import ".."
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris

ClippingRectangle {
    id: mediaBlock

    property var root: null
    property var lockSurface: null
    property var stage: null
    property var peakMonitor: null
    readonly property bool isSeeking: seekMouse.pressed

                            width: parent.width
                            y: stage.blockY("media")
                            implicitHeight: mediaCardCol.implicitHeight + 24
                            height: implicitHeight
                            radius: root.uiRadiusLg
                            color: Theme.blend(root.uiCardBg, lockSurface.artAccent, lockSurface.playerIsPlaying ? 0.14 : 0.04)
                            border.color: lockSurface.playerIsPlaying ? Theme.alpha(lockSurface.artAccent, 0.45) : root.uiCardBorder
                            border.width: 1
                            visible: root.showMediaCard
                                && lockSurface.activePlayer !== null
                                && ((lockSurface.activePlayer?.trackTitle ?? "") !== "" || lockSurface.playerIsPlaying)

                            Behavior on y { NumberAnimation { duration: Theme.expressiveDefault; easing.type: Theme.animEasingEntrance } }
                            Behavior on color { ColorAnimation { duration: Theme.animSlow; easing.type: Theme.animColorEasing } }
                            Behavior on border.color { ColorAnimation { duration: Theme.animSlow; easing.type: Theme.animColorEasing } }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.NoButton
                                onWheel: (wheel) => {
                                    if (lockSurface.activePlayer && (lockSurface.activePlayer.volumeSupported ?? true)) {
                                        let delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                                        let cur = (lockSurface.activePlayer.volume !== undefined && !isNaN(lockSurface.activePlayer.volume))
                                            ? lockSurface.activePlayer.volume
                                            : 1.0;
                                        let next = Math.max(0.0, Math.min(1.0, cur + delta));
                                        lockSurface.activePlayer.volume = next;
                                        lockSurface.showVolumeToast("vol " + Math.round(next * 100) + "%");
                                    } else {
                                        lockSurface.adjustSystemVolume(wheel.angleDelta.y > 0 ? 0.05 : -0.05);
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
                                visible: root.showMediaVisualizer
                                opacity: lockSurface.playerIsPlaying ? (root.isLight ? 0.28 : 0.22) : 0.06

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
                                            let pList = (peakMonitor?.peaks && peakMonitor.peaks.length > 0) ? peakMonitor.peaks : [];
                                            if (pList.length >= 2) {
                                                let mix = index / 23.0;
                                                return (pList[0] * (1.0 - mix)) + (pList[1] * mix);
                                            }
                                            return peakMonitor?.peak ?? 0;
                                        }

                                        height: {
                                            if (!lockSurface.playerIsPlaying) return 3;
                                            let p = chPeak;
                                            let ripple = Math.sin((index * 0.65) + root.wavePhase) * 0.3 + Math.cos((index * 1.2) - root.wavePhase * 0.7) * 0.2;
                                            if (p > 0.008) {
                                                let target = (p * env * 36) + (Math.abs(ripple) * 12 * Math.min(1.0, p * 3.5));
                                                return Math.max(3, Math.min(40, Math.round(target)));
                                            }
                                            return Math.max(3, Math.round(3 + Math.abs(ripple) * 5));
                                        }

                                        color: chPeak > 0.55 ? Theme.tertiary : lockSurface.artAccent

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
                                        radius: root.uiRadiusMd
                                        color: root.uiWidgetBg
                                        border.color: root.uiCardBorder
                                        border.width: 1

                                        Image {
                                            anchors.fill: parent
                                            source: lockSurface.coverArtUrl
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            visible: status === Image.Ready && source != ""
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: Theme.iconSet === "kaomoji" ? Theme.kaoMusic : Theme.iconMusic
                                            font.family: Theme.fontIcon
                                            font.variableAxes: Theme.iconAxes
                                            font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeSm : Theme.fontSizeLg
                                            color: lockSurface.artAccent
                                            visible: lockSurface.coverArtUrl === ""
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
                                                text: root.fmtText(lockSurface.activePlayer?.trackTitle || "Unknown Track")
                                                font.family: Theme.fontDisplay
                                                font.pixelSize: Theme.fontSizeSm
                                                font.weight: Theme.fontWeightBold
                                                color: root.uiTextPrimary
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }

                                            Rectangle {
                                                visible: lockSurface.volumeHudVisible || lockSurface.playerList.length > 1
                                                height: 20
                                                implicitWidth: mediaBadgeTxt.implicitWidth + 12
                                                radius: root.uiRadiusPill
                                                color: lockSurface.volumeHudVisible ? root.uiAccentOverlay : root.uiPillBg
                                                border.color: Theme.alpha(lockSurface.artAccent, 0.45)
                                                border.width: 1

                                                Text {
                                                    id: mediaBadgeTxt
                                                    anchors.centerIn: parent
                                                    text: lockSurface.volumeHudVisible
                                                        ? lockSurface.volumeHudLabel
                                                        : root.fmtText((lockSurface.activePlayer?.identity || "player") + " " + (lockSurface.currentPlayerIdx + 1) + "/" + lockSurface.playerList.length)
                                                    font.family: Theme.fontMono
                                                    font.pixelSize: Theme.fontSizeXs
                                                    font.weight: Theme.fontWeightBold
                                                    color: lockSurface.artAccent
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    enabled: lockSurface.playerList.length > 1
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        root.manualPlayerIndex = (lockSurface.currentPlayerIdx + 1) % lockSurface.playerList.length;
                                                        lockSurface.claimSurfaceFocus();
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            text: root.fmtText(lockSurface.activePlayer?.trackArtist || "Unknown Artist")
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeXs
                                            font.weight: Theme.fontWeightDemiBold
                                            color: lockSurface.artAccent
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                            Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.animColorEasing } }
                                        }
                                    }

                                    IconButton {
                                        icon: Theme.iconPrev
                                        iconSize: Theme.fontSizeSm
                                        iconColor: root.uiTextPrimary
                                        tooltip: "previous"
                                        enabled: lockSurface.activePlayer?.canGoPrevious ?? false
                                        onClicked: {
                                            lockSurface.activePlayer?.previous();
                                            lockSurface.claimSurfaceFocus();
                                        }
                                    }

                                    Rectangle {
                                        width: lockSurface.playerIsPlaying ? 44 : 36
                                        height: 36
                                        radius: lockSurface.playerIsPlaying ? root.uiRadiusMd : root.uiRadiusPill
                                        color: lockPlayMouse.pressed
                                            ? Theme.statePress(lockSurface.artAccent, root.uiOnAccent)
                                            : (lockPlayMouse.containsMouse
                                                ? Theme.stateHover(lockSurface.artAccent, root.uiOnAccent)
                                                : lockSurface.artAccent)

                                        Behavior on width { NumberAnimation { duration: Theme.expressiveFast; easing.type: Theme.animExpressiveEasing } }
                                        Behavior on radius { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.animEasing } }
                                        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: lockSurface.playerIsPlaying ? Theme.iconPause : Theme.iconPlay
                                            font.family: Theme.fontIcon
                                            font.variableAxes: Theme.iconAxes
                                            font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeXs : Theme.fontSizeMd
                                            font.weight: Theme.fontWeightBold
                                            color: root.uiOnAccent
                                        }

                                        MouseArea {
                                            id: lockPlayMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                lockSurface.activePlayer?.togglePlaying();
                                                lockSurface.claimSurfaceFocus();
                                            }
                                        }
                                    }

                                    IconButton {
                                        icon: Theme.iconNext
                                        iconSize: Theme.fontSizeSm
                                        iconColor: root.uiTextPrimary
                                        tooltip: "next"
                                        enabled: lockSurface.activePlayer?.canGoNext ?? false
                                        onClicked: {
                                            lockSurface.activePlayer?.next();
                                            lockSurface.claimSurfaceFocus();
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    visible: root.showMediaVisualizer && (lockSurface.activePlayer?.length ?? 0) > 0

                                    Text {
                                        text: root.formatTime(lockSurface.trackPosition)
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeXs
                                        color: root.uiTextSecondary
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 14

                                        readonly property real progRatio: {
                                            let len = lockSurface.activePlayer?.length ?? 0;
                                            if (len <= 0) return 0;
                                            return Math.max(0.0, Math.min(1.0, lockSurface.trackPosition / len));
                                        }

                                        function seekToMouse(mx: real) {
                                            let len = lockSurface.activePlayer?.length ?? 0;
                                            if (len > 0 && lockSurface.activePlayer) {
                                                let pos = Math.max(0, Math.min(len, (mx / Math.max(1, width)) * len));
                                                lockSurface.trackPosition = pos;
                                                lockSurface.activePlayer.position = pos;
                                            }
                                        }

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            height: seekMouse.pressed ? 9 : (seekMouse.containsMouse ? 7 : 5)
                                            radius: root.uiRadiusPill
                                            color: Theme.alpha(root.uiTextPrimary, root.isLight ? 0.16 : 0.14)

                                            Behavior on height { NumberAnimation { duration: Theme.animFast } }

                                            Rectangle {
                                                anchors.left: parent.left
                                                anchors.top: parent.top
                                                anchors.bottom: parent.bottom
                                                width: parent.width * parent.parent.progRatio
                                                radius: root.uiRadiusPill
                                                color: lockSurface.artAccent
                                            }
                                        }

                                        MouseArea {
                                            id: seekMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            enabled: (lockSurface.activePlayer?.canSeek ?? true) && (lockSurface.activePlayer?.length ?? 0) > 0
                                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            onPressed: (mouse) => parent.seekToMouse(mouse.x)
                                            onPositionChanged: (mouse) => {
                                                if (pressed) parent.seekToMouse(mouse.x);
                                            }
                                            onReleased: lockSurface.claimSurfaceFocus()
                                        }
                                    }

                                    Text {
                                        text: root.formatTime(lockSurface.activePlayer?.length ?? 0)
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeXs
                                        color: root.uiTextSecondary
                                    }
                                }
                            }
                        }
