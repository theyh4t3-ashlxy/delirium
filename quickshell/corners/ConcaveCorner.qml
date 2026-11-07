// ConcaveCorner.qml
import QtQuick
import ".."

Item {
    id: root

    property real radius: (typeof Theme !== "undefined" ? (Theme?.scoopRadius ?? Theme?.scoopRadiusX ?? Settings?.scoopRadius ?? Settings?.screenCornerRadius ?? 16) : 16)
    property real radiusX: radius
    property real radiusY: radius
    property color fillColor: Theme?.cornerFill ?? Theme?.barBg ?? "#14140c"
    property bool flipX: false
    property bool flipY: false
    property string cornerStyle: (typeof Settings !== "undefined" ? Settings?.cornerStyle : null) ?? "cubic"

    readonly property bool hasThemeStroke: (typeof Theme !== "undefined") && (
        (Theme?.isCyberNeon ?? false) || (Theme?.isAccentGlow ?? false) || (Theme?.isGlass ?? false) || (Theme?.isPureBlack ?? false)
    )
    property bool showBorder: ((typeof Theme !== "undefined" && Theme?.scoopBorderEnabled) ?? false) || hasThemeStroke
    property real borderWidth: {
        if (typeof Theme !== "undefined" && (Theme?.scoopBorderWidth ?? 0) > 0) return Theme.scoopBorderWidth;
        if (typeof Theme !== "undefined" && ((Theme?.isCyberNeon ?? false) || (Theme?.isAccentGlow ?? false))) return 2;
        if (hasThemeStroke) return 1;
        return 0;
    }
    property color borderColor: {
        if (typeof Theme !== "undefined" && Theme?.scoopBorderEnabled && Theme?.scoopBorderColor && Theme.scoopBorderColor !== "transparent") {
            return Theme.scoopBorderColor;
        }
        if (typeof Theme !== "undefined") {
            if ((Theme?.isCyberNeon ?? false) || (Theme?.isAccentGlow ?? false)) return Theme.alpha(Theme.primary, 0.85);
            if (Theme?.isGlass ?? false) return Theme?.glassHighlight ?? Qt.rgba(1, 1, 1, 0.22);
            if (Theme?.isPureBlack ?? false) return "#222222";
        }
        return "transparent";
    }

    property alias color: root.fillColor
    property alias mirrored: root.flipX
    readonly property bool isTop: !flipY

    implicitWidth: Math.max(1, radiusX)
    implicitHeight: Math.max(1, radiusY)
    width: implicitWidth
    height: implicitHeight

    readonly property real w: width
    readonly property real h: height
    readonly property real dpr: Math.max(1.0, (Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1.0))
    readonly property real tension: {
        if (cornerStyle === "squircle") return 0.72;
        if (cornerStyle === "continuous-bezier" || cornerStyle === "g2") return 0.58;
        if (cornerStyle === "flared") return 0.38;
        return (typeof Settings !== "undefined" ? Settings?.scoopTension : null) ?? 0.55228475;
    }

    Behavior on fillColor { ColorAnimation { duration: (typeof Theme !== "undefined" ? Theme?.animFast : null) ?? 150 } }
    Behavior on borderColor { ColorAnimation { duration: (typeof Theme !== "undefined" ? Theme?.animFast : null) ?? 150 } }

    // universal scoop curve from (x0, y0) to (x1, y1) bowing toward outer corner (cx, cy)
    function traceScoopCurve(ctx, x0, y0, cx, cy, x1, y1, style, t) {
        if (style === "chamfer") {
            ctx.lineTo(x1, y1);
        } else if (style === "stepped") {
            // 3-step pixel staircase that actually uses the whole corner box instead of backtracking
            var ux = x0 - cx, uy = y0 - cy;
            var vx = x1 - cx, vy = y1 - cy;
            ctx.lineTo(cx + ux + vx / 3.0, cy + uy + vy / 3.0);
            ctx.lineTo(cx + (2.0 * ux) / 3.0 + vx / 3.0, cy + (2.0 * uy) / 3.0 + vy / 3.0);
            ctx.lineTo(cx + (2.0 * ux) / 3.0 + (2.0 * vx) / 3.0, cy + (2.0 * uy) / 3.0 + (2.0 * vy) / 3.0);
            ctx.lineTo(cx + ux / 3.0 + (2.0 * vx) / 3.0, cy + uy / 3.0 + (2.0 * vy) / 3.0);
            ctx.lineTo(cx + ux / 3.0 + vx, cy + uy / 3.0 + vy);
            ctx.lineTo(x1, y1);
        } else if (style === "hyperbolic") {
            // previously fx was backwards here, turning the curve into a weird S-bend
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

    Canvas {
        id: canvas
        width: Math.round(root.width * root.dpr)
        height: Math.round(root.height * root.dpr)
        scale: 1.0 / root.dpr
        transformOrigin: Item.TopLeft
        antialiasing: true
        smooth: true
        renderTarget: Canvas.FramebufferObject
        renderStrategy: Canvas.Immediate

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.clearRect(0, 0, canvas.width, canvas.height);
            ctx.save();
            ctx.scale(root.dpr, root.dpr);

            var fx = root.flipX;
            var fy = root.flipY;
            var w = root.w;
            var h = root.h;
            var t = root.tension;

            var sx = fx ? 0 : w;
            var sy = fy ? h : 0;
            var p1x = fx ? w : 0;
            var p1y = fy ? h : 0;
            var p2x = fx ? w : 0;
            var p2y = fy ? 0 : h;

            ctx.fillStyle = root.fillColor;
            ctx.beginPath();
            ctx.moveTo(sx, sy);
            ctx.lineTo(p1x, p1y);
            ctx.lineTo(p2x, p2y);
            root.traceScoopCurve(ctx, p2x, p2y, p1x, p1y, sx, sy, root.cornerStyle, t);
            ctx.closePath();
            ctx.fill();

            if (root.showBorder && root.borderWidth > 0 && root.borderColor !== "transparent" && root.borderColor.a > 0.01) {
                ctx.beginPath();
                ctx.moveTo(p2x, p2y);
                root.traceScoopCurve(ctx, p2x, p2y, p1x, p1y, sx, sy, root.cornerStyle, t);
                ctx.lineCap = "butt";
                ctx.lineJoin = "round";
                ctx.lineWidth = root.borderWidth;
                ctx.strokeStyle = root.borderColor;
                ctx.stroke();
            }

            ctx.restore();
        }

        Component.onCompleted: requestPaint()
        onAvailableChanged: if (available) requestPaint()

        Connections {
            target: root
            function onFillColorChanged() { canvas.requestPaint(); }
            function onBorderColorChanged() { canvas.requestPaint(); }
            function onBorderWidthChanged() { canvas.requestPaint(); }
            function onShowBorderChanged() { canvas.requestPaint(); }
            function onRadiusChanged() { canvas.requestPaint(); }
            function onRadiusXChanged() { canvas.requestPaint(); }
            function onRadiusYChanged() { canvas.requestPaint(); }
            function onWidthChanged() { canvas.requestPaint(); }
            function onHeightChanged() { canvas.requestPaint(); }
            function onFlipXChanged() { canvas.requestPaint(); }
            function onFlipYChanged() { canvas.requestPaint(); }
            function onCornerStyleChanged() { canvas.requestPaint(); }
            function onTensionChanged() { canvas.requestPaint(); }
            function onDprChanged() { canvas.requestPaint(); }
        }
    }
}
