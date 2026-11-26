// BarStudioMotionTab.qml — animation speed, easing curves, live curve tester, and embedded physics playground
import QtQuick
import QtQuick.Layouts
import ".."
import "../controls"
import "../services"

Item {
    id: root

    property bool activeTabOpen: false
    property bool springMode: false
    property string activeSandboxMode: "toy"
    property string gravityMode: "normal"
    property int bounceScore: 0
    property int bestScore: 0
    property bool curveTestAtEnd: false
    property bool curveAutoLoop: false
    onBounceScoreChanged: if (bounceScore > bestScore) bestScore = bounceScore

    function normalizeDock(p) {
        switch (p) {
        case "up":
        case "top":
            return "top";
        case "down":
        case "bottom":
            return "bottom";
        case "left":
            return "left";
        case "right":
            return "right";
        default:
            return "top";
        }
    }

    readonly property string barDock: normalizeDock(Settings?.barPosition ?? "top")
    readonly property bool isTop: barDock === "top"
    readonly property bool isBottom: barDock === "bottom"
    readonly property bool isLeft: barDock === "left"
    readonly property bool isRight: barDock === "right"
    readonly property bool isVertical: isLeft || isRight
    readonly property int barDx: isLeft ? -1 : (isRight ? 1 : 0)
    readonly property int barDy: isTop ? -1 : (isBottom ? 1 : 0)

    function resetScroll() {
        if (leftFlick) leftFlick.contentY = 0;
    }

    function resetPlayground() {
        toyBall.resetBall();
        dragCard1.snapHome();
        dragCard2.snapHome();
        dragCard3.snapHome();
    }

    onActiveTabOpenChanged: {
        if (activeTabOpen) {
            if (!toyBall.placed && canvasArea.width > 40 && canvasArea.height > 40) {
                layoutSettle.restart();
            } else {
                toyBall.wake();
            }
        }
    }
    onGravityModeChanged: if (activeTabOpen) toyBall.wake()
    onBarDockChanged: if (activeTabOpen) layoutSettle.restart()

    Timer {
        id: layoutSettle
        interval: 90
        onTriggered: root.resetPlayground()
    }

    Timer {
        id: curveLoopTimer
        interval: Math.max(260, Theme.animSlow + 260)
        running: root.activeTabOpen && root.curveAutoLoop
        repeat: true
        onTriggered: root.curveTestAtEnd = !root.curveTestAtEnd
    }

    component Chip: Rectangle {
        id: chip
        property string label: ""
        property bool active: false
        property color activeColor: Theme.primary
        property color activeTextColor: Theme.on_primary
        signal clicked

        implicitWidth: chipText.implicitWidth + 14
        implicitHeight: 24
        radius: Theme.radiusPill
        color: active ? activeColor : Theme.widgetBg
        border.color: active ? activeColor : Theme.widgetBorder
        border.width: 1

        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

        Rectangle {
            anchors.fill: parent
            radius: chip.radius
            color: Theme.on_surface
            opacity: chipMouse.pressed ? 0.14 : (chipMouse.containsMouse ? 0.07 : 0)
            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
        }

        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.label
            font.family: Theme.fontFamily
            font.variableAxes: Theme.sansAxes
            font.pixelSize: Theme.fontSizeXs
            font.weight: Theme.fontWeightBold
            color: chip.active ? chip.activeTextColor : Theme.on_surface
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }

    component ChipGroup: Row {
        id: group
        property var options: []
        property string current: ""
        property color activeColor: Theme.primary
        property color activeTextColor: Theme.on_primary
        signal picked(string key)

        spacing: 4

        Repeater {
            model: group.options
            delegate: Chip {
                required property var modelData
                label: modelData.label
                active: group.current === modelData.id
                activeColor: group.activeColor
                activeTextColor: group.activeTextColor
                onClicked: group.picked(modelData.id)
            }
        }
    }

    component Bumper: Rectangle {
        id: bmp
        property int points: 50
        property real flash: 0
        property alias icon: bmpIcon.text

        width: 52
        height: 52
        radius: 26
        color: Qt.tint(Theme.surface_container_high, Qt.alpha(Theme.primary, flash))
        border.color: Theme.widgetBorder
        border.width: 2

        function pulse() {
            pulseAnim.restart();
        }

        SequentialAnimation {
            id: pulseAnim
            ParallelAnimation {
                NumberAnimation { target: bmp; property: "flash"; to: 1; duration: 60 }
                NumberAnimation { target: bmp; property: "scale"; to: 1.22; duration: 60; easing.type: Easing.OutBack }
            }
            ParallelAnimation {
                NumberAnimation { target: bmp; property: "flash"; to: 0; duration: 240 }
                NumberAnimation { target: bmp; property: "scale"; to: 1.0; duration: 240; easing.type: Easing.OutQuad }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 1
            Text {
                id: bmpIcon
                anchors.horizontalCenter: parent.horizontalCenter
                font.family: Theme.fontIcon
                font.variableAxes: Theme.iconAxes
                font.pixelSize: 14
                color: Theme.primary
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "+" + bmp.points
                font.family: Theme.fontFamily
                font.variableAxes: Theme.sansAxes
                font.pixelSize: 8
                font.weight: Theme.fontWeightBold
                color: Theme.on_surface_variant
            }
        }
    }

    component PhysicsCard: Rectangle {
        id: pcRoot
        property int slot: 0
        readonly property int homeX: 12 + slot * 138
        readonly property int homeY: 16
        property alias icon: pcIcon.text
        property alias title: pcTitle.text
        property color accentColor: Theme.primary

        x: homeX
        y: homeY
        width: 124
        height: 90
        radius: Theme.radiusMd
        color: Theme.surface_container_highest
        border.color: cardDrag.active ? accentColor : Theme.widgetBorder
        border.width: 1
        z: cardDrag.active ? 20 : 1

        function snapHome() {
            if (cardDrag.active) return;
            animX.to = Math.max(0, Math.min(Math.max(0, canvasArea.width - width), homeX));
            animY.to = Math.max(0, Math.min(Math.max(0, canvasArea.height - height), homeY));
            animX.easing.type = root.springMode ? Easing.OutBack : Theme.animEasing;
            animY.easing.type = root.springMode ? Easing.OutBack : Theme.animEasing;
            animX.duration = Theme.animSlow;
            animY.duration = Theme.animSlow;
            momentumAnim.restart();
        }

        function animateTo(targetX, targetY) {
            if (cardDrag.active) return;
            animX.to = Math.max(0, Math.min(Math.max(0, canvasArea.width - width), targetX));
            animY.to = Math.max(0, Math.min(Math.max(0, canvasArea.height - height), targetY));
            animX.easing.type = Theme.animEasing;
            animY.easing.type = Theme.animEasing;
            animX.duration = Theme.animNormal;
            animY.duration = Theme.animNormal;
            momentumAnim.restart();
        }

        ParallelAnimation {
            id: momentumAnim
            NumberAnimation { id: animX; target: pcRoot; property: "x" }
            NumberAnimation { id: animY; target: pcRoot; property: "y" }
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 3

            Text {
                id: pcIcon
                font.family: Theme.fontIcon
                font.variableAxes: Theme.iconAxes
                font.pixelSize: 18
                color: pcRoot.accentColor
                Layout.alignment: Qt.AlignHCenter
            }
            Text {
                id: pcTitle
                font.family: Theme.fontFamily
                font.variableAxes: Theme.sansAxes
                font.pixelSize: Theme.fontSizeXs
                font.weight: Theme.fontWeightBold
                color: Theme.on_surface
                Layout.alignment: Qt.AlignHCenter
            }
            Text {
                text: "(" + Math.round(pcRoot.x) + ", " + Math.round(pcRoot.y) + ")"
                font.family: Theme.fontMono
                font.variableAxes: Theme.monoAxes
                font.weight: Theme.monoWeightRegular
                font.pixelSize: 9
                color: Theme.on_surface_variant
                Layout.alignment: Qt.AlignHCenter
            }
        }

        DragHandler {
            id: cardDrag
            target: pcRoot
            xAxis.minimum: 0
            xAxis.maximum: Math.max(0, canvasArea.width - pcRoot.width)
            yAxis.minimum: 0
            yAxis.maximum: Math.max(0, canvasArea.height - pcRoot.height)
            cursorShape: active ? Qt.ClosedHandCursor : Qt.OpenHandCursor

            onActiveChanged: {
                if (active) {
                    momentumAnim.stop();
                } else if (root.springMode) {
                    pcRoot.snapHome();
                } else {
                    pcRoot.animateTo(pcRoot.x + centroid.velocity.x * 0.22, pcRoot.y + centroid.velocity.y * 0.22);
                }
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: Theme.popupSpacing + 2

        // Left: Animation Timing & Live Curve Test
        Item {
            Layout.fillHeight: true
            Layout.preferredWidth: Math.max(320, Math.round(parent.width * 0.44))

            Flickable {
                id: leftFlick
                anchors.fill: parent
                clip: true
                contentWidth: width
                contentHeight: leftCol.implicitHeight + 16
                boundsBehavior: Flickable.StopAtBounds

                WheelHandler {
                    orientation: Qt.Vertical
                    target: parent
                }

                ColumnLayout {
                    id: leftCol
                    width: parent.width - 10
                    spacing: Theme.popupSpacing

                    CategoryHeader {
                        title: "animation timing & easing"
                        subtitle: "global motion multipliers, curve family, and base durations"
                        icon: Theme.iconFlame
                    }

                    SettingCard {
                        ChoiceGrid {
                            columns: 3
                            buttonHeight: 28
                            title: "animation speed preset"
                            model: [
                                { label: "hyprland", value: "hyprland" },
                                { label: "snappy", value: "snappy" },
                                { label: "hyper", value: "hyper" },
                                { label: "normal", value: "normal" },
                                { label: "chill", value: "chill" },
                                { label: "instant", value: "instant" }
                            ]
                            currentValue: Settings.animSpeed
                            onSelected: (val) => Settings.animSpeed = val
                        }

                        ChoiceRow {
                            title: "easing curve profile"
                            model: [
                                { label: "cubic", value: "cubic" },
                                { label: "hyprland", value: "hyprland" },
                                { label: "snappy", value: "snappy" },
                                { label: "expressive", value: "expressive" },
                                { label: "linear", value: "linear" }
                            ]
                            currentValue: Settings.animCurve || "cubic"
                            onSelected: (val) => Settings.animCurve = val
                        }

                        ChoiceRow {
                            title: "easing direction"
                            model: [
                                { label: "out", value: "out" },
                                { label: "in", value: "in" },
                                { label: "in-out", value: "inout" }
                            ]
                            currentValue: Settings.animEasingType || "out"
                            onSelected: (val) => Settings.animEasingType = val
                        }

                        RowDivider {}

                        SliderRow {
                            title: "fast base duration"
                            from: 60
                            to: 240
                            stepSize: 10
                            value: Settings.animDurationFast
                            formatter: (v) => Math.round(v) + "ms → " + Theme.animFast + "ms"
                            onMoved: (val) => Settings.animDurationFast = val
                        }

                        SliderRow {
                            title: "normal base duration"
                            from: 100
                            to: 400
                            stepSize: 10
                            value: Settings.animDurationNormal
                            formatter: (v) => Math.round(v) + "ms → " + Theme.animNormal + "ms"
                            onMoved: (val) => Settings.animDurationNormal = val
                        }

                        SliderRow {
                            title: "slow base duration"
                            from: 180
                            to: 600
                            stepSize: 10
                            value: Settings.animDurationSlow
                            formatter: (v) => Math.round(v) + "ms → " + Theme.animSlow + "ms"
                            onMoved: (val) => Settings.animDurationSlow = val
                        }
                    }

                    CategoryHeader {
                        title: "live curve preview"
                        subtitle: "trigger motion using active Theme.animNormal + easing settings"
                        icon: Theme.iconSparkles
                    }

                    SettingCard {
                        RowLayout {
                            width: parent.width
                            spacing: 6

                            Text {
                                text: "scale " + Theme.animSpeedMult.toFixed(2) + "x · " + Theme.animNormal + "ms"
                                font.family: Theme.fontMono
                                font.variableAxes: Theme.monoAxes
                                font.weight: Theme.monoWeightRegular
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.textSecondary
                                Layout.fillWidth: true
                            }

                            Chip {
                                label: root.curveAutoLoop ? "auto: on" : "auto: off"
                                active: root.curveAutoLoop
                                onClicked: root.curveAutoLoop = !root.curveAutoLoop
                            }

                            Chip {
                                label: "trigger"
                                active: true
                                onClicked: root.curveTestAtEnd = !root.curveTestAtEnd
                            }
                        }

                        Rectangle {
                            id: previewTrack
                            width: parent.width
                            height: 36
                            radius: Theme.radiusMd
                            color: Theme.widgetBg
                            border.color: Theme.widgetBorder
                            border.width: 1

                            Rectangle {
                                id: previewKnob
                                width: 64
                                height: 24
                                anchors.verticalCenter: parent.verticalCenter
                                x: root.curveTestAtEnd ? Math.max(6, previewTrack.width - width - 6) : 6
                                radius: Theme.radiusPill
                                color: Theme.primary

                                Behavior on x {
                                    NumberAnimation {
                                        duration: Theme.animNormal
                                        easing.type: Theme.animEasing
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: Theme.animCurve
                                    font.family: Theme.fontMono
                                    font.variableAxes: Theme.monoAxes
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: Theme.monoWeightBold
                                    color: Theme.on_primary
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.curveTestAtEnd = !root.curveTestAtEnd
                            }
                        }
                    }
                }
            }

            TabScrollTrack { target: leftFlick }
        }

        // Right: Interactive Physics Playground
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radiusMd
            color: Theme.cardBg
            border.color: Theme.cardBorder
            border.width: Theme.popupBorderWidth
            clip: true

            Rectangle {
                visible: Theme.isGlass
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Theme.glassHighlight
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "physics & momentum playground"
                        font.family: Theme.fontFamily
                        font.variableAxes: Theme.sansAxes
                        font.pixelSize: Theme.fontSizeSm
                        font.weight: Theme.fontWeightBold
                        color: Theme.primary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "dock: " + root.barDock
                        font.family: Theme.fontMono
                        font.variableAxes: Theme.monoAxes
                        font.weight: Theme.monoWeightRegular
                        font.pixelSize: Theme.fontSizeXs
                        color: Theme.textSecondary
                    }

                    IconButton {
                        icon: Theme.iconRefresh
                        iconSize: Theme.fontSizeXs
                        tooltip: "reset playground"
                        onClicked: {
                            root.bounceScore = 0;
                            root.resetPlayground();
                        }
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 8

                    ChipGroup {
                        options: [
                            { id: "toy", label: "pinball toy" },
                            { id: "cards", label: "cards" }
                        ]
                        current: root.activeSandboxMode
                        onPicked: key => root.activeSandboxMode = key
                    }

                    ChipGroup {
                        visible: root.activeSandboxMode === "toy"
                        options: [
                            { id: "normal", label: "grav" },
                            { id: "zero", label: "zero-g" },
                            { id: "reverse", label: "anti-g" },
                            { id: "orbit", label: "orbit" }
                        ]
                        current: root.gravityMode
                        activeColor: Theme.secondary
                        activeTextColor: Theme.on_secondary
                        onPicked: key => root.gravityMode = key
                    }

                    Chip {
                        visible: root.activeSandboxMode === "cards"
                        label: root.springMode ? "spring snapback" : "momentum flick"
                        active: true
                        activeColor: root.springMode ? Theme.warn_container : Theme.primary_overlay
                        activeTextColor: root.springMode ? Theme.on_warn_container : Theme.primary
                        onClicked: root.springMode = !root.springMode
                    }
                }

                Rectangle {
                    id: canvasArea
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 160
                    radius: Theme.radiusSm
                    color: Qt.alpha(Theme.surface_container_high, 0.35)
                    border.color: Theme.widgetBorder
                    border.width: 1
                    clip: true

                    onWidthChanged: if (width > 40) layoutSettle.restart()
                    onHeightChanged: if (height > 40) layoutSettle.restart()

                    // pinball layer
                    Item {
                        id: toyLayer
                        anchors.fill: parent
                        visible: root.activeSandboxMode === "toy"

                        function mapX(u, d) {
                            const w = canvasArea.width;
                            return root.isVertical ? (root.isLeft ? d * w : (1 - d) * w) : u * w;
                        }
                        function mapY(u, d) {
                            const h = canvasArea.height;
                            return root.isVertical ? u * h : (root.isTop ? d * h : (1 - d) * h);
                        }

                        Repeater {
                            id: bumperRepeater
                            model: [
                                { u: 0.24, d: 0.42, points: 25, icon: Theme.iconSparkles },
                                { u: 0.50, d: 0.28, points: 100, icon: Theme.iconFlame },
                                { u: 0.76, d: 0.42, points: 50, icon: Theme.iconShield }
                            ]
                            delegate: Bumper {
                                required property var modelData
                                points: modelData.points
                                icon: modelData.icon
                                x: Math.round(toyLayer.mapX(modelData.u, modelData.d) - width / 2)
                                y: Math.round(toyLayer.mapY(modelData.u, modelData.d) - height / 2)
                            }
                        }

                        RowLayout {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 8
                            spacing: 8

                            Rectangle {
                                implicitHeight: 20
                                implicitWidth: scText.implicitWidth + 12
                                radius: Theme.radiusPill
                                color: Theme.primary_overlay

                                Text {
                                    id: scText
                                    anchors.centerIn: parent
                                    text: "score " + root.bounceScore + " · best " + root.bestScore
                                    font.family: Theme.fontMono
                                    font.variableAxes: Theme.monoAxes
                                    font.pixelSize: 9
                                    font.weight: Theme.monoWeightBold
                                    color: Theme.primary
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "click = shockwave · drag ball to fling"
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.variableAxes: Theme.sansAxes
                                font.weight: Theme.fontWeightRegular
                                font.pixelSize: 9
                                color: Theme.on_surface_variant
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: mouse => {
                                const dx = toyBall.x + toyBall.width / 2 - mouse.x;
                                const dy = toyBall.y + toyBall.height / 2 - mouse.y;
                                const dist = Math.max(16, Math.hypot(dx, dy));
                                const force = Math.min(1800, 35000 / dist);
                                toyBall.vx += (dx / dist) * force;
                                toyBall.vy += (dy / dist) * force;
                                toyBall.wake();
                                root.bounceScore += 5;
                            }
                        }

                        Rectangle {
                            id: toyBall
                            width: 28
                            height: 28
                            radius: 14
                            color: Theme.primary
                            border.color: Theme.on_primary
                            border.width: 2
                            z: 10

                            property real vx: 0
                            property real vy: 0
                            property real chaosAngle: 0
                            property real restTime: 0
                            property bool placed: false
                            property bool asleep: true
                            property bool dragging: ballDrag.active

                            function wake() {
                                if (!placed) return;
                                asleep = false;
                                restTime = 0;
                            }

                            function resetBall() {
                                if (canvasArea.width <= 40 || canvasArea.height <= 40) return;
                                const cx = toyLayer.mapX(0.5, 0.8);
                                const cy = toyLayer.mapY(0.5, 0.8);
                                x = Math.round(cx - width / 2);
                                y = Math.round(cy - height / 2);
                                const lateral = (Math.random() - 0.5) * 360;
                                const away = 240;
                                vx = root.isVertical ? -root.barDx * away : lateral;
                                vy = root.isVertical ? lateral : -root.barDy * away;
                                placed = true;
                                wake();
                            }

                            Text {
                                anchors.centerIn: parent
                                text: Theme.iconDistro
                                font.family: Theme.fontIcon
                                font.variableAxes: Theme.iconAxes
                                font.pixelSize: 12
                                color: Theme.on_primary
                            }

                            DragHandler {
                                id: ballDrag
                                target: toyBall
                                xAxis.minimum: 0
                                xAxis.maximum: Math.max(0, canvasArea.width - toyBall.width)
                                yAxis.minimum: 0
                                yAxis.maximum: Math.max(0, canvasArea.height - toyBall.height)
                                cursorShape: active ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                                onActiveChanged: {
                                    if (active) {
                                        toyBall.vx = 0;
                                        toyBall.vy = 0;
                                    } else {
                                        const cap = 1400;
                                        toyBall.vx = Math.max(-cap, Math.min(cap, centroid.velocity.x));
                                        toyBall.vy = Math.max(-cap, Math.min(cap, centroid.velocity.y));
                                        if (Math.hypot(toyBall.vx, toyBall.vy) < 60) {
                                            toyBall.vx = -root.barDx * 380;
                                            toyBall.vy = -root.barDy * 380;
                                        }
                                        toyBall.wake();
                                    }
                                }
                            }
                        }

                        FrameAnimation {
                            running: root.activeTabOpen && root.activeSandboxMode === "toy" && !toyBall.dragging && !toyBall.asleep

                            onTriggered: {
                                const dt = Math.min(0.05, frameTime);
                                if (dt <= 0) return;

                                const gMag = 920;
                                let gx = 0, gy = 0;
                                if (root.gravityMode === "normal") {
                                    gx = root.barDx * gMag;
                                    gy = root.barDy * gMag;
                                } else if (root.gravityMode === "reverse") {
                                    gx = -root.barDx * gMag;
                                    gy = -root.barDy * gMag;
                                } else if (root.gravityMode === "orbit") {
                                    toyBall.chaosAngle += 0.08 * (dt / 0.016);
                                    gx = Math.sin(toyBall.chaosAngle) * gMag;
                                    gy = Math.cos(toyBall.chaosAngle * 1.3) * gMag;
                                }

                                toyBall.vx += gx * dt;
                                toyBall.vy += gy * dt;

                                const friction = Math.pow(0.994, dt / 0.016);
                                toyBall.vx *= friction;
                                toyBall.vy *= friction;

                                toyBall.x += toyBall.vx * dt;
                                toyBall.y += toyBall.vy * dt;

                                const maxX = Math.max(0, canvasArea.width - toyBall.width);
                                const maxY = Math.max(0, canvasArea.height - toyBall.height);
                                const bounceLoss = 0.78;

                                if (toyBall.x < 0 || toyBall.x > maxX) {
                                    toyBall.x = Math.max(0, Math.min(maxX, toyBall.x));
                                    if (Math.abs(toyBall.vx) > 50) root.bounceScore += 1;
                                    toyBall.vx = -toyBall.vx * bounceLoss;
                                }
                                if (toyBall.y < 0 || toyBall.y > maxY) {
                                    toyBall.y = Math.max(0, Math.min(maxY, toyBall.y));
                                    if (Math.abs(toyBall.vy) > 50) root.bounceScore += 1;
                                    toyBall.vy = -toyBall.vy * bounceLoss;
                                }

                                const bx = toyBall.x + toyBall.width / 2;
                                const by = toyBall.y + toyBall.height / 2;
                                const ballRadius = toyBall.width / 2;

                                for (let i = 0; i < bumperRepeater.count; ++i) {
                                    const b = bumperRepeater.itemAt(i);
                                    if (!b) continue;
                                    const cx = b.x + b.width / 2;
                                    const cy = b.y + b.height / 2;
                                    const dist = Math.hypot(bx - cx, by - cy);
                                    const minDist = ballRadius + b.width / 2;

                                    if (dist < minDist && dist > 0.001) {
                                        const nx = (bx - cx) / dist;
                                        const ny = (by - cy) / dist;

                                        toyBall.x = cx + nx * (minDist + 1) - ballRadius;
                                        toyBall.y = cy + ny * (minDist + 1) - ballRadius;

                                        const dot = toyBall.vx * nx + toyBall.vy * ny;
                                        if (dot < 0) {
                                            toyBall.vx -= 1.88 * dot * nx;
                                            toyBall.vy -= 1.88 * dot * ny;
                                        }
                                        toyBall.vx += nx * 140;
                                        toyBall.vy += ny * 140;

                                        b.pulse();
                                        root.bounceScore += b.points;
                                    }
                                }

                                if (Math.hypot(toyBall.vx, toyBall.vy) < 20 && root.gravityMode !== "orbit") {
                                    toyBall.restTime += dt;
                                    if (toyBall.restTime > 0.4) {
                                        toyBall.vx = 0;
                                        toyBall.vy = 0;
                                        toyBall.asleep = true;
                                    }
                                } else {
                                    toyBall.restTime = 0;
                                }
                            }
                        }
                    }

                    // draggable physics cards layer
                    Item {
                        id: cardsLayer
                        anchors.fill: parent
                        visible: root.activeSandboxMode === "cards"

                        Text {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.margins: 8
                            text: root.springMode ? "release to snap back" : "drag and release to flick"
                            font.family: Theme.fontFamily
                            font.variableAxes: Theme.sansAxes
                            font.weight: Theme.fontWeightRegular
                            font.pixelSize: 9
                            color: Theme.on_surface_variant
                        }

                        PhysicsCard {
                            id: dragCard1
                            slot: 0
                            icon: Theme.iconRefresh
                            title: "flick momentum"
                            accentColor: Theme.primary
                        }

                        PhysicsCard {
                            id: dragCard2
                            slot: 1
                            icon: Theme.iconExpand
                            title: "ease curve card"
                            accentColor: Theme.warn
                        }

                        PhysicsCard {
                            id: dragCard3
                            slot: 2
                            icon: Theme.iconMusic
                            title: "media pill"
                            accentColor: Theme.secondary
                        }
                    }
                }
            }
        }
    }
}
