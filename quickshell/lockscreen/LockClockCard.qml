// LockClockCard.qml
import QtQuick
import QtQuick.Layouts
import ".."
import Quickshell

ColumnLayout {
    id: clockBlock

    required property var lockRoot
    required property var surface
    required property var centerStage

    visible: lockRoot.showClock || lockRoot.showDate || lockRoot.activeQuoteText !== ""
    width: parent.width
                            y: centerStage.blockY("clock")
                            spacing: 6

                            Behavior on y { NumberAnimation { duration: Theme.expressiveDefault; easing.type: Theme.animEasingEntrance } }

                            readonly property int baseClockPx: Math.round((lockRoot.clockStyle === "minimal" ? 56 : 86) * Theme.fontScale * lockRoot.clockScale)
                            readonly property int rawHours: lockRoot.currentTime.getHours()
                            readonly property int displayHourNum: lockRoot.effectiveClock24h ? rawHours : ((rawHours % 12) || 12)
                            readonly property int displayMinNum: lockRoot.currentTime.getMinutes()
                            readonly property int displaySecNum: lockRoot.currentTime.getSeconds()

                            readonly property string mainHoursText: (displayHourNum < 10 ? "0" : "") + displayHourNum
                            readonly property string mainMinutesText: (displayMinNum < 10 ? "0" : "") + displayMinNum
                            readonly property string secondsDigits: (displaySecNum < 10 ? "0" : "") + displaySecNum
                            readonly property string amPmText: lockRoot.fmtText(rawHours >= 12 ? "PM" : "AM")
                            readonly property string formattedDateText: lockRoot.fmtText(Qt.formatDateTime(lockRoot.currentTime, lockRoot.dateFormat))

                            Text {
                                visible: lockRoot.showDate && lockRoot.dateAboveClock && lockRoot.clockStyle !== "editorial"
                                text: clockBlock.formattedDateText
                                font.family: Theme.fontDisplay
                                font.pixelSize: Theme.fontSizeMd
                                font.weight: Theme.fontWeightDemiBold
                                color: lockRoot.uiAccent
                                Layout.alignment: Qt.AlignHCenter
                            }

                            // style 1 & 2: inline or minimal clock
                            RowLayout {
                                visible: lockRoot.showClock && (lockRoot.clockStyle === "inline" || lockRoot.clockStyle === "minimal")
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 10

                                Text {
                                    text: {
                                        let hm = clockBlock.mainHoursText + ":" + clockBlock.mainMinutesText;
                                        if (lockRoot.effectiveShowSeconds && lockRoot.secondsStyle === "inline") {
                                            return hm + ":" + clockBlock.secondsDigits + (!lockRoot.effectiveClock24h ? (" " + clockBlock.amPmText) : "");
                                        }
                                        if (!lockRoot.effectiveShowSeconds && !lockRoot.effectiveClock24h) {
                                            return hm + " " + clockBlock.amPmText;
                                        }
                                        return hm;
                                    }
                                    font.family: Theme.fontDisplay
                                    font.pixelSize: (lockRoot.effectiveShowSeconds && lockRoot.secondsStyle === "inline")
                                        ? Math.round(clockBlock.baseClockPx * 0.76)
                                        : clockBlock.baseClockPx
                                    font.weight: lockRoot.clockStyle === "minimal" ? Theme.fontWeightDemiBold : Theme.fontWeightBold
                                    color: lockRoot.uiTextPrimary
                                    Layout.alignment: Qt.AlignVCenter

                                    Behavior on font.pixelSize { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
                                }

                                ColumnLayout {
                                    visible: lockRoot.effectiveShowSeconds && lockRoot.secondsStyle === "badge"
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 4

                                    Rectangle {
                                        readonly property int badgeFontPx: Math.max(18, Math.round(clockBlock.baseClockPx * 0.38))
                                        height: badgeFontPx + 14
                                        implicitWidth: secBadgeTxt.implicitWidth + 20
                                        radius: lockRoot.uiRadiusMd
                                        color: lockRoot.uiAccentOverlay
                                        border.color: Theme.alpha(lockRoot.uiAccent, 0.55)
                                        border.width: 1

                                        Text {
                                            id: secBadgeTxt
                                            anchors.centerIn: parent
                                            text: clockBlock.secondsDigits
                                            font.family: Theme.fontMono
                                            font.pixelSize: parent.badgeFontPx
                                            font.weight: Theme.fontWeightBold
                                            color: lockRoot.uiAccent
                                        }
                                    }

                                    Text {
                                        visible: !lockRoot.effectiveClock24h
                                        text: clockBlock.amPmText
                                        font.family: Theme.fontMono
                                        font.pixelSize: Math.max(11, Math.round(clockBlock.baseClockPx * 0.18))
                                        font.weight: Theme.fontWeightBold
                                        color: lockRoot.uiTextSecondary
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                }

                                ColumnLayout {
                                    visible: lockRoot.effectiveShowSeconds && lockRoot.secondsStyle === "supersub"
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: -2

                                    Text {
                                        text: ":" + clockBlock.secondsDigits
                                        font.family: Theme.fontDisplay
                                        font.pixelSize: Math.max(20, Math.round(clockBlock.baseClockPx * 0.44))
                                        font.weight: Theme.fontWeightBold
                                        color: lockRoot.uiAccent
                                    }

                                    Text {
                                        visible: !lockRoot.effectiveClock24h
                                        text: clockBlock.amPmText
                                        font.family: Theme.fontMono
                                        font.pixelSize: Math.max(12, Math.round(clockBlock.baseClockPx * 0.22))
                                        font.weight: Theme.fontWeightBold
                                        color: lockRoot.uiTextSecondary
                                    }
                                }
                            }

                            // style 3: stacked m3 expressive clock
                            RowLayout {
                                visible: lockRoot.showClock && lockRoot.clockStyle === "stacked"
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 14

                                ColumnLayout {
                                    spacing: -20

                                    Text {
                                        text: clockBlock.mainHoursText
                                        font.family: Theme.fontDisplay
                                        font.pixelSize: Math.round(92 * Theme.fontScale * lockRoot.clockScale)
                                        font.weight: Theme.fontWeightBold
                                        color: lockRoot.uiTextPrimary
                                        Layout.alignment: Qt.AlignHCenter
                                    }

                                    Text {
                                        text: clockBlock.mainMinutesText
                                        font.family: Theme.fontDisplay
                                        font.pixelSize: Math.round(92 * Theme.fontScale * lockRoot.clockScale)
                                        font.weight: Theme.fontWeightBold
                                        color: lockRoot.uiAccent
                                        Layout.alignment: Qt.AlignHCenter
                                    }

                                    Text {
                                        visible: lockRoot.effectiveShowSeconds && lockRoot.secondsStyle === "tower"
                                        text: clockBlock.secondsDigits
                                        font.family: Theme.fontDisplay
                                        font.pixelSize: Math.round(92 * Theme.fontScale * lockRoot.clockScale)
                                        font.weight: Theme.fontWeightBold
                                        color: Theme.tertiary
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                }

                                ColumnLayout {
                                    visible: (lockRoot.effectiveShowSeconds && lockRoot.secondsStyle !== "tower") || !lockRoot.effectiveClock24h
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 8

                                    Rectangle {
                                        visible: !lockRoot.effectiveClock24h
                                        readonly property int amPx: Math.max(14, Math.round(22 * Theme.fontScale * lockRoot.clockScale))
                                        height: amPx + 14
                                        implicitWidth: stackAmTxt.implicitWidth + 18
                                        radius: lockRoot.uiRadiusMd
                                        color: lockRoot.uiPillBg
                                        border.color: lockRoot.uiPillBorder
                                        border.width: 1

                                        Text {
                                            id: stackAmTxt
                                            anchors.centerIn: parent
                                            text: clockBlock.amPmText
                                            font.family: Theme.fontMono
                                            font.pixelSize: parent.amPx
                                            font.weight: Theme.fontWeightBold
                                            color: lockRoot.uiTextSecondary
                                        }
                                    }

                                    Rectangle {
                                        visible: lockRoot.effectiveShowSeconds && lockRoot.secondsStyle !== "tower"
                                        readonly property int secPx: Math.max(22, Math.round(38 * Theme.fontScale * lockRoot.clockScale))
                                        height: secPx + 18
                                        implicitWidth: stackSecTxt.implicitWidth + 22
                                        radius: lockRoot.uiRadiusLg
                                        color: lockRoot.uiAccentOverlay
                                        border.color: Theme.alpha(lockRoot.uiAccent, 0.55)
                                        border.width: 1

                                        Text {
                                            id: stackSecTxt
                                            anchors.centerIn: parent
                                            text: ":" + clockBlock.secondsDigits
                                            font.family: Theme.fontMono
                                            font.pixelSize: parent.secPx
                                            font.weight: Theme.fontWeightBold
                                            color: lockRoot.uiAccent
                                        }
                                    }
                                }
                            }

                            // style 4: "split" twin squircle flip-cards
                            RowLayout {
                                visible: lockRoot.showClock && lockRoot.clockStyle === "split"
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 10

                                readonly property int cardSize: Math.round(108 * Theme.fontScale * lockRoot.clockScale)
                                readonly property int digitPx: Math.round(62 * Theme.fontScale * lockRoot.clockScale)

                                Rectangle {
                                    width: parent.cardSize
                                    height: parent.cardSize
                                    radius: lockRoot.uiRadiusXl
                                    color: lockRoot.uiCardBg
                                    border.color: Theme.alpha(lockRoot.uiAccent, 0.35)
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: clockBlock.mainHoursText
                                        font.family: Theme.fontDisplay
                                        font.pixelSize: parent.parent.digitPx
                                        font.weight: Theme.fontWeightBold
                                        color: lockRoot.uiTextPrimary
                                    }

                                    Text {
                                        visible: !lockRoot.effectiveClock24h
                                        anchors.bottom: parent.bottom
                                        anchors.right: parent.right
                                        anchors.margins: 8
                                        text: clockBlock.amPmText
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightBold
                                        color: lockRoot.uiAccent
                                    }
                                }

                                ColumnLayout {
                                    spacing: 10
                                    Layout.alignment: Qt.AlignVCenter
                                    Rectangle {
                                        width: 8; height: 8; radius: 4
                                        color: lockRoot.uiAccent
                                        opacity: (clockBlock.displaySecNum % 2 === 0) ? 1.0 : 0.35
                                        Behavior on opacity { NumberAnimation { duration: 250 } }
                                    }
                                    Rectangle {
                                        width: 8; height: 8; radius: 4
                                        color: lockRoot.uiAccent
                                        opacity: (clockBlock.displaySecNum % 2 === 0) ? 1.0 : 0.35
                                        Behavior on opacity { NumberAnimation { duration: 250 } }
                                    }
                                }

                                Rectangle {
                                    width: parent.cardSize
                                    height: parent.cardSize
                                    radius: lockRoot.uiRadiusXl
                                    color: Theme.blend(lockRoot.uiCardBg, lockRoot.uiAccent, 0.14)
                                    border.color: Theme.alpha(lockRoot.uiAccent, 0.55)
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: clockBlock.mainMinutesText
                                        font.family: Theme.fontDisplay
                                        font.pixelSize: parent.parent.digitPx
                                        font.weight: Theme.fontWeightBold
                                        color: lockRoot.uiAccent
                                    }

                                    Text {
                                        visible: lockRoot.effectiveShowSeconds
                                        anchors.bottom: parent.bottom
                                        anchors.right: parent.right
                                        anchors.margins: 8
                                        text: ":" + clockBlock.secondsDigits
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightBold
                                        color: lockRoot.uiTextSecondary
                                    }
                                }
                            }

                            // style 5: "typo" word clock
                            ColumnLayout {
                                visible: lockRoot.showClock && lockRoot.clockStyle === "typo"
                                Layout.alignment: Qt.AlignHCenter
                                spacing: -6

                                Text {
                                    text: lockRoot.numberToWords(clockBlock.displayHourNum)
                                    font.family: Theme.fontDisplay
                                    font.pixelSize: Math.round(56 * Theme.fontScale * lockRoot.clockScale)
                                    font.weight: Theme.fontWeightBold
                                    color: lockRoot.uiTextPrimary
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                Text {
                                    text: clockBlock.displayMinNum === 0
                                        ? lockRoot.fmtText("o'clock")
                                        : (clockBlock.displayMinNum < 10
                                            ? (lockRoot.fmtText("oh ") + lockRoot.numberToWords(clockBlock.displayMinNum))
                                            : lockRoot.numberToWords(clockBlock.displayMinNum))
                                    font.family: Theme.fontDisplay
                                    font.pixelSize: Math.round(48 * Theme.fontScale * lockRoot.clockScale)
                                    font.italic: true
                                    font.weight: Theme.fontWeightDemiBold
                                    color: lockRoot.uiAccent
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }

                            // style 6: "digital" terminal monospace readout
                            Rectangle {
                                visible: lockRoot.showClock && lockRoot.clockStyle === "digital"
                                Layout.alignment: Qt.AlignHCenter
                                implicitWidth: digRow.implicitWidth + 36
                                implicitHeight: digRow.implicitHeight + 24
                                radius: lockRoot.uiRadiusLg
                                color: lockRoot.uiCardBg
                                border.color: Theme.alpha(lockRoot.uiAccent, 0.55)
                                border.width: 1

                                RowLayout {
                                    id: digRow
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        text: clockBlock.mainHoursText + ":" + clockBlock.mainMinutesText + (lockRoot.effectiveShowSeconds ? (":" + clockBlock.secondsDigits) : "")
                                        font.family: Theme.fontMono
                                        font.pixelSize: Math.round(54 * Theme.fontScale * lockRoot.clockScale)
                                        font.weight: Theme.fontWeightBold
                                        color: lockRoot.uiAccent
                                    }

                                    Text {
                                        visible: !lockRoot.effectiveClock24h
                                        text: clockBlock.amPmText
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeSm
                                        font.weight: Theme.fontWeightBold
                                        color: lockRoot.uiTextSecondary
                                        Layout.alignment: Qt.AlignBottom
                                        Layout.bottomMargin: 8
                                    }
                                }
                            }

                            // style 7: "editorial" magazine weekday banner + time pill
                            ColumnLayout {
                                visible: lockRoot.showClock && lockRoot.clockStyle === "editorial"
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 6

                                Text {
                                    text: lockRoot.fmtText(Qt.formatDateTime(lockRoot.currentTime, "dddd"))
                                    font.family: Theme.fontDisplay
                                    font.pixelSize: Math.round(58 * Theme.fontScale * lockRoot.clockScale)
                                    font.weight: Theme.fontWeightBold
                                    color: lockRoot.uiTextPrimary
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                RowLayout {
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: 8

                                    Rectangle {
                                        height: 34
                                        implicitWidth: edTimeTxt.implicitWidth + 24
                                        radius: lockRoot.uiRadiusPill
                                        color: lockRoot.uiAccent

                                        Text {
                                            id: edTimeTxt
                                            anchors.centerIn: parent
                                            text: clockBlock.mainHoursText + ":" + clockBlock.mainMinutesText
                                                + (lockRoot.effectiveShowSeconds ? (":" + clockBlock.secondsDigits) : "")
                                                + (!lockRoot.effectiveClock24h ? (" " + clockBlock.amPmText) : "")
                                            font.family: Theme.fontMono
                                            font.pixelSize: Theme.fontSizeMd
                                            font.weight: Theme.fontWeightBold
                                            color: lockRoot.uiOnAccent
                                        }
                                    }

                                    Rectangle {
                                        visible: lockRoot.showDate
                                        height: 34
                                        implicitWidth: edDateTxt.implicitWidth + 24
                                        radius: lockRoot.uiRadiusPill
                                        color: lockRoot.uiPillBg
                                        border.color: lockRoot.uiPillBorder
                                        border.width: 1

                                        Text {
                                            id: edDateTxt
                                            anchors.centerIn: parent
                                            text: lockRoot.fmtText(Qt.formatDateTime(lockRoot.currentTime, "MMMM d, yyyy"))
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeSm
                                            font.weight: Theme.fontWeightDemiBold
                                            color: lockRoot.uiTextPrimary
                                        }
                                    }
                                }
                            }

                            // 60-second animated bar when secondsStyle === "tower"
                            RowLayout {
                                visible: lockRoot.showClock && lockRoot.clockStyle !== "stacked" && lockRoot.clockStyle !== "editorial" && lockRoot.effectiveShowSeconds && (lockRoot.secondsStyle === "tower" || lockRoot.clockStyle === "typo")
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 10

                                Rectangle {
                                    width: 150
                                    height: 8
                                    radius: lockRoot.uiRadiusPill
                                    color: lockRoot.uiPillBg
                                    border.color: lockRoot.uiPillBorder
                                    border.width: 1

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: Math.max(parent.height, parent.width * ((clockBlock.displaySecNum + 1) / 60.0))
                                        radius: lockRoot.uiRadiusPill
                                        color: lockRoot.uiAccent

                                        Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                                    }
                                }

                                Text {
                                    text: clockBlock.secondsDigits + "s" + (!lockRoot.effectiveClock24h ? (" • " + clockBlock.amPmText) : "")
                                    font.family: Theme.fontMono
                                    font.pixelSize: Math.max(12, Math.round(Theme.fontSizeSm * lockRoot.clockScale))
                                    font.weight: Theme.fontWeightBold
                                    color: lockRoot.uiAccent
                                }
                            }

                            Text {
                                visible: lockRoot.showDate && !lockRoot.dateAboveClock && lockRoot.clockStyle !== "editorial"
                                text: clockBlock.formattedDateText
                                font.family: Theme.fontDisplay
                                font.pixelSize: Theme.fontSizeMd
                                font.weight: Theme.fontWeightDemiBold
                                color: lockRoot.uiAccent
                                Layout.alignment: Qt.AlignHCenter
                            }

                            // quote pill
                            Rectangle {
                                visible: lockRoot.activeQuoteText !== ""
                                Layout.alignment: Qt.AlignHCenter
                                Layout.topMargin: 4
                                Layout.maximumWidth: centerStage.width - 16
                                implicitWidth: Math.min(centerStage.width - 16, quoteTxt.implicitWidth + 24)
                                implicitHeight: quoteTxt.implicitHeight + 12
                                radius: lockRoot.uiRadiusPill
                                color: quoteMouse.containsMouse ? lockRoot.uiPillHover : "transparent"
                                border.color: quoteMouse.containsMouse ? lockRoot.uiPillBorder : "transparent"
                                border.width: 1

                                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                Text {
                                    id: quoteTxt
                                    anchors.centerIn: parent
                                    width: Math.min(centerStage.width - 40, implicitWidth)
                                    text: "\"" + lockRoot.activeQuoteText + "\""
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeXs
                                    font.italic: true
                                    color: quoteMouse.containsMouse ? lockRoot.uiTextPrimary : lockRoot.uiTextSecondary
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                }

                                MouseArea {
                                    id: quoteMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        lockRoot.refreshQuotes();
                                        surface.claimSurfaceFocus();
                                    }
                                }
                            }
                        }

                        // mpris media player card + visualizer
