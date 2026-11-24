// LockClockCard.qml
import QtQuick
import QtQuick.Layouts
import ".."
import Quickshell

ColumnLayout {
    id: clockBlock

    property var root: null
    property var lockSurface: null
    property var stage: null

    visible: root.showClock || root.showDate || root.activeQuoteText !== ""
    width: parent.width
                            y: stage.blockY("clock")
                            spacing: 6

                            Behavior on y { NumberAnimation { duration: Theme.expressiveDefault; easing.type: Theme.animEasingEntrance } }

                            readonly property int baseClockPx: Math.round((root.clockStyle === "minimal" ? 56 : 86) * Theme.fontScale * root.clockScale)
                            readonly property int rawHours: root.currentTime.getHours()
                            readonly property int displayHourNum: root.effectiveClock24h ? rawHours : ((rawHours % 12) || 12)
                            readonly property int displayMinNum: root.currentTime.getMinutes()
                            readonly property int displaySecNum: root.currentTime.getSeconds()

                            readonly property string mainHoursText: (displayHourNum < 10 ? "0" : "") + displayHourNum
                            readonly property string mainMinutesText: (displayMinNum < 10 ? "0" : "") + displayMinNum
                            readonly property string secondsDigits: (displaySecNum < 10 ? "0" : "") + displaySecNum
                            readonly property string amPmText: root.fmtText(rawHours >= 12 ? "PM" : "AM")
                            readonly property string formattedDateText: root.fmtText(Qt.formatDateTime(root.currentTime, root.dateFormat))

                            Text {
                                visible: root.showDate && root.dateAboveClock && root.clockStyle !== "editorial"
                                text: clockBlock.formattedDateText
                                font.family: Theme.fontDisplay
                                font.pixelSize: Theme.fontSizeMd
                                font.weight: Theme.fontWeightDemiBold
                                color: root.uiAccent
                                Layout.alignment: Qt.AlignHCenter
                            }

                            // style 1 & 2: inline or minimal clock
                            RowLayout {
                                visible: root.showClock && (root.clockStyle === "inline" || root.clockStyle === "minimal")
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 10

                                Text {
                                    text: {
                                        let hm = clockBlock.mainHoursText + ":" + clockBlock.mainMinutesText;
                                        if (root.effectiveShowSeconds && root.secondsStyle === "inline") {
                                            return hm + ":" + clockBlock.secondsDigits + (!root.effectiveClock24h ? (" " + clockBlock.amPmText) : "");
                                        }
                                        if (!root.effectiveShowSeconds && !root.effectiveClock24h) {
                                            return hm + " " + clockBlock.amPmText;
                                        }
                                        return hm;
                                    }
                                    font.family: Theme.fontDisplay
                                    font.pixelSize: (root.effectiveShowSeconds && root.secondsStyle === "inline")
                                        ? Math.round(clockBlock.baseClockPx * 0.76)
                                        : clockBlock.baseClockPx
                                    font.weight: root.clockStyle === "minimal" ? Theme.fontWeightDemiBold : Theme.fontWeightBold
                                    color: root.uiTextPrimary
                                    Layout.alignment: Qt.AlignVCenter

                                    Behavior on font.pixelSize { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
                                }

                                ColumnLayout {
                                    visible: root.effectiveShowSeconds && root.secondsStyle === "badge"
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 4

                                    Rectangle {
                                        readonly property int badgeFontPx: Math.max(18, Math.round(clockBlock.baseClockPx * 0.38))
                                        height: badgeFontPx + 14
                                        implicitWidth: secBadgeTxt.implicitWidth + 20
                                        radius: root.uiRadiusMd
                                        color: root.uiAccentOverlay
                                        border.color: Theme.alpha(root.uiAccent, 0.55)
                                        border.width: 1

                                        Text {
                                            id: secBadgeTxt
                                            anchors.centerIn: parent
                                            text: clockBlock.secondsDigits
                                            font.family: Theme.fontMono
                                            font.pixelSize: parent.badgeFontPx
                                            font.weight: Theme.fontWeightBold
                                            color: root.uiAccent
                                        }
                                    }

                                    Text {
                                        visible: !root.effectiveClock24h
                                        text: clockBlock.amPmText
                                        font.family: Theme.fontMono
                                        font.pixelSize: Math.max(11, Math.round(clockBlock.baseClockPx * 0.18))
                                        font.weight: Theme.fontWeightBold
                                        color: root.uiTextSecondary
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                }

                                ColumnLayout {
                                    visible: root.effectiveShowSeconds && root.secondsStyle === "supersub"
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: -2

                                    Text {
                                        text: ":" + clockBlock.secondsDigits
                                        font.family: Theme.fontDisplay
                                        font.pixelSize: Math.max(20, Math.round(clockBlock.baseClockPx * 0.44))
                                        font.weight: Theme.fontWeightBold
                                        color: root.uiAccent
                                    }

                                    Text {
                                        visible: !root.effectiveClock24h
                                        text: clockBlock.amPmText
                                        font.family: Theme.fontMono
                                        font.pixelSize: Math.max(12, Math.round(clockBlock.baseClockPx * 0.22))
                                        font.weight: Theme.fontWeightBold
                                        color: root.uiTextSecondary
                                    }
                                }
                            }

                            // style 3: stacked m3 expressive clock
                            RowLayout {
                                visible: root.showClock && root.clockStyle === "stacked"
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 14

                                ColumnLayout {
                                    spacing: -20

                                    Text {
                                        text: clockBlock.mainHoursText
                                        font.family: Theme.fontDisplay
                                        font.pixelSize: Math.round(92 * Theme.fontScale * root.clockScale)
                                        font.weight: Theme.fontWeightBold
                                        color: root.uiTextPrimary
                                        Layout.alignment: Qt.AlignHCenter
                                    }

                                    Text {
                                        text: clockBlock.mainMinutesText
                                        font.family: Theme.fontDisplay
                                        font.pixelSize: Math.round(92 * Theme.fontScale * root.clockScale)
                                        font.weight: Theme.fontWeightBold
                                        color: root.uiAccent
                                        Layout.alignment: Qt.AlignHCenter
                                    }

                                    Text {
                                        visible: root.effectiveShowSeconds && root.secondsStyle === "tower"
                                        text: clockBlock.secondsDigits
                                        font.family: Theme.fontDisplay
                                        font.pixelSize: Math.round(92 * Theme.fontScale * root.clockScale)
                                        font.weight: Theme.fontWeightBold
                                        color: Theme.tertiary
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                }

                                ColumnLayout {
                                    visible: (root.effectiveShowSeconds && root.secondsStyle !== "tower") || !root.effectiveClock24h
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 8

                                    Rectangle {
                                        visible: !root.effectiveClock24h
                                        readonly property int amPx: Math.max(14, Math.round(22 * Theme.fontScale * root.clockScale))
                                        height: amPx + 14
                                        implicitWidth: stackAmTxt.implicitWidth + 18
                                        radius: root.uiRadiusMd
                                        color: root.uiPillBg
                                        border.color: root.uiPillBorder
                                        border.width: 1

                                        Text {
                                            id: stackAmTxt
                                            anchors.centerIn: parent
                                            text: clockBlock.amPmText
                                            font.family: Theme.fontMono
                                            font.pixelSize: parent.amPx
                                            font.weight: Theme.fontWeightBold
                                            color: root.uiTextSecondary
                                        }
                                    }

                                    Rectangle {
                                        visible: root.effectiveShowSeconds && root.secondsStyle !== "tower"
                                        readonly property int secPx: Math.max(22, Math.round(38 * Theme.fontScale * root.clockScale))
                                        height: secPx + 18
                                        implicitWidth: stackSecTxt.implicitWidth + 22
                                        radius: root.uiRadiusLg
                                        color: root.uiAccentOverlay
                                        border.color: Theme.alpha(root.uiAccent, 0.55)
                                        border.width: 1

                                        Text {
                                            id: stackSecTxt
                                            anchors.centerIn: parent
                                            text: ":" + clockBlock.secondsDigits
                                            font.family: Theme.fontMono
                                            font.pixelSize: parent.secPx
                                            font.weight: Theme.fontWeightBold
                                            color: root.uiAccent
                                        }
                                    }
                                }
                            }

                            // style 4: "split" twin squircle flip-cards
                            RowLayout {
                                visible: root.showClock && root.clockStyle === "split"
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 10

                                readonly property int cardSize: Math.round(108 * Theme.fontScale * root.clockScale)
                                readonly property int digitPx: Math.round(62 * Theme.fontScale * root.clockScale)

                                Rectangle {
                                    width: parent.cardSize
                                    height: parent.cardSize
                                    radius: root.uiRadiusXl
                                    color: root.uiCardBg
                                    border.color: Theme.alpha(root.uiAccent, 0.35)
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: clockBlock.mainHoursText
                                        font.family: Theme.fontDisplay
                                        font.pixelSize: parent.parent.digitPx
                                        font.weight: Theme.fontWeightBold
                                        color: root.uiTextPrimary
                                    }

                                    Text {
                                        visible: !root.effectiveClock24h
                                        anchors.bottom: parent.bottom
                                        anchors.right: parent.right
                                        anchors.margins: 8
                                        text: clockBlock.amPmText
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightBold
                                        color: root.uiAccent
                                    }
                                }

                                ColumnLayout {
                                    spacing: 10
                                    Layout.alignment: Qt.AlignVCenter
                                    Rectangle {
                                        width: 8; height: 8; radius: 4
                                        color: root.uiAccent
                                        opacity: (clockBlock.displaySecNum % 2 === 0) ? 1.0 : 0.35
                                        Behavior on opacity { NumberAnimation { duration: 250 } }
                                    }
                                    Rectangle {
                                        width: 8; height: 8; radius: 4
                                        color: root.uiAccent
                                        opacity: (clockBlock.displaySecNum % 2 === 0) ? 1.0 : 0.35
                                        Behavior on opacity { NumberAnimation { duration: 250 } }
                                    }
                                }

                                Rectangle {
                                    width: parent.cardSize
                                    height: parent.cardSize
                                    radius: root.uiRadiusXl
                                    color: Theme.blend(root.uiCardBg, root.uiAccent, 0.14)
                                    border.color: Theme.alpha(root.uiAccent, 0.55)
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: clockBlock.mainMinutesText
                                        font.family: Theme.fontDisplay
                                        font.pixelSize: parent.parent.digitPx
                                        font.weight: Theme.fontWeightBold
                                        color: root.uiAccent
                                    }

                                    Text {
                                        visible: root.effectiveShowSeconds
                                        anchors.bottom: parent.bottom
                                        anchors.right: parent.right
                                        anchors.margins: 8
                                        text: ":" + clockBlock.secondsDigits
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightBold
                                        color: root.uiTextSecondary
                                    }
                                }
                            }

                            // style 5: "typo" word clock
                            ColumnLayout {
                                visible: root.showClock && root.clockStyle === "typo"
                                Layout.alignment: Qt.AlignHCenter
                                spacing: -6

                                Text {
                                    text: root.numberToWords(clockBlock.displayHourNum)
                                    font.family: Theme.fontDisplay
                                    font.pixelSize: Math.round(56 * Theme.fontScale * root.clockScale)
                                    font.weight: Theme.fontWeightBold
                                    color: root.uiTextPrimary
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                Text {
                                    text: clockBlock.displayMinNum === 0
                                        ? root.fmtText("o'clock")
                                        : (clockBlock.displayMinNum < 10
                                            ? (root.fmtText("oh ") + root.numberToWords(clockBlock.displayMinNum))
                                            : root.numberToWords(clockBlock.displayMinNum))
                                    font.family: Theme.fontDisplay
                                    font.pixelSize: Math.round(48 * Theme.fontScale * root.clockScale)
                                    font.italic: true
                                    font.weight: Theme.fontWeightDemiBold
                                    color: root.uiAccent
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }

                            // style 6: "digital" terminal monospace readout
                            Rectangle {
                                visible: root.showClock && root.clockStyle === "digital"
                                Layout.alignment: Qt.AlignHCenter
                                implicitWidth: digRow.implicitWidth + 36
                                implicitHeight: digRow.implicitHeight + 24
                                radius: root.uiRadiusLg
                                color: root.uiCardBg
                                border.color: Theme.alpha(root.uiAccent, 0.55)
                                border.width: 1

                                RowLayout {
                                    id: digRow
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        text: clockBlock.mainHoursText + ":" + clockBlock.mainMinutesText + (root.effectiveShowSeconds ? (":" + clockBlock.secondsDigits) : "")
                                        font.family: Theme.fontMono
                                        font.pixelSize: Math.round(54 * Theme.fontScale * root.clockScale)
                                        font.weight: Theme.fontWeightBold
                                        color: root.uiAccent
                                    }

                                    Text {
                                        visible: !root.effectiveClock24h
                                        text: clockBlock.amPmText
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeSm
                                        font.weight: Theme.fontWeightBold
                                        color: root.uiTextSecondary
                                        Layout.alignment: Qt.AlignBottom
                                        Layout.bottomMargin: 8
                                    }
                                }
                            }

                            // style 7: "editorial" magazine weekday banner + time pill
                            ColumnLayout {
                                visible: root.showClock && root.clockStyle === "editorial"
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 6

                                Text {
                                    text: root.fmtText(Qt.formatDateTime(root.currentTime, "dddd"))
                                    font.family: Theme.fontDisplay
                                    font.pixelSize: Math.round(58 * Theme.fontScale * root.clockScale)
                                    font.weight: Theme.fontWeightBold
                                    color: root.uiTextPrimary
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                RowLayout {
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: 8

                                    Rectangle {
                                        height: 34
                                        implicitWidth: edTimeTxt.implicitWidth + 24
                                        radius: root.uiRadiusPill
                                        color: root.uiAccent

                                        Text {
                                            id: edTimeTxt
                                            anchors.centerIn: parent
                                            text: clockBlock.mainHoursText + ":" + clockBlock.mainMinutesText
                                                + (root.effectiveShowSeconds ? (":" + clockBlock.secondsDigits) : "")
                                                + (!root.effectiveClock24h ? (" " + clockBlock.amPmText) : "")
                                            font.family: Theme.fontMono
                                            font.pixelSize: Theme.fontSizeMd
                                            font.weight: Theme.fontWeightBold
                                            color: root.uiOnAccent
                                        }
                                    }

                                    Rectangle {
                                        visible: root.showDate
                                        height: 34
                                        implicitWidth: edDateTxt.implicitWidth + 24
                                        radius: root.uiRadiusPill
                                        color: root.uiPillBg
                                        border.color: root.uiPillBorder
                                        border.width: 1

                                        Text {
                                            id: edDateTxt
                                            anchors.centerIn: parent
                                            text: root.fmtText(Qt.formatDateTime(root.currentTime, "MMMM d, yyyy"))
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeSm
                                            font.weight: Theme.fontWeightDemiBold
                                            color: root.uiTextPrimary
                                        }
                                    }
                                }
                            }

                            // 60-second animated bar when secondsStyle === "tower"
                            RowLayout {
                                visible: root.showClock && root.clockStyle !== "stacked" && root.clockStyle !== "editorial" && root.effectiveShowSeconds && (root.secondsStyle === "tower" || root.clockStyle === "typo")
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 10

                                Rectangle {
                                    width: 150
                                    height: 8
                                    radius: root.uiRadiusPill
                                    color: root.uiPillBg
                                    border.color: root.uiPillBorder
                                    border.width: 1

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: Math.max(parent.height, parent.width * ((clockBlock.displaySecNum + 1) / 60.0))
                                        radius: root.uiRadiusPill
                                        color: root.uiAccent

                                        Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                                    }
                                }

                                Text {
                                    text: clockBlock.secondsDigits + "s" + (!root.effectiveClock24h ? (" • " + clockBlock.amPmText) : "")
                                    font.family: Theme.fontMono
                                    font.pixelSize: Math.max(12, Math.round(Theme.fontSizeSm * root.clockScale))
                                    font.weight: Theme.fontWeightBold
                                    color: root.uiAccent
                                }
                            }

                            Text {
                                visible: root.showDate && !root.dateAboveClock && root.clockStyle !== "editorial"
                                text: clockBlock.formattedDateText
                                font.family: Theme.fontDisplay
                                font.pixelSize: Theme.fontSizeMd
                                font.weight: Theme.fontWeightDemiBold
                                color: root.uiAccent
                                Layout.alignment: Qt.AlignHCenter
                            }

                            // quote pill
                            Rectangle {
                                visible: root.activeQuoteText !== ""
                                Layout.alignment: Qt.AlignHCenter
                                Layout.topMargin: 4
                                Layout.maximumWidth: stage.width - 16
                                implicitWidth: Math.min(stage.width - 16, quoteTxt.implicitWidth + 24)
                                implicitHeight: quoteTxt.implicitHeight + 12
                                radius: root.uiRadiusPill
                                color: quoteMouse.containsMouse ? root.uiPillHover : "transparent"
                                border.color: quoteMouse.containsMouse ? root.uiPillBorder : "transparent"
                                border.width: 1

                                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                Text {
                                    id: quoteTxt
                                    anchors.centerIn: parent
                                    width: Math.min(stage.width - 40, implicitWidth)
                                    text: root.activeQuoteText
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeXs
                                    font.italic: root.quoteMode === "quotes" || root.quoteMode === "custom"
                                    color: quoteMouse.containsMouse ? root.uiTextPrimary : root.uiTextSecondary
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                }

                                MouseArea {
                                    id: quoteMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.refreshQuotes();
                                        lockSurface.claimSurfaceFocus();
                                    }
                                }
                            }
                        }
