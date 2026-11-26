// LockStudioDrawer.qml
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import ".."
import "../controls"
import "../services"

Rectangle {
    id: optionsCard

    property var root: null
    property var lockSurface: null
    property var statusBarItem: null
    property var burstAnim: null

    function fmtIdleSecs(sec: int): string {
        let s = Math.max(0, Math.round(sec));
        if (s < 60) return s + "s";
        let m = Math.floor(s / 60);
        let rem = s % 60;
        return rem === 0 ? (m + "m") : (m + "m " + rem + "s");
    }

    readonly property bool hasInputFocus: customQuoteInput.activeFocus

                component OptChip: Rectangle {
                    id: cRoot
                    property string label: ""
                    property string icon: ""
                    property bool selected: false
                    signal clicked()

                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    radius: selected ? root.uiRadiusMd : root.uiRadiusPill
                    opacity: root.studioLocked ? 0.55 : 1.0
                    color: selected
                        ? root.uiAccentOverlay
                        : (cMouse.pressed ? root.uiWidgetActive : (cMouse.containsMouse ? root.uiWidgetHover : root.uiWidgetBg))
                    border.color: selected
                        ? Theme.alpha(root.uiAccent, 0.65)
                        : (cMouse.containsMouse ? Theme.alpha(root.uiAccent, 0.35) : root.uiWidgetBorder)
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
                            font.variableAxes: Theme.iconAxes
                            font.pixelSize: Theme.fontSizeXs
                            color: cRoot.selected ? root.uiAccent : root.uiTextSecondary
                        }

                        Text {
                            text: root.fmtText(cRoot.label)
                            font.family: Theme.fontFamily
                            font.variableAxes: Theme.sansAxes
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: cRoot.selected ? Theme.fontWeightBold : Theme.fontWeightMedium
                            color: cRoot.selected ? root.uiAccent : root.uiTextSecondary
                        }
                    }

                    MouseArea {
                        id: cMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !root.studioLocked
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                        onClicked: {
                            cRoot.clicked();
                            lockSurface.claimSurfaceFocus();
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
                    opacity: root.studioLocked ? 0.55 : 1.0

                    readonly property real ratio: Math.max(0.0, Math.min(1.0, (value - from) / Math.max(0.0001, to - from)))

                    function setFromRatio(r: real) {
                        if (root.studioLocked) return;
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
                            font.variableAxes: Theme.iconAxes
                            font.pixelSize: Theme.fontSizeXs
                            color: sMouse.pressed || sMouse.containsMouse ? root.uiAccent : root.uiTextSecondary
                        }

                        Text {
                            text: root.fmtText(sRoot.label)
                            font.family: Theme.fontFamily
                            font.variableAxes: Theme.sansAxes
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: Theme.fontWeightDemiBold
                            color: root.uiTextSecondary
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            height: 18
                            implicitWidth: valTxt.implicitWidth + 10
                            radius: root.uiRadiusPill
                            color: sMouse.pressed ? root.uiAccentOverlay : root.uiWidgetBg
                            border.color: sMouse.pressed ? Theme.alpha(root.uiAccent, 0.5) : root.uiWidgetBorder
                            border.width: 1

                            Text {
                                id: valTxt
                                anchors.centerIn: parent
                                text: sRoot.displayText
                                font.family: Theme.fontMono
                                font.variableAxes: Theme.monoAxes
                                font.pixelSize: Theme.fontSizeXs
                                font.weight: Theme.monoWeightBold
                                color: root.uiAccent
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
                            radius: root.uiRadiusPill
                            color: root.uiWidgetBg
                            border.color: sMouse.containsMouse ? Theme.alpha(root.uiAccent, 0.35) : root.uiWidgetBorder
                            border.width: 1

                            Behavior on height { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
                            Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: Math.max(parent.height, parent.width * sRoot.ratio)
                                radius: root.uiRadiusPill
                                color: sMouse.pressed
                                    ? Theme.statePress(root.uiAccent, root.uiOnAccent)
                                    : (sMouse.containsMouse ? Theme.stateHover(root.uiAccent, root.uiOnAccent) : root.uiAccent)

                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            }
                        }

                        Rectangle {
                            width: sMouse.pressed ? 6 : 4
                            height: sMouse.pressed ? 20 : (sMouse.containsMouse ? 18 : 14)
                            radius: root.uiRadiusPill
                            color: root.uiTextPrimary
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.max(0, Math.min(parent.width - width, (parent.width * sRoot.ratio) - (width / 2)))

                            Behavior on width { NumberAnimation { duration: Theme.animFast } }
                            Behavior on height { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animExpressiveEasing } }
                        }

                        MouseArea {
                            id: sMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !root.studioLocked
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                            onPressed: (mouse) => sRoot.setFromRatio(mouse.x / width)
                            onPositionChanged: (mouse) => {
                                if (pressed) sRoot.setFromRatio(mouse.x / width);
                            }
                            onReleased: lockSurface.claimSurfaceFocus()
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
                    radius: root.uiRadiusSm
                    opacity: root.studioLocked ? 0.55 : 1.0
                    color: rowMouse.containsMouse ? root.uiWidgetHover : "transparent"

                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        spacing: 10

                        Text {
                            text: tRow.icon
                            font.family: Theme.fontIcon
                            font.variableAxes: Theme.iconAxes
                            font.pixelSize: Theme.fontSizeMd
                            color: tRow.checked ? root.uiAccent : root.uiTextSecondary
                            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
                        }

                        Text {
                            text: root.fmtText(tRow.label)
                            font.family: Theme.fontFamily
                            font.variableAxes: Theme.sansAxes
                            font.weight: Theme.fontWeightRegular
                            font.pixelSize: Theme.fontSizeXs
                            color: root.uiTextPrimary
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
                        enabled: !root.studioLocked
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                        onClicked: {
                            tRow.toggled();
                            lockSurface.claimSurfaceFocus();
                        }
                    }
                }

                        anchors.top: statusBarItem ? statusBarItem.bottom : parent.top
                        anchors.right: statusBarItem ? statusBarItem.right : parent.right
                        anchors.topMargin: 10
                        width: 416
                        height: Math.min(parent.height - 104, optionsLayout.implicitHeight + (Theme.popupPadding * 2))
                        radius: root.uiRadiusLg
                        color: root.uiPopupBg
                        border.color: root.uiPopupBorder
                        border.width: Theme.popupBorderWidth
                        visible: opacity > 0.01 && !root.zenMode
                        opacity: lockSurface.optionsOpen ? 1.0 : 0.0
                        scale: lockSurface.optionsOpen ? 1.0 : 0.95
                        transformOrigin: Item.TopRight
                        clip: true
                        z: 100

                        // frosted top rim highlight
                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.topMargin: 1
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            height: 1
                            color: Theme.alpha("#ffffff", root.isLight ? 0.45 : 0.16)
                            z: 5
                        }

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
                                        font.variableAxes: Theme.iconAxes
                                        font.pixelSize: Theme.fontSizeMd
                                        color: root.uiAccent
                                    }

                                    Text {
                                        text: root.fmtText("lock screen studio")
                                        font.family: Theme.fontDisplay
                                        font.variableAxes: Theme.displayAxes
                                        font.pixelSize: Theme.fontSizeMd
                                        font.weight: Theme.fontWeightBold
                                        color: root.uiTextPrimary
                                        Layout.fillWidth: true
                                    }

                                    IconButton {
                                        icon: root.studioLocked ? Theme.iconLock : Theme.iconShield
                                        iconSize: Theme.fontSizeXs
                                        iconColor: root.uiTextPrimary
                                        highlighted: root.studioLocked
                                        tooltip: root.studioLocked ? "unlock studio controls" : "lock studio controls"
                                        onClicked: {
                                            root.studioLocked = !root.studioLocked;
                                            root.flushStateToDisk();
                                            lockSurface.claimSurfaceFocus();
                                        }
                                    }

                                    IconButton {
                                        icon: Theme.iconRefresh
                                        iconSize: Theme.fontSizeXs
                                        iconColor: root.uiTextPrimary
                                        enabled: !root.studioLocked
                                        tooltip: "reset defaults"
                                        onClicked: {
                                            root.resetDefaults();
                                            lockSurface.claimSurfaceFocus();
                                        }
                                    }

                                    IconButton {
                                        icon: Theme.iconClose
                                        iconSize: Theme.fontSizeXs
                                        iconColor: root.uiTextPrimary
                                        tooltip: "close"
                                        onClicked: {
                                            lockSurface.optionsOpen = false;
                                            if (lockSurface?.claimSurfaceFocus) lockSurface.claimSurfaceFocus();
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 36
                                    opacity: root.studioLocked ? 0.5 : 1.0
                                    radius: surpriseMouse.pressed ? root.uiRadiusPill : root.uiRadiusMd
                                    color: surpriseMouse.pressed
                                        ? Theme.statePress(root.uiAccent, root.uiOnAccent)
                                        : (surpriseMouse.containsMouse
                                            ? Theme.stateHover(root.uiAccent, root.uiOnAccent)
                                            : root.uiAccent)

                                    Behavior on radius { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
                                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 8

                                        Text {
                                            text: Theme.iconSparkles
                                            font.family: Theme.fontIcon
                                            font.variableAxes: Theme.iconAxes
                                            font.pixelSize: Theme.fontSizeMd
                                            color: root.uiOnAccent
                                        }

                                        Text {
                                            text: root.fmtText("surprise me! (roll layout & vibe)")
                                            font.family: Theme.fontDisplay
                                            font.variableAxes: Theme.displayAxes
                                            font.pixelSize: Theme.fontSizeXs
                                            font.weight: Theme.fontWeightBold
                                            color: root.uiOnAccent
                                        }
                                    }

                                    MouseArea {
                                        id: surpriseMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        enabled: !root.studioLocked
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                                        onClicked: {
                                            if (burstAnim) burstAnim.restart();
                                            root.surpriseMe();
                                            lockSurface.claimSurfaceFocus();
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Repeater {
                                        model: [
                                            { id: "layout",  label: "layout",  icon: Theme.iconGrid },
                                            { id: "clock",   label: "clock",   icon: Theme.iconClock },
                                            { id: "vibe",    label: "vibe",    icon: Theme.iconPalette },
                                            { id: "widgets", label: "cards",   icon: Theme.iconSettings },
                                            { id: "idle",    label: "idle",    icon: Theme.iconCoffee }
                                        ]
                                        delegate: OptChip {
                                            required property var modelData
                                            label: modelData.label
                                            icon: modelData.icon
                                            selected: root.studioTab === modelData.id
                                            onClicked: root.studioTab = modelData.id
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: Theme.popupDividerHeight
                                    color: root.uiWidgetBorder
                                }

                                // tab 1: presets, position, stack order, stage width, corner shape
                                ColumnLayout {
                                    visible: root.studioTab === "layout"
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: root.fmtText("quick presets")
                                        font.family: Theme.fontFamily
                                        font.variableAxes: Theme.sansAxes
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightDemiBold
                                        color: root.uiTextSecondary
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
                                                    if (burstAnim) burstAnim.restart();
                                                    root.applyPreset(modelData);
                                                }
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text {
                                            text: root.fmtText("screen position")
                                            font.family: Theme.fontFamily
                                            font.variableAxes: Theme.sansAxes
                                            font.pixelSize: Theme.fontSizeXs
                                            font.weight: Theme.fontWeightDemiBold
                                            color: root.uiTextSecondary
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            visible: root.layoutPosition === "custom"
                                            text: Math.round(root.customNormX * 100) + "% , " + Math.round(root.customNormY * 100) + "%"
                                            font.family: Theme.fontMono
                                            font.variableAxes: Theme.monoAxes
                                            font.weight: Theme.monoWeightRegular
                                            font.pixelSize: Theme.fontSizeXs
                                            color: root.uiAccent
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
                                                selected: root.layoutPosition === modelData
                                                onClicked: {
                                                    root.layoutPosition = modelData;
                                                    root.saveSandbox();
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        text: root.fmtText("block stack order")
                                        font.family: Theme.fontFamily
                                        font.variableAxes: Theme.sansAxes
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightDemiBold
                                        color: root.uiTextSecondary
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
                                                selected: root.stackOrder === modelData.ord
                                                onClicked: {
                                                    root.stackOrder = modelData.ord;
                                                    root.saveSandbox();
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        text: root.fmtText("corner shape style")
                                        font.family: Theme.fontFamily
                                        font.variableAxes: Theme.sansAxes
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightDemiBold
                                        color: root.uiTextSecondary
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 5

                                        Repeater {
                                            model: ["theme", "pill", "squircle", "sharp"]
                                            delegate: OptChip {
                                                required property string modelData
                                                label: modelData
                                                selected: root.shapePreset === modelData
                                                onClicked: {
                                                    root.shapePreset = modelData;
                                                    root.saveSandbox();
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
                                        value: root.stageWidth
                                        displayText: Math.round(root.stageWidth) + "px"
                                        onMoved: (v) => {
                                            root.stageWidth = Math.round(v);
                                            root.saveSandbox();
                                        }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconGrid
                                        label: "free drag mode (snap guides + arrow keys)"
                                        checked: root.freeDragMode
                                        onToggled: root.freeDragMode = !root.freeDragMode
                                    }

                                    Text {
                                        text: root.fmtText("lock & unlock transition")
                                        font.family: Theme.fontFamily
                                        font.variableAxes: Theme.sansAxes
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightDemiBold
                                        color: root.uiTextSecondary
                                    }

                                    GridLayout {
                                        Layout.fillWidth: true
                                        columns: 3
                                        columnSpacing: 4
                                        rowSpacing: 4

                                        Repeater {
                                            model: [
                                                { id: "blur-dissolve", lbl: "dissolve" },
                                                { id: "slide-up",      lbl: "slide up" },
                                                { id: "zoom-snap",     lbl: "zoom snap" },
                                                { id: "curtain-fade",  lbl: "curtain" },
                                                { id: "editorial-stagger", lbl: "stagger" }
                                            ]
                                            delegate: OptChip {
                                                required property var modelData
                                                label: modelData.lbl
                                                selected: root.lockTransition === modelData.id
                                                onClicked: {
                                                    root.lockTransition = modelData.id;
                                                    root.saveSandbox();
                                                }
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Repeater {
                                            model: [
                                                { id: "snappy",    lbl: "fast" },
                                                { id: "smooth",    lbl: "smooth" },
                                                { id: "cinematic", lbl: "cinematic" }
                                            ]
                                            delegate: OptChip {
                                                required property var modelData
                                                label: modelData.lbl
                                                selected: root.lockAnimSpeed === modelData.id
                                                onClicked: {
                                                    root.lockAnimSpeed = modelData.id;
                                                    root.saveSandbox();
                                                }
                                            }
                                        }
                                    }
                                }

                                // tab 2: clock design, date format, text casing, password mask
                                ColumnLayout {
                                    visible: root.studioTab === "clock"
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: root.fmtText("clock architecture")
                                        font.family: Theme.fontFamily
                                        font.variableAxes: Theme.sansAxes
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightDemiBold
                                        color: root.uiTextSecondary
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Repeater {
                                            model: ["inline", "stacked", "split", "typo"]
                                            delegate: OptChip {
                                                required property string modelData
                                                label: modelData
                                                selected: root.clockStyle === modelData
                                                onClicked: {
                                                    root.clockStyle = modelData;
                                                    root.saveSandbox();
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
                                                selected: root.clockStyle === modelData
                                                onClicked: {
                                                    root.clockStyle = modelData;
                                                    root.saveSandbox();
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        text: root.fmtText("clock typeface & weight")
                                        font.family: Theme.fontFamily
                                        font.variableAxes: Theme.sansAxes
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightDemiBold
                                        color: root.uiTextSecondary
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Repeater {
                                            model: [
                                                { id: "display", lbl: "display" },
                                                { id: "sans",    lbl: "sans" },
                                                { id: "mono",    lbl: "mono" },
                                                { id: "serif",   lbl: "serif" }
                                            ]
                                            delegate: OptChip {
                                                required property var modelData
                                                label: modelData.lbl
                                                selected: root.clockFont === modelData.id
                                                onClicked: {
                                                    root.clockFont = modelData.id;
                                                    root.saveSandbox();
                                                }
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Repeater {
                                            model: ["light", "bold", "black"]
                                            delegate: OptChip {
                                                required property string modelData
                                                label: modelData
                                                selected: root.clockWeight === modelData
                                                onClicked: {
                                                    root.clockWeight = modelData;
                                                    root.saveSandbox();
                                                }
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        OptChip {
                                            label: "12-hour"
                                            selected: !root.effectiveClock24h
                                            onClicked: {
                                                root.sandboxClock24h = false;
                                                root.saveSandbox();
                                            }
                                        }
                                        OptChip {
                                            label: "24-hour"
                                            selected: root.effectiveClock24h
                                            onClicked: {
                                                root.sandboxClock24h = true;
                                                root.saveSandbox();
                                            }
                                        }
                                        OptChip {
                                            label: "seconds"
                                            selected: root.effectiveShowSeconds
                                            onClicked: {
                                                root.showSeconds = !root.showSeconds;
                                                root.saveSandbox();
                                            }
                                        }
                                    }

                                    RowLayout {
                                        visible: root.effectiveShowSeconds
                                        Layout.fillWidth: true
                                        spacing: 5

                                        OptChip {
                                            label: "pill"
                                            selected: root.secondsStyle === "badge"
                                            onClicked: { root.secondsStyle = "badge"; root.saveSandbox(); }
                                        }
                                        OptChip {
                                            label: "split"
                                            selected: root.secondsStyle === "supersub"
                                            onClicked: { root.secondsStyle = "supersub"; root.saveSandbox(); }
                                        }
                                        OptChip {
                                            label: "bar"
                                            selected: root.secondsStyle === "tower"
                                            onClicked: { root.secondsStyle = "tower"; root.saveSandbox(); }
                                        }
                                        OptChip {
                                            label: "inline"
                                            selected: root.secondsStyle === "inline"
                                            onClicked: { root.secondsStyle = "inline"; root.saveSandbox(); }
                                        }
                                    }

                                    Text {
                                        text: root.fmtText("date format")
                                        font.family: Theme.fontFamily
                                        font.variableAxes: Theme.sansAxes
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightDemiBold
                                        color: root.uiTextSecondary
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
                                                selected: root.dateFormat === modelData.fmt
                                                onClicked: {
                                                    root.dateFormat = modelData.fmt;
                                                    root.saveSandbox();
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        text: root.fmtText("text casing (follow user preference)")
                                        font.family: Theme.fontFamily
                                        font.variableAxes: Theme.sansAxes
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightDemiBold
                                        color: root.uiTextSecondary
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
                                                selected: root.textCase === modelData.id
                                                onClicked: {
                                                    root.textCase = modelData.id;
                                                    root.saveSandbox();
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
                                        value: root.clockScale
                                        displayText: Math.round(root.clockScale * 100) + "%"
                                        onMoved: (v) => {
                                            root.clockScale = v;
                                            root.saveSandbox();
                                        }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconCalendar
                                        label: "place date above clock"
                                        checked: root.dateAboveClock
                                        onToggled: {
                                            root.dateAboveClock = !root.dateAboveClock;
                                            root.saveSandbox();
                                        }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconClock
                                        label: "sync clock format across rice"
                                        checked: root.syncClockGlobal
                                        onToggled: {
                                            root.syncClockGlobal = !root.syncClockGlobal;
                                            root.saveSandbox();
                                        }
                                    }
                                }

                                // tab 3: theme mode, atmosphere, custom quote, password mask
                                ColumnLayout {
                                    visible: root.studioTab === "vibe"
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: root.fmtText("theme mode (" + (root.isLight ? "light" : "dark") + ")")
                                        font.family: Theme.fontFamily
                                        font.variableAxes: Theme.sansAxes
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightDemiBold
                                        color: root.uiTextSecondary
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 5

                                        OptChip {
                                            label: "auto"
                                            icon: Theme.iconSparkles
                                            selected: root.backdropMode === "auto"
                                            onClicked: { root.backdropMode = "auto"; root.saveSandbox(); }
                                        }
                                        OptChip {
                                            label: "dark"
                                            icon: Theme.iconMoon
                                            selected: root.backdropMode === "dark"
                                            onClicked: { root.backdropMode = "dark"; root.saveSandbox(); }
                                        }
                                        OptChip {
                                            label: "light"
                                            icon: Theme.iconSun
                                            selected: root.backdropMode === "light"
                                            onClicked: { root.backdropMode = "light"; root.saveSandbox(); }
                                        }
                                    }

                                    Text {
                                        text: root.fmtText("backdrop overlay texture")
                                        font.family: Theme.fontFamily
                                        font.variableAxes: Theme.sansAxes
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightDemiBold
                                        color: root.uiTextSecondary
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 5

                                        Repeater {
                                            model: ["none", "dots", "grid"]
                                            delegate: OptChip {
                                                required property string modelData
                                                label: modelData
                                                selected: root.backdropTexture === modelData
                                                onClicked: { root.backdropTexture = modelData; root.saveSandbox(); }
                                            }
                                        }
                                    }

                                    // built-in lockscreen wallpaper picker + custom matugen palette
                                    Text {
                                        text: root.fmtText("lock wallpaper & matugen palette")
                                        font.family: Theme.fontFamily
                                        font.variableAxes: Theme.sansAxes
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightDemiBold
                                        color: root.uiTextSecondary
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 5

                                        OptChip {
                                            label: "sync desktop"
                                            icon: Theme.iconWallpaper
                                            selected: root.wallpaperSync
                                            onClicked: {
                                                root.wallpaperSync = true;
                                                root.syncPaletteWithDesktop = true;
                                                root.saveSandbox();
                                            }
                                        }
                                        OptChip {
                                            label: "custom pick"
                                            icon: Theme.iconPalette
                                            selected: !root.wallpaperSync
                                            onClicked: {
                                                root.wallpaperSync = false;
                                                if (root.localWallpaperOverride === "") {
                                                    let wp = root.pickRandomWallpaperInMemory();
                                                    if (wp) root.localWallpaperOverride = wp;
                                                }
                                                if (!root.syncPaletteWithDesktop && root.localWallpaperOverride !== "") {
                                                    root.extractLockPalette(root.localWallpaperOverride);
                                                }
                                                root.saveSandbox();
                                            }
                                        }
                                    }

                                    Flickable {
                                        visible: !root.wallpaperSync && (WallpaperService?.wallpaperList?.length ?? 0) > 0
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 62
                                        contentWidth: thumbStrip.implicitWidth
                                        clip: true
                                        boundsBehavior: Flickable.StopAtBounds

                                        Row {
                                            id: thumbStrip
                                            spacing: 6
                                            height: 60

                                            Repeater {
                                                model: (WallpaperService?.wallpaperList ?? []).slice(0, 24)
                                                delegate: Rectangle {
                                                    required property var modelData
                                                    readonly property string wpPath: modelData?.path ?? ""
                                                    readonly property string wpThumb: modelData?.thumb || modelData?.path || ""
                                                    readonly property bool isCur: root.localWallpaperOverride === wpPath
                                                    width: 92
                                                    height: 58
                                                    radius: root.uiRadiusSm
                                                    color: root.uiWidgetBg
                                                    border.color: isCur ? root.uiAccent : (wpItemMa.containsMouse ? Theme.alpha(root.uiAccent, 0.55) : root.uiWidgetBorder)
                                                    border.width: isCur ? 2 : 1
                                                    clip: true

                                                    Image {
                                                        anchors.fill: parent
                                                        source: parent.wpThumb !== "" ? ("file://" + parent.wpThumb) : ""
                                                        sourceSize: Qt.size(140, 90)
                                                        fillMode: Image.PreserveAspectCrop
                                                        asynchronous: true
                                                    }

                                                    MouseArea {
                                                        id: wpItemMa
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        enabled: !root.studioLocked
                                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                                                        onClicked: {
                                                            root.wallpaperSync = false;
                                                            root.localWallpaperOverride = parent.wpPath;
                                                            if (!root.syncPaletteWithDesktop) {
                                                                root.extractLockPalette(parent.wpPath);
                                                            }
                                                            root.saveSandbox();
                                                            lockSurface.claimSurfaceFocus();
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    SandboxToggleRow {
                                        visible: !root.wallpaperSync && root.localWallpaperOverride !== ""
                                        icon: Theme.iconPalette
                                        label: root.isExtractingPalette ? "extracting matugen palette..." : "matugen colors from lock wallpaper"
                                        checked: !root.syncPaletteWithDesktop
                                        onToggled: {
                                            root.syncPaletteWithDesktop = !root.syncPaletteWithDesktop;
                                            if (!root.syncPaletteWithDesktop && root.localWallpaperOverride !== "") {
                                                root.extractLockPalette(root.localWallpaperOverride);
                                            }
                                            root.saveSandbox();
                                        }
                                    }

                                    RowLayout {
                                        visible: !root.wallpaperSync && !root.syncPaletteWithDesktop && root.localWallpaperOverride !== ""
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Repeater {
                                            model: [
                                                { id: "scheme-tonal-spot", lbl: "tonal" },
                                                { id: "scheme-vibrant",    lbl: "vibrant" },
                                                { id: "scheme-expressive", lbl: "expressive" },
                                                { id: "scheme-monochrome", lbl: "mono" }
                                            ]
                                            delegate: OptChip {
                                                required property var modelData
                                                label: modelData.lbl
                                                selected: root.lockMatugenScheme === modelData.id
                                                onClicked: {
                                                    root.lockMatugenScheme = modelData.id;
                                                    root.extractLockPalette(root.localWallpaperOverride);
                                                    root.saveSandbox();
                                                }
                                            }
                                        }
                                    }

                                    RowLayout {
                                        visible: root.useCustomLockPalette
                                        Layout.fillWidth: true
                                        spacing: 5

                                        Repeater {
                                            model: [
                                                root.lockPalPrimary,
                                                root.lockPalSecondary,
                                                root.lockPalTertiary,
                                                root.lockPalContainer,
                                                root.lockPalSurface
                                            ]
                                            delegate: Rectangle {
                                                required property string modelData
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 16
                                                radius: root.uiRadiusPill
                                                color: modelData !== "" ? modelData : "transparent"
                                                border.color: Theme.alpha(root.uiTextPrimary, 0.25)
                                                border.width: 1
                                            }
                                        }
                                    }

                                    SandboxSlider {
                                        label: root.isLight ? "frost wash intensity" : "backdrop dim"
                                        icon: root.isLight ? Theme.iconSun : Theme.iconMoon
                                        from: 0.05
                                        to: 0.95
                                        stepSize: 0.02
                                        value: root.scrimDim
                                        displayText: Math.round(root.scrimDim * 100) + "%"
                                        onMoved: (v) => {
                                            root.scrimDim = v;
                                            root.saveSandbox();
                                        }
                                    }

                                    SandboxSlider {
                                        label: "card & pill opacity boost"
                                        icon: Theme.iconPalette
                                        from: -0.35
                                        to: 0.35
                                        stepSize: 0.05
                                        value: root.cardOpacityBoost
                                        displayText: (root.cardOpacityBoost >= 0 ? "+" : "") + Math.round(root.cardOpacityBoost * 100) + "%"
                                        onMoved: (v) => {
                                            root.cardOpacityBoost = v;
                                            root.saveSandbox();
                                        }
                                    }

                                    SandboxSlider {
                                        label: "cinematic vignette"
                                        icon: Theme.iconEye
                                        from: 0.0
                                        to: 0.85
                                        stepSize: 0.05
                                        value: root.vignetteStrength
                                        displayText: Math.round(root.vignetteStrength * 100) + "%"
                                        onMoved: (v) => {
                                            root.vignetteStrength = v;
                                            root.saveSandbox();
                                        }
                                    }

                                    SandboxSlider {
                                        label: "focus depth zoom"
                                        icon: Theme.iconExpand
                                        from: 1.00
                                        to: 1.18
                                        stepSize: 0.01
                                        value: root.focusZoom
                                        displayText: Math.round((root.focusZoom - 1.0) * 100) + "%"
                                        onMoved: (v) => {
                                            root.focusZoom = v;
                                            root.saveSandbox();
                                        }
                                    }

                                    Text {
                                        text: root.fmtText("password mask character")
                                        font.family: Theme.fontFamily
                                        font.variableAxes: Theme.sansAxes
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightDemiBold
                                        color: root.uiTextSecondary
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
                                                selected: root.pwMaskChar === modelData.ch
                                                onClicked: {
                                                    root.pwMaskChar = modelData.ch;
                                                    root.saveSandbox();
                                                }
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text {
                                            text: root.fmtText("quote / greeting source")
                                            font.family: Theme.fontFamily
                                            font.variableAxes: Theme.sansAxes
                                            font.pixelSize: Theme.fontSizeXs
                                            font.weight: Theme.fontWeightDemiBold
                                            color: root.uiTextSecondary
                                            Layout.fillWidth: true
                                        }
                                        IconButton {
                                            icon: Theme.iconRefresh
                                            iconSize: Theme.fontSizeXs
                                            iconColor: root.uiTextPrimary
                                            tooltip: "roll new quote"
                                            visible: root.quoteMode !== "off" && root.quoteMode !== "custom"
                                            onClicked: root.refreshQuotes()
                                        }
                                    }

                                    GridLayout {
                                        Layout.fillWidth: true
                                        columns: 3
                                        columnSpacing: 4
                                        rowSpacing: 4

                                        Repeater {
                                            model: ["smart", "hyprland", "delirium", "quotes", "actions", "custom", "off"]
                                            delegate: OptChip {
                                                required property string modelData
                                                label: modelData
                                                selected: root.quoteMode === modelData
                                                onClicked: {
                                                    root.quoteMode = modelData;
                                                    root.refreshQuotes();
                                                    root.saveSandbox();
                                                }
                                            }
                                        }
                                    }

                                    // custom quote input box when quoteMode === "custom"
                                    Rectangle {
                                        visible: root.quoteMode === "custom"
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 34
                                        radius: root.uiRadiusMd
                                        color: root.uiWidgetBg
                                        border.color: customQuoteInput.activeFocus ? root.uiAccent : root.uiWidgetBorder
                                        border.width: 1

                                        TextInput {
                                            id: customQuoteInput
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            verticalAlignment: TextInput.AlignVCenter
                                            text: root.customQuoteText
                                            font.family: Theme.fontFamily
                                            font.variableAxes: Theme.sansAxes
                                            font.weight: Theme.fontWeightRegular
                                            font.pixelSize: Theme.fontSizeXs
                                            color: root.uiTextPrimary
                                            clip: true
                                            onTextEdited: {
                                                root.customQuoteText = text;
                                                root.saveSandbox();
                                            }
                                            onAccepted: if (lockSurface?.claimSurfaceFocus) lockSurface.claimSurfaceFocus();
                                            Keys.onEscapePressed: {
                                                lockSurface.optionsOpen = false;
                                                if (lockSurface?.claimSurfaceFocus) lockSurface.claimSurfaceFocus();
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: Theme.popupActionHeight + 2
                                        radius: root.uiRadiusMd
                                        opacity: root.studioLocked ? 0.5 : 1.0
                                        color: shuffleMouse.pressed
                                            ? root.uiWidgetActive
                                            : (shuffleMouse.containsMouse ? root.uiWidgetHover : root.uiWidgetBg)
                                        border.color: shuffleMouse.containsMouse ? Theme.alpha(root.uiAccent, 0.55) : root.uiWidgetBorder
                                        border.width: 1

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 12
                                            spacing: 8

                                            Text {
                                                text: Theme.iconShuffle
                                                font.family: Theme.fontIcon
                                                font.variableAxes: Theme.iconAxes
                                                font.pixelSize: Theme.fontSizeMd
                                                color: root.uiAccent
                                            }
                                            Text {
                                                text: root.fmtText("shuffle lock wallpaper")
                                                font.family: Theme.fontFamily
                                                font.variableAxes: Theme.sansAxes
                                                font.pixelSize: Theme.fontSizeXs
                                                font.weight: Theme.fontWeightDemiBold
                                                color: root.uiTextPrimary
                                                Layout.fillWidth: true
                                            }
                                        }

                                        MouseArea {
                                            id: shuffleMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            enabled: !root.studioLocked
                                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                                            onClicked: {
                                                let nextWp = root.pickRandomWallpaperInMemory();
                                                if (nextWp && nextWp !== "") {
                                                    root.wallpaperSync = false;
                                                    root.localWallpaperOverride = nextWp;
                                                    root.saveSandbox();
                                                }
                                                lockSurface.claimSurfaceFocus();
                                            }
                                        }
                                    }
                                }

                                // tab 4: modular widget visibility (nothing forced!)
                                ColumnLayout {
                                    visible: root.studioTab === "widgets"
                                    Layout.fillWidth: true
                                    spacing: 2

                                    SandboxToggleRow {
                                        icon: Theme.iconClock
                                        label: "show clock readout"
                                        checked: root.showClock
                                        onToggled: { root.showClock = !root.showClock; root.saveSandbox(); }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconCalendar
                                        label: "show date label"
                                        checked: root.showDate
                                        onToggled: { root.showDate = !root.showDate; root.saveSandbox(); }
                                    }

                                    SandboxToggleRow {
                                        icon: root.showMediaCard ? Theme.iconMusic : Theme.iconEyeOff
                                        label: "show now playing media card"
                                        checked: root.showMediaCard
                                        onToggled: { root.showMediaCard = !root.showMediaCard; root.saveSandbox(); }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconEqualizer
                                        label: "media spectrum & seekbar"
                                        checked: root.showMediaVisualizer
                                        onToggled: { root.showMediaVisualizer = !root.showMediaVisualizer; root.saveSandbox(); }
                                    }

                                    SandboxToggleRow {
                                        icon: root.showUserPill ? Theme.iconUser : Theme.iconEyeOff
                                        label: "show top-left user & timer pill"
                                        checked: root.showUserPill
                                        onToggled: { root.showUserPill = !root.showUserPill; root.saveSandbox(); }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconSliders
                                        label: "show top-right status bar (hover corner if off)"
                                        checked: root.showStatusBar
                                        onToggled: { root.showStatusBar = !root.showStatusBar; root.saveSandbox(); }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconVolHigh
                                        label: "show system volume in top bar"
                                        checked: root.showSystemVol
                                        onToggled: { root.showSystemVol = !root.showSystemVol; root.saveSandbox(); }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconPower
                                        label: "show bottom power dock"
                                        checked: root.showPowerDock
                                        onToggled: { root.showPowerDock = !root.showPowerDock; root.saveSandbox(); }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconShield
                                        label: "2-step confirmation on power buttons"
                                        checked: root.confirmPowerActions
                                        onToggled: { root.confirmPowerActions = !root.confirmPowerActions; root.saveSandbox(); }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconLogout
                                        label: "include logout button in power dock"
                                        checked: root.allowLogoutOnLock
                                        onToggled: { root.allowLogoutOnLock = !root.allowLogoutOnLock; root.saveSandbox(); }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconSparkles
                                        label: "ambient audio-reactive glow orbs"
                                        checked: root.ambientOrbs
                                        onToggled: { root.ambientOrbs = !root.ambientOrbs; root.saveSandbox(); }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconMusic
                                        label: "album art backdrop when playing"
                                        checked: root.albumArtBackdrop
                                        onToggled: { root.albumArtBackdrop = !root.albumArtBackdrop; root.saveSandbox(); }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconWallpaper
                                        label: "sync wallpaper with desktop"
                                        checked: root.wallpaperSync
                                        onToggled: {
                                            root.wallpaperSync = !root.wallpaperSync;
                                            if (root.wallpaperSync) root.localWallpaperOverride = "";
                                            root.saveSandbox();
                                        }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconCrop
                                        label: "show concave screen corners"
                                        checked: root.showScreenCorners
                                        onToggled: { root.showScreenCorners = !root.showScreenCorners; root.saveSandbox(); }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconMoon
                                        label: "auto-zen screensaver after 30s idle"
                                        checked: root.autoZenIdle
                                        onToggled: { root.autoZenIdle = !root.autoZenIdle; root.saveSandbox(); }
                                    }
                                }

                                // tab 5: idle timers & security pam controls
                                ColumnLayout {
                                    visible: root.studioTab === "idle"
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: root.fmtText("automatic idle timeouts")
                                        font.family: Theme.fontFamily
                                        font.variableAxes: Theme.sansAxes
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightDemiBold
                                        color: root.uiTextSecondary
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconSun
                                        label: "auto dim display when idle"
                                        checked: Settings?.idleDimEnabled ?? true
                                        onToggled: {
                                            if (Settings) {
                                                Settings.idleDimEnabled = !Settings.idleDimEnabled;
                                                if (Settings.save) Settings.save();
                                            }
                                        }
                                    }

                                    SandboxSlider {
                                        visible: Settings?.idleDimEnabled ?? true
                                        label: "dim delay"
                                        icon: Theme.iconClock
                                        from: 30
                                        to: 600
                                        stepSize: 30
                                        value: Settings?.idleDimSeconds ?? 150
                                        displayText: optionsCard.fmtIdleSecs(Settings?.idleDimSeconds ?? 150)
                                        onMoved: (v) => {
                                            if (Settings) {
                                                Settings.idleDimSeconds = Math.round(v);
                                                if (Settings.save) Settings.save();
                                            }
                                        }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconLock
                                        label: "auto lock screen on idle"
                                        checked: Settings?.idleLockEnabled ?? true
                                        onToggled: {
                                            if (Settings) {
                                                Settings.idleLockEnabled = !Settings.idleLockEnabled;
                                                if (Settings.save) Settings.save();
                                            }
                                        }
                                    }

                                    SandboxSlider {
                                        visible: Settings?.idleLockEnabled ?? true
                                        label: "lock delay"
                                        icon: Theme.iconClock
                                        from: 30
                                        to: 1800
                                        stepSize: 30
                                        value: Settings?.idleLockSeconds ?? 300
                                        displayText: optionsCard.fmtIdleSecs(Settings?.idleLockSeconds ?? 300)
                                        onMoved: (v) => {
                                            if (Settings) {
                                                Settings.idleLockSeconds = Math.round(v);
                                                if (Settings.save) Settings.save();
                                            }
                                        }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconEyeOff
                                        label: "turn display off (dpms)"
                                        checked: Settings?.idleDpmsEnabled ?? true
                                        onToggled: {
                                            if (Settings) {
                                                Settings.idleDpmsEnabled = !Settings.idleDpmsEnabled;
                                                if (Settings.save) Settings.save();
                                            }
                                        }
                                    }

                                    SandboxSlider {
                                        visible: Settings?.idleDpmsEnabled ?? true
                                        label: "screen off delay"
                                        icon: Theme.iconClock
                                        from: 30
                                        to: 2400
                                        stepSize: 30
                                        value: Settings?.idleDpmsSeconds ?? 330
                                        displayText: optionsCard.fmtIdleSecs(Settings?.idleDpmsSeconds ?? 330)
                                        onMoved: (v) => {
                                            if (Settings) {
                                                Settings.idleDpmsSeconds = Math.round(v);
                                                if (Settings.save) Settings.save();
                                            }
                                        }
                                    }

                                    SandboxToggleRow {
                                        icon: Theme.iconSuspend
                                        label: "auto suspend when idle"
                                        checked: Settings?.idleSuspendEnabled ?? true
                                        onToggled: {
                                            if (Settings) {
                                                Settings.idleSuspendEnabled = !Settings.idleSuspendEnabled;
                                                if (Settings.save) Settings.save();
                                            }
                                        }
                                    }

                                    SandboxSlider {
                                        visible: Settings?.idleSuspendEnabled ?? true
                                        label: "suspend delay"
                                        icon: Theme.iconClock
                                        from: 60
                                        to: 3600
                                        stepSize: 60
                                        value: Settings?.idleSuspendSeconds ?? 600
                                        displayText: optionsCard.fmtIdleSecs(Settings?.idleSuspendSeconds ?? 600)
                                        onMoved: (v) => {
                                            if (Settings) {
                                                Settings.idleSuspendSeconds = Math.round(v);
                                                if (Settings.save) Settings.save();
                                            }
                                        }
                                    }

                                    Text {
                                        text: root.fmtText("pam authentication service")
                                        font.family: Theme.fontFamily
                                        font.variableAxes: Theme.sansAxes
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightDemiBold
                                        color: root.uiTextSecondary
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Repeater {
                                            model: ["login", "swaylock"]
                                            delegate: OptChip {
                                                required property string modelData
                                                label: modelData
                                                selected: root.pamService === modelData
                                                onClicked: {
                                                    root.pamService = modelData;
                                                    root.saveSandbox();
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
