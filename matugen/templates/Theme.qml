// Theme.qml
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property var cfg: (typeof Settings !== "undefined" ? Settings : null)

    property var parsedPalette: ({})

    function parsePalette() {
        if (!paletteWatcher) return;
        let text = paletteWatcher.text();
        if (!text || text.trim() === "") return;
        let map = {};
        let re = /(?:@define-color\s+([a-zA-Z0-9_-]+)|--([a-zA-Z0-9_-]+))\s*[:\s]\s*(#[0-9a-fA-F]{3,8})/g;
        let match;
        while ((match = re.exec(text)) !== null) {
            let key = (match[1] || match[2]).replace(/-/g, "_");
            map[key] = match[3];
        }
        parsedPalette = map;
    }

    // watching palette.css like a hawk so we don't have to restart the whole shell
    property var paletteWatcher: FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || ((Quickshell.env("HOME") || "") + "/.config")) + "/quickshell/palette.css"
        watchChanges: true
        printErrors: false
        onLoaded: root.parsePalette()
        onFileChanged: root.parsePalette()
    }

    Component.onCompleted: root.parsePalette()

    // ticking time bomb so the widgets know when to panic
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    readonly property string resolvedWpFileUrl: {
        let wp = (cfg?.currentWallpaper ?? "").trim();
        if (!wp || wp.startsWith("http://") || wp.startsWith("https://")) return "";
        if (wp.startsWith("file://")) return wp;
        if (wp.startsWith("/") || wp.startsWith("~")) {
            let p = wp.startsWith("~") ? ((Quickshell.env("HOME") || "") + wp.slice(1)) : wp;
            return "file://" + p;
        }
        return "";
    }

    // guarded inside a Loader so empty paths don't spam QFSFileEngine warnings
    Loader {
        id: wpQuantizerLoader
        active: root.resolvedWpFileUrl !== ""
        sourceComponent: ColorQuantizer {
            depth: 2
            rescaleSize: 64
            source: root.resolvedWpFileUrl
        }
    }

    readonly property real wallpaperVibrancy: {
        let qColors = wpQuantizerLoader.item?.colors;
        if (!qColors || qColors.length === 0) return 0.5;
        let maxSat = 0.0;
        for (let i = 0; i < qColors.length; i++) {
            let c = qColors[i];
            if (!c) continue;
            let r = c.r, g = c.g, b = c.b;
            let mx = Math.max(r, g, b);
            let mn = Math.min(r, g, b);
            let sat = mx === 0 ? 0 : (mx - mn) / mx;
            if (sat > maxSat) maxSat = sat;
        }
        return Math.max(0.1, Math.min(1.0, maxSat));
    }

    readonly property real adaptiveAlphaBoost: (cfg?.adaptiveTransparency ?? true) ? (wallpaperVibrancy * 0.08) : 0.0
    readonly property real adaptiveSurfaceAlpha: Math.min(1.0, surfaceOpacity + adaptiveAlphaBoost)

    // matugen hex tokens + live custom color overrides from QuickSettings
    readonly property bool hasCustomColors: cfg?.customColorsEnabled ?? false

    readonly property color matugenPrimary:            parsedPalette["primary"] ?? "{{colors.primary.default.hex}}"
    readonly property color primary:                   (hasCustomColors && (cfg?.customActive ?? "") !== "") ? cfg.customActive : matugenPrimary
    readonly property color on_primary:                parsedPalette["on_primary"] ?? "{{colors.on_primary.default.hex}}"
    readonly property color primary_container:         parsedPalette["primary_container"] ?? "{{colors.primary_container.default.hex}}"
    readonly property color on_primary_container:      parsedPalette["on_primary_container"] ?? "{{colors.on_primary_container.default.hex}}"

    readonly property color secondary:                 parsedPalette["secondary"] ?? "{{colors.secondary.default.hex}}"
    readonly property color on_secondary:              parsedPalette["on_secondary"] ?? "{{colors.on_secondary.default.hex}}"
    readonly property color secondary_container:       parsedPalette["secondary_container"] ?? "{{colors.secondary_container.default.hex}}"
    readonly property color on_secondary_container:    parsedPalette["on_secondary_container"] ?? "{{colors.on_secondary_container.default.hex}}"

    readonly property color tertiary:                  parsedPalette["tertiary"] ?? "{{colors.tertiary.default.hex}}"
    readonly property color on_tertiary:               parsedPalette["on_tertiary"] ?? "{{colors.on_tertiary.default.hex}}"
    readonly property color tertiary_container:        parsedPalette["tertiary_container"] ?? "{{colors.tertiary_container.default.hex}}"
    readonly property color on_tertiary_container:     parsedPalette["on_tertiary_container"] ?? "{{colors.on_tertiary_container.default.hex}}"

    readonly property color error:                     parsedPalette["error"] ?? "{{colors.error.default.hex}}"
    readonly property color on_error:                  parsedPalette["on_error"] ?? "{{colors.on_error.default.hex}}"
    readonly property color error_container:           parsedPalette["error_container"] ?? "{{colors.error_container.default.hex}}"
    readonly property color on_error_container:        parsedPalette["on_error_container"] ?? "{{colors.on_error_container.default.hex}}"

    readonly property color matugenBg:                 parsedPalette["background"] ?? "{{colors.background.default.hex}}"
    readonly property color background:                (hasCustomColors && (cfg?.customBg ?? "") !== "") ? cfg.customBg : matugenBg
    readonly property color on_background:             parsedPalette["on_background"] ?? "{{colors.on_background.default.hex}}"

    readonly property color matugenSurface:            parsedPalette["surface"] ?? "{{colors.surface.default.hex}}"
    readonly property color surface:                   (hasCustomColors && (cfg?.customBg ?? "") !== "") ? cfg.customBg : matugenSurface
    readonly property color matugenOnSurface:          parsedPalette["on_surface"] ?? "{{colors.on_surface.default.hex}}"
    readonly property color on_surface:                (hasCustomColors && (cfg?.customText ?? "") !== "") ? cfg.customText : matugenOnSurface
    readonly property color surface_variant:           parsedPalette["surface_variant"] ?? "{{colors.surface_variant.default.hex}}"
    readonly property color matugenOnSurfaceVariant:   parsedPalette["on_surface_variant"] ?? "{{colors.on_surface_variant.default.hex}}"
    readonly property color on_surface_variant:        (hasCustomColors && (cfg?.customSubtext ?? "") !== "") ? cfg.customSubtext : matugenOnSurfaceVariant
    readonly property color textPrimary:               on_surface
    readonly property color textSecondary:             on_surface_variant

    readonly property color surface_container_lowest:  (hasCustomColors && (cfg?.customBg ?? "") !== "") ? cfg.customBg : (parsedPalette["surface_container_lowest"] ?? "{{colors.surface_container_lowest.default.hex}}")
    readonly property color surface_container_low:     (hasCustomColors && (cfg?.customBg ?? "") !== "") ? cfg.customBg : (parsedPalette["surface_container_low"] ?? "{{colors.surface_container_low.default.hex}}")
    readonly property color surface_container:         parsedPalette["surface_container"] ?? "{{colors.surface_container.default.hex}}"
    readonly property color surface_container_high:    (hasCustomColors && (cfg?.customWidgetBg ?? "") !== "") ? cfg.customWidgetBg : (parsedPalette["surface_container_high"] ?? "{{colors.surface_container_high.default.hex}}")
    readonly property color surface_container_highest: parsedPalette["surface_container_highest"] ?? "{{colors.surface_container_highest.default.hex}}"

    readonly property color surface_dim:               parsedPalette["surface_dim"] ?? "{{colors.surface_dim.default.hex}}"
    readonly property color surface_bright:            parsedPalette["surface_bright"] ?? "{{colors.surface_bright.default.hex}}"

    readonly property color matugenOutline:            parsedPalette["outline"] ?? "{{colors.outline.default.hex}}"
    readonly property color outline:                   (hasCustomColors && (cfg?.customBorder ?? "") !== "") ? cfg.customBorder : matugenOutline
    readonly property color outline_variant:           (hasCustomColors && (cfg?.customBorder ?? "") !== "") ? cfg.customBorder : (parsedPalette["outline_variant"] ?? "{{colors.outline_variant.default.hex}}")

    readonly property color shadow:                    parsedPalette["shadow"] ?? "{{colors.shadow.default.hex}}"
    readonly property color scrim:                     parsedPalette["scrim"] ?? "{{colors.scrim.default.hex}}"

    readonly property color inverse_surface:           parsedPalette["inverse_surface"] ?? "{{colors.inverse_surface.default.hex}}"
    readonly property color inverse_on_surface:        parsedPalette["inverse_on_surface"] ?? "{{colors.inverse_on_surface.default.hex}}"
    readonly property color inverse_primary:           parsedPalette["inverse_primary"] ?? "{{colors.inverse_primary.default.hex}}"
    readonly property color source_color:              parsedPalette["source_color"] ?? "{{colors.source_color.default.hex}}"

    // automatic light mode detection via surface luminance or explicit Settings flag
    readonly property real surfaceLuminance: (0.2126 * surface.r) + (0.7152 * surface.g) + (0.0722 * surface.b)
    readonly property bool isLightMode: Boolean(cfg?.matugenMode === "light" || cfg?.lightMode || cfg?.isLight || cfg?.themeMode === "light" || surfaceLuminance > 0.5)

    /*
    math black magic so the engine doesn't combust,
    upgraded to approximate linear color space so gradients don't look like dishwater
    */
    function alpha(c: color, a: real): color {
        if (c === undefined || c.r === undefined) return Qt.rgba(0, 0, 0, 0);
        let val = (typeof a !== "number" || isNaN(a)) ? 1.0 : Math.max(0.0, Math.min(1.0, a));
        return Qt.rgba(c.r, c.g, c.b, val);
    }

    function blend(c1: color, c2: color, t: real): color {
        if (c1 === undefined || c1.r === undefined) return (c2 !== undefined) ? c2 : Qt.rgba(0, 0, 0, 0);
        if (c2 === undefined || c2.r === undefined) return c1;

        let f = (typeof t !== "number" || isNaN(t)) ? 0.0 : Math.max(0.0, Math.min(1.0, t));
        let inv = 1.0 - f;

        return Qt.rgba(
            Math.sqrt((c1.r * c1.r * inv) + (c2.r * c2.r * f)),
            Math.sqrt((c1.g * c1.g * inv) + (c2.g * c2.g * f)),
            Math.sqrt((c1.b * c1.b * inv) + (c2.b * c2.b * f)),
            (c1.a * inv) + (c2.a * f)
        );
    }

    function formatBytes(bytes: real): string {
        if (!bytes || bytes <= 0 || isNaN(bytes)) return "0 b";
        const units = ["b", "kib", "mib", "gib", "tib"];
        let i = Math.max(0, Math.min(units.length - 1, Math.floor(Math.log(bytes) / Math.log(1024))));
        let val = bytes / Math.pow(1024, i);
        return (val >= 100 || i === 0 ? Math.round(val) : val.toFixed(1)) + " " + units[i];
    }

    function formatUptime(sec: int): string {
        if (!sec || sec <= 0 || isNaN(sec)) return "0m";
        let d = Math.floor(sec / 86400);
        let h = Math.floor((sec % 86400) / 3600);
        let m = Math.floor((sec % 3600) / 60);
        if (d > 0) return d + "d " + h + "h";
        if (h > 0) return h + "h " + m + "m";
        return m + "m";
    }

    function getBatteryColor(pct: int, isCharging: bool): color {
        if (isCharging) return primary;
        let p = (pct === undefined || isNaN(pct)) ? 100 : pct;
        if (p <= 15) return error;
        if (p <= 30) return warn;
        return on_surface;
    }

    function resolveAppIcon(winClass: string): string {
        if (!winClass) return "";
        let base = winClass.trim().toLowerCase();
        if (!base) return "";

        if (typeof DesktopEntries !== "undefined" && DesktopEntries?.applications?.values) {
            let apps = DesktopEntries.applications.values;
            for (let i = 0; i < apps.length; i++) {
                let a = apps[i];
                if (!a) continue;
                let aid = (a.id ?? "").toLowerCase().replace(/\.desktop$/, "");
                let wm = (a.startupWmClass ?? "").toLowerCase();
                if (aid === base || wm === base) {
                    if (a.icon) {
                        let p = Quickshell.iconPath(a.icon);
                        if (p) return p;
                    }
                }
            }
        }

        let candidates = [
            base,
            base.replace(/-/g, ""),
            base.replace(/_bin$/, ""),
            base.replace(/-bin$/, "")
        ];
        if (Quickshell?.hasThemeIcon && Quickshell.hasThemeIcon(base + "-browser")) {
            candidates.unshift(base + "-browser");
        }
        let parts = base.split(".");
        if (parts.length > 1) {
            candidates.push(parts[parts.length - 1]);
        }
        for (let i = 0; i < candidates.length; i++) {
            let cand = candidates[i];
            if (!cand) continue;
            if (Quickshell?.hasThemeIcon && !Quickshell.hasThemeIcon(cand)) continue;
            let p = Quickshell.iconPath(cand);
            if (p) return p;
        }
        if (Quickshell?.hasThemeIcon && Quickshell.hasThemeIcon("application-x-executable")) {
            return Quickshell.iconPath("application-x-executable");
        }
        return "";
    }

    readonly property color primary_overlay:        alpha(primary, 0.18)
    readonly property color secondary_overlay:      alpha(secondary, 0.18)
    readonly property color tertiary_overlay:       alpha(tertiary, 0.18)
    readonly property color error_overlay:          alpha(error, 0.22)
    readonly property color warn:                   tertiary
    readonly property color warn_container:         tertiary_container
    readonly property color on_warn_container:      on_tertiary_container
    readonly property color warn_overlay:           tertiary_overlay

    function stateHover(baseColor: color, contentColor: color): color {
        return blend(baseColor, (contentColor !== undefined && contentColor !== "" ? contentColor : on_surface), 0.08);
    }
    function stateFocus(baseColor: color, contentColor: color): color {
        return blend(baseColor, (contentColor !== undefined && contentColor !== "" ? contentColor : on_surface), 0.10);
    }
    function statePress(baseColor: color, contentColor: color): color {
        return blend(baseColor, (contentColor !== undefined && contentColor !== "" ? contentColor : on_surface), 0.12);
    }
    function stateDrag(baseColor: color, contentColor: color): color {
        return blend(baseColor, (contentColor !== undefined && contentColor !== "" ? contentColor : on_surface), 0.16);
    }

    readonly property color on_surface_disabled:    alpha(on_surface, 0.38)
    readonly property color outline_disabled:       alpha(outline, 0.12)
    readonly property color fontStrokeColor:        isLightMode ? "#ffffff" : "#000000"
    readonly property color textStroke:             isLightMode ? "#ffffff" : "#000000"
    readonly property color textShadow:             isLightMode ? alpha(shadow, 0.25) : "#000000"

    readonly property string fontSans:              cfg?.fontSans ?? cfg?.fontFamily ?? "Noto Sans"
    readonly property string fontMono:              cfg?.fontMono ?? "JetBrainsMono Nerd Font"
    readonly property string fontDisplay:           cfg?.fontDisplay ?? fontSans

    readonly property var    fontFamiliesVibe:      [fontSans, "Noto Sans", "Noto Sans CJK JP"]
    readonly property string fontVibe:              fontSans
    readonly property string fontFamily:            fontSans

    readonly property int    fontWeightLight:       300
    readonly property int    fontWeightRegular:     400
    readonly property int    fontWeightMedium:      500
    readonly property int    fontWeightDemiBold:    600
    readonly property int    fontWeightBold:        700

    readonly property real   fontScale:             cfg?.fontScale ?? 1.0
    readonly property int    fontSizeXs:            Math.round(9 * fontScale)
    readonly property int    fontSizeSm:            Math.round(11 * fontScale)
    readonly property int    fontSizeMd:            Math.round(13 * fontScale)
    readonly property int    fontSizeLg:            Math.round(15 * fontScale)
    readonly property int    fontSizeXl:            Math.round(18 * fontScale)
    readonly property int    fontSizeTitle:         Math.round(22 * fontScale)

    function getFontWeight(weight: string): int {
        if (!weight || typeof weight !== "string") return Font.Normal;
        let w = weight.toLowerCase().trim();
        const map = {
            "thin": Font.Thin, "extralight": Font.ExtraLight, "ultralight": Font.ExtraLight,
            "light": Font.Light, "normal": Font.Normal, "regular": Font.Normal,
            "medium": Font.Medium, "demibold": Font.DemiBold, "semibold": Font.DemiBold,
            "bold": Font.Bold, "extrabold": Font.ExtraBold, "ultrabold": Font.ExtraBold,
            "black": Font.Black, "heavy": Font.Black
        };
        return map[w] ?? Font.Normal;
    }

    readonly property int    widgetRadius:          cfg?.widgetRadius ?? 6
    readonly property int    popupRadius:           cfg?.popupRadius ?? 8
    readonly property int    effectiveCardRadius: {
        let gr = cfg?.globalRounding ?? 24;
        let wr = widgetRadius;
        if (wr > 32) return Math.min(16, Math.max(8, Math.round(gr * 0.6)));
        return Math.max(6, wr);
    }
    readonly property int    radiusXs:              4
    readonly property int    radiusSm:              Math.min(10, Math.max(3, Math.round(effectiveCardRadius * 0.65)))
    readonly property int    radiusMd:              Math.min(16, Math.max(4, effectiveCardRadius))
    readonly property int    radiusLg:              Math.max(8, Math.min(24, popupRadius))
    readonly property int    radiusXl:              Math.max(14, Math.min(32, Math.round(popupRadius * 1.25)))
    readonly property int    radiusXxl:             Math.max(18, Math.min(40, Math.round(popupRadius * 1.5)))
    readonly property int    radiusPill:            9999
    readonly property int    radiusFull:            9999

    readonly property int    barHeight:             cfg?.barHeight ?? 32
    readonly property int    barRadius:             cfg?.barRadius ?? 0
    readonly property int    widgetSpacing:         cfg?.widgetSpacing ?? 4
    readonly property int    widgetPaddingH:        cfg?.widgetPaddingH ?? 8
    readonly property int    widgetPaddingV:        cfg?.widgetPaddingV ?? 4
    readonly property string paddingScale:          cfg?.paddingScale ?? "cozy"
    readonly property real   paddingScaleMult: {
        let ps = paddingScale;
        if (ps === "compact") return 0.8;
        if (ps === "comfortable") return 1.25;
        return 1.0;
    }
    readonly property real   barOpacity:            cfg?.barOpacity ?? 1.0
    readonly property real   popupOpacity:          cfg?.popupOpacity ?? 1.0
    readonly property real   glassmorphismLevel:    cfg?.glassmorphismLevel ?? 0.85
    readonly property real   cardOpacity:           cfg?.cardOpacity ?? 0.95
    readonly property real   surfaceOpacity:        cfg?.surfaceOpacity ?? 0.90

    readonly property int    scoopRadiusX:          cfg?.scoopRadius ?? 16
    readonly property int    scoopRadiusY:          cfg?.scoopRadius ?? 16
    readonly property real   scoopTension:          cfg?.scoopTension ?? 0.5522847498307936
    readonly property string scoopStyle:            cfg?.cornerStyle ?? "cubic"
    readonly property bool   cornerFillets:         cfg?.cornerFillets ?? true
    readonly property real   cornerSmoothing:       cfg?.cornerSmoothing ?? 0.7
    readonly property int    screenCornerRadius:    cfg?.screenCornerRadius ?? 16
    readonly property int    screenBorderWidth:     cfg?.screenBorderWidth ?? 2
    readonly property bool   screenFrameDocked:     cfg?.screenFrameDocked ?? true
    readonly property string screenCornerMode:      cfg?.screenCornerMode ?? "all"
    readonly property string cornerColorMode:       cfg?.cornerColorMode ?? "bar"
    readonly property string barStyle:              cfg?.barStyle ?? "glass"
    readonly property int    scoopRadius:           cfg?.scoopRadius ?? 16
    readonly property bool   isGlass:               barStyle === "glass" || barStyle === "glass-frost"
    readonly property bool   isGlassFrost:          barStyle === "glass-frost"
    readonly property bool   isCyberNeon:           barStyle === "cyber-neon"
    readonly property bool   isAccentGlow:          barStyle === "accent-glow"
    readonly property bool   isPureBlack:           barStyle === "pure-black"
    readonly property bool   isBento:               barStyle === "bento-floating"
    readonly property bool   isTranslucent:         barStyle === "translucent"
    readonly property bool   isMonochrome:          barStyle === "monochrome"
    readonly property bool   isTextIconSet:         iconSet === "kaomoji" || iconSet === "text"

    // light- and dark-mode aware style resolver so glass & borders look crisp in both modes
    function getStyleColor(role: string, bs: string): color {
        let lightGlassBorder = alpha(outline_variant, 0.52);
        let lightFrostBorder = alpha(outline_variant, 0.65);

        switch (role) {
            case "barBg":
                if (bs === "regular") return surface_container_low;
                if (bs === "pure-black") return isLightMode ? "#ffffff" : "#000000";
                if (bs === "glass") return alpha(surface_container_lowest, Math.min(1.0, (isLightMode ? 0.68 : 0.40) + adaptiveAlphaBoost));
                if (bs === "glass-frost") return alpha(surface_container_lowest, Math.min(1.0, (isLightMode ? 0.78 : 0.55) + adaptiveAlphaBoost));
                if (bs === "cyber-neon") return isLightMode ? alpha(surface_container_lowest, 0.94) : alpha("#050508", 0.94);
                if (bs === "bento-floating") return alpha(surface_container_low, Math.min(1.0, 0.88 + adaptiveAlphaBoost));
                if (bs === "translucent") return alpha(surface_container_low, Math.min(1.0, (isLightMode ? 0.80 : 0.70) + adaptiveAlphaBoost));
                if (bs === "accent-glow") return alpha(surface_container_lowest, 0.90);
                if (bs === "monochrome") return surface_container_highest;
                return surface_container_low;
            case "barBorderColor":
                if (bs === "regular") return alpha(outline_variant, 0.40);
                if (bs === "pure-black") return isLightMode ? "#e0e0e0" : "#1f1f1f";
                if (bs === "glass") return isLightMode ? lightGlassBorder : Qt.rgba(1, 1, 1, 0.16);
                if (bs === "glass-frost") return isLightMode ? lightFrostBorder : Qt.rgba(1, 1, 1, 0.24);
                if (bs === "cyber-neon") return primary;
                if (bs === "bento-floating") return alpha(outline_variant, 0.45);
                if (bs === "accent-glow") return primary;
                if (bs === "translucent") return alpha(outline_variant, 0.35);
                return alpha(outline_variant, 0.50);
            case "widgetBg":
                if (bs === "regular") return surface_container_high;
                if (bs === "pure-black") return isLightMode ? "#f2f2f2" : "#0a0a0a";
                if (bs === "glass") return alpha(surface_container_high, isLightMode ? 0.55 : 0.28);
                if (bs === "glass-frost") return alpha(surface_container_high, isLightMode ? 0.68 : 0.38);
                if (bs === "cyber-neon") return alpha(surface_container_lowest, 0.85);
                if (bs === "bento-floating") return alpha(surface_container_high, isLightMode ? 0.65 : 0.50);
                if (bs === "translucent") return alpha(surface_container_high, isLightMode ? 0.58 : 0.40);
                if (bs === "accent-glow") return alpha(primary_container, 0.65);
                if (bs === "monochrome") return surface_container_high;
                return surface_container_low;
            case "widgetHover":
                if (bs === "regular") return alpha(surface_container_highest, 0.85);
                if (bs === "pure-black") return isLightMode ? "#e6e6e6" : "#181818";
                if (bs === "glass") return alpha(surface_container_highest, isLightMode ? 0.72 : 0.48);
                if (bs === "glass-frost") return alpha(surface_container_highest, isLightMode ? 0.82 : 0.60);
                if (bs === "cyber-neon") return alpha(primary_container, 0.50);
                if (bs === "bento-floating") return alpha(surface_container_highest, 0.70);
                if (bs === "translucent") return alpha(surface_container_highest, 0.65);
                if (bs === "accent-glow") return alpha(primary, 0.35);
                if (bs === "monochrome") return surface_container_highest;
                return surface_container_highest;
            case "widgetActive":
                if (bs === "regular") return alpha(primary_container, 0.90);
                if (bs === "pure-black") return isLightMode ? "#d9d9d9" : "#242424";
                if (bs === "glass") return alpha(surface_container_highest, isLightMode ? 0.85 : 0.65);
                if (bs === "glass-frost") return alpha(surface_container_highest, isLightMode ? 0.90 : 0.80);
                if (bs === "cyber-neon") return alpha(primary, 0.45);
                if (bs === "bento-floating") return alpha(surface_container_highest, 0.90);
                if (bs === "translucent") return alpha(surface_container_highest, 0.85);
                if (bs === "accent-glow") return alpha(primary, 0.55);
                if (bs === "monochrome") return alpha(on_surface, 0.20);
                return surface_container_highest;
            case "widgetBorder":
                if (bs === "regular") return alpha(outline_variant, 0.40);
                if (bs === "pure-black") return isLightMode ? "#dcdcdc" : "#1f1f1f";
                if (bs === "glass") return isLightMode ? lightGlassBorder : Qt.rgba(1, 1, 1, 0.12);
                if (bs === "glass-frost") return isLightMode ? lightFrostBorder : Qt.rgba(1, 1, 1, 0.20);
                if (bs === "cyber-neon") return alpha(primary, 0.60);
                if (bs === "bento-floating") return alpha(outline_variant, 0.40);
                if (bs === "translucent") return alpha(outline_variant, 0.35);
                if (bs === "accent-glow") return alpha(primary, 0.70);
                if (bs === "monochrome") return alpha(outline, 0.40);
                return alpha(outline_variant, 0.50);
            case "popupBg":
                if (bs === "regular") return surface_container_low;
                if (bs === "pure-black") return isLightMode ? "#ffffff" : "#000000";
                if (bs === "glass") return alpha(surface_container_lowest, Math.min(1.0, (isLightMode ? 0.86 : 0.60) + adaptiveAlphaBoost));
                if (bs === "glass-frost") return alpha(surface_container_lowest, Math.min(1.0, (isLightMode ? 0.92 : 0.75) + adaptiveAlphaBoost));
                if (bs === "cyber-neon") return isLightMode ? alpha(surface_container_lowest, 0.96) : alpha("#07070b", 0.96);
                if (bs === "bento-floating") return alpha(surface_container_low, Math.min(1.0, 0.92 + adaptiveAlphaBoost));
                if (bs === "translucent") return alpha(surface_container_low, Math.min(1.0, (isLightMode ? 0.88 : 0.80) + adaptiveAlphaBoost));
                if (bs === "accent-glow") return alpha(surface_container_lowest, 0.95);
                if (bs === "monochrome") return surface_container_low;
                return surface_container_low;
            case "popupBorderColor":
                if (bs === "regular") return alpha(outline_variant, 0.45);
                if (bs === "pure-black") return isLightMode ? "#dcdcdc" : "#1f1f1f";
                if (bs === "glass") return isLightMode ? lightFrostBorder : Qt.rgba(1, 1, 1, 0.18);
                if (bs === "glass-frost") return isLightMode ? lightFrostBorder : Qt.rgba(1, 1, 1, 0.26);
                if (bs === "cyber-neon") return primary;
                if (bs === "bento-floating") return alpha(outline_variant, 0.50);
                if (bs === "accent-glow") return alpha(primary, 0.85);
                if (bs === "translucent") return alpha(outline_variant, 0.40);
                if (bs === "monochrome") return alpha(outline, 0.45);
                return alpha(outline_variant, 0.50);
            case "cardBg":
                if (bs === "regular") return surface_container_high;
                if (bs === "pure-black") return isLightMode ? "#f7f7f7" : "#080808";
                if (bs === "glass") return alpha(surface_container_high, isLightMode ? 0.65 : 0.30);
                if (bs === "glass-frost") return alpha(surface_container_high, isLightMode ? 0.76 : 0.45);
                if (bs === "cyber-neon") return alpha(surface_container_low, 0.75);
                if (bs === "bento-floating") return alpha(surface_container_high, isLightMode ? 0.75 : 0.60);
                if (bs === "translucent") return alpha(surface_container_high, isLightMode ? 0.68 : 0.50);
                if (bs === "accent-glow") return alpha(primary_container, 0.45);
                if (bs === "monochrome") return surface_container_high;
                return surface_container_high;
            case "cardBorder":
                if (bs === "regular") return alpha(outline_variant, 0.35);
                if (bs === "pure-black") return isLightMode ? "#e2e2e2" : "#1c1c1c";
                if (bs === "glass") return isLightMode ? lightGlassBorder : Qt.rgba(1, 1, 1, 0.12);
                if (bs === "glass-frost") return isLightMode ? lightFrostBorder : Qt.rgba(1, 1, 1, 0.20);
                if (bs === "cyber-neon") return alpha(primary, 0.50);
                if (bs === "bento-floating") return alpha(outline_variant, 0.35);
                if (bs === "translucent") return alpha(outline_variant, 0.30);
                if (bs === "accent-glow") return alpha(primary, 0.60);
                if (bs === "monochrome") return alpha(outline, 0.35);
                return alpha(outline_variant, 0.40);
            case "pillBg":
                if (hasCustomColors && (cfg?.customWidgetBg ?? "") !== "") return cfg.customWidgetBg;
                if (bs === "regular") return surface_container_high;
                if (bs === "pure-black") return isLightMode ? "#f2f2f2" : "#0a0a0a";
                if (bs === "glass") return alpha(surface_container_high, isLightMode ? 0.62 : 0.25);
                if (bs === "glass-frost") return alpha(surface_container_high, isLightMode ? 0.74 : 0.35);
                if (bs === "cyber-neon") return alpha(surface_container_low, 0.60);
                if (bs === "bento-floating") return alpha(surface_container_high, isLightMode ? 0.68 : 0.50);
                if (bs === "translucent") return alpha(surface_container_high, isLightMode ? 0.62 : 0.45);
                if (bs === "accent-glow") return alpha(primary, 0.22);
                if (bs === "monochrome") return surface_container;
                return surface_container_high;
            case "pillHover":
                if (bs === "regular") return alpha(surface_container_highest, 0.85);
                if (bs === "pure-black") return isLightMode ? "#e6e6e6" : "#181818";
                if (bs === "glass") return alpha(surface_container_highest, isLightMode ? 0.78 : 0.45);
                if (bs === "glass-frost") return alpha(surface_container_highest, isLightMode ? 0.85 : 0.55);
                if (bs === "cyber-neon") return alpha(primary_container, 0.40);
                if (bs === "bento-floating") return alpha(surface_container_highest, 0.65);
                if (bs === "translucent") return alpha(surface_container_highest, 0.70);
                if (bs === "accent-glow") return alpha(primary, 0.40);
                if (bs === "monochrome") return surface_container_highest;
                return surface_container_highest;
            case "pillBorder":
                if (hasCustomColors && (cfg?.customBorder ?? "") !== "") return cfg.customBorder;
                if (bs === "regular") return alpha(outline_variant, 0.35);
                if (bs === "pure-black") return isLightMode ? "#dddddd" : "#222222";
                if (bs === "glass") return isLightMode ? lightGlassBorder : Qt.rgba(1, 1, 1, 0.14);
                if (bs === "glass-frost") return isLightMode ? lightFrostBorder : Qt.rgba(1, 1, 1, 0.22);
                if (bs === "cyber-neon") return alpha(primary, 0.75);
                if (bs === "bento-floating") return alpha(outline_variant, 0.30);
                if (bs === "translucent") return alpha(outline_variant, 0.25);
                if (bs === "accent-glow") return alpha(primary, 0.85);
                if (bs === "monochrome") return alpha(outline, 0.35);
                return Qt.rgba(0, 0, 0, 0);
            default:
                return surface_container_low;
        }
    }

    readonly property color barBg:            alpha(getStyleColor("barBg", barStyle), barOpacity)
    readonly property color barBorderColor:   getStyleColor("barBorderColor", barStyle)
    readonly property color cornerFill: {
        let cm = cfg?.cornerColorMode ?? "bar";
        if (cm === "accent") return primary;
        if (cm === "pure-black") return isLightMode ? "#ffffff" : "#000000";
        if (cm === "theme") return surface_container_high;
        return barBg;
    }
    readonly property color widgetBg:         getStyleColor("widgetBg", barStyle)
    readonly property color widgetHover:      getStyleColor("widgetHover", barStyle)
    readonly property color widgetActive:     getStyleColor("widgetActive", barStyle)
    readonly property color widgetBorder:     getStyleColor("widgetBorder", barStyle)
    readonly property color popupBg:          alpha(getStyleColor("popupBg", barStyle), popupOpacity * surfaceOpacity)
    readonly property color popupBorderColor: getStyleColor("popupBorderColor", barStyle)
    readonly property color cardBg:           alpha(getStyleColor("cardBg", barStyle), cardOpacity)
    readonly property color cardBorder:       getStyleColor("cardBorder", barStyle)
    readonly property color pillBg:           getStyleColor("pillBg", barStyle)
    readonly property color pillHover:        getStyleColor("pillHover", barStyle)
    readonly property color pillBorder:       getStyleColor("pillBorder", barStyle)

    readonly property color  glassHighlight:        isLightMode ? alpha(outline_variant, 0.45) : Qt.rgba(1, 1, 1, 0.16)
    readonly property color  glassBorder:           isLightMode ? alpha(outline_variant, 0.40) : Qt.rgba(1, 1, 1, 0.12)
    readonly property color  glassGlow:             alpha(primary, 0.25)
    readonly property color  cardGlow:              alpha(primary, 0.15)
    readonly property int    popupBorderWidth:      cfg?.popupBorderWidth ?? 1
    readonly property bool   scoopBorderEnabled:    cfg?.scoopBorderEnabled ?? true
    readonly property int    scoopBorderWidth:      cfg?.scoopBorderWidth ?? (screenBorderWidth > 0 ? screenBorderWidth : 2)
    readonly property color  scoopBorderColor: {
        let sc = cfg?.scoopBorderColor ?? "auto";
        if (sc !== "auto" && sc !== "") return sc;
        if (cornerColorMode === "accent") return primary;
        return barBorderColor;
    }

    readonly property int    popupWidth:             460
    readonly property int    popupHeight:            580
    readonly property int    popupMinWidth:          320
    readonly property int    popupMaxWidth:          620
    readonly property int    popupMinHeight:         180
    readonly property int    popupMaxHeight:         760
    readonly property int    popupWorkspaceMaxHeight: 460
    readonly property int    popupPadding:           16
    readonly property int    popupSpacing:           10
    readonly property int    popupDividerHeight:     1
    readonly property int    popupCardHeight:        44
    readonly property int    popupCardMinWidth:      190
    readonly property int    popupCardGap:           6
    readonly property int    popupCardPadding:       8
    readonly property int    popupCardIconSize:      26
    readonly property int    popupActionHeight:      32
    readonly property int    popupColumns:           2

    readonly property int    workspaceDotSize:       8
    readonly property int    workspaceIndicatorSize: 8
    readonly property int    workspaceIndicatorMin:  8
    readonly property int    workspaceSpacing:       widgetSpacing
    readonly property int    workspaceActiveSize:    20
    readonly property int    workspaceWidgetPadding: Math.max(widgetPaddingH, widgetPaddingV)

    readonly property int    thumbSize:              180

    readonly property real   animSpeedMult: {
        let sp = cfg?.animSpeed ?? "normal";
        if (sp === "instant") return 0.01;
        if (sp === "snappy" || sp === "superSnappy") return 0.7;
        if (sp === "hyper") return 0.4;
        if (sp === "chill") return 1.6;
        if (sp === "hyprland") return 0.85;
        return 1.0;
    }
    readonly property bool   isVertical:            cfg?.barPosition === "left" || cfg?.barPosition === "right"
    readonly property string animCurve:             cfg?.animCurve ?? "cubic"
    readonly property string animEasingType:        cfg?.animEasingType ?? "out"
    readonly property int    animDurationFast:      cfg?.animDurationFast ?? 120
    readonly property int    animDurationNormal:    cfg?.animDurationNormal ?? 200
    readonly property int    animDurationSlow:      cfg?.animDurationSlow ?? 350
    readonly property int    animFast:              Math.round(animDurationFast * animSpeedMult)
    readonly property int    animNormal:            Math.round(animDurationNormal * animSpeedMult)
    readonly property int    animDefault:           animNormal
    readonly property int    animSlow:              Math.round(animDurationSlow * animSpeedMult)
    readonly property int    expressiveFast:        Math.round(180 * animSpeedMult)
    readonly property int    expressiveDefault:     Math.round(320 * animSpeedMult)
    readonly property int    expressiveSlow:        Math.round(480 * animSpeedMult)
    readonly property int    workspaceTrailDuration:Math.round(260 * animSpeedMult)
    readonly property bool   workspaceActiveTrail:  cfg?.workspaceActiveTrail ?? true

    readonly property var    hyprlandBezier:            [0.05, 0.9, 0.1, 1.05, 1.0, 1.0]
    readonly property var    hyprlandExitBezier:        [0.3, 0.0, 0.8, 0.15, 1.0, 1.0]
    readonly property var    smoothBezier:              [0.16, 1.0, 0.3, 1.0, 1.0, 1.0]
    readonly property var    snappyBezier:              [0.2, 0.0, 0.0, 1.0, 1.0, 1.0]
    readonly property var    expressiveBezier:          [0.1, 1.15, 0.2, 1.0, 1.0, 1.0]
    readonly property var    standardBezier:            [0.25, 0.1, 0.25, 1.0, 1.0, 1.0]
    readonly property var    motionExpressiveFast:      [0.38, 1.25, 0.25, 1.0, 1.0, 1.0]
    readonly property var    motionExpressiveDefault:   [0.34, 1.45, 0.22, 1.0, 1.0, 1.0]
    readonly property var    motionExpressiveSlow:      [0.25, 1.35, 0.15, 1.0, 1.0, 1.0]
    readonly property var    motionEmphasized:          [0.20, 0.0, 0.0, 1.0, 1.0, 1.0]
    readonly property var    motionEmphasizedDecel:     [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
    readonly property var    motionEmphasizedAccel:     [0.30, 0.0, 0.8, 0.15, 1.0, 1.0]

    function getBezierPoints(curve: var): var {
        if (!curve) return standardBezier;
        if (Array.isArray(curve)) {
            if (curve.length >= 6) return [Number(curve[0]), Number(curve[1]), Number(curve[2]), Number(curve[3]), Number(curve[4]), Number(curve[5])];
            if (curve.length >= 4) return [Number(curve[0]), Number(curve[1]), Number(curve[2]), Number(curve[3]), 1.0, 1.0];
        }
        if (typeof curve !== "string") return standardBezier;
        let c = curve.trim().toLowerCase();
        if (c === "hyprland") return hyprlandBezier;
        if (c === "smooth" || c === "cubic") return smoothBezier;
        if (c === "snappy") return snappyBezier;
        if (c === "expressive") return expressiveBezier;
        if (c === "expressive-fast") return motionExpressiveFast;
        if (c === "expressive-default") return motionExpressiveDefault;
        if (c === "expressive-slow") return motionExpressiveSlow;
        if (c === "emphasized") return motionEmphasized;
        if (c === "emphasized-decel") return motionEmphasizedDecel;
        if (c === "emphasized-accel") return motionEmphasizedAccel;
        if (c === "linear") return [0.0, 0.0, 1.0, 1.0, 1.0, 1.0];

        let m = c.match(/^(?:cubic-bezier\s*\(\s*)?([0-9.-]+)\s*,\s*([0-9.-]+)\s*,\s*([0-9.-]+)\s*,\s*([0-9.-]+)(?:\s*\))?$/);
        if (m) {
            let p1 = parseFloat(m[1]), p2 = parseFloat(m[2]), p3 = parseFloat(m[3]), p4 = parseFloat(m[4]);
            if (!isNaN(p1) && !isNaN(p2) && !isNaN(p3) && !isNaN(p4)) {
                return [p1, p2, p3, p4, 1.0, 1.0];
            }
        }
        return standardBezier;
    }

    readonly property var    animBezierPoints:      getBezierPoints(animCurve)
    readonly property real   animOvershoot:         (animCurve === "hyprland" || cfg?.animSpeed === "hyprland") ? 1.05 : ((animCurve === "expressive") ? 1.15 : 1.70158)

    function getEasing(curve: string, type: string): int {
        let c = (curve ?? "cubic").toLowerCase();
        let t = (type ?? "out").toLowerCase();
        if (c === "linear") return Easing.Linear;
        if (c === "bezier" || c === "spline" || c === "bezierspline") return Easing.BezierSpline;
        if (c === "quad" || c === "snappy") {
            if (t === "in") return Easing.InQuad;
            if (t === "inout" || t === "in_out") return Easing.InOutQuad;
            if (t === "outin" || t === "out_in") return Easing.OutInQuad;
            return Easing.OutQuad;
        }
        if (c === "quart") {
            if (t === "in") return Easing.InQuart;
            if (t === "inout" || t === "in_out") return Easing.InOutQuart;
            if (t === "outin" || t === "out_in") return Easing.OutInQuart;
            return Easing.OutQuart;
        }
        if (c === "quint") {
            if (t === "in") return Easing.InQuint;
            if (t === "inout" || t === "in_out") return Easing.InOutQuint;
            if (t === "outin" || t === "out_in") return Easing.OutInQuint;
            return Easing.OutQuint;
        }
        if (c === "sine") {
            if (t === "in") return Easing.InSine;
            if (t === "inout" || t === "in_out") return Easing.InOutSine;
            if (t === "outin" || t === "out_in") return Easing.OutInSine;
            return Easing.OutSine;
        }
        if (c === "expo") {
            if (t === "in") return Easing.InExpo;
            if (t === "inout" || t === "in_out") return Easing.InOutExpo;
            if (t === "outin" || t === "out_in") return Easing.OutInExpo;
            return Easing.OutExpo;
        }
        if (c === "circ") {
            if (t === "in") return Easing.InCirc;
            if (t === "inout" || t === "in_out") return Easing.InOutCirc;
            if (t === "outin" || t === "out_in") return Easing.OutInCirc;
            return Easing.OutCirc;
        }
        if (c === "back" || c === "expressive") {
            if (t === "in") return Easing.InBack;
            if (t === "inout" || t === "in_out") return Easing.InOutBack;
            if (t === "outin" || t === "out_in") return Easing.OutInBack;
            return Easing.OutBack;
        }
        if (c === "elastic") {
            if (t === "in") return Easing.InElastic;
            if (t === "inout" || t === "in_out") return Easing.InOutElastic;
            if (t === "outin" || t === "out_in") return Easing.OutInElastic;
            return Easing.OutElastic;
        }
        if (c === "bounce") {
            if (t === "in") return Easing.InBounce;
            if (t === "inout" || t === "in_out") return Easing.InOutBounce;
            if (t === "outin" || t === "out_in") return Easing.OutInBounce;
            return Easing.OutBounce;
        }
        if (t === "in") return Easing.InCubic;
        if (t === "inout" || t === "in_out") return Easing.InOutCubic;
        if (t === "outin" || t === "out_in") return Easing.OutInCubic;
        return Easing.OutCubic;
    }

    readonly property int    animEasing:            getEasing(animCurve, animEasingType)
    readonly property int    animExpressiveEasing:  animCurve === "back" ? getEasing("back", animEasingType) : Easing.OutBack
    readonly property int    animEasingEntrance:    (animCurve === "expressive" || animCurve === "hyprland" || animCurve === "back" || cfg?.animSpeed === "hyprland") ? Easing.OutBack : (animCurve === "snappy" ? Easing.OutQuad : Easing.OutCubic)
    readonly property int    animEasingExit:        (animCurve === "snappy") ? Easing.InQuad : Easing.InCubic
    readonly property int    animColorEasing:       Easing.OutQuad

    // -------------------------------------------------------------------------
    // Native Icon Resolution Engine (Zero Font Dependencies)
    // -------------------------------------------------------------------------
    readonly property string iconSet:               cfg?.iconSet ?? "system"
    readonly property string fontIcon:              fontFamily

    // Backward compatibility font aliases
    readonly property string fontMaterialRounded:   fontFamily
    readonly property string fontMaterialOutlined:  fontFamily
    readonly property string fontMaterialSharp:     fontFamily
    readonly property string fontSegoe:             fontFamily
    readonly property string fontAwesome:           fontFamily

    // Resolves a bundled SVG asset from assets/icons/
    function bundledIconPath(name: string): string {
        if (!name || name === "") return "";
        let clean = name.trim();
        if (clean.startsWith("assets/icons/")) clean = clean.substring("assets/icons/".length);
        if (clean.endsWith(".svg")) clean = clean.substring(0, clean.length - 4);
        return Qt.resolvedUrl("assets/icons/" + clean + ".svg").toString();
    }

    // Resolves any icon name, semantic key, bundled asset, or direct URL to a valid image source
    function resolveIconSource(name: string): string {
        if (!name || name === "") return "";
        let s = name.trim();

        // 1. Return already resolved URLs directly
        if (s.startsWith("image://") || s.startsWith("file://") || s.startsWith("qrc:/") ||
            s.startsWith("http://") || s.startsWith("https://")) {
            return s;
        }

        // 2. Absolute filesystem paths
        if (s.startsWith("/")) {
            return "file://" + s;
        }

        // 3. Bundled SVG path references
        if (s.startsWith("assets/icons/") || s.startsWith("./assets/icons/") || s.endsWith(".svg")) {
            return bundledIconPath(s);
        }

        // 4. Bundled specialty icons dictionary
        const bundledMap = {
            "distro": "nixos",
            "nixos": "nixos",
            "nix": "nixos",
            "arch": "arch",
            "coffee": "coffee",
            "flame": "flame",
            "sparkles": "sparkles",
            "pin": "pin",
            "tray": "tray",
            "cpu": "cpu",
            "ram": "ram",
            "mem": "ram",
            "thermo": "thermo",
            "temperature": "thermo",
            "equalizer": "equalizer",
            "radio": "radio",
            "filter": "filter"
        };
        if (bundledMap[s]) {
            return bundledIconPath(bundledMap[s]);
        }

        // 5. Semantic icon key dictionary mapping to FreeDesktop standard names
        const semanticMap = {
            "appLauncher": "view-app-grid",
            "app-launcher": "view-app-grid",
            "workspaces": "view-paged",
            "search": "system-search",
            "close": "window-close",
            "check": "object-select-symbolic",
            "checkCircle": "emblem-ok-symbolic",
            "settings": "preferences-system",
            "gear": "preferences-system",
            "save": "document-save",
            "refresh": "view-refresh",
            "trash": "user-trash",
            "clipboard": "edit-paste",
            "grid": "view-grid",
            "note": "accessories-text-editor",
            "edit": "accessories-text-editor",
            "clock": "preferences-system-time",
            "eye": "view-visible",
            "eyeOff": "view-hidden",
            "heart": "emblem-favorite",
            "download": "download",
            "folder": "folder",
            "globe": "applications-internet",
            "camera": "camera-photo",
            "crop": "transform-crop",
            "screenshot": "applets-screenshooter",
            "volMute": "audio-volume-muted",
            "volLow": "audio-volume-low",
            "volMid": "audio-volume-medium",
            "volHigh": "audio-volume-high",
            "mic": "audio-input-microphone",
            "micMute": "microphone-sensitivity-muted",
            "palette": "preferences-desktop-theme",
            "headphones": "audio-headphones",
            "batFull": "battery-full",
            "batHalf": "battery-good",
            "batQuarter": "battery-low",
            "batEmpty": "battery-empty",
            "batCharge": "battery-charging-symbolic",
            "batCharging": "battery-charging-symbolic",
            "sun": "weather-clear",
            "moon": "weather-clear-night",
            "brightness": "weather-clear",
            "music": "audio-x-generic",
            "play": "media-playback-start",
            "pause": "media-playback-pause",
            "next": "media-skip-forward",
            "prev": "media-skip-backward",
            "shuffle": "media-playlist-shuffle",
            "repeat": "media-playlist-repeat",
            "repeatOne": "media-playlist-repeat-song",
            "wallhaven": "preferences-desktop-wallpaper",
            "wallpaper": "preferences-desktop-wallpaper",
            "bell": "preferences-system-notifications",
            "bellOutline": "preferences-system-notifications",
            "bellOff": "notifications-disabled",
            "ethernet": "network-wired",
            "wifi": "network-wireless",
            "wifiHigh": "network-wireless-signal-excellent",
            "wifiMed": "network-wireless-signal-good",
            "wifiLow": "network-wireless-signal-weak",
            "wifiOff": "network-wireless-offline",
            "bluetooth": "bluetooth-active",
            "bluetoothConnected": "bluetooth-active",
            "bluetoothOff": "bluetooth-disabled",
            "power": "system-shutdown",
            "shutdown": "system-shutdown",
            "lock": "system-lock-screen",
            "logout": "system-log-out",
            "reboot": "system-reboot",
            "suspend": "system-suspend",
            "hibernate": "system-suspend-hibernate",
            "chevronRight": "go-next",
            "chevronLeft": "go-previous",
            "chevronDown": "go-down",
            "chevronUp": "go-up",
            "sliders": "preferences-other",
            "terminal": "utilities-terminal",
            "calendar": "x-office-calendar",
            "battery": "battery",
            "volume": "audio-volume-high",
            "history": "document-open-recent",
            "copy": "edit-copy",
            "externalLink": "document-open-remote",
            "signal": "network-wireless-signal-good",
            "user": "user-identity",
            "shield": "security-high",
            "expand": "view-fullscreen",
            "collapse": "view-restore",
            "keyboard": "input-keyboard"
        };
        let target = semanticMap[s] || s;

        // 6. FreeDesktop system theme icon resolution via Quickshell
        if (typeof Quickshell !== "undefined" && Quickshell.iconPath) {
            let p = Quickshell.iconPath(target);
            if (p) return p;
        }
        return "image://icon/" + target;
    }

    // Backward compatibility helper for legacy getIcon calls
    function getIcon(mat: string, win: string, fa: string, key: var, kao: var, txt: var): string {
        if (key && typeof key === "string") return resolveIconSource(key);
        return "";
    }

    // Dynamic Hardware / Status Icon Helpers
    function getBatteryIcon(pct: int, isCharging: bool, isSaver: bool, isVertical: bool): string {
        let p = (pct === undefined || pct === null || isNaN(pct)) ? -1 : Math.max(0, Math.min(100, Math.round(pct)));
        if (p < 0) return resolveIconSource(isCharging ? "battery-charging-symbolic" : "battery-symbolic");

        let step = Math.min(100, Math.max(0, Math.round(p / 10) * 10));
        let cand = isCharging
            ? (step === 100 ? "battery-level-100-charged-symbolic" : "battery-level-" + step + "-charging-symbolic")
            : "battery-level-" + step + "-symbolic";

        if (typeof Quickshell !== "undefined" && Quickshell.hasThemeIcon && Quickshell.hasThemeIcon(cand)) {
            return resolveIconSource(cand);
        }

        if (isCharging) {
            if (p >= 90) return resolveIconSource("battery-full-charging-symbolic");
            if (p >= 50) return resolveIconSource("battery-good-charging-symbolic");
            if (p >= 20) return resolveIconSource("battery-low-charging-symbolic");
            return resolveIconSource("battery-empty-charging-symbolic");
        } else {
            if (p >= 90) return resolveIconSource("battery-full-symbolic");
            if (p >= 50) return resolveIconSource("battery-good-symbolic");
            if (p >= 20) return resolveIconSource("battery-low-symbolic");
            return resolveIconSource("battery-empty-symbolic");
        }
    }

    function getVolumeIcon(volRatio: real, isMuted: bool): string {
        if (isMuted || volRatio === undefined || isNaN(volRatio) || volRatio <= 0.001) {
            return resolveIconSource("audio-volume-muted");
        }
        let pct = Math.round(volRatio * 100);
        if (pct > 100) return resolveIconSource("audio-volume-overamplified");
        if (pct <= 33) return resolveIconSource("audio-volume-low");
        if (pct <= 66) return resolveIconSource("audio-volume-medium");
        return resolveIconSource("audio-volume-high");
    }

    function getBrightnessIcon(pct: int): string {
        let p = (pct === undefined || isNaN(pct)) ? 50 : pct;
        if (p <= 25) {
            if (typeof Quickshell !== "undefined" && Quickshell.hasThemeIcon && Quickshell.hasThemeIcon("display-brightness-low-symbolic")) {
                return resolveIconSource("display-brightness-low-symbolic");
            }
            return resolveIconSource("weather-clear-night");
        }
        if (p <= 70) {
            if (typeof Quickshell !== "undefined" && Quickshell.hasThemeIcon && Quickshell.hasThemeIcon("display-brightness-medium-symbolic")) {
                return resolveIconSource("display-brightness-medium-symbolic");
            }
            return resolveIconSource("display-brightness-symbolic");
        }
        if (typeof Quickshell !== "undefined" && Quickshell.hasThemeIcon && Quickshell.hasThemeIcon("display-brightness-high-symbolic")) {
            return resolveIconSource("display-brightness-high-symbolic");
        }
        return resolveIconSource("weather-clear");
    }

    function getWifiIcon(signalPct: int, isConnected: bool, isEthernet: bool): string {
        if (isEthernet) return resolveIconSource("network-wired");
        if (!isConnected) return resolveIconSource("network-wireless-offline");
        let sig = (signalPct === undefined || signalPct === null || isNaN(signalPct)) ? 0 : signalPct;
        if (sig < 25) return resolveIconSource("network-wireless-signal-weak");
        if (sig < 50) return resolveIconSource("network-wireless-signal-ok");
        if (sig < 75) return resolveIconSource("network-wireless-signal-good");
        return resolveIconSource("network-wireless-signal-excellent");
    }

    // -------------------------------------------------------------------------
    // 104 Theme Icon Properties
    // -------------------------------------------------------------------------
    readonly property string iconDistro:            resolveIconSource("distro")
    readonly property string iconNix:               resolveIconSource("nix")
    readonly property string iconArch:              resolveIconSource("arch")
    readonly property string iconAppLauncher:       resolveIconSource("appLauncher")
    readonly property string iconWorkspaces:        resolveIconSource("workspaces")
    readonly property string iconSearch:            resolveIconSource("search")
    readonly property string iconClose:             resolveIconSource("close")
    readonly property string iconCheck:             resolveIconSource("check")
    readonly property string iconCheckCircle:       resolveIconSource("checkCircle")
    readonly property string iconSettings:          resolveIconSource("settings")
    readonly property string iconGear:              iconSettings
    readonly property string iconSave:              resolveIconSource("save")
    readonly property string iconRefresh:           resolveIconSource("refresh")
    readonly property string iconTrash:             resolveIconSource("trash")
    readonly property string iconClipboard:         resolveIconSource("clipboard")
    readonly property string iconTray:              resolveIconSource("tray")
    readonly property string iconGrid:              resolveIconSource("grid")
    readonly property string iconNote:              resolveIconSource("note")
    readonly property string iconEdit:              iconNote
    readonly property string iconCoffee:            resolveIconSource("coffee")
    readonly property string iconClock:             resolveIconSource("clock")
    readonly property string iconCpu:               resolveIconSource("cpu")
    readonly property string iconMem:               resolveIconSource("mem")
    readonly property string iconThermo:            resolveIconSource("thermo")
    readonly property string iconEye:               resolveIconSource("eye")
    readonly property string iconEyeOff:            resolveIconSource("eyeOff")
    readonly property string iconHeart:             resolveIconSource("heart")
    readonly property string iconPin:               resolveIconSource("pin")
    readonly property string iconDownload:          resolveIconSource("download")
    readonly property string iconFolder:            resolveIconSource("folder")
    readonly property string iconGlobe:             resolveIconSource("globe")
    readonly property string iconCamera:            resolveIconSource("camera")
    readonly property string iconCrop:              resolveIconSource("crop")
    readonly property string iconScreenshot:        resolveIconSource("screenshot")

    readonly property string iconVolMute:           resolveIconSource("volMute")
    readonly property string iconVolLow:            resolveIconSource("volLow")
    readonly property string iconVolMid:            resolveIconSource("volMid")
    readonly property string iconVolHigh:           resolveIconSource("volHigh")
    readonly property string iconMic:               resolveIconSource("mic")
    readonly property string iconMicMute:           resolveIconSource("micMute")
    readonly property string iconPalette:           resolveIconSource("palette")
    readonly property string iconHeadphones:        resolveIconSource("headphones")
    readonly property string iconEqualizer:         resolveIconSource("equalizer")

    readonly property string iconBatFull:           resolveIconSource("batFull")
    readonly property string iconBatHalf:           resolveIconSource("batHalf")
    readonly property string iconBatQuarter:        resolveIconSource("batQuarter")
    readonly property string iconBatEmpty:          resolveIconSource("batEmpty")
    readonly property string iconBatCharge:         resolveIconSource("batCharge")
    readonly property string iconBatCharging:       iconBatCharge

    readonly property string iconSun:               resolveIconSource("sun")
    readonly property string iconMoon:              resolveIconSource("moon")
    readonly property string iconBrightness:        iconSun

    readonly property string iconMusic:             resolveIconSource("music")
    readonly property string iconPlay:              resolveIconSource("play")
    readonly property string iconPause:             resolveIconSource("pause")
    readonly property string iconNext:              resolveIconSource("next")
    readonly property string iconPrev:              resolveIconSource("prev")
    readonly property string iconShuffle:           resolveIconSource("shuffle")
    readonly property string iconRepeat:            resolveIconSource("repeat")
    readonly property string iconRepeatOne:         resolveIconSource("repeatOne")

    readonly property string iconWallhaven:         resolveIconSource("wallhaven")
    readonly property string iconWallpaper:         resolveIconSource("wallpaper")
    readonly property string iconBell:              resolveIconSource("bell")
    readonly property string iconBellOutline:       resolveIconSource("bellOutline")
    readonly property string iconBellOff:           resolveIconSource("bellOff")

    readonly property string iconEthernet:          resolveIconSource("ethernet")
    readonly property string iconWifi:              resolveIconSource("wifi")
    readonly property string iconWifiHigh:          resolveIconSource("wifiHigh")
    readonly property string iconWifiMed:           resolveIconSource("wifiMed")
    readonly property string iconWifiLow:           resolveIconSource("wifiLow")
    readonly property string iconWifiOff:           resolveIconSource("wifiOff")
    readonly property string iconBluetooth:         resolveIconSource("bluetooth")
    readonly property string iconBluetoothConnected:resolveIconSource("bluetoothConnected")
    readonly property string iconBluetoothOff:      resolveIconSource("bluetoothOff")

    readonly property string iconPower:             resolveIconSource("power")
    readonly property string iconShutdown:          iconPower
    readonly property string iconLock:              resolveIconSource("lock")
    readonly property string iconLogout:            resolveIconSource("logout")
    readonly property string iconReboot:            resolveIconSource("reboot")
    readonly property string iconSuspend:           resolveIconSource("suspend")
    readonly property string iconHibernate:         resolveIconSource("hibernate")

    readonly property string iconChevronRight:      resolveIconSource("chevronRight")
    readonly property string iconChevronLeft:       resolveIconSource("chevronLeft")
    readonly property string iconChevronDown:       resolveIconSource("chevronDown")
    readonly property string iconChevronUp:         resolveIconSource("chevronUp")
    readonly property string iconFlame:             resolveIconSource("flame")
    readonly property string iconSparkles:          resolveIconSource("sparkles")
    readonly property string iconRadio:             resolveIconSource("radio")
    readonly property string iconSliders:           resolveIconSource("sliders")
    readonly property string iconTerminal:          resolveIconSource("terminal")
    readonly property string iconCalendar:          resolveIconSource("calendar")
    readonly property string iconBattery:           resolveIconSource("battery")
    readonly property string iconVolume:            resolveIconSource("volume")
    readonly property string iconHistory:           resolveIconSource("history")
    readonly property string iconCopy:              resolveIconSource("copy")
    readonly property string iconExternalLink:      resolveIconSource("externalLink")
    readonly property string iconSignal:            resolveIconSource("signal")
    readonly property string iconFilter:            resolveIconSource("filter")
    readonly property string iconUser:              resolveIconSource("user")
    readonly property string iconShield:            resolveIconSource("shield")
    readonly property string iconExpand:            resolveIconSource("expand")
    readonly property string iconCollapse:          resolveIconSource("collapse")
    readonly property string iconKeyboard:          resolveIconSource("keyboard")

    readonly property string kaoHappy:              "(ﾉ◕ヮ◕)ﾉ*:･ﾟ✧"
    readonly property string kaoSad:                "( ╥ω╥ )"
    readonly property string kaoCoffee:             "( -_-)旦~"
    readonly property string kaoShrug:              "¯\\_(ツ)_/¯"
    readonly property string kaoEmpty:              "( ´・ω・` )"
    readonly property string kaoMusic:              "ヽ(•‿•)ノ♪"
    readonly property string kaoSearch:             "( ⚆_⚆)"
    readonly property string kaoError:              "( ;´Д` )"
    readonly property string kaoLoading:            "( ⊙_⊙;)"
    readonly property string kaoPeace:              "ヽ(・∀・)ノ"
    readonly property string kaoSleepy:             "( -.- )zzZ"
    readonly property string kaoCool:               "( ⌐■_■ )"
    readonly property string kaoLove:               "( ´▽`ʃ♡ƪ)"
    readonly property string kaoAnger:              "( ╬ Ò﹏Ó)"
    readonly property string kaoChaos:              "(╯°□°)╯︵ ┻━┻"
    readonly property string kaoWink:               "( ¬‿¬ )"
    readonly property string kaoFlex:               "ᕦ(ò_óˇ)ᕤ"
    readonly property string kaoBolt:               "( ✧∇✧ )و"
    readonly property string kaoDead:               "( ×_× )"
    readonly property string kaoCat:                "(=^･ω･^=)"
    readonly property string kaoPanic:              "( °Д°；)"
    readonly property string kaoVibe:               "( ˘ ³˘)♥"
    readonly property string kaoJam:                "( ~‾▿‾)~"
    readonly property string kaoDJ:                 "d( -_- )b"
    readonly property string kaoSilent:             "( ˙×˙ )"
    readonly property string kaoCozy:               "(っ˘ω˘ς)"
    readonly property string kaoCheer:              "(ﾉ>ω<)ﾉ :｡･:*:･ﾟ"
    readonly property string kaoSmug:               "( ˘⌣˘ )"
    readonly property string kaoFire:               "(ง •̀_•́)ง"
    readonly property string kaoSparkle:            "( ✧ω✧ )"
    readonly property string kaoTableFlip:          "(╯°□°)╯︵ ┻━┻"
    readonly property string kaoPutBack:            "┬─┬ノ( º _ ºノ)"

    function getVibe(kao: string, nerd: string, text: string): string {
        let style = cfg?.vibeStyle ?? "nerd";
        if (style === "kaomoji") return kao ?? "";
        if (style === "nerd") return (nerd ?? "").toLowerCase();
        return (text ?? "").toLowerCase();
    }

    readonly property var quotes: Object.freeze({
        "system": [
            "\"Talk is cheap. Show me the code.\" — Linus Torvalds",
            "\"Do one thing and do it well.\" — Douglas McIlroy",
            "\"Beware of bugs in the above code; I have only proved it correct, not tried it.\" — Donald Knuth",
            "\"There is no cloud, it's just someone else's computer.\" — Tech Adage",
            "\"No matter where you go, everyone's connected.\" — Serial Experiments Lain",
            "\"Unix is simple. It just takes a genius to understand its simplicity.\" — Dennis Ritchie",
            "\"Simplicity is prerequisite for reliability.\" — Edsger W. Dijkstra",
            "\"Measuring programming progress by lines of code is like measuring aircraft building progress by weight.\" — Bill Gates",
            "\"The most important property of a program is whether it accomplishes the intention of its user.\" — C.A.R. Hoare",
            "\"Premature optimization is the root of all evil.\" — Donald Knuth"
        ],
        "philosophy": [
            "\"Silence is a source of great strength.\" — Lao Tzu",
            "\"Music is the shorthand of emotion.\" — Leo Tolstoy",
            "\"We suffer more often in imagination than in reality.\" — Seneca",
            "\"Waste no more time arguing what a good man should be. Be one.\" — Marcus Aurelius",
            "\"The unexamined life is not worth living.\" — Socrates",
            "\"He who has a why to live can bear almost any how.\" — Friedrich Nietzsche",
            "\"It is not that we have a short time to live, but that we waste a lot of it.\" — Seneca",
            "\"The impediment to action advances action. What stands in the way becomes the way.\" — Marcus Aurelius",
            "\"Knowing yourself is the beginning of all wisdom.\" — Aristotle"
        ],
        "focus": [
            "\"Leave me alone, I know what I'm doing.\" — Kimi Räikkönen",
            "\"Deep work is the ability to focus without distraction on a cognitively demanding task.\" — Cal Newport",
            "\"Concentration is the secret of strength.\" — Ralph Waldo Emerson",
            "\"The successful warrior is the average man, with laser-like focus.\" — Bruce Lee",
            "\"Order your soul. Reduce your wants.\" — Augustine",
            "\"It is during our darkest moments that we must focus to see the light.\" — Aristotle",
            "\"Do not dwell in the past, do not dream of the future, concentrate the mind on the present moment.\" — Buddha"
        ],
        "simplicity": [
            "\"Simplicity is prerequisite for reliability.\" — Edsger W. Dijkstra",
            "\"An idiot admires complexity, a genius admires simplicity.\" — Terry Davis",
            "\"Simplicity is the ultimate sophistication.\" — Leonardo da Vinci",
            "\"Perfection is achieved not when there is nothing more to add, but when there is nothing left to take away.\" — Antoine de Saint-Exupéry",
            "\"Make it simple, but significant.\" — Don Draper",
            "\"Truth is ever to be found in simplicity, and not in the multiplicity and confusion of things.\" — Isaac Newton",
            "\"Fools ignore complexity. Pragmatists suffer it. Some can avoid it. Geniuses remove it.\" — Alan Perlis"
        ]
    })

    readonly property var statusFlavor: Object.freeze({
        "network_on": [
            "latency low, packets clean, link stable",
            "tailscale tunnel connected • homelab reachable",
            "bgp and routing tables nominal",
            "wifi link established • packet flow healthy",
            "gigabit link active • zero dropped frames",
            "dns resolved and upstream responsive",
            "local gateway responsive • 1.1.1.1 reachable"
        ],
        "network_off": [
            "offline mode • reading local man pages",
            "pure local computing • radio interfaces down",
            "airgapped mode active • zero external egress",
            "network interfaces disconnected",
            "127.0.0.1 is the only safe place left",
            "ethernet and wifi down • working locally"
        ],
        "battery_charging": [
            "usb-c power delivery active • charging cells",
            "plugged in • performance governor active",
            "fast charging active • battery replenishing",
            "external power connected • thermals nominal",
            "feeding clean wall juice into the system",
            "acpi state: charging • battery warming",
            "charge level rising • power brick negotiated"
        ],
        "battery_low": [
            "battery low • connect charger soon",
            "power reserve dropping below threshold",
            "dimming backlight to preserve remaining run time",
            "tlp powersave mode active • conserve battery",
            "save open buffers • charger recommended",
            "battery at critical level • running on reserve"
        ],
        "battery_full": [
            "battery fully charged • cells balanced",
            "charge cycle complete • ready for unplugged use",
            "charge threshold held • battery at 100%",
            "power adapter connected • battery healthy and full",
            "full battery • thermals cool and nominal"
        ],
        "media_playing": [
            "audio stream active • pipewire graph running",
            "soundtrack locked in • flow state engaged",
            "lossless stream playing smoothly",
            "mpris session active • headphones connected",
            "playback active • pipewire latency clean"
        ],
        "media_quiet": [
            "audio graph idle • no active playback",
            "wireplumber suspended sinks to conserve power",
            "quiet room • no audio streams active",
            "dac idle • zero background noise",
            "silence maintained • ready for audio"
        ],
        "notes_empty": [
            "task list clear • all items completed",
            "scratchpad empty • ready for notes",
            "zero pending items • workspace organized",
            "all notes archived • clean slate",
            "buffer empty • no tasks remaining"
        ],
        "notifs_empty": [
            "notification tray clear • zero unread pings",
            "inbox zero • no pending alerts",
            "dbus notification daemon quiet",
            "distraction-free desktop • zero unread toasts",
            "all notifications dismissed"
        ],
        "dnd_on": [
            "do not disturb active • notifications silenced",
            "focus mode engaged • routing pings to dev null",
            "world muted • deep work in progress",
            "quiet hours active • alerts suppressed",
            "notification daemon holding toasts until unmuted"
        ],
        "volume_muted": [
            "audio output muted • silence enforced",
            "master volume muted • hardware mute active",
            "pipewire sink muted • zero audio output",
            "output muted • tap volume key to restore"
        ],
        "volume_high": [
            "volume output high • mind your hearing",
            "preamp volume past nominal threshold",
            "high output level active on current sink",
            "audio output level near peak dynamic range"
        ],
        "brightness_high": [
            "backlight at high luminance",
            "peak display brightness active",
            "high contrast backlight for ambient lighting",
            "panel backlight set to maximum visibility"
        ],
        "brightness_low": [
            "dim mode engaged • comfortable for low light",
            "low backlight active • reducing eye strain",
            "minimal display luminance active",
            "night mode brightness • preserving dark adaptation"
        ],
        "idle_inhibited": [
            "idle inhibitor active • display will stay awake",
            "system keep-awake engaged for active tasks",
            "wayland idle protocol inhibited",
            "sleep timers suspended during active task"
        ],
        "idle_normal": [
            "idle timer active • power management nominal",
            "cpu idling • thermals cool and quiet",
            "system in normal power-saving state",
            "display sleep timer running normally"
        ],
        "system": [
            "all services green • dotfiles running smooth",
            "layer-shell desktop running responsive and clean",
            "hyprland ipc responsive • compositor synced",
            "system thermals nominal • memory clean",
            "zero errors in system journal • uptime steady",
            "desktop environment stable and focused"
        ],
        "screenshot": [
            "screen region captured to clipboard",
            "native wayland capture completed",
            "pixels acquired • ready to share",
            "framebuffer capture saved and ready",
            "screenshot saved to ~/pictures/screenshots"
        ]
    })

    // Backward-compatible alias for existing callers accessing Theme.flavorQuotes directly
    readonly property var flavorQuotes: statusFlavor

    // F02: Dedicated quote helper for attributed quotes (system, philosophy, focus, simplicity)
    function getQuote(category: string, fallback: string): string {
        let cat = category || "system";
        let pool = quotes[cat] ?? quotes["system"];
        if (!pool || pool.length === 0) return fallback ?? "";
        let totalMinutes = clock.hours * 60 + clock.minutes;
        return pool[totalMinutes % pool.length] ?? fallback ?? "";
    }

    // F02: Dedicated contextual hardware / desktop status helper
    function getStatusFlavor(category: string, fallback: string): string {
        if (!cfg?.unhingedFlavor) return (fallback ?? "").toLowerCase();
        let list = statusFlavor[category];
        if (!list || list.length === 0) return (fallback ?? "").toLowerCase();
        let totalMinutes = clock.hours * 60 + clock.minutes;
        return (list[totalMinutes % list.length] ?? fallback ?? "").toLowerCase();
    }

    // F02: Backward-compatible adapter for all existing call sites
    function getFlavor(category: string, fallback: string): string {
        if (!cfg?.unhingedFlavor) return (fallback ?? "").toLowerCase();
        let list = statusFlavor[category] ?? quotes[category];
        if (!list || list.length === 0) return (fallback ?? "").toLowerCase();
        let totalMinutes = clock.hours * 60 + clock.minutes;
        return (list[totalMinutes % list.length] ?? fallback ?? "").toLowerCase();
    }
}
