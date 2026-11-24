import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import ".."
import "../controls"
import Quickshell
import Quickshell.Widgets

Rectangle {
    id: root

    required property var notificationItem
    readonly property var notif: notificationItem

    // expired = timer ran out (keep in bell popup); dismissed = user clicked X / middle-click
    signal expired()
    signal dismissed()

    readonly property bool isCritical: notif?.urgency === 2
    readonly property color accentColor: isCritical ? Theme.error : Theme.primary

    property int timeoutMs: {
        if (!notif) return 5000;
        if (notif.expireTimeout > 0) return notif.expireTimeout;
        if (notif.expireTimeout === 0) return 0;
        return isCritical ? 10000 : (Settings?.notificationTimeout ?? 5000);
    }

    property bool dockTop: (Settings?.barPosition ?? "top") === "top" || (Settings?.barPosition ?? "top") === "up"
    property bool dockBottom: (Settings?.barPosition ?? "top") === "bottom" || (Settings?.barPosition ?? "top") === "down"
    property bool dockLeft: (Settings?.barPosition ?? "top") === "left"
    property bool dockRight: (Settings?.barPosition ?? "top") === "right"

    readonly property string notifEdge: Settings?.notificationEdge ?? "right"
    readonly property bool isEdgeRight: notifEdge === "right"
    readonly property bool isEdgeLeft: notifEdge === "left"
    readonly property bool isEdgeTop: notifEdge === "top"
    readonly property bool isEdgeBottom: notifEdge === "bottom"

    readonly property bool isConcave: (Settings?.notificationCornerStyle ?? "concave") === "concave"
    readonly property real scoopR: Math.min(18, Math.max(8, Theme?.scoopRadiusX ?? 14))
    readonly property color cardBg: isCritical
        ? Theme.blend(Theme.popupBg, Theme.error, 0.12)
        : (Theme?.popupBg ?? Theme?.surface ?? "#1e1e2e")
    readonly property color cardBorderColor: isCritical
        ? Theme.error
        : (Theme?.popupBorderColor ?? Theme?.widgetBorder ?? "#33ffffff")
    readonly property real cardBorderWidth: Theme?.popupBorderWidth ?? 1

    width: 360
    implicitHeight: col.implicitHeight + col.anchors.topMargin + (root.timeoutMs > 0 ? 18 : 14)
    height: implicitHeight
    Layout.preferredHeight: implicitHeight

    readonly property real defaultRadius: Theme?.popupRadius ?? Theme?.radiusMd ?? 14
    readonly property string cornerStyle: Settings?.cornerStyle ?? "cubic"
    readonly property real tension: {
        if (cornerStyle === "squircle") return 0.72;
        if (cornerStyle === "continuous-bezier" || cornerStyle === "g2") return 0.58;
        if (cornerStyle === "flared") return 0.38;
        return Settings?.scoopTension ?? 0.55228475;
    }
    readonly property real hullS: root.scoopR
    readonly property real hullR: Math.min(root.defaultRadius, Math.min(root.width, root.height) * 0.4)
    readonly property real hullK: root.tension

    radius: !isConcave ? defaultRadius : 0
    color: isConcave ? "transparent" : cardBg
    border.color: isConcave ? "transparent" : cardBorderColor
    border.width: isConcave ? 0 : cardBorderWidth
    clip: false

    // unified concave hull + seamless border open along the docked screen bezel edge
    Shape {
        id: hullRight
        anchors.fill: parent
        visible: root.isConcave && root.isEdgeRight
        preferredRendererType: Shape.CurveRenderer
        z: -1

        readonly property real w: root.width
        readonly property real h: root.height
        readonly property real s: root.hullS
        readonly property real r: root.hullR
        readonly property real k: root.hullK

        ShapePath {
            fillColor: root.cardBg
            strokeColor: "transparent"
            strokeWidth: 0

            startX: hullRight.w; startY: -hullRight.s
            PathCubic {
                x: hullRight.w - hullRight.s; y: 0
                control1X: hullRight.w; control1Y: -hullRight.s * (1.0 - hullRight.k)
                control2X: hullRight.w - hullRight.s * (1.0 - hullRight.k); control2Y: 0
            }
            PathLine { x: hullRight.r; y: 0 }
            PathCubic {
                x: 0; y: hullRight.r
                control1X: hullRight.r * (1.0 - hullRight.k); control1Y: 0
                control2X: 0; control2Y: hullRight.r * (1.0 - hullRight.k)
            }
            PathLine { x: 0; y: hullRight.h - hullRight.r }
            PathCubic {
                x: hullRight.r; y: hullRight.h
                control1X: 0; control1Y: hullRight.h - hullRight.r * (1.0 - hullRight.k)
                control2X: hullRight.r * (1.0 - hullRight.k); control2Y: hullRight.h
            }
            PathLine { x: hullRight.w - hullRight.s; y: hullRight.h }
            PathCubic {
                x: hullRight.w; y: hullRight.h + hullRight.s
                control1X: hullRight.w - hullRight.s * (1.0 - hullRight.k); control1Y: hullRight.h
                control2X: hullRight.w; control2Y: hullRight.h + hullRight.s * (1.0 - hullRight.k)
            }
            PathLine { x: hullRight.w; y: -hullRight.s }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.cardBorderWidth > 0 ? root.cardBorderColor : "transparent"
            strokeWidth: root.cardBorderWidth
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            startX: hullRight.w; startY: -hullRight.s
            PathCubic {
                x: hullRight.w - hullRight.s; y: 0
                control1X: hullRight.w; control1Y: -hullRight.s * (1.0 - hullRight.k)
                control2X: hullRight.w - hullRight.s * (1.0 - hullRight.k); control2Y: 0
            }
            PathLine { x: hullRight.r; y: 0 }
            PathCubic {
                x: 0; y: hullRight.r
                control1X: hullRight.r * (1.0 - hullRight.k); control1Y: 0
                control2X: 0; control2Y: hullRight.r * (1.0 - hullRight.k)
            }
            PathLine { x: 0; y: hullRight.h - hullRight.r }
            PathCubic {
                x: hullRight.r; y: hullRight.h
                control1X: 0; control1Y: hullRight.h - hullRight.r * (1.0 - hullRight.k)
                control2X: hullRight.r * (1.0 - hullRight.k); control2Y: hullRight.h
            }
            PathLine { x: hullRight.w - hullRight.s; y: hullRight.h }
            PathCubic {
                x: hullRight.w; y: hullRight.h + hullRight.s
                control1X: hullRight.w - hullRight.s * (1.0 - hullRight.k); control1Y: hullRight.h
                control2X: hullRight.w; control2Y: hullRight.h + hullRight.s * (1.0 - hullRight.k)
            }
        }
    }

    Shape {
        id: hullLeft
        anchors.fill: parent
        visible: root.isConcave && root.isEdgeLeft
        preferredRendererType: Shape.CurveRenderer
        z: -1

        readonly property real w: root.width
        readonly property real h: root.height
        readonly property real s: root.hullS
        readonly property real r: root.hullR
        readonly property real k: root.hullK

        ShapePath {
            fillColor: root.cardBg
            strokeColor: "transparent"
            strokeWidth: 0

            startX: 0; startY: -hullLeft.s
            PathCubic {
                x: hullLeft.s; y: 0
                control1X: 0; control1Y: -hullLeft.s * (1.0 - hullLeft.k)
                control2X: hullLeft.s * (1.0 - hullLeft.k); control2Y: 0
            }
            PathLine { x: hullLeft.w - hullLeft.r; y: 0 }
            PathCubic {
                x: hullLeft.w; y: hullLeft.r
                control1X: hullLeft.w - hullLeft.r * (1.0 - hullLeft.k); control1Y: 0
                control2X: hullLeft.w; control2Y: hullLeft.r * (1.0 - hullLeft.k)
            }
            PathLine { x: hullLeft.w; y: hullLeft.h - hullLeft.r }
            PathCubic {
                x: hullLeft.w - hullLeft.r; y: hullLeft.h
                control1X: hullLeft.w; control1Y: hullLeft.h - hullLeft.r * (1.0 - hullLeft.k)
                control2X: hullLeft.w - hullLeft.r * (1.0 - hullLeft.k); control2Y: hullLeft.h
            }
            PathLine { x: hullLeft.s; y: hullLeft.h }
            PathCubic {
                x: 0; y: hullLeft.h + hullLeft.s
                control1X: hullLeft.s * (1.0 - hullLeft.k); control1Y: hullLeft.h
                control2X: 0; control2Y: hullLeft.h + hullLeft.s * (1.0 - hullLeft.k)
            }
            PathLine { x: 0; y: -hullLeft.s }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.cardBorderWidth > 0 ? root.cardBorderColor : "transparent"
            strokeWidth: root.cardBorderWidth
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            startX: 0; startY: -hullLeft.s
            PathCubic {
                x: hullLeft.s; y: 0
                control1X: 0; control1Y: -hullLeft.s * (1.0 - hullLeft.k)
                control2X: hullLeft.s * (1.0 - hullLeft.k); control2Y: 0
            }
            PathLine { x: hullLeft.w - hullLeft.r; y: 0 }
            PathCubic {
                x: hullLeft.w; y: hullLeft.r
                control1X: hullLeft.w - hullLeft.r * (1.0 - hullLeft.k); control1Y: 0
                control2X: hullLeft.w; control2Y: hullLeft.r * (1.0 - hullLeft.k)
            }
            PathLine { x: hullLeft.w; y: hullLeft.h - hullLeft.r }
            PathCubic {
                x: hullLeft.w - hullLeft.r; y: hullLeft.h
                control1X: hullLeft.w; control1Y: hullLeft.h - hullLeft.r * (1.0 - hullLeft.k)
                control2X: hullLeft.w - hullLeft.r * (1.0 - hullLeft.k); control2Y: hullLeft.h
            }
            PathLine { x: hullLeft.s; y: hullLeft.h }
            PathCubic {
                x: 0; y: hullLeft.h + hullLeft.s
                control1X: hullLeft.s * (1.0 - hullLeft.k); control1Y: hullLeft.h
                control2X: 0; control2Y: hullLeft.h + hullLeft.s * (1.0 - hullLeft.k)
            }
        }
    }

    Shape {
        id: hullTop
        anchors.fill: parent
        visible: root.isConcave && root.isEdgeTop
        preferredRendererType: Shape.CurveRenderer
        z: -1

        readonly property real w: root.width
        readonly property real h: root.height
        readonly property real s: root.hullS
        readonly property real r: root.hullR
        readonly property real k: root.hullK

        ShapePath {
            fillColor: root.cardBg
            strokeColor: "transparent"
            strokeWidth: 0

            startX: -hullTop.s; startY: 0
            PathCubic {
                x: 0; y: hullTop.s
                control1X: -hullTop.s * (1.0 - hullTop.k); control1Y: 0
                control2X: 0; control2Y: hullTop.s * (1.0 - hullTop.k)
            }
            PathLine { x: 0; y: hullTop.h - hullTop.r }
            PathCubic {
                x: hullTop.r; y: hullTop.h
                control1X: 0; control1Y: hullTop.h - hullTop.r * (1.0 - hullTop.k)
                control2X: hullTop.r * (1.0 - hullTop.k); control2Y: hullTop.h
            }
            PathLine { x: hullTop.w - hullTop.r; y: hullTop.h }
            PathCubic {
                x: hullTop.w; y: hullTop.h - hullTop.r
                control1X: hullTop.w - hullTop.r * (1.0 - hullTop.k); control1Y: hullTop.h
                control2X: hullTop.w; control2Y: hullTop.h - hullTop.r * (1.0 - hullTop.k)
            }
            PathLine { x: hullTop.w; y: hullTop.s }
            PathCubic {
                x: hullTop.w + hullTop.s; y: 0
                control1X: hullTop.w; control1Y: hullTop.s * (1.0 - hullTop.k)
                control2X: hullTop.w + hullTop.s * (1.0 - hullTop.k); control2Y: 0
            }
            PathLine { x: -hullTop.s; y: 0 }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.cardBorderWidth > 0 ? root.cardBorderColor : "transparent"
            strokeWidth: root.cardBorderWidth
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            startX: -hullTop.s; startY: 0
            PathCubic {
                x: 0; y: hullTop.s
                control1X: -hullTop.s * (1.0 - hullTop.k); control1Y: 0
                control2X: 0; control2Y: hullTop.s * (1.0 - hullTop.k)
            }
            PathLine { x: 0; y: hullTop.h - hullTop.r }
            PathCubic {
                x: hullTop.r; y: hullTop.h
                control1X: 0; control1Y: hullTop.h - hullTop.r * (1.0 - hullTop.k)
                control2X: hullTop.r * (1.0 - hullTop.k); control2Y: hullTop.h
            }
            PathLine { x: hullTop.w - hullTop.r; y: hullTop.h }
            PathCubic {
                x: hullTop.w; y: hullTop.h - hullTop.r
                control1X: hullTop.w - hullTop.r * (1.0 - hullTop.k); control1Y: hullTop.h
                control2X: hullTop.w; control2Y: hullTop.h - hullTop.r * (1.0 - hullTop.k)
            }
            PathLine { x: hullTop.w; y: hullTop.s }
            PathCubic {
                x: hullTop.w + hullTop.s; y: 0
                control1X: hullTop.w; control1Y: hullTop.s * (1.0 - hullTop.k)
                control2X: hullTop.w + hullTop.s * (1.0 - hullTop.k); control2Y: 0
            }
        }
    }

    Shape {
        id: hullBottom
        anchors.fill: parent
        visible: root.isConcave && root.isEdgeBottom
        preferredRendererType: Shape.CurveRenderer
        z: -1

        readonly property real w: root.width
        readonly property real h: root.height
        readonly property real s: root.hullS
        readonly property real r: root.hullR
        readonly property real k: root.hullK

        ShapePath {
            fillColor: root.cardBg
            strokeColor: "transparent"
            strokeWidth: 0

            startX: -hullBottom.s; startY: hullBottom.h
            PathCubic {
                x: 0; y: hullBottom.h - hullBottom.s
                control1X: -hullBottom.s * (1.0 - hullBottom.k); control1Y: hullBottom.h
                control2X: 0; control2Y: hullBottom.h - hullBottom.s * (1.0 - hullBottom.k)
            }
            PathLine { x: 0; y: hullBottom.r }
            PathCubic {
                x: hullBottom.r; y: 0
                control1X: 0; control1Y: hullBottom.r * (1.0 - hullBottom.k)
                control2X: hullBottom.r * (1.0 - hullBottom.k); control2Y: 0
            }
            PathLine { x: hullBottom.w - hullBottom.r; y: 0 }
            PathCubic {
                x: hullBottom.w; y: hullBottom.r
                control1X: hullBottom.w - hullBottom.r * (1.0 - hullBottom.k); control1Y: 0
                control2X: hullBottom.w; control2Y: hullBottom.r * (1.0 - hullBottom.k)
            }
            PathLine { x: hullBottom.w; y: hullBottom.h - hullBottom.s }
            PathCubic {
                x: hullBottom.w + hullBottom.s; y: hullBottom.h
                control1X: hullBottom.w; control1Y: hullBottom.h - hullBottom.s * (1.0 - hullBottom.k)
                control2X: hullBottom.w + hullBottom.s * (1.0 - hullBottom.k); control2Y: hullBottom.h
            }
            PathLine { x: -hullBottom.s; y: hullBottom.h }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.cardBorderWidth > 0 ? root.cardBorderColor : "transparent"
            strokeWidth: root.cardBorderWidth
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            startX: -hullBottom.s; startY: hullBottom.h
            PathCubic {
                x: 0; y: hullBottom.h - hullBottom.s
                control1X: -hullBottom.s * (1.0 - hullBottom.k); control1Y: hullBottom.h
                control2X: 0; control2Y: hullBottom.h - hullBottom.s * (1.0 - hullBottom.k)
            }
            PathLine { x: 0; y: hullBottom.r }
            PathCubic {
                x: hullBottom.r; y: 0
                control1X: 0; control1Y: hullBottom.r * (1.0 - hullBottom.k)
                control2X: hullBottom.r * (1.0 - hullBottom.k); control2Y: 0
            }
            PathLine { x: hullBottom.w - hullBottom.r; y: 0 }
            PathCubic {
                x: hullBottom.w; y: hullBottom.r
                control1X: hullBottom.w - hullBottom.r * (1.0 - hullBottom.k); control1Y: 0
                control2X: hullBottom.w; control2Y: hullBottom.r * (1.0 - hullBottom.k)
            }
            PathLine { x: hullBottom.w; y: hullBottom.h - hullBottom.s }
            PathCubic {
                x: hullBottom.w + hullBottom.s; y: hullBottom.h
                control1X: hullBottom.w; control1Y: hullBottom.h - hullBottom.s * (1.0 - hullBottom.k)
                control2X: hullBottom.w + hullBottom.s * (1.0 - hullBottom.k); control2Y: hullBottom.h
            }
        }
    }

    // check theme icon existence first so qt doesn't cry about missing qrc paths
    readonly property string resolvedIcon: {
        if (!root.notif) return "";
        let icon = root.notif.appIcon || "";
        if (icon) {
            if (icon.startsWith("image://") || icon.startsWith("file://")) return icon;
            if (icon.startsWith("/")) return "file://" + icon;
            if (Quickshell?.hasThemeIcon && Quickshell.hasThemeIcon(icon)) {
                return Quickshell.iconPath(icon);
            }
            let lower = icon.toLowerCase();
            if (Quickshell?.hasThemeIcon && Quickshell.hasThemeIcon(lower)) {
                return Quickshell.iconPath(lower);
            }
        }
        if (Theme?.resolveAppIcon) {
            return Theme.resolveAppIcon(root.notif.desktopEntry || root.notif.appIcon || root.notif.appName || "");
        }
        return "";
    }

    readonly property real slideDistance: 120
    readonly property real ingressOffsetX: isEdgeLeft ? -slideDistance : (isEdgeRight ? slideDistance : 0)
    readonly property real ingressOffsetY: isEdgeTop ? -slideDistance : (isEdgeBottom ? slideDistance : 0)

    property real slideOffsetX: (notif?._entered) ? 0 : root.ingressOffsetX
    property real slideOffsetY: (notif?._entered) ? 0 : root.ingressOffsetY
    property real cardOpacity: (notif?._entered) ? 1.0 : 0.0
    property bool _userDismissed: false
    property bool _closing: false

    onNotifChanged: {
        if (notif && !root._closing && notif._elapsedMs === 0) {
            root.elapsedMs = 0;
        }
    }

    transform: Translate {
        x: root.slideOffsetX
        y: root.slideOffsetY
    }
    opacity: root.cardOpacity

    Component.onCompleted: {
        if (root.notif && !root.notif._entered) {
            root.notif._entered = true;
            enterAnim.restart();
        }
    }

    ParallelAnimation {
        id: enterAnim
        NumberAnimation {
            target: root
            property: "slideOffsetX"
            from: root.ingressOffsetX
            to: 0
            duration: Theme?.animNormal ?? 200
            easing.type: Theme?.animEasingEntrance ?? Easing.OutCubic
        }
        NumberAnimation {
            target: root
            property: "slideOffsetY"
            from: root.ingressOffsetY
            to: 0
            duration: Theme?.animNormal ?? 200
            easing.type: Theme?.animEasingEntrance ?? Easing.OutCubic
        }
        NumberAnimation {
            target: root
            property: "cardOpacity"
            from: 0.0
            to: 1.0
            duration: Theme?.animFast ?? 120
            easing.type: Theme?.animEasing ?? Easing.OutCubic
        }
    }

    ParallelAnimation {
        id: exitAnim
        NumberAnimation {
            target: root
            property: "slideOffsetX"
            to: root.ingressOffsetX
            duration: Theme?.animFast ?? 120
            easing.type: Theme?.animEasingExit ?? Easing.InCubic
        }
        NumberAnimation {
            target: root
            property: "slideOffsetY"
            to: root.ingressOffsetY
            duration: Theme?.animFast ?? 120
            easing.type: Theme?.animEasingExit ?? Easing.InCubic
        }
        NumberAnimation {
            target: root
            property: "cardOpacity"
            to: 0.0
            duration: Theme?.animFast ?? 120
            easing.type: Theme?.animEasingExit ?? Easing.InCubic
        }
        onFinished: {
            if (root._userDismissed) {
                root.dismissed();
            } else {
                root.expired();
            }
        }
    }

    function closeToast(permanent: bool) {
        if (root._closing) return;
        root._closing = true;
        root._userDismissed = permanent;
        progressTimer.stop();
        exitAnim.restart();
    }

    HoverHandler {
        id: cardHover
    }

    readonly property bool isHovered: cardHover.hovered
    onIsHoveredChanged: {
        if (!isHovered) _lastTick = Date.now();
    }

    property real elapsedMs: notif?._elapsedMs ?? 0
    property real _lastTick: 0
    readonly property real progressRatio: root.timeoutMs > 0 ? Math.max(0.0, 1.0 - (elapsedMs / root.timeoutMs)) : 1.0

    Timer {
        id: progressTimer
        interval: 30
        repeat: true
        running: root.timeoutMs > 0 && !root.isHovered && !root._closing
        onTriggered: {
            let now = Date.now();
            if (root._lastTick > 0) {
                root.elapsedMs += (now - root._lastTick);
                if (root.notif) root.notif._elapsedMs = root.elapsedMs;
            }
            root._lastTick = now;
            if (root.elapsedMs >= root.timeoutMs) {
                root.closeToast(false);
            }
        }
    }

    // middle-click to dismiss permanently, right-click to shoo the toast off screen
    MouseArea {
        id: cardMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.ArrowCursor
        onClicked: (mouse) => {
            if (mouse.button === Qt.MiddleButton) {
                root.closeToast(true);
            } else if (mouse.button === Qt.RightButton) {
                root.closeToast(false);
            }
        }
    }

    // anchored to top/left/right only so wrapped text never causes a height binding loop
    ColumnLayout {
        id: col
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 14
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                radius: Theme?.radiusSm ?? 6
                color: Theme?.pillBg ?? "#2a2a3c"
                border.color: Theme?.pillBorder ?? "transparent"
                border.width: 1
                clip: true

                IconImage {
                    id: notifIconImg
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    implicitSize: 16
                    source: root.resolvedIcon
                    visible: root.resolvedIcon !== "" && notifIconImg.status !== Image.Error
                }

                Text {
                    anchors.centerIn: parent
                    visible: !notifIconImg.visible
                    text: root.isCritical ? Theme.iconFlame : (Theme?.iconBell ?? "\uE7F5")
                    font.family: Theme?.fontIcon ?? Theme?.fontMono
                    font.variableAxes: Theme?.iconAxes ?? ({})
                    font.pixelSize: Theme?.fontSizeXs ?? 12
                    color: root.accentColor
                }
            }

            Text {
                text: (root.notif?.appName || "system").toLowerCase()
                font.family: Theme?.fontMono ?? "monospace"
                font.pixelSize: Theme?.fontSizeXs ?? 11
                font.weight: Theme?.fontWeightBold ?? Font.Bold
                color: root.accentColor
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Rectangle {
                visible: root.isCritical
                height: 18
                implicitWidth: urgentTxt.implicitWidth + 10
                radius: Theme.radiusPill
                color: Theme.error_overlay
                border.color: Theme.error
                border.width: 1

                Text {
                    id: urgentTxt
                    anchors.centerIn: parent
                    text: "urgent"
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeXs
                    font.weight: Theme.fontWeightBold
                    color: Theme.error
                }
            }

            IconButton {
                icon: Theme?.iconClose ?? "\uE5CD"
                iconSize: Theme?.fontSizeXs ?? 11
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                tooltip: "dismiss"
                onClicked: root.closeToast(true)
            }
        }

        Text {
            text: (root.notif?.summary ?? "").toLowerCase()
            font.family: Theme?.fontDisplay ?? Theme?.fontFamily ?? "sans-serif"
            font.pixelSize: Theme?.fontSizeSm ?? 13
            font.weight: Theme?.fontWeightBold ?? Font.DemiBold
            color: Theme?.on_surface ?? "#cdd6f4"
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            visible: text !== ""
        }

        Text {
            text: (root.notif?.body ?? "").replace(/<[^>]*>/g, "").toLowerCase()
            font.family: Theme?.fontFamily ?? "sans-serif"
            font.pixelSize: Theme?.fontSizeXs ?? 11
            color: Theme?.on_surface_variant ?? "#a6adc8"
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            visible: text !== ""
            maximumLineCount: 6
            elide: Text.ElideRight
        }

        ClippingRectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 120
            radius: Theme?.radiusSm ?? 6
            color: Theme?.cardBg ?? "transparent"
            border.color: Theme?.cardBorder ?? "transparent"
            border.width: 1
            visible: Boolean(root.notif?.image) && previewImg.status !== Image.Error

            Image {
                id: previewImg
                anchors.fill: parent
                source: root.notif?.image ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: Boolean(root.notif?.actions && root.notif.actions.length > 0)

            Repeater {
                model: root.notif?.actions ?? []

                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    height: 28
                    radius: actMouse.pressed ? Theme.radiusPill : (Theme?.radiusSm ?? 6)
                    color: actMouse.pressed
                        ? root.accentColor
                        : (actMouse.containsMouse
                            ? (root.isCritical ? Theme.error_overlay : Theme.primary_overlay)
                            : Theme.pillBg)
                    border.color: actMouse.containsMouse ? root.accentColor : (Theme?.pillBorder ?? "#33ffffff")
                    border.width: 1

                    Behavior on radius { NumberAnimation { duration: Theme?.animFast ?? 120 } }
                    Behavior on color { ColorAnimation { duration: Theme?.animFast ?? 120; easing.type: Theme?.animColorEasing ?? Easing.OutQuad } }

                    Text {
                        anchors.centerIn: parent
                        text: (modelData?.text || modelData?.id || "action").toLowerCase()
                        font.family: Theme?.fontFamily ?? "sans-serif"
                        font.pixelSize: Theme?.fontSizeXs ?? 11
                        font.weight: Theme?.fontWeightBold ?? Font.Medium
                        color: actMouse.pressed
                            ? (root.isCritical ? Theme.on_error : Theme.on_primary)
                            : (actMouse.containsMouse ? root.accentColor : Theme.on_surface)
                        elide: Text.ElideRight
                        width: parent.width - 12
                        horizontalAlignment: Text.AlignHCenter
                    }

                    MouseArea {
                        id: actMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData && typeof modelData.invoke === "function") {
                                modelData.invoke();
                            }
                            root.closeToast(true);
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: (root.isConcave && root.isEdgeLeft) ? (root.scoopR + 6) : 12
        anchors.rightMargin: (root.isConcave && root.isEdgeRight) ? (root.scoopR + 6) : 12
        height: 3
        radius: 1.5
        color: Theme?.pillBg ?? "#2a2a3c"
        visible: root.timeoutMs > 0

        Rectangle {
            id: progressBar
            height: parent.height
            radius: 1.5
            color: root.accentColor
            width: parent.width * root.progressRatio
        }
    }
}
