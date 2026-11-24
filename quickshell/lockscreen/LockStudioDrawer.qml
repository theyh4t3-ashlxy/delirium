// LockStudioDrawer.qml
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import ".."
import "../controls"

Rectangle {
    id: optionsCard

    required property var lockRoot
    required property var surface
    property var statusBar: null
    property var pwInput: null
    property var surpriseBurstAnim: null

                component OptChip: Rectangle {
                    id: cRoot
                    property string label: ""
                    property string icon: ""
                    property bool selected: false
                    signal clicked()

                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    radius: selected ? lockRoot.uiRadiusMd : lockRoot.uiRadiusPill
                    opacity: lockRoot.studioLocked ? 0.55 : 1.0
                    color: selected
                        ? lockRoot.uiAccentOverlay
                        : (cMouse.pressed ? lockRoot.uiWidgetActive : (cMouse.containsMouse ? lockRoot.uiWidgetHover : lockRoot.uiWidgetBg))
                    border.color: selected
                        ? Theme.alpha(lockRoot.uiAccent, 0.65)
                        : (cMouse.containsMouse ? Theme.alpha(lockRoot.uiAccent, 0.35) : lockRoot.uiWidgetBorder)
                    border.width: 1

                    Behavior on radius { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
                    Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            visible: cRoot.icon !== ""
                            text: cRoot.icon
                            font.family: Theme.fontIcon
                            font.pixelSize: Theme.fontSizeXs
                            color: cRoot.selected ? lockRoot.uiAccent : lockRoot.uiTextSecondary
                        }

                        Text {
                            text: lockRoot.fmtText(cRoot.label)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: cRoot.selected ? Theme.fontWeightBold : Theme.fontWeightMedium
                            color: cRoot.selected ? lockRoot.uiAccent : lockRoot.uiTextSecondary
                        }
                    }

                    MouseArea {
                        id: cMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !lockRoot.studioLocked
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                        onClicked: {
                            cRoot.clicked();
                            surface.claimSurfaceFocus();
                        }
                    }
                }

                component SandboxSlider: ColumnLayout {
                    id: sRoot
                    property string label: ""
                    property string icon: ""
                    property real from: 0.0
                    property real to: 1.0
                    property real value: 0.5
                    property real stepSize: 0.02
                    property string displayText: Math.round(value * 100) + "%"
                    signal moved(real newValue)

                    Layout.fillWidth: true
                    spacing: 5
                    opacity: lockRoot.studioLocked ? 0.55 : 1.0

                    readonly property real ratio: Math.max(0.0, Math.min(1.0, (value - from) / Math.max(0.0001, to - from)))

                    function setFromRatio(r: real) {
                        if (lockRoot.studioLocked) return;
                        let clamped = Math.max(0.0, Math.min(1.0, r));
                        let raw = from + clamped * (to - from);
                        if (stepSize > 0) {
                            raw = Math.round(raw / stepSize) * stepSize;
                        }
                        let finalVal = Math.max(from, Math.min(to, raw));
                        sRoot.moved(finalVal);
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            visible: sRoot.icon !== ""
                            text: sRoot.icon
                            font.family: Theme.fontIcon
                            font.pixelSize: Theme.fontSizeXs
                            color: sMouse.pressed || sMouse.containsMouse ? lockRoot.uiAccent : lockRoot.uiTextSecondary
                        }

                        Text {
                            text: lockRoot.fmtText(sRoot.label)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: Theme.fontWeightDemiBold
                            color: lockRoot.uiTextSecondary
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            height: 18
                            implicitWidth: valTxt.implicitWidth + 10
                            radius: lockRoot.uiRadiusPill
                            color: sMouse.pressed ? lockRoot.uiAccentOverlay : lockRoot.uiWidgetBg
                            border.color: sMouse.pressed ? Theme.alpha(lockRoot.uiAccent, 0.5) : lockRoot.uiWidgetBorder
                            border.width: 1

                            Text {
                                id: valTxt
                                anchors.centerIn: parent
                                text: sRoot.displayText
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeXs
                                font.weight: Theme.fontWeightBold
                                color: lockRoot.uiAccent
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 20

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: sMouse.pressed ? 14 : (sMouse.containsMouse ? 12 : 8)
                            radius: lockRoot.uiRadiusPill
                            color: lockRoot.uiWidgetBg
                            border.color: sMouse.containsMouse ? Theme.alpha(lockRoot.uiAccent, 0.35) : lockRoot.uiWidgetBorder
                            border.width: 1

                            Behavior on height { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
                            Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: Math.max(parent.height, parent.width * sRoot.ratio)
                                radius: lockRoot.uiRadiusPill
                                color: sMouse.pressed
                                    ? Theme.statePress(lockRoot.uiAccent, lockRoot.uiOnAccent)
                                    : (sMouse.containsMouse ? Theme.stateHover(lockRoot.uiAccent, lockRoot.uiOnAccent) : lockRoot.uiAccent)

                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            }
                        }

                        Rectangle {
                            width: sMouse.pressed ? 6 : 4
                            height: sMouse.pressed ? 20 : (sMouse.containsMouse ? 18 : 14)
                            radius: lockRoot.uiRadiusPill
                            color: lockRoot.uiTextPrimary
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.max(0, Math.min(parent.width - width, (parent.width * sRoot.ratio) - (width / 2)))

                            Behavior on width { NumberAnimation { duration: Theme.animFast } }
                            Behavior on height { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animExpressiveEasing } }
                        }

                        MouseArea {
                            id: sMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !lockRoot.studioLocked
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                            onPressed: (mouse) => sRoot.setFromRatio(mouse.x / width)
                            onPositionChanged: (mouse) => {
                                if (pressed) sRoot.setFromRatio(mouse.x / width);
                            }
                            onReleased: surface.claimSurfaceFocus()
                            onWheel: (wheel) => {
                                let dir = wheel.angleDelta.y > 0 ? 1 : -1;
                                let next = Math.max(sRoot.from, Math.min(sRoot.to, sRoot.value + (dir * sRoot.stepSize)));
                                sRoot.moved(next);
                            }
                        }
                    }
                }

                component SandboxToggleRow: Rectangle {
                    id: tRow
                    property string icon: ""
                    property string label: ""
                    property bool checked: false
                    signal toggled()

                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: lockRoot.uiRadiusSm
                    opacity: lockRoot.studioLocked ? 0.55 : 1.0
                    color: rowMouse.containsMouse ? lockRoot.uiWidgetHover : "transparent"

                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        spacing: 10

                        Text {
                            text: tRow.icon
                            font.family: Theme.fontIcon
                            font.pixelSize: Theme.fontSizeMd
                            color: tRow.checked ? lockRoot.uiAccent : lockRoot.uiTextSecondary
                            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
                        }

                        Text {
                            text: lockRoot.fmtText(tRow.label)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            color: lockRoot.uiTextPrimary
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        ToggleSwitch {
                            id: sw
                            enabled: false
                            checked: tRow.checked

                            Binding {
                                target: sw
                                property: "checked"
                                value: tRow.checked
                            }
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !lockRoot.studioLocked
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                        onClicked: {
                            tRow.toggled();
                            surface.claimSurfaceFocus();
                        }
                    }
                }

                        anchors.top: statusBar ? statusBar.bottom : parent.top
                        anchors.right: statusBar ? statusBar.right : parent.right
                        anchors.topMargin: 10
                        width: 380
                        height: Math.min(parent.height - 110, optionsLayout.implicitHeight + (Theme.popupPadding * 2))
                        radius: lockRoot.uiRadiusLg
                        color: lockRoot.uiPopupBg
                        border.color: lockRoot.uiPopupBorder
                        border.width: Theme.popupBorderWidth
                        visible: opacity > 0.01 && !lockRoot.zenMode
                        opacity: surface.optionsOpen ? 1.0 : 0.0
                        scale: surface.optionsOpen ? 1.0 : 0.95
                        transformOrigin: Item.TopRight
                        clip: true
                        z: 100

                        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.animEasing } }
                        Behavior on scale { NumberAnimation { duration: Theme.expressiveFast; easing.type: Theme.animEasingEntrance } }
                        Behavior on height { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
                        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                        }

                        Flickable {
                            anchors.fill: parent
                            anchors.margins: Theme.popupPadding
                            contentHeight: optionsLayout.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            ColumnLayout {
                                id: optionsLayout
                                width: parent.width
                                spacing: Theme.popupSpacing

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: Theme.iconSliders
                                        font.family: Theme.fontIcon
                                        font.pixelSize: Theme.fontSizeMd
                                        color: lockRoot.uiAccent
                                    }

                                    Text {
                                        text: lockRoot.fmtText("lock screen studio")
                                        font.family: Theme.fontDisplay
                                        font.pixelSize: Theme.fontSizeMd
                                        font.weight: Theme.fontWeightBold
                                        color: lockRoot.uiTextPrimary
                                        Layout.fillWidth: true
                                    }

                                    IconButton {
                                        icon: lockRoot.studioLocked ? Theme.iconLock : Theme.iconShield
                                        iconSize: Theme.fontSizeXs
                                        highlighted: lockRoot.studioLocked
                                        tooltip: lockRoot.studioLocked ? "unlock studio controls" : "lock studio controls"
                                        onClicked: {
                                            lockRoot.studioLocked = !lockRoot.studioLocked;
                                            lockRoot.flushStateToDisk();
                                            surface.claimSurfaceFocus();
                                        }
                                    }

                                    IconButton {
                                        icon: Theme.iconRefresh
                                        iconSize: Theme.fontSizeXs
                                        enabled: !lockRoot.studioLocked
                                        tooltip: "reset defaults"
                                        onClicked: {
                                            lockRoot.resetDefaults();
                                            surface.claimSurfaceFocus();
                                        }
                                    }

                                    IconButton {
                                        icon: Theme.iconClose
                                        iconSize: Theme.fontSizeXs
                                        tooltip: "close"
                                        onClicked: {
                                            surface.optionsOpen = false;
                                            if (pwInput) pwInput.forceActiveFocus(); else surface.claimSurfaceFocus();;
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 36
                                    opacity: lockRoot.studioLocked ? 0.5 : 1.0
                                    radius: surpriseMouse.pressed ? lockRoot.uiRadiusPill : lockRoot.uiRadiusMd
                                    color: surpriseMouse.pressed
                                        ? Theme.statePress(lockRoot.uiAccent, lockRoot.uiOnAccent)
                                        : (surpriseMouse.containsMouse
                                            ? Theme.stateHover(lockRoot.uiAccent, lockRoot.uiOnAccent)
                                            : lockRoot.uiAccent)

                                    Behavior on radius { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
                                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 8

                                        Text {
                                            text: Theme.iconSparkles
                                            font.family: Theme.fontIcon
                                            font.pixelSize: Theme.fontSizeMd
                                            color: lockRoot.uiOnAccent
                                        }

                                        Text {
                                            text: lockRoot.fmtText("surprise me! (roll layout & vibe)")
                                            font.family: Theme.fontDisplay
                                            font.pixelSize: Theme.fontSizeXs
                                            font.weight: Theme.fontWeightBold
                                            color: lockRoot.uiOnAccent
                                        }
                                    }

                                    MouseArea {
                                        id: surpriseMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        enabled: !lockRoot.studioLocked
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                                        onClicked: {
                                            surpriseBurstAnim.restart();
                                            lockRoot.surpriseMe();
                                            surface.claimSurfaceFocus();
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 5

                                    Repeater {
                                        model: [
                                            { id: "layout",  label: "layout",  icon: Theme.iconGrid },
                                            { id: "clock",   label: "clock",   icon: Theme.iconClock },
                                            { id: "vibe",    label: "vibe",    icon: Theme.iconPalette },
                                            { id: "widgets", label: "widgets", icon: Theme.iconSettings }
                                        ]
                                        delegate: OptChip {
                                            required property var modelData
                                            label: modelData.label
                                            icon: modelData.icon
                                            selected: lockRoot.studioTab === modelData.id
                                            onClicked: lockRoot.studioTab = modelData.id
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: Theme.popupDividerHeight
                                    color: lockRoot.uiWidgetBorder
                                }

                                // tab 1: presets, position, stack order, stage width, corner shape
                                ColumnLayout {
                                    visible: lockRoot.studioTab === "layout"
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: lockRoot.fmtText("quick presets")
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightDemiBold
                                        color: lockRoot.uiTextSecondary
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Repeater {
                                            model: ["expressive", "cards", "editorial", "cyber", "minimal"]
                                            delegate: OptChip {
                                                required property string modelData
                                                label: modelData
                                                selected: false
                                                onClicked: {
                                                    surpriseBurstAnim.restart();
                                                    lockRoot.applyPreset(modelData);
                                                }
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text {
                                            text: lockRoot.fmtText("screen position")
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeXs
                                            font.weight: Theme.fontWeightDemiBold
                                            color: lockRoot.uiTextSecondary
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            visible: lockRoot.layoutPosition === "custom"
                                            text: Math.round(lockRoot.customNormX * 100) + "% , " + Math.round(lockRoot.customNormY * 100) + "%"
                                            font.family: Theme.fontMono
                                            font.pixelSize: Theme.fontSizeXs
                                            color: lockRoot.uiAccent
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 5

                                        Repeater {
                                            model: ["left", "top", "center", "bottom", "right"]
                                            delegate: OptChip {
                                                required property string modelData
                                                label: modelData
                                                selected: lockRoot.layoutPosition === modelData
                                                onClicked: {
                                                    lockRoot.layoutPosition = modelData;
                                                    lockRoot.saveSandbox();
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        text: lockRoot.fmtText("block stack order")
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightDemiBold
                                        color: lockRoot.uiTextSecondary
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Repeater {
                                            model: [
                                                { ord: "clock,media,password", lbl: "clk•med•pw" },
                                                { ord: "clock,password,media", lbl: "clk•pw•med" },
                                                { ord: "media,clock,password", lbl: "med•clk•pw" },
                                                { ord: "password,clock,media", lbl: "pw•clk•med" }
                                            ]
                                            delegate: OptChip {
                                                required property var modelData
                                                label: modelData.lbl
                                                selected: lockRoot.stackOrder === modelData.ord
                                                onClicked: {
                                                    lockRoot.stackOrder = modelData.ord;
                                                    lockRoot.saveSandbox();
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        text: lockRoot.fmtText("corner shape style")
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightDemiBold
                                        color: lockRoot.uiTextSecondary
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 5

                                        Repeater {
                                            model: ["theme", "pill", "squircle", "sharp"]
                                            delegate: OptChip {
                                                required property string modelData
                                                label: modelData
                                                selected: lockRoot.shapePreset === modelData
                                                onClicked: {
                                                    lockRoot.shapePreset = modelData;
                                                    lockRoot.saveSandbox();
                                                }
                                            }
                                        }
                                    }

                                    SandboxSlider {
                                        label: "stage width"
                                        icon: Theme.iconExpand
                                        from: 340
                                        to: 620
                                        stepSize: 8
                                        value: lockRoot.stageWidth
                                        displayText: Math.round(lockRoot.stageWidth) + "px"
                                        onMoved: (v) => {
                                            lockRoot.stageWidth = Math.round(v);
                                            lockRoot.saveSandbox();
                                        }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconGrid
                                        label: "free drag mode (snap guides + arrow keys)"
                                        checked: lockRoot.freeDragMode
                                        onToggled: lockRoot.freeDragMode = !lockRoot.freeDragMode
                                    }
                                }

                                // tab 2: clock design, date format, text casing, password mask
                                ColumnLayout {
                                    visible: lockRoot.studioTab === "clock"
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: lockRoot.fmtText("clock architecture")
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightDemiBold
                                        color: lockRoot.uiTextSecondary
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Repeater {
                                            model: ["inline", "stacked", "split", "typo"]
                                            delegate: OptChip {
                                                required property string modelData
                                                label: modelData
                                                selected: lockRoot.clockStyle === modelData
                                                onClicked: {
                                                    lockRoot.clockStyle = modelData;
                                                    lockRoot.saveSandbox();
                                                }
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Repeater {
                                            model: ["digital", "editorial", "minimal"]
                                            delegate: OptChip {
                                                required property string modelData
                                                label: modelData
                                                selected: lockRoot.clockStyle === modelData
                                                onClicked: {
                                                    lockRoot.clockStyle = modelData;
                                                    lockRoot.saveSandbox();
                                                }
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        OptChip {
                                            label: "12-hour"
                                            selected: !lockRoot.effectiveClock24h
                                            onClicked: {
                                                lockRoot.sandboxClock24h = false;
                                                lockRoot.saveSandbox();
                                            }
                                        }
                                        OptChip {
                                            label: "24-hour"
                                            selected: lockRoot.effectiveClock24h
                                            onClicked: {
                                                lockRoot.sandboxClock24h = true;
                                                lockRoot.saveSandbox();
                                            }
                                        }
                                        OptChip {
                                            label: "seconds"
                                            selected: lockRoot.effectiveShowSeconds
                                            onClicked: {
                                                lockRoot.showSeconds = !lockRoot.showSeconds;
                                                lockRoot.saveSandbox();
                                            }
                                        }
                                    }

                                    RowLayout {
                                        visible: lockRoot.effectiveShowSeconds
                                        Layout.fillWidth: true
                                        spacing: 5

                                        OptChip {
                                            label: "pill"
                                            selected: lockRoot.secondsStyle === "badge"
                                            onClicked: { lockRoot.secondsStyle = "badge"; lockRoot.saveSandbox(); }
                                        }
                                        OptChip {
                                            label: "split"
                                            selected: lockRoot.secondsStyle === "supersub"
                                            onClicked: { lockRoot.secondsStyle = "supersub"; lockRoot.saveSandbox(); }
                                        }
                                        OptChip {
                                            label: "bar"
                                            selected: lockRoot.secondsStyle === "tower"
                                            onClicked: { lockRoot.secondsStyle = "tower"; lockRoot.saveSandbox(); }
                                        }
                                        OptChip {
                                            label: "inline"
                                            selected: lockRoot.secondsStyle === "inline"
                                            onClicked: { lockRoot.secondsStyle = "inline"; lockRoot.saveSandbox(); }
                                        }
                                    }

                                    Text {
                                        text: lockRoot.fmtText("date format")
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightDemiBold
                                        color: lockRoot.uiTextSecondary
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Repeater {
                                            model: [
                                                { fmt: "dddd, MMMM d", lbl: "full" },
                                                { fmt: "ddd, MMM d",   lbl: "short" },
                                                { fmt: "yyyy-MM-dd",   lbl: "iso" },
                                                { fmt: "dd.MM.yyyy",   lbl: "eu" },
                                                { fmt: "MM/dd/yyyy",   lbl: "us" }
                                            ]
                                            delegate: OptChip {
                                                required property var modelData
                                                label: modelData.lbl
                                                selected: lockRoot.dateFormat === modelData.fmt
                                                onClicked: {
                                                    lockRoot.dateFormat = modelData.fmt;
                                                    lockRoot.saveSandbox();
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        text: lockRoot.fmtText("text casing (follow user preference)")
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightDemiBold
                                        color: lockRoot.uiTextSecondary
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 5

                                        Repeater {
                                            model: [
                                                { id: "lower",  lbl: "lowercase" },
                                                { id: "normal", lbl: "Normal" },
                                                { id: "upper",  lbl: "UPPER" }
                                            ]
                                            delegate: OptChip {
                                                required property var modelData
                                                label: modelData.lbl
                                                selected: lockRoot.textCase === modelData.id
                                                onClicked: {
                                                    lockRoot.textCase = modelData.id;
                                                    lockRoot.saveSandbox();
                                                }
                                            }
                                        }
                                    }

                                    SandboxSlider {
                                        label: "clock scale"
                                        icon: Theme.iconClock
                                        from: 0.70
                                        to: 1.50
                                        stepSize: 0.03
                                        value: lockRoot.clockScale
                                        displayText: Math.round(lockRoot.clockScale * 100) + "%"
                                        onMoved: (v) => {
                                            lockRoot.clockScale = v;
                                            lockRoot.saveSandbox();
                                        }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconCalendar
                                        label: "place date above clock"
                                        checked: lockRoot.dateAboveClock
                                        onToggled: {
                                            lockRoot.dateAboveClock = !lockRoot.dateAboveClock;
                                            lockRoot.saveSandbox();
                                        }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconClock
                                        label: "sync clock format across rice"
                                        checked: lockRoot.syncClockGlobal
                                        onToggled: {
                                            lockRoot.syncClockGlobal = !lockRoot.syncClockGlobal;
                                            lockRoot.saveSandbox();
                                        }
                                    }
                                }

                                // tab 3: theme mode, atmosphere, custom quote, password mask
                                ColumnLayout {
                                    visible: lockRoot.studioTab === "vibe"
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: lockRoot.fmtText("theme mode (" + (lockRoot.isLight ? "light" : "dark") + ")")
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightDemiBold
                                        color: lockRoot.uiTextSecondary
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 5

                                        OptChip {
                                            label: "auto"
                                            icon: Theme.iconSparkles
                                            selected: lockRoot.backdropMode === "auto"
                                            onClicked: { lockRoot.backdropMode = "auto"; lockRoot.saveSandbox(); }
                                        }
                                        OptChip {
                                            label: "dark"
                                            icon: Theme.iconMoon
                                            selected: lockRoot.backdropMode === "dark"
                                            onClicked: { lockRoot.backdropMode = "dark"; lockRoot.saveSandbox(); }
                                        }
                                        OptChip {
                                            label: "light"
                                            icon: Theme.iconSun
                                            selected: lockRoot.backdropMode === "light"
                                            onClicked: { lockRoot.backdropMode = "light"; lockRoot.saveSandbox(); }
                                        }
                                    }

                                    SandboxSlider {
                                        label: lockRoot.isLight ? "frost wash intensity" : "backdrop dim"
                                        icon: lockRoot.isLight ? Theme.iconSun : Theme.iconMoon
                                        from: 0.05
                                        to: 0.95
                                        stepSize: 0.02
                                        value: lockRoot.scrimDim
                                        displayText: Math.round(lockRoot.scrimDim * 100) + "%"
                                        onMoved: (v) => {
                                            lockRoot.scrimDim = v;
                                            lockRoot.saveSandbox();
                                        }
                                    }

                                    SandboxSlider {
                                        label: "card & pill opacity boost"
                                        icon: Theme.iconPalette
                                        from: -0.35
                                        to: 0.35
                                        stepSize: 0.05
                                        value: lockRoot.cardOpacityBoost
                                        displayText: (lockRoot.cardOpacityBoost >= 0 ? "+" : "") + Math.round(lockRoot.cardOpacityBoost * 100) + "%"
                                        onMoved: (v) => {
                                            lockRoot.cardOpacityBoost = v;
                                            lockRoot.saveSandbox();
                                        }
                                    }

                                    SandboxSlider {
                                        label: "cinematic vignette"
                                        icon: Theme.iconEye
                                        from: 0.0
                                        to: 0.85
                                        stepSize: 0.05
                                        value: lockRoot.vignetteStrength
                                        displayText: Math.round(lockRoot.vignetteStrength * 100) + "%"
                                        onMoved: (v) => {
                                            lockRoot.vignetteStrength = v;
                                            lockRoot.saveSandbox();
                                        }
                                    }

                                    SandboxSlider {
                                        label: "focus depth zoom"
                                        icon: Theme.iconExpand
                                        from: 1.00
                                        to: 1.18
                                        stepSize: 0.01
                                        value: lockRoot.focusZoom
                                        displayText: Math.round((lockRoot.focusZoom - 1.0) * 100) + "%"
                                        onMoved: (v) => {
                                            lockRoot.focusZoom = v;
                                            lockRoot.saveSandbox();
                                        }
                                    }

                                    Text {
                                        text: lockRoot.fmtText("password mask character")
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightDemiBold
                                        color: lockRoot.uiTextSecondary
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Repeater {
                                            model: [
                                                { ch: "•",    lbl: "dot •" },
                                                { ch: "*",    lbl: "star *" },
                                                { ch: "✦",    lbl: "spark ✦" },
                                                { ch: "▪",    lbl: "block ▪" },
                                                { ch: "none", lbl: "stealth" }
                                            ]
                                            delegate: OptChip {
                                                required property var modelData
                                                label: modelData.lbl
                                                selected: lockRoot.pwMaskChar === modelData.ch
                                                onClicked: {
                                                    lockRoot.pwMaskChar = modelData.ch;
                                                    lockRoot.saveSandbox();
                                                }
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text {
                                            text: lockRoot.fmtText("quote / greeting source")
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeXs
                                            font.weight: Theme.fontWeightDemiBold
                                            color: lockRoot.uiTextSecondary
                                            Layout.fillWidth: true
                                        }
                                        IconButton {
                                            icon: Theme.iconRefresh
                                            iconSize: Theme.fontSizeXs
                                            tooltip: "roll new quote"
                                            visible: lockRoot.quoteMode !== "off" && lockRoot.quoteMode !== "custom"
                                            onClicked: lockRoot.refreshQuotes()
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Repeater {
                                            model: ["smart", "hyprland", "unhinged", "custom", "off"]
                                            delegate: OptChip {
                                                required property string modelData
                                                label: modelData
                                                selected: lockRoot.quoteMode === modelData
                                                onClicked: {
                                                    lockRoot.quoteMode = modelData;
                                                    lockRoot.refreshQuotes();
                                                    lockRoot.saveSandbox();
                                                }
                                            }
                                        }
                                    }

                                    // custom quote input box when quoteMode === "custom"
                                    Rectangle {
                                        visible: lockRoot.quoteMode === "custom"
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 34
                                        radius: lockRoot.uiRadiusMd
                                        color: lockRoot.uiWidgetBg
                                        border.color: customQuoteInput.activeFocus ? lockRoot.uiAccent : lockRoot.uiWidgetBorder
                                        border.width: 1

                                        TextInput {
                                            id: customQuoteInput
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            verticalAlignment: TextInput.AlignVCenter
                                            text: lockRoot.customQuoteText
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeXs
                                            color: lockRoot.uiTextPrimary
                                            clip: true
                                            onTextEdited: {
                                                lockRoot.customQuoteText = text;
                                                lockRoot.saveSandbox();
                                            }
                                            onAccepted: if (pwInput) pwInput.forceActiveFocus(); else surface.claimSurfaceFocus();
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: Theme.popupActionHeight + 2
                                        radius: lockRoot.uiRadiusMd
                                        opacity: lockRoot.studioLocked ? 0.5 : 1.0
                                        color: shuffleMouse.pressed
                                            ? lockRoot.uiWidgetActive
                                            : (shuffleMouse.containsMouse ? lockRoot.uiWidgetHover : lockRoot.uiWidgetBg)
                                        border.color: shuffleMouse.containsMouse ? Theme.alpha(lockRoot.uiAccent, 0.55) : lockRoot.uiWidgetBorder
                                        border.width: 1

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 12
                                            spacing: 8

                                            Text {
                                                text: Theme.iconShuffle
                                                font.family: Theme.fontIcon
                                                font.pixelSize: Theme.fontSizeMd
                                                color: lockRoot.uiAccent
                                            }
                                            Text {
                                                text: lockRoot.fmtText("shuffle lock wallpaper")
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeXs
                                                font.weight: Theme.fontWeightDemiBold
                                                color: lockRoot.uiTextPrimary
                                                Layout.fillWidth: true
                                            }
                                        }

                                        MouseArea {
                                            id: shuffleMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            enabled: !lockRoot.studioLocked
                                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                                            onClicked: {
                                                let nextWp = lockRoot.pickRandomWallpaperInMemory();
                                                if (nextWp && nextWp !== "") {
                                                    lockRoot.wallpaperSync = false;
                                                    lockRoot.localWallpaperOverride = nextWp;
                                                    lockRoot.saveSandbox();
                                                }
                                                surface.claimSurfaceFocus();
                                            }
                                        }
                                    }
                                }

                                // tab 4: modular widget visibility (nothing forced!)
                                ColumnLayout {
                                    visible: lockRoot.studioTab === "widgets"
                                    Layout.fillWidth: true
                                    spacing: 2

                                    SandboxToggleRow {
                                        icon: Theme.iconClock
                                        label: "show clock readout"
                                        checked: lockRoot.showClock
                                        onToggled: { lockRoot.showClock = !lockRoot.showClock; lockRoot.saveSandbox(); }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconCalendar
                                        label: "show date label"
                                        checked: lockRoot.showDate
                                        onToggled: { lockRoot.showDate = !lockRoot.showDate; lockRoot.saveSandbox(); }
                                    }

                                    SandboxToggleRow {
                                        icon: lockRoot.showMediaCard ? Theme.iconMusic : Theme.iconEyeOff
                                        label: "show now playing media card"
                                        checked: lockRoot.showMediaCard
                                        onToggled: { lockRoot.showMediaCard = !lockRoot.showMediaCard; lockRoot.saveSandbox(); }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconEqualizer
                                        label: "media spectrum & seekbar"
                                        checked: lockRoot.showMediaVisualizer
                                        onToggled: { lockRoot.showMediaVisualizer = !lockRoot.showMediaVisualizer; lockRoot.saveSandbox(); }
                                    }

                                    SandboxToggleRow {
                                        icon: lockRoot.showUserPill ? Theme.iconUser : Theme.iconEyeOff
                                        label: "show top-left user & timer pill"
                                        checked: lockRoot.showUserPill
                                        onToggled: { lockRoot.showUserPill = !lockRoot.showUserPill; lockRoot.saveSandbox(); }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconSliders
                                        label: "show top-right status bar (hover corner if off)"
                                        checked: lockRoot.showStatusBar
                                        onToggled: { lockRoot.showStatusBar = !lockRoot.showStatusBar; lockRoot.saveSandbox(); }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconVolHigh
                                        label: "show system volume in top bar"
                                        checked: lockRoot.showSystemVol
                                        onToggled: { lockRoot.showSystemVol = !lockRoot.showSystemVol; lockRoot.saveSandbox(); }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconPower
                                        label: "show bottom power dock"
                                        checked: lockRoot.showPowerDock
                                        onToggled: { lockRoot.showPowerDock = !lockRoot.showPowerDock; lockRoot.saveSandbox(); }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconShield
                                        label: "2-step confirmation on power buttons"
                                        checked: lockRoot.confirmPowerActions
                                        onToggled: { lockRoot.confirmPowerActions = !lockRoot.confirmPowerActions; lockRoot.saveSandbox(); }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconLogout
                                        label: "include logout button in power dock"
                                        checked: lockRoot.allowLogoutOnLock
                                        onToggled: { lockRoot.allowLogoutOnLock = !lockRoot.allowLogoutOnLock; lockRoot.saveSandbox(); }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconSparkles
                                        label: "ambient audio-reactive glow orbs"
                                        checked: lockRoot.ambientOrbs
                                        onToggled: { lockRoot.ambientOrbs = !lockRoot.ambientOrbs; lockRoot.saveSandbox(); }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconMusic
                                        label: "album art backdrop when playing"
                                        checked: lockRoot.albumArtBackdrop
                                        onToggled: { lockRoot.albumArtBackdrop = !lockRoot.albumArtBackdrop; lockRoot.saveSandbox(); }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconWallpaper
                                        label: "sync wallpaper with desktop"
                                        checked: lockRoot.wallpaperSync
                                        onToggled: {
                                            lockRoot.wallpaperSync = !lockRoot.wallpaperSync;
                                            if (lockRoot.wallpaperSync) lockRoot.localWallpaperOverride = "";
                                            lockRoot.saveSandbox();
                                        }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconCrop
                                        label: "show concave screen corners"
                                        checked: lockRoot.showScreenCorners
                                        onToggled: { lockRoot.showScreenCorners = !lockRoot.showScreenCorners; lockRoot.saveSandbox(); }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconMoon
                                        label: "auto-zen screensaver after 30s idle"
                                        checked: lockRoot.autoZenIdle
                                        onToggled: { lockRoot.autoZenIdle = !lockRoot.autoZenIdle; lockRoot.saveSandbox(); }
                                    }
                                }
                            }
                        }
                    }
