// Workspaces.qml
import QtQuick
import QtQuick.Layouts
import ".."
import "../controls"
import Quickshell
import Quickshell.Hyprland

Rectangle {
    id: wsContainer

    readonly property bool isFloatingBar: (Settings?.barFloating ?? false) || Theme.isBento
    readonly property int effectiveBarMargin: isFloatingBar ? ((Settings?.barMargin > 0) ? Settings.barMargin : 8) : 0

    // extra padding on the ends of the pill so the outer dots don't hug the curved caps
    readonly property int trackPadding: Math.max(Theme.workspaceWidgetPadding * 2, 10)

    implicitWidth: Theme.isVertical
        ? (Theme.barHeight - 8)
        : (wsRow.implicitWidth + trackPadding * 2)
    implicitHeight: Theme.isVertical
        ? (wsCol.implicitHeight + trackPadding * 2)
        : (Theme.barHeight - 8)

    radius: Theme.radiusPill
    color: {
        if (wsMouse.pressed) return Theme.widgetActive;
        if (popup.open) return Theme.primary_overlay;
        if (wsMouse.containsMouse) return Theme.pillHover;
        return Theme.pillBg;
    }
    border.color: popup.open ? Theme.primary : Theme.pillBorder
    border.width: (border.color === "transparent" || border.color.a === 0) ? 0 : 1

    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
    Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

    property var workspaceList: []
    property var workspaceMap: ({})
    property int scratchpadWindows: 0

    // routes through Settings' Lua dispatcher (hl.dsp.focus) when hyprlandLua is enabled
    function dispatchWs(target) {
        if (Settings?.dispatchWorkspace) {
            Settings.dispatchWorkspace(target);
        } else if (Settings?.hyprlandLua ?? true) {
            let arg = typeof target === "number" ? target : `"${target}"`;
            Hyprland.dispatch(`hl.dsp.focus({ workspace = ${arg} })`);
        } else {
            Hyprland.dispatch("workspace " + target);
        }
    }

    // hl.dsp.workspace.toggle_special() applies the "special:" prefix itself
    function toggleSpecialWs(name) {
        let cleanName = String(name || "scratchpad").replace(/^special:/, "");
        if (Settings?.dispatchToggleSpecial) {
            Settings.dispatchToggleSpecial(cleanName);
        } else if (Settings?.hyprlandLua ?? true) {
            Hyprland.dispatch(`hl.dsp.workspace.toggle_special("${cleanName}")`);
        } else {
            Hyprland.dispatch("togglespecialworkspace " + cleanName);
        }
    }

    // send active window to a regular or special workspace (right-click action in popup)
    function moveWindowToWs(target, followWindow) {
        let follow = followWindow ?? false;
        if (Settings?.hyprlandLua ?? true) {
            let arg = typeof target === "number" ? target : `"${target}"`;
            Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${arg}, follow = ${follow ? "true" : "false"} })`);
        } else {
            let cmd = follow ? "movetoworkspace" : "movetoworkspacesilent";
            Hyprland.dispatch(`${cmd} ${target}`);
        }
    }

    function updateWorkspaceList() {
        let vals = Hyprland.workspaces?.values || [];
        let list = [];
        let map = {};
        let scratchCount = 0;

        for (let i = 0; i < vals.length; i++) {
            let w = vals[i];
            if (!w) continue;
            if (w.id > 0) {
                list.push(w);
                map[w.id] = w;
            } else if (w.name === "special:scratchpad" || w.name === "scratchpad" || String(w.name).startsWith("special:")) {
                scratchCount += (w.windows ?? 0);
            }
        }

        list.sort((a, b) => a.id - b.id);
        workspaceList = list;
        workspaceMap = map;
        scratchpadWindows = scratchCount;
    }

    Component.onCompleted: updateWorkspaceList()

    Connections {
        target: Hyprland.workspaces
        function onValuesChanged() {
            wsDebounce.restart();
        }
    }

    Timer {
        id: wsDebounce
        interval: 10
        repeat: false
        onTriggered: wsContainer.updateWorkspaceList()
    }

    Timer {
        id: wsWheelCooldown
        interval: 110
        repeat: false
    }

    readonly property int currentWsId: Hyprland.focusedWorkspace?.id ?? 1
    readonly property int currentWsIdx: {
        for (let i = 0; i < workspaceList.length; i++) {
            if (workspaceList[i].id === currentWsId) return i;
        }
        return 0;
    }

    property int prevWsIdx: 0
    property bool movingForward: true
    onCurrentWsIdxChanged: {
        movingForward = currentWsIdx >= prevWsIdx;
        prevWsIdx = currentWsIdx;
    }

    readonly property string wsMode: Settings?.workspaceMode ?? "slide"

    function syncAnchor() {
        let pt = wsContainer.mapToItem(null, 0, 0);
        if (pt && wsContainer.visible) {
            if (Theme.isVertical) {
                popup.targetRelativeX = 0;
                popup.targetRelativeY = pt.y + (wsContainer.height / 2) + wsContainer.effectiveBarMargin;
            } else {
                popup.targetRelativeX = pt.x + (wsContainer.width / 2) + wsContainer.effectiveBarMargin;
                popup.targetRelativeY = 0;
            }
        } else {
            popup.targetRelativeX = 0;
            popup.targetRelativeY = 0;
        }
    }

    function togglePopup() {
        wsContainer.syncAnchor();
        if (!popup.open) {
            popup.pinned = true;
            popup.open = true;
        } else if (!popup.pinned) {
            popup.pinned = true;
        } else {
            popup.pinned = false;
            popup.open = false;
        }
    }

    // vertical bar track
    Item {
        id: wsTrackV
        visible: Theme.isVertical
        anchors.centerIn: parent
        implicitWidth: Math.max(Theme.workspaceDotSize, Theme.workspaceIndicatorSize)
        implicitHeight: wsCol.implicitHeight

        Rectangle {
            id: fluidIndicatorV
            visible: wsContainer.workspaceList.length > 0 && wsContainer.wsMode !== "discrete"
            width: Theme.workspaceDotSize
            radius: Theme.radiusPill
            color: Theme.primary
            z: 2
            anchors.horizontalCenter: parent.horizontalCenter

            readonly property var activeItem: wsRepeaterV.itemAt(wsContainer.currentWsIdx)
            readonly property real targetY: activeItem ? activeItem.y : 0
            readonly property real targetH: activeItem ? activeItem.height : Theme.workspaceActiveSize

            property real topEdge: targetY
            property real bottomEdge: targetY + targetH

            Behavior on topEdge {
                enabled: wsContainer.wsMode === "fluid-trail"
                NumberAnimation {
                    duration: wsContainer.movingForward ? Theme.workspaceTrailDuration : Theme.animFast
                    easing.type: Theme.animEasing
                }
            }
            Behavior on bottomEdge {
                enabled: wsContainer.wsMode === "fluid-trail"
                NumberAnimation {
                    duration: wsContainer.movingForward ? Theme.animFast : Theme.workspaceTrailDuration
                    easing.type: Theme.animEasing
                }
            }

            y: wsContainer.wsMode === "fluid-trail" ? topEdge : targetY
            height: wsContainer.wsMode === "fluid-trail"
                ? Math.max(Theme.workspaceDotSize, bottomEdge - topEdge)
                : targetH

            Behavior on y {
                enabled: wsContainer.wsMode === "slide"
                NumberAnimation { duration: Theme.animNormal; easing.type: Theme.animEasing }
            }
            Behavior on height {
                enabled: wsContainer.wsMode === "slide"
                NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing }
            }
        }

        Column {
            id: wsCol
            spacing: Theme.workspaceSpacing
            anchors.horizontalCenter: parent.horizontalCenter
            z: 1

            Repeater {
                id: wsRepeaterV
                model: wsContainer.workspaceList

                Item {
                    id: wsItemV
                    required property var modelData
                    readonly property bool isFocused: wsContainer.currentWsId === modelData.id
                    readonly property bool isActive: modelData.windows > 0

                    width: Theme.workspaceDotSize
                    height: isFocused ? Theme.workspaceActiveSize : Theme.workspaceDotSize

                    Behavior on height {
                        NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: Theme.workspaceDotSize
                        height: parent.height
                        radius: Theme.radiusPill
                        color: (wsContainer.wsMode === "discrete" && parent.isFocused)
                            ? Theme.primary
                            : (parent.isActive ? Theme.on_surface_variant : Theme.outline_variant)
                        opacity: (wsContainer.wsMode !== "discrete" && parent.isFocused)
                            ? 0.25
                            : (parent.isActive ? 0.9 : 0.4)

                        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
                        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                    }
                }
            }
        }
    }

    // horizontal bar track
    Item {
        id: wsTrackH
        visible: !Theme.isVertical
        anchors.centerIn: parent
        implicitWidth: wsRow.implicitWidth
        implicitHeight: Math.max(Theme.workspaceDotSize, Theme.workspaceIndicatorSize)

        Rectangle {
            id: fluidIndicatorH
            visible: wsContainer.workspaceList.length > 0 && wsContainer.wsMode !== "discrete"
            height: Theme.workspaceDotSize
            radius: Theme.radiusPill
            color: Theme.primary
            z: 2
            anchors.verticalCenter: parent.verticalCenter

            readonly property var activeItem: wsRepeaterH.itemAt(wsContainer.currentWsIdx)
            readonly property real targetX: activeItem ? activeItem.x : 0
            readonly property real targetW: activeItem ? activeItem.width : Theme.workspaceActiveSize

            property real leftEdge: targetX
            property real rightEdge: targetX + targetW

            Behavior on leftEdge {
                enabled: wsContainer.wsMode === "fluid-trail"
                NumberAnimation {
                    duration: wsContainer.movingForward ? Theme.workspaceTrailDuration : Theme.animFast
                    easing.type: Theme.animEasing
                }
            }
            Behavior on rightEdge {
                enabled: wsContainer.wsMode === "fluid-trail"
                NumberAnimation {
                    duration: wsContainer.movingForward ? Theme.animFast : Theme.workspaceTrailDuration
                    easing.type: Theme.animEasing
                }
            }

            x: wsContainer.wsMode === "fluid-trail" ? leftEdge : targetX
            width: wsContainer.wsMode === "fluid-trail"
                ? Math.max(Theme.workspaceDotSize, rightEdge - leftEdge)
                : targetW

            Behavior on x {
                enabled: wsContainer.wsMode === "slide"
                NumberAnimation { duration: Theme.animNormal; easing.type: Theme.animEasing }
            }
            Behavior on width {
                enabled: wsContainer.wsMode === "slide"
                NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing }
            }
        }

        Row {
            id: wsRow
            spacing: Theme.workspaceSpacing
            anchors.verticalCenter: parent.verticalCenter
            z: 1

            Repeater {
                id: wsRepeaterH
                model: wsContainer.workspaceList

                Item {
                    id: wsItemH
                    required property var modelData
                    readonly property bool isFocused: wsContainer.currentWsId === modelData.id
                    readonly property bool isActive: modelData.windows > 0

                    width: isFocused ? Theme.workspaceActiveSize : Theme.workspaceDotSize
                    height: Theme.workspaceDotSize

                    Behavior on width {
                        NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width
                        height: Theme.workspaceDotSize
                        radius: Theme.radiusPill
                        color: (wsContainer.wsMode === "discrete" && parent.isFocused)
                            ? Theme.primary
                            : (parent.isActive ? Theme.on_surface_variant : Theme.outline_variant)
                        opacity: (wsContainer.wsMode !== "discrete" && parent.isFocused)
                            ? 0.25
                            : (parent.isActive ? 0.9 : 0.4)

                        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
                        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                    }
                }
            }
        }
    }

    Connections {
        target: Settings
        function onRequestWorkspacesToggle() {
            wsContainer.syncAnchor();
            popup.pinned = !popup.open;
            popup.open = !popup.open;
        }
        function onRequestWorkspacesOpen() {
            wsContainer.syncAnchor();
            popup.pinned = true;
            popup.open = true;
        }
        function onRequestWorkspacesClose() {
            popup.pinned = false;
            popup.open = false;
        }
    }

    HoverFlyoutHandler {
        popup: popup
        mouseArea: wsMouse
        updatePos: () => wsContainer.syncAnchor()
    }

    // click an unfocused dot to jump straight to that workspace, click active dot (or right-click) to open popup
    MouseArea {
        id: wsMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onClicked: (mouse) => {
            if (mouse.button === Qt.MiddleButton) {
                wsContainer.toggleSpecialWs("scratchpad");
                return;
            }
            if (mouse.button === Qt.RightButton) {
                wsContainer.togglePopup();
                return;
            }

            // hit-test which dot was clicked before falling back to toggling the popup
            if (Theme.isVertical) {
                let lp = wsCol.mapFromItem(wsMouse, mouse.x, mouse.y);
                for (let i = 0; i < wsContainer.workspaceList.length; i++) {
                    let item = wsRepeaterV.itemAt(i);
                    if (item && lp.y >= item.y - 3 && lp.y <= item.y + item.height + 3) {
                        let targetId = wsContainer.workspaceList[i].id;
                        if (targetId !== wsContainer.currentWsId) {
                            wsContainer.dispatchWs(targetId);
                            return;
                        }
                        break;
                    }
                }
            } else {
                let lp = wsRow.mapFromItem(wsMouse, mouse.x, mouse.y);
                for (let i = 0; i < wsContainer.workspaceList.length; i++) {
                    let item = wsRepeaterH.itemAt(i);
                    if (item && lp.x >= item.x - 3 && lp.x <= item.x + item.width + 3) {
                        let targetId = wsContainer.workspaceList[i].id;
                        if (targetId !== wsContainer.currentWsId) {
                            wsContainer.dispatchWs(targetId);
                            return;
                        }
                        break;
                    }
                }
            }

            wsContainer.togglePopup();
        }

        onWheel: (wheel) => {
            wheel.accepted = true;
            if (wsWheelCooldown.running) return;
            let delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
            if (Math.abs(delta) < 12) return;
            wsWheelCooldown.restart();
            if (delta < 0) {
                wsContainer.dispatchWs("r+1");
            } else if (delta > 0) {
                wsContainer.dispatchWs("r-1");
            }
        }
    }

    PopupPanel {
        id: popup
        cardWidth: Math.max(
            Theme.popupMinWidth,
            Math.min(
                Theme.popupMaxWidth,
                Math.max(
                    popupHeader.implicitWidth,
                    (Theme.popupCardMinWidth * Theme.popupColumns) + (Theme.widgetSpacing * (Theme.popupColumns - 1))
                ) + (Theme.popupPadding * 2)
            )
        )
        cardHeight: Math.max(
            Theme.popupMinHeight,
            Math.min(Theme.popupMaxHeight, popupContent.implicitHeight + (Theme.popupPadding * 2))
        )
        targetRelativeX: 0
        targetRelativeY: 0

        content: ColumnLayout {
            id: popupContent
            width: Math.max(0, popup.cardWidth - (Theme.popupPadding * 2))
            spacing: Theme.popupSpacing

            // header matching ScreenCapture, Bluetooth, NetworkStatus & WallpaperBrowser
            RowLayout {
                id: popupHeader
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    width: 34
                    height: 34
                    radius: Theme.radiusMd
                    color: Theme.primary_overlay
                    border.color: Theme.alpha(Theme.primary, 0.35)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: Theme.iconWorkspaces
                        font.family: Theme.fontIcon
                        font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeSm : Theme.fontSizeLg
                        color: Theme.primary
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: "workspaces & scratchpad"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMd
                        font.weight: Font.Bold
                        color: Theme.on_surface
                    }

                    Text {
                        text: "left-click to focus • right-click to send active window"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXs
                        color: Theme.on_surface_variant
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    height: 22
                    implicitWidth: wsBadgeTxt.implicitWidth + 14
                    radius: Theme.radiusPill
                    color: Theme.primary_overlay
                    border.color: Theme.primary
                    border.width: 1

                    Text {
                        id: wsBadgeTxt
                        anchors.centerIn: parent
                        text: "ws " + wsContainer.currentWsId
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeXs
                        font.weight: Font.Bold
                        color: Theme.primary
                    }
                }
            }

            // workspace grid container card
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Math.min(workspaceGrid.implicitHeight + 20, Theme.popupWorkspaceMaxHeight)
                radius: Theme.radiusMd
                color: Theme.cardBg
                border.color: Theme.cardBorder
                border.width: 1
                clip: true

                Rectangle {
                    visible: Theme.isGlass
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: Theme.glassHighlight
                }

                Flickable {
                    id: workspaceScroller
                    anchors.fill: parent
                    anchors.margins: 10
                    clip: true
                    contentWidth: width
                    contentHeight: workspaceGrid.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.VerticalFlick
                    interactive: contentHeight > height

                    Grid {
                        id: workspaceGrid
                        width: workspaceScroller.width
                        columns: Math.max(1, Math.min(Theme.popupColumns, Settings?.workspaceCount ?? Theme.popupColumns))
                        columnSpacing: 6
                        rowSpacing: 6

                        readonly property real cardWidth: Math.max(
                            0,
                            Math.floor((width - (columnSpacing * (columns - 1))) / columns)
                        )

                        Repeater {
                            model: Settings?.workspaceCount ?? 10

                            delegate: Rectangle {
                                id: cardDelegate
                                required property int index
                                readonly property int wsId: index + 1
                                readonly property var wsObj: wsContainer.workspaceMap[wsId] ?? null
                                readonly property bool isCurrent: wsContainer.currentWsId === wsId
                                readonly property int winCount: wsObj?.windows ?? 0
                                readonly property bool hasWindows: winCount > 0

                                width: workspaceGrid.cardWidth
                                height: Theme.popupCardHeight
                                radius: Theme.radiusSm
                                color: isCurrent
                                    ? Theme.primary_overlay
                                    : (cardMouse.containsMouse ? Theme.widgetHover : Theme.widgetBg)
                                border.color: isCurrent
                                    ? Theme.primary
                                    : (cardMouse.containsMouse ? Theme.alpha(Theme.primary, 0.45) : Theme.widgetBorder)
                                border.width: 1

                                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
                                Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: Theme.popupCardPadding
                                    spacing: 8

                                    Rectangle {
                                        Layout.preferredWidth: Theme.popupCardIconSize
                                        Layout.preferredHeight: Theme.popupCardIconSize
                                        radius: Theme.radiusSm
                                        color: isCurrent
                                            ? Theme.primary
                                            : (hasWindows ? Theme.alpha(Theme.primary, 0.18) : Theme.cardBg)
                                        border.color: isCurrent ? Theme.primary : Theme.widgetBorder
                                        border.width: 1

                                        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                        Text {
                                            text: wsId
                                            font.family: Theme.fontMono
                                            font.pixelSize: Theme.fontSizeSm
                                            font.weight: Font.Bold
                                            color: isCurrent ? Theme.on_primary : (hasWindows ? Theme.primary : Theme.on_surface_variant)
                                            anchors.centerIn: parent
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            text: "workspace " + wsId
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeSm
                                            font.weight: isCurrent ? Font.Bold : Font.DemiBold
                                            color: isCurrent ? Theme.primary : Theme.on_surface
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: isCurrent
                                                ? "active workspace"
                                                : (hasWindows ? (winCount + (winCount === 1 ? " window" : " windows")) : "empty")
                                            font.family: Theme.fontMono
                                            font.pixelSize: Theme.fontSizeXs
                                            color: isCurrent ? Theme.primary : Theme.on_surface_variant
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }

                                    // use Theme.fontIcon for iconCheck so Material mode doesn't turn it into a tofu box
                                    Rectangle {
                                        Layout.preferredWidth: 22
                                        Layout.preferredHeight: 22
                                        radius: Theme.radiusPill
                                        color: isCurrent
                                            ? Theme.primary
                                            : (cardMouse.containsMouse ? Theme.primary_overlay : "transparent")
                                        opacity: (isCurrent || cardMouse.containsMouse) ? 1.0 : 0.0

                                        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: isCurrent ? Theme.iconCheck : Theme.iconChevronRight
                                            font.family: Theme.fontIcon
                                            font.pixelSize: Theme.fontSizeXs
                                            color: isCurrent ? Theme.on_primary : Theme.primary
                                        }
                                    }
                                }

                                MouseArea {
                                    id: cardMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: (mouse) => {
                                        if (mouse.button === Qt.RightButton) {
                                            wsContainer.moveWindowToWs(wsId, false);
                                            return;
                                        }
                                        wsContainer.dispatchWs(wsId);
                                        popup.pinned = false;
                                        popup.open = false;
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // scratchpad footer action (left-click toggles scratchpad, right-click stashes active window)
            Rectangle {
                Layout.preferredHeight: 36
                Layout.fillWidth: true
                radius: Theme.radiusMd
                color: specialMouse.containsMouse ? Theme.primary_overlay : Theme.cardBg
                border.color: specialMouse.containsMouse ? Theme.primary : Theme.cardBorder
                border.width: 1

                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
                Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Text {
                        text: Theme.iconSparkles
                        font.family: Theme.fontIcon
                        font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeXs : Theme.fontSizeSm
                        color: Theme.primary
                    }

                    Text {
                        text: "go to scratchpad"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXs
                        font.weight: Font.Bold
                        color: Theme.on_surface
                        Layout.fillWidth: true
                    }

                    Text {
                        text: wsContainer.scratchpadWindows > 0
                            ? (wsContainer.scratchpadWindows + (wsContainer.scratchpadWindows === 1 ? " stashed window" : " stashed windows"))
                            : "right-click to stash window"
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeXs
                        color: wsContainer.scratchpadWindows > 0 ? Theme.primary : Theme.on_surface_variant
                    }
                }

                MouseArea {
                    id: specialMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.RightButton) {
                            wsContainer.moveWindowToWs("special:scratchpad", false);
                            return;
                        }
                        wsContainer.toggleSpecialWs("scratchpad");
                        popup.pinned = false;
                        popup.open = false;
                    }
                }
            }
        }
    }
}
