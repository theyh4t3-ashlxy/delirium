// StatusBar.qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."
import "../widgets"
import "../controls"
import "../corners"
import Quickshell.Services.UPower

PanelWindow {
    id: root

    required property var modelData
    screen: modelData
    color: "transparent"

    function hasAdjacentMonitorAt(dir, corner) {
        if (!root.screen) return false;
        let all = Quickshell.screens;
        if (!all || all.length <= 1) return false;
        let sx = root.screen.x, sy = root.screen.y, sw = root.screen.width, sh = root.screen.height;
        for (let i = 0; i < all.length; i++) {
            let o = all[i];
            if (o === root.screen || o.name === root.screen.name) continue;
            let ox = o.x, oy = o.y, ow = o.width, oh = o.height;
            if (dir === "right" && Math.abs(ox - (sx + sw)) <= 4) {
                if (!corner) {
                    if (!(oy + oh <= sy || oy >= sy + sh)) return true;
                } else if (corner === "topRight" || corner === "top" || corner === "topLeft") {
                    if (oy <= sy + 4 && (oy + oh) >= sy + 4) return true;
                } else if (corner === "bottomRight" || corner === "bottom" || corner === "bottomLeft") {
                    if (oy <= sy + sh - 4 && (oy + oh) >= sy + sh - 4) return true;
                }
            }
            if (dir === "left" && Math.abs((ox + ow) - sx) <= 4) {
                if (!corner) {
                    if (!(oy + oh <= sy || oy >= sy + sh)) return true;
                } else if (corner === "topLeft" || corner === "top" || corner === "topRight") {
                    if (oy <= sy + 4 && (oy + oh) >= sy + 4) return true;
                } else if (corner === "bottomLeft" || corner === "bottom" || corner === "bottomRight") {
                    if (oy <= sy + sh - 4 && (oy + oh) >= sy + sh - 4) return true;
                }
            }
            if (dir === "top" && Math.abs((oy + oh) - sy) <= 4) {
                if (!corner) {
                    if (!(ox + ow <= sx || ox >= sx + sw)) return true;
                } else if (corner === "topLeft" || corner === "left" || corner === "bottomLeft") {
                    if (ox <= sx + 4 && (ox + ow) >= sx + 4) return true;
                } else if (corner === "topRight" || corner === "right" || corner === "bottomRight") {
                    if (ox <= sx + sw - 4 && (ox + ow) >= sx + sw - 4) return true;
                }
            }
            if (dir === "bottom" && Math.abs(oy - (sy + sh)) <= 4) {
                if (!corner) {
                    if (!(ox + ow <= sx || ox >= sx + sw)) return true;
                } else if (corner === "bottomLeft" || corner === "left" || corner === "topLeft") {
                    if (ox <= sx + 4 && (ox + ow) >= sx + 4) return true;
                } else if (corner === "bottomRight" || corner === "right" || corner === "topRight") {
                    if (ox <= sx + sw - 4 && (ox + ow) >= sx + sw - 4) return true;
                }
            }
        }
        return false;
    }

    function hasAdjacentMonitor(dir) {
        return hasAdjacentMonitorAt(dir, null);
    }

    readonly property var hyprMonitor: Hyprland.monitorFor ? Hyprland.monitorFor(root.screen) : null
    readonly property bool isFullscreen: (hyprMonitor?.activeWorkspace?.hasFullscreen) ?? (Hyprland.focusedWorkspace?.hasFullscreen ?? false)
    visible: !root.isFullscreen

    onIsFullscreenChanged: {
        if (root.isFullscreen && launcherPopup.open) {
            launcherPopup.open = false;
        }
    }

    readonly property string pos: Settings?.barPosition ?? "up"
    readonly property bool isTop: pos === "up" || pos === "top"
    readonly property bool isBottom: pos === "down" || pos === "bottom"
    readonly property bool isLeft: pos === "left"
    readonly property bool isRight: pos === "right"
    readonly property bool isVertical: isLeft || isRight

    readonly property int effectivePaddingH: Math.max(4, Math.round(Theme.widgetPaddingH * Theme.paddingScaleMult))
    readonly property int effectiveSpacing: Math.max(2, Math.round(Theme.widgetSpacing * Theme.paddingScaleMult))

    readonly property real maxWindowTitleWidth: {
        let halfScreen = root.width / 2;
        let centerHalf = (centerRowH.visible ? centerRowH.width : 0) / 2;
        let clockStart = halfScreen - centerHalf;
        return Math.max(160, clockStart - 260);
    }
    readonly property real maxRightRowWidth: {
        let halfScreen = root.width / 2;
        let centerHalf = (centerRowH.visible ? centerRowH.width : 0) / 2;
        let clockRight = halfScreen - centerHalf;
        return Math.max(380, clockRight - (root.effectivePaddingH * 2));
    }

    readonly property bool isFloating: (Settings?.barFloating ?? false) || Theme.isBento || (Settings?.barStyle === "bento-floating")
    readonly property bool isIslandMode: Theme.isBento || (Settings?.barStyle === "bento-floating") || (root.isFloating && (Settings?.barIslandMode ?? true))
    readonly property int barMargin: Settings?.barMargin ?? 0
    readonly property int effectiveBarMargin: root.isFloating ? (root.barMargin > 0 ? root.barMargin : 8) : 0
    readonly property int barRadius: Settings?.barRadius ?? 0
    readonly property int effectiveBarRadius: root.isFloating ? (root.barRadius > 0 ? root.barRadius : Theme.screenCornerRadius) : 0

    readonly property int scoopRadius: Math.round(Settings?.scoopRadius ?? Settings?.screenCornerRadius ?? Theme.scoopRadius)
    readonly property string cornerMode: Settings?.screenCornerMode ?? Theme.screenCornerMode

    readonly property bool scoopAllowedLeft: {
        if (cornerMode === "none" || cornerMode === "opposite") return false;
        if (cornerMode === "monitor") {
            let c = isBottom ? "bottomLeft" : "topLeft";
            return !hasAdjacentMonitorAt("left", c) && !hasAdjacentMonitorAt(isBottom ? "bottom" : "top", c);
        }
        if (cornerMode === "all" || cornerMode === "left") return true;
        if (isTop && cornerMode === "top") return true;
        if (isBottom && cornerMode === "bottom") return true;
        return false;
    }
    readonly property bool scoopAllowedRight: {
        if (cornerMode === "none" || cornerMode === "opposite") return false;
        if (cornerMode === "monitor") {
            let c = isBottom ? "bottomRight" : "topRight";
            return !hasAdjacentMonitorAt("right", c) && !hasAdjacentMonitorAt(isBottom ? "bottom" : "top", c);
        }
        if (cornerMode === "all" || cornerMode === "right") return true;
        if (isTop && cornerMode === "top") return true;
        if (isBottom && cornerMode === "bottom") return true;
        return false;
    }
    readonly property bool scoopAllowedTop: {
        if (cornerMode === "none" || cornerMode === "opposite") return false;
        if (cornerMode === "monitor") {
            let c = isRight ? "topRight" : "topLeft";
            return !hasAdjacentMonitorAt("top", c) && !hasAdjacentMonitorAt(isRight ? "right" : "left", c);
        }
        if (cornerMode === "all" || cornerMode === "top") return true;
        if (isLeft && cornerMode === "left") return true;
        if (isRight && cornerMode === "right") return true;
        return false;
    }
    readonly property bool scoopAllowedBottom: {
        if (cornerMode === "none" || cornerMode === "opposite") return false;
        if (cornerMode === "monitor") {
            let c = isRight ? "bottomRight" : "bottomLeft";
            return !hasAdjacentMonitorAt("bottom", c) && !hasAdjacentMonitorAt(isRight ? "right" : "left", c);
        }
        if (cornerMode === "all" || cornerMode === "bottom") return true;
        if (isLeft && cornerMode === "left") return true;
        if (isRight && cornerMode === "right") return true;
        return false;
    }

    readonly property bool borderLeftAllowed: cornerMode === "all" || cornerMode === "left" || (cornerMode === "monitor" && !hasAdjacentMonitor("left")) || (cornerMode === "opposite" && isRight)
    readonly property bool borderRightAllowed: cornerMode === "all" || cornerMode === "right" || (cornerMode === "monitor" && !hasAdjacentMonitor("right")) || (cornerMode === "opposite" && isLeft)
    readonly property bool borderTopAllowed: cornerMode === "all" || cornerMode === "top" || (cornerMode === "monitor" && !hasAdjacentMonitor("top")) || (cornerMode === "opposite" && isBottom)
    readonly property bool borderBottomAllowed: cornerMode === "all" || cornerMode === "bottom" || (cornerMode === "monitor" && !hasAdjacentMonitor("bottom")) || (cornerMode === "opposite" && isTop)

    readonly property int borderWidth: Math.round(Theme.screenFrameDocked ? Theme.screenBorderWidth : 0)
    readonly property bool hasBarScoops: !root.isFloating && !root.isIslandMode && Theme.screenFrameDocked && root.scoopRadius > 0 && (
        root.isVertical ? (scoopAllowedTop || scoopAllowedBottom) : (scoopAllowedLeft || scoopAllowedRight)
    )

    readonly property string cornerStyle: Theme.scoopStyle
    readonly property real scoopTension: {
        if (cornerStyle === "squircle") return 0.72;
        if (cornerStyle === "continuous-bezier" || cornerStyle === "g2") return 0.58;
        if (cornerStyle === "flared") return 0.38;
        return Theme.scoopTension;
    }

    readonly property real dpr: Math.max(1.0, (Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1.0))

    readonly property bool hasCaptureModuleOnBar: {
        if (!root.isModuleVisible("screenCapture")) return false;
        let left = Settings?.barModulesLeft ?? [];
        let center = Settings?.barModulesCenter ?? ["clock"];
        let right = Settings?.barModulesRight ?? [];
        return left.indexOf("screenCapture") !== -1 || left.indexOf("capture") !== -1
            || center.indexOf("screenCapture") !== -1 || center.indexOf("capture") !== -1
            || right.indexOf("screenCapture") !== -1 || right.indexOf("capture") !== -1;
    }

    function traceScoopCurve(ctx, x0, y0, cx, cy, x1, y1, style, t) {
        if (style === "chamfer") {
            ctx.lineTo(x1, y1);
        } else if (style === "stepped") {
            var ux = x0 - cx, uy = y0 - cy;
            var vx = x1 - cx, vy = y1 - cy;
            ctx.lineTo(cx + ux + vx / 3.0, cy + uy + vy / 3.0);
            ctx.lineTo(cx + (2.0 * ux) / 3.0 + vx / 3.0, cy + (2.0 * uy) / 3.0 + vy / 3.0);
            ctx.lineTo(cx + (2.0 * ux) / 3.0 + (2.0 * vx) / 3.0, cy + (2.0 * uy) / 3.0 + (2.0 * vy) / 3.0);
            ctx.lineTo(cx + ux / 3.0 + (2.0 * vx) / 3.0, cy + uy / 3.0 + (2.0 * vy) / 3.0);
            ctx.lineTo(cx + ux / 3.0 + vx, cy + uy / 3.0 + vy);
            ctx.lineTo(x1, y1);
        } else if (style === "hyperbolic") {
            var hx = cx + (x0 + x1 - 2.0 * cx) * 0.2;
            var hy = cy + (y0 + y1 - 2.0 * cy) * 0.2;
            ctx.quadraticCurveTo(hx, hy, x1, y1);
        } else {
            var c1x = x0 + (cx - x0) * t;
            var c1y = y0 + (cy - y0) * t;
            var c2x = x1 + (cx - x1) * t;
            var c2y = y1 + (cy - y1) * t;
            ctx.bezierCurveTo(c1x, c1y, c2x, c2y, x1, y1);
        }
    }

    anchors {
        top: root.isTop || root.isVertical
        bottom: root.isBottom || root.isVertical
        left: root.isLeft || !root.isVertical
        right: root.isRight || !root.isVertical
    }

    margins {
        top: root.isFloating && (root.isTop || root.isVertical) ? root.effectiveBarMargin : 0
        bottom: root.isFloating && (root.isBottom || root.isVertical) ? root.effectiveBarMargin : 0
        left: root.isFloating && (root.isLeft || !root.isVertical) ? root.effectiveBarMargin : 0
        right: root.isFloating && (root.isRight || !root.isVertical) ? root.effectiveBarMargin : 0
    }

    implicitWidth: root.isVertical ? (Theme.barHeight + (root.hasBarScoops ? root.scoopRadius : 0)) : (root.screen?.width ?? 1920)
    implicitHeight: root.isVertical ? (root.screen?.height ?? 1080) : (Theme.barHeight + (root.hasBarScoops ? root.scoopRadius : 0))
    exclusiveZone: Theme.barHeight + (root.isFloating ? root.effectiveBarMargin : 0)
    exclusionMode: ExclusionMode.Normal

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell:bar"

    mask: Region {
        item: root.isIslandMode ? null : barBg
        Region { item: root.isIslandMode ? (root.isVertical ? bentoTopIslandV : bentoLeftIsland) : null }
        Region { item: root.isIslandMode ? (root.isVertical ? bentoCenterIslandV : bentoCenterIsland) : null }
        Region { item: root.isIslandMode ? (root.isVertical ? bentoBottomIslandV : bentoRightIsland) : null }
    }

    property alias launcherPopup: launcherPopup

    AppLauncher {
        id: launcherPopup
        screen: root.screen
    }

    Timer {
        id: wsScrollCooldown
        interval: 120
        repeat: false
    }

    Connections {
        target: Settings
        function onRequestLauncherToggle() {
            if (!root.screen || Quickshell.screens.length <= 1 || (root.hyprMonitor && Hyprland.focusedMonitor && root.hyprMonitor.id === Hyprland.focusedMonitor.id)) {
                root.launcherPopup.targetRelativeX = 0;
                root.launcherPopup.targetRelativeY = 0;
                root.launcherPopup.open = !root.launcherPopup.open;
            }
        }
        function onRequestLauncherOpen() {
            if (!root.screen || Quickshell.screens.length <= 1 || (root.hyprMonitor && Hyprland.focusedMonitor && root.hyprMonitor.id === Hyprland.focusedMonitor.id)) {
                root.launcherPopup.targetRelativeX = 0;
                root.launcherPopup.targetRelativeY = 0;
                root.launcherPopup.open = true;
            }
        }
        function onRequestLauncherClose() {
            root.launcherPopup.open = false;
        }
    }

    Component { id: compLauncher; Rectangle {
        id: launcherPill
        visible: Settings?.showLauncher ?? true
        implicitWidth: root.isVertical ? (Theme.barHeight - 8) : Math.max(36, launcherText.implicitWidth + 16)
        implicitHeight: root.isVertical ? Math.max(36, launcherText.implicitHeight + 12) : (Theme.barHeight - 8)
        width: implicitWidth
        height: implicitHeight
        radius: Theme.radiusPill
        color: lMouse.pressed ? Theme.widgetActive : lMouse.containsMouse ? Theme.pillHover : (root.launcherPopup.open ? Theme.primary_overlay : Theme.pillBg)
        border.color: root.launcherPopup.open ? Theme.primary : Theme.pillBorder
        border.width: (border.color === "transparent" || border.color.a === 0) ? 0 : 1
        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
        Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
        Behavior on implicitWidth { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
        Text {
            id: launcherText
            anchors.centerIn: parent
            text: Theme.iconDistro ?? Theme.iconArch
            font.family: Theme.fontIcon
            font.pixelSize: Theme.isTextIconSet ? (root.isVertical ? Theme.fontSizeXs : Theme.fontSizeSm) : Theme.fontSizeLg
            color: root.launcherPopup.open || lMouse.containsMouse ? Theme.primary : Theme.on_surface
            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
        }
        MouseArea {
            id: lMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor
            onClicked: (mouse) => {
                if (mouse.button === Qt.LeftButton) {
                    let pt = launcherPill.mapToItem(null, 0, 0);
                    if (pt) {
                        if (root.isVertical) {
                            root.launcherPopup.targetRelativeX = 0;
                            root.launcherPopup.targetRelativeY = pt.y + (launcherPill.implicitHeight / 2) + root.effectiveBarMargin;
                        } else {
                            root.launcherPopup.targetRelativeX = pt.x + (launcherPill.implicitWidth / 2) + root.effectiveBarMargin;
                            root.launcherPopup.targetRelativeY = 0;
                        }
                    }
                    root.launcherPopup.open = !root.launcherPopup.open;
                } else if (mouse.button === Qt.RightButton) {
                    if (typeof Settings !== "undefined" && Settings?.requestPowerMenuToggle) {
                        Settings.requestPowerMenuToggle();
                    }
                } else if (mouse.button === Qt.MiddleButton) {
                    if (typeof Settings !== "undefined" && Settings?.requestWallpaperToggle) {
                        Settings.requestWallpaperToggle();
                    } else if (typeof Settings !== "undefined" && Settings?.requestQuickSettingsToggle) {
                        Settings.requestQuickSettingsToggle();
                    }
                }
            }
        }
    }}

    Component { id: compWallpaper; WallpaperBrowser { barScreen: root.screen; barMonitor: root.hyprMonitor } }
    Component { id: compWorkspaces; Workspaces {} }
    Component { id: compWindowTitle; WindowTitle { barScreen: root.screen; barMonitor: root.hyprMonitor } }
    Component { id: compClock; Clock {} }
    Component { id: compMedia; NowPlaying {} }
    Component { id: compQuickNotes; QuickNotes { barScreen: root.screen; barMonitor: root.hyprMonitor } }
    Component { id: compClipboard; Clipboard {} }
    Component { id: compIdleInhibitor; IdleInhibitor { barScreen: root.screen; barMonitor: root.hyprMonitor } }
    Component { id: compNotifications; Notifications {} }
    Component { id: compSystemTray; SystemTray {} }
    Component { id: compBluetooth; Bluetooth {} }
    Component { id: compNetwork; NetworkStatus {} }
    Component { id: compVolume; VolumeControl {} }
    Component { id: compBattery; Battery { barScreen: root.screen; barMonitor: root.hyprMonitor } }
    Component { id: compQuickSettings; QuickSettings { barScreen: root.screen; barMonitor: root.hyprMonitor } }
    Component { id: compPowerMenu; PowerMenu {} }
    Component { id: compScreenCapture; ScreenCapture { barScreen: root.screen; barMonitor: root.hyprMonitor } }
    Component { id: compDynamicNotch; DynamicNotch { barScreen: root.screen; barMonitor: root.hyprMonitor } }
    Component { id: compLayout; LayoutSwitcher { barScreen: root.screen; barMonitor: root.hyprMonitor } }

    function getModuleComponent(modId) {
        if (modId === "launcher") return compLauncher;
        if (modId === "wallpaper") return compWallpaper;
        if (modId === "workspaces") return compWorkspaces;
        if (modId === "layout" || modId === "layoutSwitcher") return compLayout;
        if (modId === "windowTitle") return compWindowTitle;
        if (modId === "clock") return compClock;
        if (modId === "dynamicNotch" || modId === "notch") return compDynamicNotch;
        if (modId === "media") return compMedia;
        if (modId === "quickNotes") return compQuickNotes;
        if (modId === "clipboard") return compClipboard;
        if (modId === "idleInhibitor") return compIdleInhibitor;
        if (modId === "notifications") return compNotifications;
        if (modId === "systemTray") return compSystemTray;
        if (modId === "bluetooth") return compBluetooth;
        if (modId === "network") return compNetwork;
        if (modId === "volume") return compVolume;
        if (modId === "battery") return compBattery;
        if (modId === "quickSettings") return compQuickSettings;
        if (modId === "powerMenu") return compPowerMenu;
        if (modId === "screenCapture" || modId === "capture") return compScreenCapture;
        return null;
    }

    function isModuleVisible(modId) {
        if (modId === "launcher") return Settings?.showLauncher ?? true;
        if (modId === "wallpaper") return Settings?.showWallpaper ?? true;
        if (modId === "workspaces") return Settings?.showWorkspaces ?? true;
        if (modId === "layout" || modId === "layoutSwitcher") return Settings?.showLayoutSwitcher ?? true;
        if (modId === "windowTitle") return (Settings?.showWindowTitle ?? true) && !root.isVertical;
        if (modId === "clock") return Settings?.showClock ?? true;
        if (modId === "dynamicNotch" || modId === "notch") return Settings?.showDynamicNotch ?? true;
        if (modId === "media") return Settings?.showMedia ?? true;
        if (modId === "quickNotes") return Settings?.showQuickNotes ?? true;
        if (modId === "clipboard") return Settings?.showClipboard ?? true;
        if (modId === "idleInhibitor") return Settings?.showIdleInhibitor ?? true;
        if (modId === "notifications") return Settings?.showNotifications ?? true;
        if (modId === "systemTray") return Settings?.showSystemTray ?? true;
        if (modId === "bluetooth") return Settings?.showBluetooth ?? true;
        if (modId === "network") return Settings?.showNetwork ?? true;
        if (modId === "volume") return Settings?.showVolume ?? true;
        if (modId === "battery") return (Settings?.showBattery ?? true) && (UPower.displayDevice?.isPresent ?? false);
        if (modId === "quickSettings") return Settings?.showQuickSettings ?? true;
        if (modId === "powerMenu") return Settings?.showPowerMenu ?? true;
        if (modId === "screenCapture" || modId === "capture") return Settings?.showScreenCapture ?? true;
        return true;
    }

    Item {
        id: barRootItem
        anchors.fill: parent

        Rectangle {
            visible: Theme.isAccentGlow && !root.isIslandMode
            anchors.fill: barBg
            anchors.margins: -4
            radius: root.effectiveBarRadius + 4
            color: Theme.alpha(Theme.primary, 0.28)
            z: -2
        }

        // single unified shape for docked bar + concave corners
        Canvas {
            id: unifiedBarCanvas
            width: Math.round(parent.width * root.dpr)
            height: Math.round(parent.height * root.dpr)
            scale: 1.0 / root.dpr
            transformOrigin: Item.TopLeft
            visible: !root.isFloating && !root.isIslandMode
            antialiasing: true
            smooth: true
            renderTarget: Canvas.FramebufferObject
            renderStrategy: Canvas.Immediate

            property color fillColor: Theme.cornerFill
            Behavior on fillColor { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
            property real glowOpacity: Theme.isCyberNeon ? 1.0 : 0.85

            SequentialAnimation on glowOpacity {
                loops: Animation.Infinite
                running: Theme.isCyberNeon && !root.isIslandMode && !root.isFloating
                NumberAnimation { from: 0.55; to: 1.0; duration: 1200; easing.type: Easing.InOutQuad }
                NumberAnimation { from: 1.0; to: 0.55; duration: 1200; easing.type: Easing.InOutQuad }
            }

            onFillColorChanged: requestPaint()
            onGlowOpacityChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onAvailableChanged: if (available) requestPaint()
            Component.onCompleted: requestPaint()

            Connections {
                target: root
                function onPosChanged() { unifiedBarCanvas.requestPaint(); }
                function onScoopRadiusChanged() { unifiedBarCanvas.requestPaint(); }
                function onHasBarScoopsChanged() { unifiedBarCanvas.requestPaint(); }
                function onScoopAllowedLeftChanged() { unifiedBarCanvas.requestPaint(); }
                function onScoopAllowedRightChanged() { unifiedBarCanvas.requestPaint(); }
                function onScoopAllowedTopChanged() { unifiedBarCanvas.requestPaint(); }
                function onScoopAllowedBottomChanged() { unifiedBarCanvas.requestPaint(); }
                function onBorderLeftAllowedChanged() { unifiedBarCanvas.requestPaint(); }
                function onBorderRightAllowedChanged() { unifiedBarCanvas.requestPaint(); }
                function onBorderTopAllowedChanged() { unifiedBarCanvas.requestPaint(); }
                function onBorderBottomAllowedChanged() { unifiedBarCanvas.requestPaint(); }
                function onBorderWidthChanged() { unifiedBarCanvas.requestPaint(); }
                function onCornerStyleChanged() { unifiedBarCanvas.requestPaint(); }
                function onScoopTensionChanged() { unifiedBarCanvas.requestPaint(); }
                function onDprChanged() { unifiedBarCanvas.requestPaint(); }
            }

            Connections {
                target: Theme
                function onScoopBorderEnabledChanged() { unifiedBarCanvas.requestPaint(); }
                function onScoopBorderWidthChanged() { unifiedBarCanvas.requestPaint(); }
                function onScoopBorderColorChanged() { unifiedBarCanvas.requestPaint(); }
                function onBarStyleChanged() { unifiedBarCanvas.requestPaint(); }
            }

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.clearRect(0, 0, unifiedBarCanvas.width, unifiedBarCanvas.height);
                ctx.save();
                ctx.scale(root.dpr, root.dpr);

                var W = barRootItem.width;
                var H = barRootItem.height;
                var barH = Theme.barHeight;
                var r = root.hasBarScoops ? root.scoopRadius : 0;
                var style = root.cornerStyle;
                var t = root.scoopTension;

                var alreadyInsetH = root.screen ? (W < root.screen.width) : false;
                var alreadyInsetV = root.screen ? (H < root.screen.height) : false;

                var bwL = (!alreadyInsetH && root.borderLeftAllowed) ? root.borderWidth : 0;
                var bwR = (!alreadyInsetH && root.borderRightAllowed) ? root.borderWidth : 0;
                var bwT = (!alreadyInsetV && root.borderTopAllowed) ? root.borderWidth : 0;
                var bwB = (!alreadyInsetV && root.borderBottomAllowed) ? root.borderWidth : 0;

                var sL = root.hasBarScoops && !root.isVertical && r > 0 && root.scoopAllowedLeft;
                var sR = root.hasBarScoops && !root.isVertical && r > 0 && root.scoopAllowedRight;
                var sT = root.hasBarScoops && root.isVertical && r > 0 && root.scoopAllowedTop;
                var sB = root.hasBarScoops && root.isVertical && r > 0 && root.scoopAllowedBottom;

                ctx.fillStyle = unifiedBarCanvas.fillColor;
                ctx.beginPath();

                if (root.isTop) {
                    ctx.moveTo(0, 0);
                    ctx.lineTo(W, 0);
                    if (sR) {
                        ctx.lineTo(W, barH + r);
                        if (bwR > 0) ctx.lineTo(W - bwR, barH + r);
                        root.traceScoopCurve(ctx, W - bwR, barH + r, W - bwR, barH, W - bwR - r, barH, style, t);
                    } else {
                        ctx.lineTo(W, barH);
                    }
                    ctx.lineTo(sL ? (bwL + r) : 0, barH);
                    if (sL) {
                        root.traceScoopCurve(ctx, bwL + r, barH, bwL, barH, bwL, barH + r, style, t);
                        if (bwL > 0) ctx.lineTo(0, barH + r);
                    }
                    ctx.closePath();
                } else if (root.isBottom) {
                    var topY = H - barH;
                    ctx.moveTo(0, H);
                    ctx.lineTo(W, H);
                    if (sR) {
                        ctx.lineTo(W, 0);
                        if (bwR > 0) ctx.lineTo(W - bwR, 0);
                        root.traceScoopCurve(ctx, W - bwR, 0, W - bwR, topY, W - bwR - r, topY, style, t);
                    } else {
                        ctx.lineTo(W, topY);
                    }
                    ctx.lineTo(sL ? (bwL + r) : 0, topY);
                    if (sL) {
                        root.traceScoopCurve(ctx, bwL + r, topY, bwL, topY, bwL, 0, style, t);
                        if (bwL > 0) ctx.lineTo(0, 0);
                    }
                    ctx.closePath();
                } else if (root.isLeft) {
                    ctx.moveTo(0, 0);
                    ctx.lineTo(0, H);
                    if (sB) {
                        ctx.lineTo(barH + r, H);
                        if (bwB > 0) ctx.lineTo(barH + r, H - bwB);
                        root.traceScoopCurve(ctx, barH + r, H - bwB, barH, H - bwB, barH, H - bwB - r, style, t);
                    } else {
                        ctx.lineTo(barH, H);
                    }
                    ctx.lineTo(barH, sT ? (bwT + r) : 0);
                    if (sT) {
                        root.traceScoopCurve(ctx, barH, bwT + r, barH, bwT, barH + r, bwT, style, t);
                        if (bwT > 0) ctx.lineTo(barH + r, 0);
                    }
                    ctx.closePath();
                } else if (root.isRight) {
                    var leftX = W - barH;
                    ctx.moveTo(W, 0);
                    ctx.lineTo(W, H);
                    if (sB) {
                        ctx.lineTo(0, H);
                        if (bwB > 0) ctx.lineTo(0, H - bwB);
                        root.traceScoopCurve(ctx, 0, H - bwB, leftX, H - bwB, leftX, H - bwB - r, style, t);
                    } else {
                        ctx.lineTo(leftX, H);
                    }
                    ctx.lineTo(leftX, sT ? (bwT + r) : 0);
                    if (sT) {
                        root.traceScoopCurve(ctx, leftX, bwT + r, leftX, bwT, 0, bwT, style, t);
                        if (bwT > 0) ctx.lineTo(0, 0);
                    }
                    ctx.closePath();
                }

                ctx.fill();

                var hasCustomBorder = Theme.scoopBorderEnabled && Theme.scoopBorderWidth > 0 && Theme.scoopBorderColor !== "transparent" && Theme.scoopBorderColor.a > 0.01;
                var hasNeon = Theme.isCyberNeon || Theme.isAccentGlow;
                var hasGlass = Theme.isGlass;
                var hasPureBlack = Theme.isPureBlack;

                if (hasCustomBorder || hasNeon || hasGlass || hasPureBlack) {
                    ctx.beginPath();
                    if (root.isTop) {
                        if (sL) {
                            ctx.moveTo(bwL, barH + r);
                            root.traceScoopCurve(ctx, bwL, barH + r, bwL, barH, bwL + r, barH, style, t);
                        } else {
                            ctx.moveTo(0, barH);
                        }
                        ctx.lineTo(sR ? (W - bwR - r) : W, barH);
                        if (sR) {
                            root.traceScoopCurve(ctx, W - bwR - r, barH, W - bwR, barH, W - bwR, barH + r, style, t);
                        }
                    } else if (root.isBottom) {
                        var bTopY = H - barH;
                        if (sL) {
                            ctx.moveTo(bwL, 0);
                            root.traceScoopCurve(ctx, bwL, 0, bwL, bTopY, bwL + r, bTopY, style, t);
                        } else {
                            ctx.moveTo(0, bTopY);
                        }
                        ctx.lineTo(sR ? (W - bwR - r) : W, bTopY);
                        if (sR) {
                            root.traceScoopCurve(ctx, W - bwR - r, bTopY, W - bwR, bTopY, W - bwR, 0, style, t);
                        }
                    } else if (root.isLeft) {
                        if (sT) {
                            ctx.moveTo(barH + r, bwT);
                            root.traceScoopCurve(ctx, barH + r, bwT, barH, bwT, barH, bwT + r, style, t);
                        } else {
                            ctx.moveTo(barH, 0);
                        }
                        ctx.lineTo(barH, sB ? (H - bwB - r) : H);
                        if (sB) {
                            root.traceScoopCurve(ctx, barH, H - bwB - r, barH, H - bwB, barH + r, H - bwB, style, t);
                        }
                    } else if (root.isRight) {
                        var rLeftX = W - barH;
                        if (sT) {
                            ctx.moveTo(0, bwT);
                            root.traceScoopCurve(ctx, 0, bwT, rLeftX, bwT, rLeftX, bwT + r, style, t);
                        } else {
                            ctx.moveTo(rLeftX, 0);
                        }
                        ctx.lineTo(rLeftX, sB ? (H - bwB - r) : H);
                        if (sB) {
                            root.traceScoopCurve(ctx, rLeftX, H - bwB - r, rLeftX, H - bwB, 0, H - bwB, style, t);
                        }
                    }

                    ctx.lineCap = "butt";
                    ctx.lineJoin = "round";
                    if (hasNeon && (Settings?.scoopBorderColor ?? "auto") === "auto") {
                        ctx.lineWidth = Theme.scoopBorderWidth > 0 ? Theme.scoopBorderWidth : 2;
                        ctx.strokeStyle = Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, unifiedBarCanvas.glowOpacity);
                    } else if (hasCustomBorder) {
                        ctx.lineWidth = Theme.scoopBorderWidth;
                        ctx.strokeStyle = Theme.scoopBorderColor;
                    } else if (hasGlass) {
                        ctx.lineWidth = 1;
                        ctx.strokeStyle = Theme.glassHighlight;
                    } else if (hasPureBlack) {
                        ctx.lineWidth = 1;
                        ctx.strokeStyle = "#1f1f1f";
                    }
                    ctx.stroke();
                }

                ctx.restore();
            }
        }

        // layout box and background for floating mode
        Rectangle {
            id: barBg
            x: root.isRight && root.hasBarScoops && root.scoopRadius > 0 ? root.scoopRadius : 0
            y: root.isBottom && root.hasBarScoops && root.scoopRadius > 0 ? root.scoopRadius : 0
            width: root.isVertical ? Theme.barHeight : parent.width
            height: root.isVertical ? parent.height : Theme.barHeight
            radius: root.effectiveBarRadius
            clip: root.isFloating && root.effectiveBarRadius > 0 && !root.isIslandMode
            color: (root.isIslandMode || !root.isFloating) ? "transparent" : Theme.barBg
            border.color: (root.isIslandMode || !root.isFloating) ? "transparent" : Theme.barBorderColor
            border.width: (root.isIslandMode || !root.isFloating || border.color === "transparent" || border.color.a === 0) ? 0 : 1

            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
            Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

            // scroll on empty bar space to cycle workspaces via Settings' Lua-aware dispatcher
            WheelHandler {
                enabled: (Settings?.barScrollWorkspaces ?? true) && !root.isIslandMode
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (event) => {
                    if (wsScrollCooldown.running) return;
                    let dy = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                    if (Math.abs(dy) < 15) return;
                    wsScrollCooldown.restart();
                    let target = dy > 0 ? "e-1" : "e+1";
                    if (typeof Settings !== "undefined" && Settings?.dispatchWorkspace) {
                        Settings.dispatchWorkspace(target);
                    } else {
                        Hyprland.dispatch("workspace " + target);
                    }
                }
            }
        }

        Item {
            anchors.fill: barBg
            visible: !root.isVertical

            // bento floating island: left
            Rectangle {
                id: bentoLeftIsland
                visible: root.isIslandMode && !root.isVertical && leftRowH.visible && (leftRowH.implicitWidth > 0)
                anchors.verticalCenter: leftRowH.verticalCenter
                anchors.left: leftRowH.left
                anchors.leftMargin: -6
                width: leftRowH.implicitWidth + 12
                height: Theme.barHeight - 6
                radius: Theme.radiusMd > 4 ? Theme.radiusMd : 8
                color: Theme.cardBg
                border.color: Theme.isCyberNeon ? Theme.primary : Theme.cardBorder
                border.width: 1
                z: -1
                scale: (Settings?.bentoHoverLift ?? true) && bentoLeftHover.hovered ? 1.015 : 1.0
                HoverHandler { id: bentoLeftHover }
                Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutQuad } }
                Behavior on width { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.animEasing } }
                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                Rectangle {
                    visible: Theme.isAccentGlow
                    anchors.fill: parent
                    anchors.margins: -4
                    radius: parent.radius + 4
                    color: Theme.alpha(Theme.primary, 0.22)
                    z: -2
                }
                Rectangle {
                    visible: Theme.isGlass
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: Theme.glassHighlight
                }
            }

            // bento floating island: center
            Rectangle {
                id: bentoCenterIsland
                visible: root.isIslandMode && !root.isVertical && centerRowH.visible && (centerRowH.implicitWidth > 0)
                anchors.centerIn: centerRowH
                width: centerRowH.implicitWidth + 24
                height: Theme.barHeight - 6
                radius: Theme.radiusMd > 4 ? Theme.radiusMd : 8
                color: Theme.cardBg
                border.color: Theme.isCyberNeon ? Theme.primary : Theme.cardBorder
                border.width: 1
                z: -1
                scale: (Settings?.bentoHoverLift ?? true) && bentoCenterHover.hovered ? 1.015 : 1.0
                HoverHandler { id: bentoCenterHover }
                Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutQuad } }
                Behavior on width { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.animEasing } }
                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                Rectangle {
                    visible: Theme.isAccentGlow
                    anchors.fill: parent
                    anchors.margins: -4
                    radius: parent.radius + 4
                    color: Theme.alpha(Theme.primary, 0.22)
                    z: -2
                }
                Rectangle {
                    visible: Theme.isGlass
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: Theme.glassHighlight
                }
            }

            // bento floating island: right
            Rectangle {
                id: bentoRightIsland
                visible: root.isIslandMode && !root.isVertical && rightRowContainer.visible && (rightRowContainer.width > 0)
                anchors.verticalCenter: rightRowContainer.verticalCenter
                anchors.right: rightRowContainer.right
                anchors.rightMargin: -6
                width: rightRowContainer.width + 12
                height: Theme.barHeight - 6
                radius: Theme.radiusMd > 4 ? Theme.radiusMd : 8
                color: Theme.cardBg
                border.color: Theme.isCyberNeon ? Theme.primary : Theme.cardBorder
                border.width: 1
                z: -1
                scale: (Settings?.bentoHoverLift ?? true) && bentoRightHover.hovered ? 1.015 : 1.0
                HoverHandler { id: bentoRightHover }
                Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutQuad } }
                Behavior on width { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.animEasing } }
                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                Rectangle {
                    visible: Theme.isAccentGlow
                    anchors.fill: parent
                    anchors.margins: -4
                    radius: parent.radius + 4
                    color: Theme.alpha(Theme.primary, 0.22)
                    z: -2
                }
                Rectangle {
                    visible: Theme.isGlass
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: Theme.glassHighlight
                }
            }

            Row {
                id: leftRowH
                anchors.left: parent.left
                anchors.leftMargin: root.effectivePaddingH
                anchors.verticalCenter: parent.verticalCenter
                spacing: root.effectiveSpacing

                Repeater {
                    model: Settings.barModulesLeft ?? []
                    delegate: Loader {
                        id: lModLoader
                        required property string modelData
                        active: root.isModuleVisible(modelData) && !root.isVertical
                        visible: active
                        sourceComponent: root.getModuleComponent(modelData)
                        readonly property real targetW: {
                            if (!item) return (Theme.barHeight - 8);
                            if (modelData === "windowTitle") {
                                let mode = Settings?.windowTitleMode ?? "auto";
                                if (mode === "fill") {
                                    return Math.max(80, root.maxWindowTitleWidth);
                                }
                                if (mode === "compact") {
                                    return Math.max(40, Math.min(item.implicitWidth, 260));
                                }
                                let maxAllowed = Math.min(Settings?.windowTitleMaxWidth ?? 760, root.maxWindowTitleWidth);
                                return Math.max(40, Math.min(item.implicitWidth, maxAllowed));
                            }
                            return item.implicitWidth;
                        }
                        width: Math.round(targetW)
                        height: Math.round(item ? item.implicitHeight : (Theme.barHeight - 8))
                        clip: true
                        Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }

                        Binding {
                            target: lModLoader.item
                            property: "width"
                            value: lModLoader.width
                            when: lModLoader.item !== null
                        }
                    }
                }
            }

            Row {
                id: centerRowH
                anchors.centerIn: parent
                spacing: root.effectiveSpacing
                z: 10

                // fallback live screen recording pill if ScreenCapture isn't already on the bar
                Rectangle {
                    visible: (typeof ScreenRecService !== "undefined" && ScreenRecService.isRecording) && !root.hasCaptureModuleOnBar
                    implicitHeight: Theme.barHeight - 8
                    implicitWidth: recRowH.implicitWidth + 18
                    radius: Theme.radiusPill
                    color: recMouseH.pressed ? Theme.error : (recMouseH.containsMouse ? Theme.alpha(Theme.error, 0.28) : Theme.error_overlay)
                    border.color: Theme.error
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                    RowLayout {
                        id: recRowH
                        anchors.centerIn: parent
                        spacing: 6

                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            color: recMouseH.pressed ? Theme.on_error : Theme.error

                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                running: typeof ScreenRecService !== "undefined" && ScreenRecService.isRecording
                                NumberAnimation { from: 1.0; to: 0.20; duration: 650; easing.type: Easing.InOutQuad }
                                NumberAnimation { from: 0.20; to: 1.0; duration: 650; easing.type: Easing.InOutQuad }
                            }
                        }

                        Text {
                            text: "REC " + (ScreenRecService?.elapsedTimeString ?? "00:00")
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: Font.Bold
                            color: recMouseH.pressed ? Theme.on_error : Theme.error
                        }
                    }

                    MouseArea {
                        id: recMouseH
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.RightButton) {
                                ScreenRecService?.discardRecording();
                            } else {
                                ScreenRecService?.stopRecording();
                            }
                        }
                    }
                }

                Repeater {
                    model: Settings.barModulesCenter ?? ["clock"]
                    delegate: Loader {
                        required property string modelData
                        active: root.isModuleVisible(modelData) && !root.isVertical
                        visible: active
                        sourceComponent: root.getModuleComponent(modelData)
                        width: Math.round(item ? item.implicitWidth : (Theme.barHeight - 8))
                        height: Math.round(item ? item.implicitHeight : (Theme.barHeight - 8))
                        Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
                    }
                }
            }

            Item {
                id: rightRowContainer
                anchors.right: parent.right
                anchors.rightMargin: root.effectivePaddingH
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(rightRowH.implicitWidth, root.maxRightRowWidth)
                height: rightRowH.implicitHeight
                clip: rightRowH.implicitWidth > root.maxRightRowWidth
                Behavior on width { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.animEasing } }

                Row {
                    id: rightRowH
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: root.effectiveSpacing
                    width: Math.min(implicitWidth, root.maxRightRowWidth)
                    clip: true

                    Repeater {
                        model: Settings.barModulesRight ?? []
                        delegate: Loader {
                            id: rModLoader
                            required property string modelData
                            active: root.isModuleVisible(modelData) && !root.isVertical
                            visible: active
                            sourceComponent: root.getModuleComponent(modelData)
                            readonly property real targetW: item ? item.implicitWidth : (Theme.barHeight - 8)
                            width: Math.round(targetW)
                            height: Math.round(item ? item.implicitHeight : (Theme.barHeight - 8))
                            clip: true
                            Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }

                            Binding {
                                target: rModLoader.item
                                property: "width"
                                value: rModLoader.width
                                when: rModLoader.item !== null
                            }
                        }
                    }
                }
            }
        }

        Item {
            anchors.fill: barBg
            visible: root.isVertical

            // bento floating island: top vertical
            Rectangle {
                id: bentoTopIslandV
                visible: root.isIslandMode && root.isVertical && leftRowV.visible && (leftRowV.implicitHeight > 0)
                anchors.horizontalCenter: leftRowV.horizontalCenter
                anchors.top: leftRowV.top
                anchors.topMargin: -6
                width: Theme.barHeight - 6
                height: leftRowV.implicitHeight + 12
                radius: Theme.radiusMd > 4 ? Theme.radiusMd : 8
                color: Theme.cardBg
                border.color: Theme.isCyberNeon ? Theme.primary : Theme.cardBorder
                border.width: 1
                z: -1
                scale: (Settings?.bentoHoverLift ?? true) && bentoTopHoverV.hovered ? 1.015 : 1.0
                HoverHandler { id: bentoTopHoverV }
                Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutQuad } }
                Behavior on height { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.animEasing } }
                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                Rectangle {
                    visible: Theme.isAccentGlow
                    anchors.fill: parent
                    anchors.margins: -4
                    radius: parent.radius + 4
                    color: Theme.alpha(Theme.primary, 0.22)
                    z: -2
                }
                Rectangle {
                    visible: Theme.isGlass
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: Theme.glassHighlight
                }
            }

            // bento floating island: center vertical
            Rectangle {
                id: bentoCenterIslandV
                visible: root.isIslandMode && root.isVertical && centerRowV.visible && (centerRowV.implicitHeight > 0)
                anchors.centerIn: centerRowV
                width: Theme.barHeight - 6
                height: centerRowV.implicitHeight + 16
                radius: Theme.radiusMd > 4 ? Theme.radiusMd : 8
                color: Theme.cardBg
                border.color: Theme.isCyberNeon ? Theme.primary : Theme.cardBorder
                border.width: 1
                z: -1
                scale: (Settings?.bentoHoverLift ?? true) && bentoCenterHoverV.hovered ? 1.015 : 1.0
                HoverHandler { id: bentoCenterHoverV }
                Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutQuad } }
                Behavior on height { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.animEasing } }
                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                Rectangle {
                    visible: Theme.isAccentGlow
                    anchors.fill: parent
                    anchors.margins: -4
                    radius: parent.radius + 4
                    color: Theme.alpha(Theme.primary, 0.22)
                    z: -2
                }
                Rectangle {
                    visible: Theme.isGlass
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: Theme.glassHighlight
                }
            }

            // bento floating island: bottom vertical
            Rectangle {
                id: bentoBottomIslandV
                visible: root.isIslandMode && root.isVertical && rightRowV.visible && (rightRowV.implicitHeight > 0)
                anchors.horizontalCenter: rightRowV.horizontalCenter
                anchors.bottom: rightRowV.bottom
                anchors.bottomMargin: -6
                width: Theme.barHeight - 6
                height: rightRowV.implicitHeight + 12
                radius: Theme.radiusMd > 4 ? Theme.radiusMd : 8
                color: Theme.cardBg
                border.color: Theme.isCyberNeon ? Theme.primary : Theme.cardBorder
                border.width: 1
                z: -1
                scale: (Settings?.bentoHoverLift ?? true) && bentoBottomHoverV.hovered ? 1.015 : 1.0
                HoverHandler { id: bentoBottomHoverV }
                Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutQuad } }
                Behavior on height { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.animEasing } }
                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                Rectangle {
                    visible: Theme.isAccentGlow
                    anchors.fill: parent
                    anchors.margins: -4
                    radius: parent.radius + 4
                    color: Theme.alpha(Theme.primary, 0.22)
                    z: -2
                }
                Rectangle {
                    visible: Theme.isGlass
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: Theme.glassHighlight
                }
            }

            Column {
                id: leftRowV
                anchors.top: parent.top
                anchors.topMargin: root.effectivePaddingH
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: root.effectiveSpacing

                Repeater {
                    model: Settings.barModulesLeft ?? []
                    delegate: Loader {
                        id: lModLoaderV
                        required property string modelData
                        active: root.isModuleVisible(modelData) && root.isVertical
                        visible: active
                        sourceComponent: root.getModuleComponent(modelData)
                        width: Math.round(item ? item.implicitWidth : (Theme.barHeight - 8))
                        height: Math.round(item ? item.implicitHeight : (Theme.barHeight - 8))
                        Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }

                        Binding {
                            target: lModLoaderV.item
                            property: "width"
                            value: lModLoaderV.width
                            when: lModLoaderV.item !== null
                        }
                    }
                }
            }

            Column {
                id: centerRowV
                anchors.centerIn: parent
                spacing: root.effectiveSpacing
                z: 10

                // fallback live screen recording pill (vertical)
                Rectangle {
                    visible: (typeof ScreenRecService !== "undefined" && ScreenRecService.isRecording) && !root.hasCaptureModuleOnBar
                    implicitWidth: Theme.barHeight - 8
                    implicitHeight: Theme.barHeight - 8
                    radius: Theme.radiusPill
                    color: recMouseV.pressed ? Theme.error : (recMouseV.containsMouse ? Theme.alpha(Theme.error, 0.28) : Theme.error_overlay)
                    border.color: Theme.error
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 10
                        height: 10
                        radius: 5
                        color: recMouseV.pressed ? Theme.on_error : Theme.error

                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: typeof ScreenRecService !== "undefined" && ScreenRecService.isRecording
                            NumberAnimation { from: 1.0; to: 0.20; duration: 650; easing.type: Easing.InOutQuad }
                            NumberAnimation { from: 0.20; to: 1.0; duration: 650; easing.type: Easing.InOutQuad }
                        }
                    }

                    MouseArea {
                        id: recMouseV
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.RightButton) {
                                ScreenRecService?.discardRecording();
                            } else {
                                ScreenRecService?.stopRecording();
                            }
                        }
                    }
                }

                Repeater {
                    model: Settings.barModulesCenter ?? ["clock"]
                    delegate: Loader {
                        id: cModLoaderV
                        required property string modelData
                        active: root.isModuleVisible(modelData) && root.isVertical
                        visible: active
                        sourceComponent: root.getModuleComponent(modelData)
                        width: Math.round(item ? item.implicitWidth : (Theme.barHeight - 8))
                        height: Math.round(item ? item.implicitHeight : (Theme.barHeight - 8))
                        Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }

                        Binding {
                            target: cModLoaderV.item
                            property: "width"
                            value: cModLoaderV.width
                            when: cModLoaderV.item !== null
                        }
                    }
                }
            }

            Column {
                id: rightRowV
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.effectivePaddingH
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: root.effectiveSpacing

                Repeater {
                    model: Settings.barModulesRight ?? []
                    delegate: Loader {
                        id: rModLoaderV
                        required property string modelData
                        active: root.isModuleVisible(modelData) && root.isVertical
                        visible: active
                        sourceComponent: root.getModuleComponent(modelData)
                        width: Math.round(item ? item.implicitWidth : (Theme.barHeight - 8))
                        height: Math.round(item ? item.implicitHeight : (Theme.barHeight - 8))
                        Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }

                        Binding {
                            target: rModLoaderV.item
                            property: "width"
                            value: rModLoaderV.width
                            when: rModLoaderV.item !== null
                        }
                    }
                }
            }
        }
    }
}
