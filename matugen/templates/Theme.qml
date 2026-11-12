// Theme.qml
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property var cfg: (typeof Settings !== "undefined" ? Settings : null)

    // watching palette.css like a hawk so we don't have to restart the whole shell
    property var paletteWatcher: FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || ((Quickshell.env("HOME") || "") + "/.config")) + "/quickshell/palette.css"
        watchChanges: true
        printErrors: false
    }

    // ticking time bomb so the widgets know when to panic
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // squinting at the wallpaper to guess how obnoxious the colors are
    ColorQuantizer {
        id: wpQuantizer
        depth: 2
        source: {
            let wp = cfg?.currentWallpaper ?? "";
            if (!wp) return "";
            if (wp.startsWith("/") || wp.startsWith("~")) {
                let p = wp.startsWith("~") ? ((Quickshell.env("HOME") || "") + wp.slice(1)) : wp;
                return "file://" + p;
            }
            return wp;
        }
    }

    readonly property real wallpaperVibrancy: {
        if (!wpQuantizer.colors || wpQuantizer.colors.length === 0) return 0.5;
        let maxSat = 0.0;
        for (let i = 0; i < wpQuantizer.colors.length; i++) {
            let c = wpQuantizer.colors[i];
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

    readonly property color matugenPrimary:            "{{colors.primary.default.hex}}"
    readonly property color primary:                   (hasCustomColors && (cfg?.customActive ?? "") !== "") ? cfg.customActive : matugenPrimary
    readonly property color on_primary:                "{{colors.on_primary.default.hex}}"
    readonly property color primary_container:         "{{colors.primary_container.default.hex}}"
    readonly property color on_primary_container:      "{{colors.on_primary_container.default.hex}}"

    readonly property color secondary:                 "{{colors.secondary.default.hex}}"
    readonly property color on_secondary:              "{{colors.on_secondary.default.hex}}"
    readonly property color secondary_container:       "{{colors.secondary_container.default.hex}}"
    readonly property color on_secondary_container:    "{{colors.on_secondary_container.default.hex}}"

    readonly property color tertiary:                  "{{colors.tertiary.default.hex}}"
    readonly property color on_tertiary:               "{{colors.on_tertiary.default.hex}}"
    readonly property color tertiary_container:        "{{colors.tertiary_container.default.hex}}"
    readonly property color on_tertiary_container:     "{{colors.on_tertiary_container.default.hex}}"

    readonly property color error:                     "{{colors.error.default.hex}}"
    readonly property color on_error:                  "{{colors.on_error.default.hex}}"
    readonly property color error_container:           "{{colors.error_container.default.hex}}"
    readonly property color on_error_container:        "{{colors.on_error_container.default.hex}}"

    readonly property color matugenBg:                 "{{colors.background.default.hex}}"
    readonly property color background:                (hasCustomColors && (cfg?.customBg ?? "") !== "") ? cfg.customBg : matugenBg
    readonly property color on_background:             "{{colors.on_background.default.hex}}"

    readonly property color matugenSurface:            "{{colors.surface.default.hex}}"
    readonly property color surface:                   (hasCustomColors && (cfg?.customBg ?? "") !== "") ? cfg.customBg : matugenSurface
    readonly property color matugenOnSurface:          "{{colors.on_surface.default.hex}}"
    readonly property color on_surface:                (hasCustomColors && (cfg?.customText ?? "") !== "") ? cfg.customText : matugenOnSurface
    readonly property color surface_variant:           "{{colors.surface_variant.default.hex}}"
    readonly property color matugenOnSurfaceVariant:   "{{colors.on_surface_variant.default.hex}}"
    readonly property color on_surface_variant:        (hasCustomColors && (cfg?.customSubtext ?? "") !== "") ? cfg.customSubtext : matugenOnSurfaceVariant
    readonly property color textPrimary:               on_surface
    readonly property color textSecondary:             on_surface_variant

    readonly property color surface_container_lowest:  (hasCustomColors && (cfg?.customBg ?? "") !== "") ? cfg.customBg : "{{colors.surface_container_lowest.default.hex}}"
    readonly property color surface_container_low:     (hasCustomColors && (cfg?.customBg ?? "") !== "") ? cfg.customBg : "{{colors.surface_container_low.default.hex}}"
    readonly property color surface_container:         "{{colors.surface_container.default.hex}}"
    readonly property color surface_container_high:    (hasCustomColors && (cfg?.customWidgetBg ?? "") !== "") ? cfg.customWidgetBg : "{{colors.surface_container_high.default.hex}}"
    readonly property color surface_container_highest: "{{colors.surface_container_highest.default.hex}}"

    readonly property color surface_dim:               "{{colors.surface_dim.default.hex}}"
    readonly property color surface_bright:            "{{colors.surface_bright.default.hex}}"

    readonly property color matugenOutline:            "{{colors.outline.default.hex}}"
    readonly property color outline:                   (hasCustomColors && (cfg?.customBorder ?? "") !== "") ? cfg.customBorder : matugenOutline
    readonly property color outline_variant:           (hasCustomColors && (cfg?.customBorder ?? "") !== "") ? cfg.customBorder : "{{colors.outline_variant.default.hex}}"

    readonly property color shadow:                    "{{colors.shadow.default.hex}}"
    readonly property color scrim:                     "{{colors.scrim.default.hex}}"

    readonly property color inverse_surface:           "{{colors.inverse_surface.default.hex}}"
    readonly property color inverse_on_surface:        "{{colors.inverse_on_surface.default.hex}}"
    readonly property color inverse_primary:           "{{colors.inverse_primary.default.hex}}"
    readonly property color source_color:              "{{colors.source_color.default.hex}}"

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

        // squaring the channels so the middle of the gradient doesn't turn into wet concrete
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

    /*
    centralized icon detective so we stop copy-pasting the same 45-line
    for-loop into every single widget like cavemen
    */
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

    // radioactive state tints and depression overlays
    readonly property color primary_overlay:        alpha(primary, 0.18)
    readonly property color secondary_overlay:      alpha(secondary, 0.18)
    readonly property color tertiary_overlay:       alpha(tertiary, 0.18)
    readonly property color error_overlay:          alpha(error, 0.22)
    readonly property color warn:                   tertiary
    readonly property color warn_container:         tertiary_container
    readonly property color on_warn_container:      on_tertiary_container
    readonly property color warn_overlay:           tertiary_overlay

    // google's sacred opacity percentages for button pokes
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
    readonly property color fontStrokeColor:        "#000000"
    readonly property color textStroke:             "#000000"
    readonly property color textShadow:             "#000000"

    // font witchcraft and pixel size guesswork
    readonly property string fontSans:              cfg?.fontSans ?? cfg?.fontFamily ?? "Noto Sans"
    readonly property string fontMono:              cfg?.fontMono ?? "JetBrainsMono Nerd Font"
    readonly property string fontDisplay:           cfg?.fontDisplay ?? fontSans

    // font fallback pile so glyphs dont turn into tofu rectangles
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

    // translation layer between random strings and qt font weight deities
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

    // rounding corners until my screen turns into an oval pebble
    readonly property int    widgetRadius:          cfg?.widgetRadius ?? 6
    readonly property int    popupRadius:           cfg?.popupRadius ?? 8
    readonly property int    radiusXs:              4
    readonly property int    radiusSm:              Math.max(3, Math.round(widgetRadius * 0.75))
    readonly property int    radiusMd:              Math.max(4, widgetRadius)
    readonly property int    radiusLg:              Math.max(8, popupRadius)
    readonly property int    radiusXl:              Math.max(14, Math.round(popupRadius * 1.75))
    readonly property int    radiusXxl:             Math.max(18, Math.round(popupRadius * 2.0))
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

    // color casino determining which glass shader liquefies your gpu today
    function getStyleColor(role: string, bs: string): color {
        switch (role) {
            case "barBg":
                if (bs === "regular") return alpha(surface_container_low, 0.95);
                if (bs === "pure-black") return "#000000";
                if (bs === "glass") return alpha(surface_container_lowest, Math.min(1.0, 0.40 + adaptiveAlphaBoost));
                if (bs === "glass-frost") return alpha(surface_container_lowest, Math.min(1.0, 0.55 + adaptiveAlphaBoost));
                if (bs === "cyber-neon") return alpha("#050508", 0.94);
                if (bs === "bento-floating") return alpha(surface_container_low, Math.min(1.0, 0.88 + adaptiveAlphaBoost));
                if (bs === "translucent") return alpha(surface_container_low, Math.min(1.0, 0.70 + adaptiveAlphaBoost));
                if (bs === "accent-glow") return alpha(surface_container_lowest, 0.90);
                if (bs === "monochrome") return surface_container_highest;
                return surface_container_low;
            case "barBorderColor":
                if (bs === "regular") return alpha(outline_variant, 0.40);
                if (bs === "pure-black") return "#1f1f1f";
                if (bs === "glass") return Qt.rgba(1, 1, 1, 0.16);
                if (bs === "glass-frost") return Qt.rgba(1, 1, 1, 0.24);
                if (bs === "cyber-neon") return primary;
                if (bs === "bento-floating") return alpha(outline_variant, 0.45);
                if (bs === "accent-glow") return primary;
                if (bs === "translucent") return alpha(outline_variant, 0.35);
                return alpha(outline_variant, 0.50);
            case "widgetBg":
                if (bs === "regular") return alpha(surface_container_high, 0.60);
                if (bs === "pure-black") return "#0a0a0a";
                if (bs === "glass") return alpha(surface_container_high, 0.28);
                if (bs === "glass-frost") return alpha(surface_container_high, 0.38);
                if (bs === "cyber-neon") return alpha(surface_container_lowest, 0.85);
                if (bs === "bento-floating") return alpha(surface_container_high, 0.50);
                if (bs === "translucent") return alpha(surface_container_high, 0.40);
                if (bs === "accent-glow") return alpha(primary_container, 0.65);
                if (bs === "monochrome") return surface_container_high;
                return surface_container_low;
            case "widgetHover":
                if (bs === "regular") return alpha(surface_container_highest, 0.85);
                if (bs === "pure-black") return "#181818";
                if (bs === "glass") return alpha(surface_container_highest, 0.48);
                if (bs === "glass-frost") return alpha(surface_container_highest, 0.60);
                if (bs === "cyber-neon") return alpha(primary_container, 0.50);
                if (bs === "bento-floating") return alpha(surface_container_highest, 0.70);
                if (bs === "translucent") return alpha(surface_container_highest, 0.65);
                if (bs === "accent-glow") return alpha(primary, 0.35);
                if (bs === "monochrome") return surface_container_highest;
                return surface_container_highest;
            case "widgetActive":
                if (bs === "regular") return alpha(primary_container, 0.90);
                if (bs === "pure-black") return "#242424";
                if (bs === "glass") return alpha(surface_container_highest, 0.65);
                if (bs === "glass-frost") return alpha(surface_container_highest, 0.80);
                if (bs === "cyber-neon") return alpha(primary, 0.45);
                if (bs === "bento-floating") return alpha(surface_container_highest, 0.90);
                if (bs === "translucent") return alpha(surface_container_highest, 0.85);
                if (bs === "accent-glow") return alpha(primary, 0.55);
                if (bs === "monochrome") return alpha(on_surface, 0.20);
                return surface_container_highest;
            case "widgetBorder":
                if (bs === "regular") return alpha(outline_variant, 0.40);
                if (bs === "pure-black") return "#1f1f1f";
                if (bs === "glass") return Qt.rgba(1, 1, 1, 0.12);
                if (bs === "glass-frost") return Qt.rgba(1, 1, 1, 0.20);
                if (bs === "cyber-neon") return alpha(primary, 0.60);
                if (bs === "bento-floating") return alpha(outline_variant, 0.40);
                if (bs === "translucent") return alpha(outline_variant, 0.35);
                if (bs === "accent-glow") return alpha(primary, 0.70);
                if (bs === "monochrome") return alpha(outline, 0.40);
                return alpha(outline_variant, 0.50);
            case "popupBg":
                if (bs === "regular") return alpha(surface_container_low, 0.96);
                if (bs === "pure-black") return "#000000";
                if (bs === "glass") return alpha(surface_container_lowest, Math.min(1.0, 0.60 + adaptiveAlphaBoost));
                if (bs === "glass-frost") return alpha(surface_container_lowest, Math.min(1.0, 0.75 + adaptiveAlphaBoost));
                if (bs === "cyber-neon") return alpha("#07070b", 0.96);
                if (bs === "bento-floating") return alpha(surface_container_low, Math.min(1.0, 0.92 + adaptiveAlphaBoost));
                if (bs === "translucent") return alpha(surface_container_low, Math.min(1.0, 0.80 + adaptiveAlphaBoost));
                if (bs === "accent-glow") return alpha(surface_container_lowest, 0.95);
                if (bs === "monochrome") return surface_container_low;
                return surface_container_low;
            case "popupBorderColor":
                if (bs === "regular") return alpha(outline_variant, 0.45);
                if (bs === "pure-black") return "#1f1f1f";
                if (bs === "glass") return Qt.rgba(1, 1, 1, 0.18);
                if (bs === "glass-frost") return Qt.rgba(1, 1, 1, 0.26);
                if (bs === "cyber-neon") return primary;
                if (bs === "bento-floating") return alpha(outline_variant, 0.50);
                if (bs === "accent-glow") return alpha(primary, 0.85);
                if (bs === "translucent") return alpha(outline_variant, 0.40);
                if (bs === "monochrome") return alpha(outline, 0.45);
                return alpha(outline_variant, 0.50);
            case "cardBg":
                if (bs === "regular") return alpha(surface_container_high, 0.75);
                if (bs === "pure-black") return "#080808";
                if (bs === "glass") return alpha(surface_container_high, 0.30);
                if (bs === "glass-frost") return alpha(surface_container_high, 0.45);
                if (bs === "cyber-neon") return alpha(surface_container_low, 0.75);
                if (bs === "bento-floating") return alpha(surface_container_high, 0.60);
                if (bs === "translucent") return alpha(surface_container_high, 0.50);
                if (bs === "accent-glow") return alpha(primary_container, 0.45);
                if (bs === "monochrome") return surface_container_high;
                return surface_container_high;
            case "cardBorder":
                if (bs === "regular") return alpha(outline_variant, 0.35);
                if (bs === "pure-black") return "#1c1c1c";
                if (bs === "glass") return Qt.rgba(1, 1, 1, 0.12);
                if (bs === "glass-frost") return Qt.rgba(1, 1, 1, 0.20);
                if (bs === "cyber-neon") return alpha(primary, 0.50);
                if (bs === "bento-floating") return alpha(outline_variant, 0.35);
                if (bs === "translucent") return alpha(outline_variant, 0.30);
                if (bs === "accent-glow") return alpha(primary, 0.60);
                if (bs === "monochrome") return alpha(outline, 0.35);
                return alpha(outline_variant, 0.40);
            case "pillBg":
                if (hasCustomColors && (cfg?.customWidgetBg ?? "") !== "") return cfg.customWidgetBg;
                if (bs === "regular") return alpha(surface_container_high, 0.65);
                if (bs === "pure-black") return "#0a0a0a";
                if (bs === "glass") return alpha(surface_container_high, 0.25);
                if (bs === "glass-frost") return alpha(surface_container_high, 0.35);
                if (bs === "cyber-neon") return alpha(surface_container_low, 0.60);
                if (bs === "bento-floating") return alpha(surface_container_high, 0.50);
                if (bs === "translucent") return alpha(surface_container_high, 0.45);
                if (bs === "accent-glow") return alpha(primary, 0.22);
                if (bs === "monochrome") return surface_container;
                return surface_container_high;
            case "pillHover":
                if (bs === "regular") return alpha(surface_container_highest, 0.85);
                if (bs === "pure-black") return "#181818";
                if (bs === "glass") return alpha(surface_container_highest, 0.45);
                if (bs === "glass-frost") return alpha(surface_container_highest, 0.55);
                if (bs === "cyber-neon") return alpha(primary_container, 0.40);
                if (bs === "bento-floating") return alpha(surface_container_highest, 0.65);
                if (bs === "translucent") return alpha(surface_container_highest, 0.70);
                if (bs === "accent-glow") return alpha(primary, 0.40);
                if (bs === "monochrome") return surface_container_highest;
                return surface_container_highest;
            case "pillBorder":
                if (hasCustomColors && (cfg?.customBorder ?? "") !== "") return cfg.customBorder;
                if (bs === "regular") return alpha(outline_variant, 0.35);
                if (bs === "pure-black") return "#222222";
                if (bs === "glass") return Qt.rgba(1, 1, 1, 0.14);
                if (bs === "glass-frost") return Qt.rgba(1, 1, 1, 0.22);
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
        let cm = Settings?.cornerColorMode ?? "bar";
        if (cm === "accent") return primary;
        if (cm === "pure-black") return "#000000";
        if (cm === "theme") return surface_container_high;
        return barBg;
    }
    readonly property color widgetBg:         getStyleColor("widgetBg", barStyle)
    readonly property color widgetHover:      getStyleColor("widgetHover", barStyle)
    readonly property color widgetActive:     getStyleColor("widgetActive", barStyle)
    readonly property color widgetBorder:     getStyleColor("widgetBorder", barStyle)
    readonly property color popupBg:          alpha(getStyleColor("popupBg", barStyle), popupOpacity)
    readonly property color popupBorderColor: getStyleColor("popupBorderColor", barStyle)
    readonly property color cardBg:           getStyleColor("cardBg", barStyle)
    readonly property color cardBorder:       getStyleColor("cardBorder", barStyle)
    readonly property color pillBg:           getStyleColor("pillBg", barStyle)
    readonly property color pillHover:        getStyleColor("pillHover", barStyle)
    readonly property color pillBorder:       getStyleColor("pillBorder", barStyle)

    // easing curves and physics to make buttons feel dangerously squishy
    readonly property color  glassHighlight:        Qt.rgba(1, 1, 1, 0.16)
    readonly property color  glassBorder:           Qt.rgba(1, 1, 1, 0.12)
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

    // fallback guardrails so popups don't shrink into a single pixel or eat the monitor
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

    // workspace dot math that took way too many reloads to center
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

    // magic numbers pretending to be physics for qt's bezier spline
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

    // icon summoner circle: pulling glyphs out of ~/.local/share by their ankles
    readonly property string userFontDir:           (Quickshell.env("XDG_DATA_HOME") || ((Quickshell.env("HOME") || "") + "/.local/share")) + "/fonts/"

    FontLoader {
        id: loaderMatRounded
        source: "file://" + root.userFontDir + "MaterialSymbolsRounded.ttf"
    }
    FontLoader {
        id: loaderMatOutlined
        source: "file://" + root.userFontDir + "MaterialSymbolsOutlined.ttf"
    }
    FontLoader {
        id: loaderMatSharp
        source: "file://" + root.userFontDir + "MaterialSymbolsSharp.ttf"
    }
    FontLoader {
        id: loaderFaSolid
        source: "file://" + root.userFontDir + "FontAwesome6Free-Solid.otf"
    }
    FontLoader {
        id: loaderSegoe
        source: "file://" + root.userFontDir + "SegoeIcons.ttf"
    }

    readonly property string iconSet:               cfg?.iconSet ?? "material"
    readonly property string fontMaterialRounded:   (loaderMatRounded.status === FontLoader.Ready && loaderMatRounded.name) ? loaderMatRounded.name : "Material Symbols Rounded"
    readonly property string fontMaterialOutlined:  (loaderMatOutlined.status === FontLoader.Ready && loaderMatOutlined.name) ? loaderMatOutlined.name : "Material Symbols Outlined"
    readonly property string fontMaterialSharp:     (loaderMatSharp.status === FontLoader.Ready && loaderMatSharp.name) ? loaderMatSharp.name : "Material Symbols Sharp"
    readonly property string fontSegoe:             (loaderSegoe.status === FontLoader.Ready && loaderSegoe.name) ? loaderSegoe.name : (cfg?.fontWindows ?? "Segoe Fluent Icons")
    readonly property string fontAwesome:           (loaderFaSolid.status === FontLoader.Ready && loaderFaSolid.name)
        ? loaderFaSolid.name
        : (cfg?.fontAwesome ?? "Font Awesome 6 Free")

    // dodging qt.fontfamilies() so the main thread doesnt flatline
    readonly property string fontIcon: {
        if (iconSet === "kaomoji" || iconSet === "text") return fontFamily;
        if (iconSet === "nerd") return cfg?.fontNerd ?? "JetBrainsMono Nerd Font";
        if (iconSet === "windows") return fontSegoe;
        if (iconSet === "awesome") return fontAwesome;

        if (iconSet === "material-outlined" || iconSet === "outlined") return fontMaterialOutlined;
        if (iconSet === "material-sharp" || iconSet === "sharp") return fontMaterialSharp;
        if (iconSet === "material-rounded" || iconSet === "rounded") return fontMaterialRounded;
        return cfg?.fontMaterial ?? fontMaterialRounded;
    }

    // actual expressive kaomoji instead of "[cpu]" and "(*_*)v"
    readonly property var kaomojiMap: Object.freeze({
        "arch": "(⌐■_■)", "nix": "(⌐■_■)", "nixos": "(⌐■_■)", "distro": "(⌐■_■)",
        "appLauncher": "(ﾉ◕ヮ◕)ﾉ", "workspaces": "( ० ० )", "search": "( ⚆_⚆)", "close": "(×_×)",
        "check": "(•̀ᴗ•́)b", "checkCircle": "(•̀ᴗ•́)b", "settings": "( ˘_˘ )", "gear": "( ˘_˘ )", "save": "(っ˘ω˘ς)",
        "refresh": "(ノ°▽°)ノ", "trash": "(╯°□°)╯", "clipboard": "(っ•̀ᴗ•́)っ", "tray": "( ˙꒳˙ )", "grid": "( ⊞_⊞ )",
        "note": "φ(．．)", "edit": "φ(．．)", "coffee": "( -_-)旦~", "clock": "( ˘ω˘ )", "cpu": "(ง•̀_•́)ง",
        "mem": "( °□° )", "thermo": "(;´Д`)", "eye": "( •_• )", "eyeOff": "( -_- )", "heart": "( ˘ ³˘)♥", "pin": "( ⌖_⌖ )",
        "download": "(っ´▽`)っ", "folder": "( ˘▾˘ )", "globe": "( ◕‿◕ )", "camera": "( ◉_• )", "crop": "( ¬_¬ )",
        "screenshot": "( ◉_• )", "volMute": "( ˙×˙ )", "volLow": "( ˙-˙ )", "volMid": "( ᵔ◡ᵔ )", "volHigh": "( ≧∇≦ )",
        "mic": "( °O° )", "micMute": "( ˙×˙ )", "palette": "( ✧ω✧ )", "headphones": "d( -_- )b", "equalizer": "( ~‾▿‾)~",
        "batFull": "( ◕‿◕ )", "batHalf": "( ・_・ )", "batQuarter": "( ;´-` )", "batEmpty": "( ×_× )", "batCharge": "( ✧∇✧ )",
        "batCharging": "( ✧∇✧ )", "sun": "( ☼‿☼ )", "moon": "( ˘ω˘ )zzZ", "brightness": "( ☼‿☼ )", "music": "ヽ(•‿•)ノ♪",
        "play": "( ▸‿▸ )", "pause": "( ˙-˙ )", "next": "( ⇀‿⇀ )", "prev": "( ↼‿↼ )", "shuffle": "( ~_~ )",
        "repeat": "( ↻_↻ )", "repeatOne": "( ↻_1 )", "wallhaven": "( ✧_✧ )", "wallpaper": "( ✧_✧ )", "bell": "( °!° )",
        "bellOutline": "( °!° )", "bellOff": "( -.- )", "ethernet": "( ⌐■_■ )", "wifi": "( •̀ᴗ•́ )و", "wifiHigh": "( •̀ᴗ•́ )و",
        "wifiMed": "( ・_・ )", "wifiLow": "( ;¬_¬ )", "wifiOff": "( ×_× )", "bluetooth": "( ˘▾˘ )",
        "bluetoothConnected": "d( •̀ᴗ•́ )b", "bluetoothOff": "( ×_× )", "power": "( ˘_˘ )", "shutdown": "( ˘_˘ )",
        "lock": "( ⌐■-■ )", "logout": "( ´ ▽ ` )ﾉ", "reboot": "( ノ°▽°)ノ", "suspend": "( -.- )zzZ", "hibernate": "( -.- )zzZ",
        "chevronRight": ">", "chevronLeft": "<", "chevronDown": "v", "chevronUp": "^", "flame": "(ง •̀_•́)ง",
        "sparkles": "( ✧ω✧ )", "radio": "( ~˘▾˘)~", "sliders": "( ˘_˘ )", "terminal": "( ¬‿¬ )", "calendar": "( ˘▾˘ )",
        "history": "( ◔_◔ )", "copy": "(っ•̀ᴗ•́)っ", "externalLink": "( ☞ﾟヮﾟ)☞", "signal": "( •̀ᴗ•́ )", "filter": "( ¬_¬ )",
        "user": "( •‿• )", "shield": "(ง •̀_•́)ง", "expand": "( ⊙_⊙ )", "collapse": "( >_< )", "keyboard": "φ(•̀ᴗ•́ )"
    })

    readonly property var textMap: Object.freeze({
        "arch": "nix", "nix": "nix", "nixos": "nix", "distro": "nix", "appLauncher": "apps", "workspaces": "ws", "search": "find", "close": "x",
        "check": "ok", "checkCircle": "ok", "settings": "cfg", "gear": "cfg", "save": "save",
        "refresh": "reload", "trash": "del", "clipboard": "clip", "tray": "tray", "grid": "grid",
        "note": "note", "edit": "edit", "coffee": "cafe", "clock": "time", "cpu": "cpu",
        "mem": "mem", "thermo": "temp", "eye": "show", "eyeOff": "hide", "heart": "fav", "pin": "pin",
        "download": "down", "folder": "dir", "globe": "web", "camera": "cam", "crop": "crop",
        "screenshot": "shot", "volMute": "mute", "volLow": "vol-", "volMid": "vol", "volHigh": "vol+",
        "mic": "mic", "micMute": "no-mic", "palette": "theme", "headphones": "audio", "equalizer": "eq",
        "batFull": "100%", "batHalf": "50%", "batQuarter": "25%", "batEmpty": "0%", "batCharge": "chg",
        "batCharging": "chg", "sun": "day", "moon": "night", "brightness": "bright", "music": "music",
        "play": "play", "pause": "pause", "next": "next", "prev": "prev", "shuffle": "shuf",
        "repeat": "loop", "repeatOne": "loop1", "wallhaven": "walls", "wallpaper": "wall", "bell": "bell",
        "bellOutline": "bell", "bellOff": "quiet", "ethernet": "eth", "wifi": "wifi", "wifiHigh": "high",
        "wifiMed": "med", "wifiLow": "low", "wifiOff": "offline", "bluetooth": "bt",
        "bluetoothConnected": "bt-on", "bluetoothOff": "bt-off", "power": "power", "shutdown": "power",
        "lock": "lock", "logout": "logout", "reboot": "reboot", "suspend": "sleep", "hibernate": "hib",
        "chevronRight": ">", "chevronLeft": "<", "chevronDown": "v", "chevronUp": "^", "flame": "chaos",
        "sparkles": "magic", "radio": "radio", "sliders": "opts", "terminal": "term", "calendar": "cal",
        "history": "hist", "copy": "copy", "externalLink": "open", "signal": "sig", "filter": "filter",
        "user": "user", "shield": "safe", "expand": "max", "collapse": "min", "keyboard": "keys"
    })

    // giant lookup table of unicode hexes because font awesome can't agree with anyone else
    readonly property var fontAwesomeMap: Object.freeze({
        "nixos": "\uF17C", "nix": "\uF17C", "arch": "\uF17C", "distro": "\uF17C",
        "appLauncher": "\uF009", "workspaces": "\uF108", "search": "\uF002", "close": "\uF00D",
        "check": "\uF00C", "checkCircle": "\uF058", "settings": "\uF013", "gear": "\uF013", "save": "\uF0C7",
        "refresh": "\uF021", "trash": "\uF2ED", "clipboard": "\uF328", "tray": "\uF01C", "grid": "\uF00A",
        "note": "\uF249", "edit": "\uF044", "coffee": "\uF0F4", "clock": "\uF017", "cpu": "\uF2DB",
        "mem": "\uF538", "thermo": "\uF2C7", "eye": "\uF06E", "eyeOff": "\uF070", "heart": "\uF004", "pin": "\uF08D",
        "download": "\uF019", "folder": "\uF07B", "globe": "\uF0AC", "camera": "\uF030", "crop": "\uF125",
        "screenshot": "\uF03E", "volMute": "\uF026", "volLow": "\uF027", "volMid": "\uF027", "volHigh": "\uF028",
        "mic": "\uF130", "micMute": "\uF131", "palette": "\uF53F", "headphones": "\uF025", "equalizer": "\uF1DE",
        "batFull": "\uF240", "batHalf": "\uF242", "batQuarter": "\uF243", "batEmpty": "\uF244", "batCharge": "\uF0E7",
        "batCharging": "\uF0E7", "sun": "\uF185", "moon": "\uF186", "brightness": "\uF185", "music": "\uF001",
        "play": "\uF04B", "pause": "\uF04C", "next": "\uF051", "prev": "\uF048", "shuffle": "\uF074",
        "repeat": "\uF363", "repeatOne": "\uF365", "wallhaven": "\uF03E", "wallpaper": "\uF03E", "bell": "\uF0F3",
        "bellOutline": "\uF0F3", "bellOff": "\uF1F6", "ethernet": "\uF796", "wifi": "\uF1EB", "wifiHigh": "\uF1EB",
        "wifiMed": "\uF6AB", "wifiLow": "\uF6AA", "wifiOff": "\uF6AC", "bluetooth": "\uF293",
        "bluetoothConnected": "\uF294", "bluetoothOff": "\uF293", "power": "\uF011", "shutdown": "\uF011",
        "lock": "\uF023", "logout": "\uF2F5", "reboot": "\uF021", "suspend": "\uF186", "hibernate": "\uF236",
        "chevronRight": "\uF054", "chevronLeft": "\uF053", "chevronDown": "\uF078", "chevronUp": "\uF077",
        "flame": "\uF06D", "sparkles": "\uE2CA", "radio": "\uF8D7", "sliders": "\uF1DE", "terminal": "\uF120",
        "calendar": "\uF133", "history": "\uF1DA", "copy": "\uF0C5", "externalLink": "\uF35D", "signal": "\uF012",
        "filter": "\uF0B0", "user": "\uF007", "shield": "\uF132", "expand": "\uF065", "collapse": "\uF066",
        "keyboard": "\uF11C"
    })

    // nerd font glyphs
    readonly property var nerdMap: Object.freeze({
        "arch": "\uF303", "nix": "\uF313", "nixos": "\uF313", "distro": "\uF313", "appLauncher": "󰀻", "workspaces": "󱂬", "search": "", "close": "",
        "check": "", "checkCircle": "", "settings": "", "gear": "", "save": "",
        "refresh": "", "trash": "", "clipboard": "󰅌", "tray": "󱊖", "grid": "󰕰",
        "note": "󰏫", "edit": "󰏫", "coffee": "󰛊", "clock": "󰥔", "cpu": "󰍛",
        "mem": "󰘚", "thermo": "󰔏", "eye": "󰈈", "eyeOff": "󰈉", "heart": "󰋑", "pin": "󰐃",
        "download": "󰇚", "folder": "󰉋", "globe": "󰖟", "camera": "󰄀", "crop": "󰩨",
        "screenshot": "󰹑", "volMute": "󰝟", "volLow": "󰕿", "volMid": "󰖀", "volHigh": "󰕾",
        "mic": "󰍬", "micMute": "󰍭", "palette": "󰏘", "headphones": "󰋋", "equalizer": "󰓃",
        "batFull": "󰁹", "batHalf": "󰁿", "batQuarter": "󰁼", "batEmpty": "󰂃", "batCharge": "󰢝",
        "batCharging": "󰢝", "sun": "󰖙", "moon": "󰖔", "brightness": "󰃠", "music": "󰝚",
        "play": "󰐊", "pause": "󰏤", "next": "󰒭", "prev": "󰒮", "shuffle": "󰒝",
        "repeat": "󰑖", "repeatOne": "󰑘", "wallhaven": "󰋩", "wallpaper": "󰋩", "bell": "󰂚",
        "bellOutline": "󰂚", "bellOff": "󰂛", "ethernet": "󰈀", "wifi": "󰤨", "wifiHigh": "󰤨",
        "wifiMed": "󰤥", "wifiLow": "󰤟", "wifiOff": "󰤮", "bluetooth": "󰂯",
        "bluetoothConnected": "󰂱", "bluetoothOff": "󰂲", "power": "󰐥", "shutdown": "󰐥",
        "lock": "󰌾", "logout": "󰍃", "reboot": "󰑓", "suspend": "󰤄", "hibernate": "󰒲",
        "chevronRight": "", "chevronLeft": "", "chevronDown": "", "chevronUp": "", "flame": "󰈸",
        "sparkles": "󰛓", "radio": "󰐹", "sliders": "󰒓", "terminal": "󰆍", "calendar": "󰃭",
        "history": "󰋚", "copy": "󰆏", "externalLink": "󰌹", "signal": "󰖩", "filter": "󰈲",
        "user": "󰀉", "shield": "󰞌", "expand": "󰊓", "collapse": "󰊔", "keyboard": "󰌌"
    })

    function getIcon(mat: string, win: string, fa: string, key: var, kao: var, txt: var): string {
        if (iconSet === "kaomoji") {
            if (typeof kao === "string" && kao !== "" && kao !== "undefined") return kao;
            if (key && kaomojiMap[key]) return kaomojiMap[key];
            return mat;
        }
        if (iconSet === "text") {
            if (typeof txt === "string" && txt !== "" && txt !== "undefined") return txt;
            if (key && textMap[key]) return textMap[key];
            return mat;
        }
        if (iconSet === "nerd") {
            if (key && nerdMap[key]) return nerdMap[key];
            return "󰋼";
        }
        if (iconSet === "windows") return win;
        if (iconSet === "awesome") {
            if (key && fontAwesomeMap[key]) return fontAwesomeMap[key];
            if (typeof fa === "string" && fa !== "") return fa;
            return "\uF128";
        }
        return mat;
    }

    function getBatteryIcon(pct: int, isCharging: bool, isSaver: bool, isVertical: bool): string {
        let p = (pct === undefined || pct === null || isNaN(pct)) ? -1 : Math.max(0, Math.min(100, Math.round(pct)));
        let lvl = p < 0 ? -1 : Math.min(10, Math.floor(p / 10));

        if (iconSet === "kaomoji") {
            if (lvl < 0) return kaomojiMap.batHalf;
            if (isCharging) return kaomojiMap.batCharge;
            if (lvl >= 9) return kaomojiMap.batFull;
            if (lvl >= 5) return kaomojiMap.batHalf;
            if (lvl >= 2) return kaomojiMap.batQuarter;
            return kaomojiMap.batEmpty;
        }

        if (iconSet === "text") {
            if (isCharging) return "chg";
            if (lvl < 0) return "bat";
            return p + "%";
        }

        if (iconSet === "nerd") {
            if (lvl < 0) return "󰁹";
            if (isCharging) {
                const nerdCharging = ["󰢟", "󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"];
                return nerdCharging[lvl];
            }
            const nerdDischarging = ["󰂃", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"];
            return nerdDischarging[lvl];
        }

        if (iconSet === "windows") {
            if (lvl < 0) return isVertical ? "\uF608" : "\uE996";
            if (isVertical) {
                if (isCharging) {
                    const chargingV = ["\uF5FD", "\uF5FE", "\uF5FF", "\uF600", "\uF601", "\uF602", "\uF603", "\uF604", "\uF605", "\uF606", "\uF607"];
                    return chargingV[lvl];
                }
                const dischargingV = ["\uF5F2", "\uF5F3", "\uF5F4", "\uF5F5", "\uF5F6", "\uF5F7", "\uF5F8", "\uF5F9", "\uF5FA", "\uF5FB", "\uF5FC"];
                return dischargingV[lvl];
            } else {
                if (isCharging) {
                    const chargingH = ["\uE85A", "\uE85B", "\uE85C", "\uE85D", "\uE85E", "\uE85F", "\uE860", "\uE861", "\uE862", "\uE83E", "\uEA93"];
                    return chargingH[lvl];
                }
                if (isSaver) {
                    const saverH = ["\uE863", "\uE864", "\uE865", "\uE866", "\uE867", "\uE868", "\uE869", "\uE86A", "\uE86B", "\uEA94", "\uEA95"];
                    return saverH[lvl];
                }
                const dischargingH = ["\uE850", "\uE851", "\uE852", "\uE853", "\uE854", "\uE855", "\uE856", "\uE857", "\uE858", "\uE859", "\uE83F"];
                return dischargingH[lvl];
            }
        }

        if (iconSet === "awesome") {
            if (lvl < 0) return fontAwesomeMap.batEmpty;
            if (isCharging) return fontAwesomeMap.batCharge;
            if (lvl >= 9) return fontAwesomeMap.batFull;
            if (lvl >= 7) return "\uF241";
            if (lvl >= 5) return fontAwesomeMap.batHalf;
            if (lvl >= 2) return fontAwesomeMap.batQuarter;
            return "\uF244";
        }

        if (lvl < 0) return "\uE1A6";
        if (isCharging) {
            const matCharging = ["\uF0A2", "\uF0A2", "\uF0A3", "\uF0A3", "\uF0A4", "\uF0A4", "\uF0A5", "\uF0A6", "\uF0A6", "\uF0A7", "\uE1A3"];
            return matCharging[lvl];
        }
        const matDischarging = ["\uEBDC", "\uF09C", "\uF09D", "\uF09D", "\uF09E", "\uF09E", "\uF09F", "\uF0A0", "\uF0A0", "\uF0A1", "\uE1A5"];
        return matDischarging[lvl];
    }

    function getVolumeIcon(volRatio: real, isMuted: bool): string {
        if (isMuted || volRatio === undefined || isNaN(volRatio) || volRatio <= 0.001) {
            return (iconSet === "kaomoji") ? kaomojiMap.volMute : (iconSet === "text") ? textMap.volMute : (iconSet === "nerd") ? nerdMap.volMute : iconVolMute;
        }
        let pct = Math.round(volRatio * 100);
        if (iconSet === "kaomoji") {
            if (pct > 100) return kaoFire;
            if (pct <= 33) return kaomojiMap.volLow;
            if (pct <= 66) return kaomojiMap.volMid;
            return kaomojiMap.volHigh;
        }
        if (iconSet === "text") {
            if (pct > 100) return "max!";
            if (pct <= 33) return textMap.volLow;
            if (pct <= 66) return textMap.volMid;
            return textMap.volHigh;
        }
        if (iconSet === "nerd") {
            if (pct <= 33) return nerdMap.volLow;
            if (pct <= 66) return nerdMap.volMid;
            return nerdMap.volHigh;
        }
        if (iconSet === "windows") {
            if (pct <= 33) return "\uE993";
            if (pct <= 66) return "\uE994";
            return "\uE995";
        }
        if (iconSet === "awesome") {
            if (pct <= 33) return fontAwesomeMap.volLow;
            if (pct <= 66) return fontAwesomeMap.volMid;
            return fontAwesomeMap.volHigh;
        }
        if (pct <= 33) return "\uE04E";
        if (pct <= 66) return "\uE04D";
        return "\uE050";
    }

    function getBrightnessIcon(pct: int): string {
        let p = (pct === undefined || isNaN(pct)) ? 50 : pct;
        if (iconSet === "kaomoji") {
            if (p <= 20) return kaoSleepy;
            if (p >= 85) return kaoSparkle;
            return kaomojiMap.brightness;
        }
        if (iconSet === "text") {
            if (p <= 25) return "dim";
            if (p >= 85) return "max";
            return textMap.brightness;
        }
        if (iconSet === "nerd") {
            if (p <= 30) return "󰃞";
            if (p <= 70) return "󰃟";
            return "󰃠";
        }
        return p <= 25 ? iconMoon : iconBrightness;
    }

    function getWifiIcon(signalPct: int, isConnected: bool, isEthernet: bool): string {
        if (isEthernet) return (iconSet === "kaomoji") ? kaomojiMap.ethernet : (iconSet === "text") ? "eth" : (iconSet === "nerd") ? "󰈀" : iconEthernet;
        if (!isConnected) return (iconSet === "kaomoji") ? kaomojiMap.wifiOff : (iconSet === "text") ? "off" : (iconSet === "nerd") ? "󰤮" : iconWifiOff;
        let sig = (signalPct === undefined || signalPct === null || isNaN(signalPct)) ? 0 : signalPct;
        if (iconSet === "kaomoji") {
            if (sig < 35) return kaomojiMap.wifiLow;
            if (sig < 70) return kaomojiMap.wifiMed;
            return kaomojiMap.wifiHigh;
        }
        if (iconSet === "text") {
            if (sig < 35) return "low";
            if (sig < 70) return "med";
            return "high";
        }
        if (iconSet === "nerd") {
            if (sig < 35) return "󰤟";
            if (sig < 70) return "󰤥";
            return "󰤨";
        }
        if (iconSet === "windows") {
            if (sig < 25) return "\uE871";
            if (sig < 50) return "\uE872";
            if (sig < 75) return "\uE873";
            return "\uE874";
        }
        if (iconSet === "awesome") {
            if (sig < 35) return fontAwesomeMap.wifiLow;
            if (sig < 70) return fontAwesomeMap.wifiMed;
            return fontAwesomeMap.wifiHigh;
        }
        if (sig < 35) return "\uE4CA";
        if (sig < 70) return "\uE4D9";
        return "\uE63E";
    }

    // four different icon fonts taped together with hope (and zero emojis)
    readonly property string iconDistro:            getIcon("\uE30A", "\uE71D", "\uF17C", "nixos")
    readonly property string iconNix:               getIcon("\uE30A", "\uE71D", "\uF17C", "nix")
    readonly property string iconArch:              getIcon("\uE30A", "\uE71D", "\uF17C", "arch")
    readonly property string iconAppLauncher:       getIcon("\uE5C3", "\uE71D", "\uF009", "appLauncher")
    readonly property string iconWorkspaces:        getIcon("\uE1A0", "\uE7C4", "\uF108", "workspaces")
    readonly property string iconSearch:            getIcon("\uE8B6", "\uE721", "\uF002", "search")
    readonly property string iconClose:             getIcon("\uE5CD", "\uE711", "\uF00D", "close")
    readonly property string iconCheck:             getIcon("\uE668", "\uE73E", "\uF00C", "check")
    readonly property string iconCheckCircle:       getIcon("\uF0BE", "\uF13E", "\uF058", "checkCircle")
    readonly property string iconSettings:          getIcon("\uE8B8", "\uE713", "\uF013", "settings")
    readonly property string iconGear:              iconSettings
    readonly property string iconSave:              getIcon("\uE161", "\uE74E", "\uF0C7", "save")
    readonly property string iconRefresh:           getIcon("\uE5D5", "\uE72C", "\uF021", "refresh")
    readonly property string iconTrash:             getIcon("\uE92E", "\uE74D", "\uF2ED", "trash")
    readonly property string iconClipboard:         getIcon("\uE14F", "\uF0E3", "\uF328", "clipboard")
    readonly property string iconTray:              getIcon("\uE156", "\uE971", "\uF01C", "tray")
    readonly property string iconGrid:              getIcon("\uE9B0", "\uF0E2", "\uF00A", "grid")
    readonly property string iconNote:              getIcon("\uE66D", "\uE70F", "\uF249", "note")
    readonly property string iconEdit:              iconNote
    readonly property string iconCoffee:            getIcon("\uEFEF", "\uEC32", "\uF0F4", "coffee")
    readonly property string iconClock:             getIcon("\uEFD6", "\uE823", "\uF017", "clock")
    readonly property string iconCpu:               getIcon("\uE322", "\uEEA1", "\uF2DB", "cpu")
    readonly property string iconMem:               getIcon("\uF7A3", "\uEEA0", "\uF538", "mem")
    readonly property string iconThermo:            getIcon("\uE846", "\uE9CA", "\uF2C7", "thermo")
    readonly property string iconEye:               getIcon("\uE8F4", "\uE7B3", "\uF06E", "eye")
    readonly property string iconEyeOff:            getIcon("\uE8F5", "\uED1A", "\uF070", "eyeOff")
    readonly property string iconHeart:             getIcon("\uE87E", "\uEB51", "\uF004", "heart")
    readonly property string iconPin:               getIcon("\uE6AA", "\uE718", "\uF08D", "pin")
    readonly property string iconDownload:          getIcon("\uF090", "\uE896", "\uF019", "download")
    readonly property string iconFolder:            getIcon("\uE2C7", "\uE838", "\uF07B", "folder")
    readonly property string iconGlobe:             getIcon("\uE64C", "\uE774", "\uF0AC", "globe")
    readonly property string iconCamera:            getIcon("\uE3AF", "\uE722", "\uF030", "camera")
    readonly property string iconCrop:              getIcon("\uE3BE", "\uE7A8", "\uF125", "crop")
    readonly property string iconScreenshot:        getIcon("\uF056", "\uE722", "\uF03E", "screenshot")

    readonly property string iconVolMute:           getIcon("\uE04F", "\uE74F", "\uF026", "volMute")
    readonly property string iconVolLow:            getIcon("\uE04E", "\uE993", "\uF027", "volLow")
    readonly property string iconVolMid:            getIcon("\uE04D", "\uE994", "\uF027", "volMid")
    readonly property string iconVolHigh:           getIcon("\uE050", "\uE995", "\uF028", "volHigh")
    readonly property string iconMic:               getIcon("\uE31D", "\uE720", "\uF130", "mic")
    readonly property string iconMicMute:           getIcon("\uE02B", "\uF781", "\uF131", "micMute")
    readonly property string iconPalette:           getIcon("\uE40A", "\uE790", "\uF53F", "palette")
    readonly property string iconHeadphones:        getIcon("\uF01F", "\uE7F6", "\uF025", "headphones")
    readonly property string iconEqualizer:         getIcon("\uE01D", "\uE9E9", "\uF1DE", "equalizer")

    readonly property string iconBatFull:           getIcon("\uE1A5", "\uE83F", "\uF240", "batFull")
    readonly property string iconBatHalf:           getIcon("\uF09E", "\uE855", "\uF242", "batHalf")
    readonly property string iconBatQuarter:        getIcon("\uF09D", "\uE852", "\uF243", "batQuarter")
    readonly property string iconBatEmpty:          getIcon("\uEBDC", "\uE850", "\uF244", "batEmpty")
    readonly property string iconBatCharge:         getIcon("\uE1A3", "\uE83E", "\uF0E7", "batCharge")
    readonly property string iconBatCharging:       iconBatCharge

    readonly property string iconSun:               getIcon("\uE518", "\uE706", "\uF185", "sun")
    readonly property string iconMoon:              getIcon("\uE51C", "\uE708", "\uF186", "moon")
    readonly property string iconBrightness:        iconSun

    readonly property string iconMusic:             getIcon("\uE405", "\uE8D6", "\uF001", "music")
    readonly property string iconPlay:              getIcon("\uE037", "\uE768", "\uF04B", "play")
    readonly property string iconPause:             getIcon("\uE034", "\uE769", "\uF04C", "pause")
    readonly property string iconNext:              getIcon("\uE044", "\uE893", "\uF051", "next")
    readonly property string iconPrev:              getIcon("\uE045", "\uE892", "\uF048", "prev")
    readonly property string iconShuffle:           getIcon("\uE043", "\uE8B1", "\uF074", "shuffle")
    readonly property string iconRepeat:            getIcon("\uE040", "\uE8EE", "\uF363", "repeat")
    readonly property string iconRepeatOne:         getIcon("\uE041", "\uE8ED", "\uF365", "repeatOne")

    readonly property string iconWallhaven:         getIcon("\uE1BC", "\uE91B", "\uF03E", "wallhaven")
    readonly property string iconWallpaper:         getIcon("\uE1BC", "\uE91B", "\uF03E", "wallpaper")
    readonly property string iconBell:              getIcon("\uE7F5", "\uEA8F", "\uF0F3", "bell")
    readonly property string iconBellOutline:       getIcon("\uE7F5", "\uEA8F", "\uF0F3", "bellOutline")
    readonly property string iconBellOff:           getIcon("\uE7F6", "\uEE79", "\uF1F6", "bellOff")

    readonly property string iconEthernet:          getIcon("\uEB2F", "\uE839", "\uF796", "ethernet")
    readonly property string iconWifi:              getIcon("\uE63E", "\uE701", "\uF1EB", "wifi")
    readonly property string iconWifiHigh:          getIcon("\uE63E", "\uE874", "\uF1EB", "wifiHigh")
    readonly property string iconWifiMed:           getIcon("\uE4D9", "\uE873", "\uF6AB", "wifiMed")
    readonly property string iconWifiLow:           getIcon("\uE4CA", "\uE872", "\uF6AA", "wifiLow")
    readonly property string iconWifiOff:           getIcon("\uE648", "\uE998", "\uF6AC", "wifiOff")
    readonly property string iconBluetooth:         getIcon("\uE1A7", "\uE702", "\uF293", "bluetooth")
    readonly property string iconBluetoothConnected:getIcon("\uE1A8", "\uE702", "\uF294", "bluetoothConnected")
    readonly property string iconBluetoothOff:      getIcon("\uE1A9", "\uE702", "\uF293", "bluetoothOff")

    readonly property string iconPower:             getIcon("\uF8C7", "\uE7E8", "\uF011", "power")
    readonly property string iconShutdown:          iconPower
    readonly property string iconLock:              getIcon("\uE899", "\uE72E", "\uF023", "lock")
    readonly property string iconLogout:            getIcon("\uE9BA", "\uF3B1", "\uF2F5", "logout")
    readonly property string iconReboot:            getIcon("\uF053", "\uE777", "\uF021", "reboot")
    readonly property string iconSuspend:           getIcon("\uF159", "\uE708", "\uF186", "suspend")
    readonly property string iconHibernate:         getIcon("\uF236", "\uE9CA", "\uF236", "hibernate")

    readonly property string iconChevronRight:      getIcon("\uE5CC", "\uE974", "\uF054", "chevronRight")
    readonly property string iconChevronLeft:       getIcon("\uE5CB", "\uE973", "\uF053", "chevronLeft")
    readonly property string iconChevronDown:       getIcon("\uE5CF", "\uE972", "\uF078", "chevronDown")
    readonly property string iconChevronUp:         getIcon("\uE5CE", "\uE971", "\uF077", "chevronUp")
    readonly property string iconFlame:             getIcon("\uEF55", "\uE945", "\uF06D", "flame")
    readonly property string iconSparkles:          getIcon("\uE65F", "\uE794", "\uE2CA", "sparkles")
    readonly property string iconRadio:             getIcon("\uE03E", "\uE93E", "\uF8D7", "radio")
    readonly property string iconSliders:           getIcon("\uE429", "\uE9E9", "\uF1DE", "sliders")
    readonly property string iconTerminal:          getIcon("\uEB8E", "\uE756", "\uF120", "terminal")
    readonly property string iconCalendar:          getIcon("\uE935", "\uE787", "\uF133", "calendar")
    readonly property string iconHistory:           getIcon("\uE8B3", "\uE81C", "\uF1DA", "history")
    readonly property string iconCopy:              getIcon("\uE14D", "\uE8C8", "\uF0C5", "copy")
    readonly property string iconExternalLink:      getIcon("\uE89E", "\uE8A7", "\uF35D", "externalLink")
    readonly property string iconSignal:            getIcon("\uE202", "\uEC3A", "\uF012", "signal")
    readonly property string iconFilter:            getIcon("\uE152", "\uE71C", "\uF0B0", "filter")
    readonly property string iconUser:              getIcon("\uF0D3", "\uE77B", "\uF007", "user")
    readonly property string iconShield:            getIcon("\uE9E0", "\uEA18", "\uF132", "shield")
    readonly property string iconExpand:            getIcon("\uE5D0", "\uE740", "\uF065", "expand")
    readonly property string iconCollapse:          getIcon("\uE94D", "\uE73F", "\uF066", "collapse")
    readonly property string iconKeyboard:          getIcon("\uE30C", "\uEA08", "\uF11C", "keyboard")

    // emotional support kaomoji faces for terminal burnout
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

    /*
    quote roulette: part relatable linux habits, part cozy check-ins,
    part classic tech quotes, and part unhinged sleep deprivation
    */
    readonly property var flavorQuotes: Object.freeze({
        "network_on": [
            "pinging 1.1.1.1 just to check if the router is mad at me",
            "\"no matter where you go, everyone's connected.\" — lain",
            "47 browser tabs open for one tiny nix error",
            "ssh session hanging because i switched wifi networks",
            "downloading node_modules (heat death of universe pending)",
            "git push --force and pray nobody notices",
            "latency low, packets clean, everything humming along",
            "copy-pasting a pipewire fix from a 2022 reddit thread",
            "\"there is no cloud, it's just someone else's computer.\"",
            "it's always dns. literally always dns",
            "bgp routes stable, unfortunately",
            "tailscale tunnel up, homelab reachable from the couch"
        ],
        "network_off": [
            "dns resolution failed: finally, inner peace",
            "rfc 1149 (ip over avian carriers) standby",
            "127.0.0.1 is the only safe place left",
            "offline mode: time to read man pages like it's 1997",
            "networkmanager gave up and honestly i respect that",
            "no packets, no masters, pure local computing",
            "airgapped paranoia protocol activated",
            "good excuse to finally clean up ~/downloads",
            "eth0 pretending to be dead so we don't have to answer emails"
        ],
        "battery_charging": [
            "shoving 65 watts into a swollen spicy pillow",
            "usb-c pd negotiating for its life",
            "plugged in: cpu governor immediately goes feral",
            "top-up in progress, grab a coffee too",
            "electrons aggressively cramming into lithium cages",
            "charging up before moving back to the couch",
            "acpi reports state: charging (and warming your lap)",
            "feeding fresh wall juice straight into the compile job"
        ],
        "battery_low": [
            "running on kernel panic adrenaline and 2% reserve",
            "where did i leave the usb-c brick...",
            "two percent left and twenty neovim buffers unsaved",
            "tlp fighting for its life right now",
            "one electron tab away from sudden poweroff",
            "dimming the screen and praying the charger is nearby",
            "upower daemon is actively drafting a will",
            "save your work right now, future you will thank you"
        ],
        "battery_full": [
            "100% charged (84% actual battery health, don't look at it)",
            "topped off and ready to wander away from the desk",
            "charge threshold holding steady, lithium cells chilling",
            "unplug me before the desk spontaneously combusts",
            "bms reports full charge. bms is probably lying",
            "full battery, clean workspace, zero excuses"
        ],
        "media_playing": [
            "decoding flac just to output it through bluetooth earbuds",
            "cava bars dancing in a terminal corner for no reason",
            "soundtrack locked in, flow state engaged",
            "pipewire graph miraculously not dropping frames today",
            "spotify eating 1.4gb of ram for a 3-minute song",
            "\"music is the shorthand of emotion.\" — leo tolstoy",
            "good headphones + late night terminal session = peak peace",
            "mpris broadcasting questionable music taste over dbus"
        ],
        "media_quiet": [
            "nothing playing except the gentle hum of case fans",
            "wireplumber suspended the sink to save 0.1 watts",
            "quiet room, quiet thoughts, clean focus",
            "waiting for the inevitable terminal bell beep",
            "letting the dac enjoy an unpaid lunch break",
            "\"silence is a source of great strength.\" — lao tzu",
            "put on a lo-fi album or enjoy the peace and quiet"
        ],
        "notes_empty": [
            "vim buffer empty. brain buffer empty",
            "todo list cleared. go touch grass or play something",
            "zero tasks pending, honestly feels illegal",
            "the markdown file contains 0 bytes. nature is healing",
            "\"simplicity is prerequisite for reliability.\" — dijkstra",
            "nothing urgent written down, take a breath",
            "no lingering chores rattling around in /tmp"
        ],
        "notifs_empty": [
            "zero `@everyone` pings ruining the vibe today",
            "inbox zero. nobody needs anything from you right now",
            "dbus is suspiciously quiet, enjoy it while it lasts",
            "no pings, no alerts, no jira tickets kicking the door down",
            "notification daemon taking a well-deserved nap",
            "peace and quiet in local airspace"
        ],
        "dnd_on": [
            "routing all dbus notifications straight to /dev/null",
            "do not disturb: deep in the dotfiles, send help later",
            "if you ping me right now i will compile webkit on your router",
            "\"leave me alone, i know what i'm doing.\" — kimi räikkönen",
            "focus mode active: world muted, compiler warm",
            "firewalling port 80 of my personal boundaries",
            "locked in. notifications can wait till tomorrow"
        ],
        "volume_muted": [
            "muted just in case auto-playing video tries something funny",
            "sending all pcm streams straight into the void",
            "muted on discord—wait let me double check the mic icon too",
            "silence dialed to eleven",
            "wireplumber ordered to execute total radio silence"
        ],
        "volume_high": [
            "permanent hearing loss speedrun (any%)",
            "pushing pipewire past 100% because the mix is quiet",
            "approaching 0dbfs, RIP to your eardrums if a notification hits",
            "speaker cones begging for humanitarian intervention",
            "vibing at slightly irresponsible decibels"
        ],
        "brightness_high": [
            "deploying tactical flashbang straight into corneas",
            "accidentally opened a white webpage at 2am",
            "pushing 100% luminance just to read dark mode text in sunlight",
            "burning the status bar permanently into the panel",
            "bright and crisp, posture check while you're looking"
        ],
        "brightness_low": [
            "cozy late-night dim mode engaged",
            "saving optical nerves from certain destruction",
            "saving 0.4 watts on backlight power like a true minimalist",
            "vampire cave ambience calibrated to perfection",
            "easy on the eyes, take a break if you're squinting"
        ],
        "idle_inhibited": [
            "caffeine active: we do not sleep until the build finishes",
            "wayland idle inhibitor holding the screen hostage",
            "staying awake so the long download doesn't drop",
            "machine pumped full of virtual espresso",
            "dpms politely told to mind its own business"
        ],
        "idle_normal": [
            "cpu governor chilling in powersave",
            "all quiet on the desktop, relax your shoulders",
            "c-states dropping deep, thermals nice and cool",
            "system breathing easy, zero runaway processes",
            "ready for a coffee break whenever you are"
        ],
        "system": [
            "spent 3 hours ricing quickshell to avoid a 10-minute task",
            "opened a terminal, typed ls, immediately closed it",
            "hyprland.lua indexing workspaces from 1 like a sociopath",
            "\"talk is cheap. show me the code.\" — linus torvalds",
            "\"an idiot admires complexity, a genius admires simplicity.\" — terry davis",
            "\"do one thing and do it well.\" — douglas mcilroy",
            "all services green, thermals cool, dotfiles looking clean",
            "forgetting the tar flags and checking --help for the 500th time",
            "six terminals open just to show off btop and fastfetch",
            "nix store eating 80gb of disk space, time to garbage collect",
            "discord screenshare showing a black window on wayland again",
            "git commit -m 'fix' followed by git commit -m 'actually fix'",
            "oom killer quietly sizing up the electron apps",
            "rewrote my config in lua and it actually worked on reload",
            "\"beware of bugs in the above code; i have only proved it correct.\" — knuth",
            "hydrated? posture okay? alright, carry on",
            "running 30 days of uptime out of pure refusal to close my tabs"
        ],
        "screenshot": [
            "grim + slurp: fastest snitch in the west",
            "copied to wl-clipboard, ready to paste into the chat",
            "saving receipts for the group chat",
            "showing off the rice on r/unixporn?",
            "another png added to ~/pictures/screenshots that you'll never delete",
            "pixels acquired, framing looks clean",
            "allocating 40mb of ram for a 12kb screenshot"
        ]
    })

    // hooked straight into the clock pulse so thoughts rotate every 60s
    function getFlavor(category: string, fallback: string): string {
        if (!cfg?.unhingedFlavor) return (fallback ?? "").toLowerCase();
        let list = flavorQuotes[category];
        if (!list || list.length === 0) return (fallback ?? "").toLowerCase();

        let totalMinutes = clock.hours * 60 + clock.minutes;
        return (list[totalMinutes % list.length] ?? fallback ?? "").toLowerCase();
    }
}
