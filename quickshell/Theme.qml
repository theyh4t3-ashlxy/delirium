// Theme.qml — centralized theme singleton delegating heavy logic & tables to quickshell/theme/*.mjs
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

import "theme/styleEngine.mjs" as StyleEngine
import "theme/motion.mjs" as Motion
import "theme/icons.mjs" as Icons
import "theme/quotes.mjs" as Quotes
import "theme/confFormat.mjs" as ConfFmt

Singleton {
    id: root
    readonly property var cfg: (typeof Settings !== "undefined" ? Settings : null)

    property var paletteColors: ({})

    function parsePaletteCss(raw: string) {
        if (!raw || raw.trim() === "") return;
        let next = {};
        const re = /--([a-z0-9-]+)\s*:\s*(#[0-9a-fA-F]{3,8})\b/g;
        let m;
        while ((m = re.exec(raw)) !== null) {
            next[m[1]] = m[2];
        }
        if (Object.keys(next).length > 0) {
            root.paletteColors = next;
        }
    }

    function palColor(cssName: string, fallback: string): color {
        return root.paletteColors[cssName] ?? fallback;
    }

    Timer {
        id: paletteRetryTimer
        interval: 45
        repeat: false
        onTriggered: paletteWatcher.reload()
    }

    // watching palette.css like a hawk so we don't have to restart the whole shell
    property var paletteWatcher: FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || ((Quickshell.env("HOME") || "") + "/.config")) + "/quickshell/palette.css"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: {
            let raw = text();
            if (!raw || raw.trim() === "") {
                paletteRetryTimer.restart();
            } else {
                root.parsePaletteCss(raw);
            }
        }
        onFileChanged: reload()
    }

    Component.onCompleted: {
        parsePaletteCss(paletteWatcher.text());
        if (!hyprSplashProc.running) hyprSplashProc.running = true;
        fontInspectTimer.restart();
    }

    property string hyprSplash: "Read the wiki."

    property Process hyprSplashProc: Process {
        command: ["hyprctl", "splash"]
        stdout: StdioCollector {
            onStreamFinished: {
                let raw = (text || "").trim();
                if (raw !== "" && !raw.toLowerCase().startsWith("error") && !raw.toLowerCase().startsWith("unknown")) {
                    root.hyprSplash = raw;
                }
            }
        }
    }

    function refreshHyprSplash() {
        if (!hyprSplashProc.running) hyprSplashProc.running = true;
    }

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

    readonly property real adaptiveAlphaBoost:   (cfg?.adaptiveTransparency ?? true) ? (wallpaperVibrancy * 0.08) : 0.0
    readonly property real adaptiveSurfaceAlpha: Math.min(1.0, surfaceOpacity + adaptiveAlphaBoost)

    // matugen hex tokens
    readonly property color matugenPrimary:            palColor("primary", "#0062a1")
    readonly property color primary:                   matugenPrimary
    readonly property color accent:                    primary
    readonly property color on_primary:                palColor("on-primary", "#ffffff")
    readonly property color primary_container:         palColor("primary-container", "#d0e4ff")
    readonly property color on_primary_container:      palColor("on-primary-container", "#001d35")

    readonly property color secondary:                 palColor("secondary", "#515e7d")
    readonly property color on_secondary:              palColor("on-secondary", "#ffffff")
    readonly property color secondary_container:       palColor("secondary-container", "#d9e2ff")
    readonly property color on_secondary_container:    palColor("on-secondary-container", "#0c1b36")

    readonly property color tertiary:                  palColor("tertiary", "#575a8b")
    readonly property color on_tertiary:               palColor("on-tertiary", "#ffffff")
    readonly property color tertiary_container:        palColor("tertiary-container", "#e0e0ff")
    readonly property color on_tertiary_container:     palColor("on-tertiary-container", "#131644")

    readonly property color error:                     palColor("error", "#ba1a1a")
    readonly property color on_error:                  palColor("on-error", "#ffffff")
    readonly property color error_container:           palColor("error-container", "#ffdad6")
    readonly property color on_error_container:        palColor("on-error-container", "#410002")

    readonly property color matugenBg:                 palColor("background", "#f8f9ff")
    readonly property color background:                matugenBg
    readonly property color on_background:             palColor("on-background", "#161c24")

    readonly property color matugenSurface:            palColor("surface", "#f8f9ff")
    readonly property color surface:                   matugenSurface
    readonly property color matugenOnSurface:          palColor("on-surface", "#161c24")
    readonly property color on_surface:                matugenOnSurface
    readonly property color surface_variant:           palColor("surface-variant", "#dde3ee")
    readonly property color matugenOnSurfaceVariant:   palColor("on-surface-variant", "#414750")
    readonly property color on_surface_variant:        matugenOnSurfaceVariant
    readonly property color textPrimary:               on_surface
    readonly property color textSecondary:             on_surface_variant

    readonly property color surface_container_lowest:  palColor("surface-container-lowest", "#ffffff")
    readonly property color surface_container_low:     palColor("surface-container-low", "#eef4ff")
    readonly property color surface_container:         palColor("surface-container", "#e8eefa")
    readonly property color surface_container_high:    palColor("surface-container-high", "#e2e8f4")
    readonly property color surface_container_highest: palColor("surface-container-highest", "#dde3ee")

    readonly property color surface_dim:               palColor("surface-dim", "#d4dae5")
    readonly property color surface_bright:            palColor("surface-bright", "#f8f9ff")

    readonly property color matugenOutline:            palColor("outline", "#717881")
    readonly property color outline:                   matugenOutline
    readonly property color outline_variant:           palColor("outline-variant", "#c1c7d2")

    readonly property color shadow:                    palColor("shadow", "#000000")
    readonly property color scrim:                     palColor("scrim", "#000000")

    readonly property color inverse_surface:           palColor("inverse-surface", "#2a3139")
    readonly property color inverse_on_surface:        palColor("inverse-on-surface", "#ebf1fc")
    readonly property color inverse_primary:           palColor("inverse-primary", "#9ccaff")
    readonly property color source_color:              palColor("source-color", "#0e9bfa")

    // automatic light mode detection via surface luminance or explicit Settings flag
    readonly property real surfaceLuminance: (0.2126 * surface.r) + (0.7152 * surface.g) + (0.0722 * surface.b)
    readonly property bool isLightMode: Boolean(cfg?.lightMode || cfg?.isLight || cfg?.themeMode === "light" || surfaceLuminance > 0.5)

    // --- color & state helpers (delegated to theme/styleEngine.mjs) ---
    function alpha(c: color, a: real): color {
        return StyleEngine.alpha(c, a, (r, g, b, al) => Qt.rgba(r, g, b, al));
    }

    function blend(c1: color, c2: color, t: real): color {
        return StyleEngine.blend(c1, c2, t, (r, g, b, al) => Qt.rgba(r, g, b, al));
    }

    function stateHover(baseColor: color, contentColor: color): color {
        return StyleEngine.stateColor(baseColor, contentColor, 0.08, on_surface, (r, g, b, al) => Qt.rgba(r, g, b, al));
    }
    function stateFocus(baseColor: color, contentColor: color): color {
        return StyleEngine.stateColor(baseColor, contentColor, 0.10, on_surface, (r, g, b, al) => Qt.rgba(r, g, b, al));
    }
    function statePress(baseColor: color, contentColor: color): color {
        return StyleEngine.stateColor(baseColor, contentColor, 0.12, on_surface, (r, g, b, al) => Qt.rgba(r, g, b, al));
    }
    function stateDrag(baseColor: color, contentColor: color): color {
        return StyleEngine.stateColor(baseColor, contentColor, 0.16, on_surface, (r, g, b, al) => Qt.rgba(r, g, b, al));
    }

    function getBatteryColor(pct: int, isCharging: bool): color {
        return StyleEngine.getBatteryColor(pct, isCharging, {
            primary: primary,
            error: error,
            warn: warn,
            on_surface: on_surface
        });
    }

    readonly property color primary_overlay:        alpha(primary, 0.18)
    readonly property color secondary_overlay:      alpha(secondary, 0.18)
    readonly property color tertiary_overlay:       alpha(tertiary, 0.18)
    readonly property color error_overlay:          alpha(error, 0.22)
    readonly property color warn:                   tertiary
    readonly property color warn_container:         tertiary_container
    readonly property color on_warn_container:      on_tertiary_container
    readonly property color warn_overlay:           tertiary_overlay

    readonly property color on_surface_disabled:    alpha(on_surface, 0.38)
    readonly property color outline_disabled:       alpha(outline, 0.12)
    readonly property color fontStrokeColor:        isLightMode ? "#ffffff" : "#000000"
    readonly property color textStroke:             isLightMode ? "#ffffff" : "#000000"
    readonly property color textShadow:             isLightMode ? alpha(shadow, 0.25) : "#000000"

    // --- formatters & shared utilities (delegated to theme/quotes.mjs & theme/icons.mjs) ---
    function formatBytes(bytes: real): string {
        return Quotes.formatBytes(bytes);
    }

    function formatUptime(sec: int): string {
        return Quotes.formatUptime(sec);
    }

    function formatTime(seconds: real, padMinutes: var): string {
        return Quotes.formatTime(seconds, Boolean(padMinutes));
    }

    function fixCoverUrl(url: var): string {
        return Quotes.fixCoverUrl(url);
    }

    function resolveAppIcon(winClass: string): string {
        return Icons.resolveAppIcon(
            winClass,
            typeof DesktopEntries !== "undefined" ? DesktopEntries?.applications?.values : null,
            {
                iconPath: (n) => Quickshell.iconPath(n),
                hasThemeIcon: (n) => Quickshell?.hasThemeIcon ? Quickshell.hasThemeIcon(n) : false
            }
        );
    }

    // --- typography & variable font axes ---
    readonly property string fontSans:              cfg?.fontSans ?? cfg?.fontFamily ?? "Noto Sans"
    readonly property string fontMono:              cfg?.fontMono ?? "JetBrainsMono Nerd Font"
    readonly property string fontDisplay:           (cfg?.fontDisplay && cfg.fontDisplay.trim() !== "") ? cfg.fontDisplay.trim() : fontSans

    readonly property var    fontFamiliesVibe:      [fontSans, "Noto Sans", "Noto Sans CJK JP"]
    readonly property string fontVibe:              fontSans
    readonly property string fontFamily:            fontSans

    readonly property string fontsScriptPath: decodeURIComponent(Qt.resolvedUrl("scripts/fonts.py").toString().replace(/^file:\/\//, ""))

    readonly property var _fallbackFontAxes: ({
        "google sans flex":  { opsz: { min: 1, def: 18, max: 144 }, wdth: { min: 25, def: 100, max: 151 }, wght: { min: 1, def: 400, max: 1000 }, ROND: { min: 0, def: 0, max: 100 }, slnt: { min: -10, def: 0, max: 0 } },
        "segoe ui variable": { wght: { min: 300, def: 400, max: 700 }, opsz: { min: 5, def: 10.5, max: 36 } },
        "cascadia mono":     { wght: { min: 200, def: 400, max: 700 } },
        "noto sans":         { wght: { min: 100, def: 400, max: 900 }, wdth: { min: 62.5, def: 100, max: 100 } },
        "noto sans mono":    { wght: { min: 100, def: 400, max: 900 }, wdth: { min: 62.5, def: 100, max: 100 } },
        "bahnschrift":       { wght: { min: 300, def: 400, max: 700 }, wdth: { min: 75, def: 100, max: 100 } },
        "adwaita sans":      { opsz: { min: 14, def: 14, max: 32 }, wght: { min: 100, def: 400, max: 900 } }
    })

    property var _inspectedAxesByFamily: ({})

    function parseAxesSpec(specStr) {
        let out = {};
        if (!specStr || String(specStr).trim() === "") return out;
        let parts = String(specStr).split(";");
        for (let i = 0; i < parts.length; i++) {
            let p = parts[i].trim().split(":");
            if (p.length >= 4) {
                let tag = p[0];
                let mn = parseFloat(p[1]), df = parseFloat(p[2]), mx = parseFloat(p[3]);
                if (tag && !isNaN(mn) && !isNaN(df) && !isNaN(mx)) {
                    out[tag] = { min: mn, def: df, max: mx };
                }
            }
        }
        return out;
    }

    function axesSpecForFamily(familyName) {
        let key = String(familyName || "").trim().toLowerCase();
        if (!key) return ({});
        if (_inspectedAxesByFamily[key] !== undefined) return _inspectedAxesByFamily[key];
        return _fallbackFontAxes[key] ?? ({});
    }

    property Timer fontInspectTimer: Timer {
        interval: 40
        repeat: false
        onTriggered: {
            if (fontInspectProc.running) fontInspectProc.running = false;
            fontInspectProc.command = ["python3", root.fontsScriptPath, "inspect", root.fontSans, root.fontDisplay, root.fontMono];
            fontInspectProc.running = true;
        }
    }

    property Process fontInspectProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                let recs = ConfFmt.parseRecords(text || "", "inspect");
                if (!recs || recs.length === 0) return;
                let next = Object.assign({}, root._inspectedAxesByFamily);
                for (let i = 0; i < recs.length; i++) {
                    let r = recs[i];
                    if (r && r.family) {
                        next[String(r.family).trim().toLowerCase()] = root.parseAxesSpec(r.axes || "");
                    }
                }
                root._inspectedAxesByFamily = next;
            }
        }
    }

    onFontSansChanged: fontInspectTimer.restart()
    onFontDisplayChanged: fontInspectTimer.restart()
    onFontMonoChanged: fontInspectTimer.restart()

    readonly property var    sansVarAxes:           axesSpecForFamily(fontSans)
    readonly property var    displayVarAxes:        axesSpecForFamily(fontDisplay)
    readonly property var    monoVarAxes:           axesSpecForFamily(fontMono)

    readonly property int    _sansWghtMin:          sansVarAxes.wght ? Math.max(100, Math.round(sansVarAxes.wght.min)) : 100
    readonly property int    _sansWghtMax:          sansVarAxes.wght ? Math.min(950, Math.round(sansVarAxes.wght.max)) : 900
    readonly property int    _monoWghtMin:          monoVarAxes.wght ? Math.max(100, Math.round(monoVarAxes.wght.min)) : 100
    readonly property int    _monoWghtMax:          monoVarAxes.wght ? Math.min(950, Math.round(monoVarAxes.wght.max)) : 900

    function _clampSansWeight(w) {
        return Math.max(_sansWghtMin, Math.min(_sansWghtMax, Math.round(w)));
    }
    function _clampMonoWeight(w) {
        return Math.max(_monoWghtMin, Math.min(_monoWghtMax, Math.round(w)));
    }

    readonly property int    fontWeightBase:        cfg?.fontWeightValue ?? 400
    readonly property int    _sansWeightDelta:      fontWeightBase - 400
    readonly property int    fontWeightLight:       _clampSansWeight(300 + _sansWeightDelta)
    readonly property int    fontWeightRegular:     _clampSansWeight(400 + _sansWeightDelta)
    readonly property int    fontWeightMedium:      _clampSansWeight(500 + _sansWeightDelta)
    readonly property int    fontWeightDemiBold:    _clampSansWeight(600 + _sansWeightDelta)
    readonly property int    fontWeightBold:        _clampSansWeight(700 + _sansWeightDelta)

    readonly property int    fontMonoWeightBase:    cfg?.fontMonoWeight ?? 400
    readonly property int    _monoWeightDelta:      fontMonoWeightBase - 400
    readonly property int    monoWeightRegular:     _clampMonoWeight(400 + _monoWeightDelta)
    readonly property int    monoWeightMedium:      _clampMonoWeight(500 + _monoWeightDelta)
    readonly property int    monoWeightBold:        _clampMonoWeight(700 + _monoWeightDelta)

    function _buildAxes(spec, pxSize, isDisplay, isMono) {
        if (!spec || Object.keys(spec).length === 0) return ({});
        let axes = {};
        if (spec.opsz !== undefined) {
            let rawOpsz = (cfg?.fontOpticalAuto ?? true)
                ? (Math.max(5, Number(pxSize) || 11) * (isDisplay ? 1.25 : 1.0))
                : (cfg?.fontOpticalSize ?? spec.opsz.def);
            axes.opsz = Math.max(spec.opsz.min, Math.min(spec.opsz.max, Math.round(rawOpsz * 10) / 10));
        }
        if (spec.wdth !== undefined) {
            let rawW = isMono ? (cfg?.fontMonoWidth ?? 100.0) : (cfg?.fontWidth ?? 100.0);
            axes.wdth = Math.max(spec.wdth.min, Math.min(spec.wdth.max, Math.round(rawW * 10) / 10));
        }
        if (!isMono && spec.ROND !== undefined) {
            let rawR = cfg?.fontRoundness ?? 0.0;
            axes.ROND = Math.max(spec.ROND.min, Math.min(spec.ROND.max, Math.round(rawR)));
        }
        if (!isMono && spec.slnt !== undefined) {
            let rawS = cfg?.fontSlant ?? 0.0;
            axes.slnt = Math.max(spec.slnt.min, Math.min(spec.slnt.max, Math.round(rawS * 10) / 10));
        }
        return axes;
    }

    function textAxesFor(pxSize, isDisplay): var {
        let spec = isDisplay ? displayVarAxes : sansVarAxes;
        return _buildAxes(spec, pxSize, Boolean(isDisplay), false);
    }

    function monoAxesFor(pxSize): var {
        return _buildAxes(monoVarAxes, pxSize, false, true);
    }

    readonly property var    sansAxes:              textAxesFor(fontSizeSm, false)
    readonly property var    titleAxes:             textAxesFor(fontSizeLg, true)
    readonly property var    displayAxes:           textAxesFor(fontSizeTitle, true)
    readonly property var    monoAxes:              monoAxesFor(fontSizeSm)

    readonly property real   fontScale:             cfg?.fontScale ?? 1.0
    readonly property int    fontSizeXs:            Math.round(9 * fontScale)
    readonly property int    fontSizeSm:            Math.round(11 * fontScale)
    readonly property int    fontSizeMd:            Math.round(13 * fontScale)
    readonly property int    fontSizeLg:            Math.round(15 * fontScale)
    readonly property int    fontSizeXl:            Math.round(18 * fontScale)
    readonly property int    fontSizeTitle:         Math.round(22 * fontScale)

    function getFontWeight(weight: string): int {
        return Quotes.getFontWeight(weight, Font);
    }

    readonly property int    widgetRadius:          cfg?.widgetRadius ?? 6
    readonly property int    popupRadius:           cfg?.popupRadius ?? 8
    readonly property int    barWidgetRadius:       widgetRadius >= 999 ? radiusPill : Math.max(0, widgetRadius)
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
    readonly property string barStyle:              StyleEngine.normalizeBarStyle(cfg?.barStyle ?? "glass")
    readonly property int    scoopRadius:           cfg?.scoopRadius ?? 16
    readonly property bool   isSolid:               barStyle === "solid"
    readonly property bool   isGlass:               barStyle === "glass" || barStyle === "frosted"
    readonly property bool   isFrosted:             barStyle === "frosted"
    readonly property bool   isOutlined:            barStyle === "outlined"
    readonly property bool   isTinted:              barStyle === "tinted"
    readonly property bool   isOled:                barStyle === "oled"
    readonly property bool   isIslands:             barStyle === "islands"
    readonly property bool   isTranslucent:         barStyle === "translucent"
    readonly property bool   isMonochrome:          barStyle === "monochrome"
    readonly property bool   isTextIconSet:         iconSet === "kaomoji" || iconSet === "text"

    readonly property string barWidgetChrome:       cfg?.barWidgetChrome ?? "grouped"
    readonly property string barGrouping:           cfg?.barGrouping ?? "clusters"
    readonly property string barDividers:           cfg?.barDividers ?? "line"
    readonly property bool   isFloatingOrIsland:    Boolean(cfg?.barFloating ?? false) || isIslands
    readonly property bool   isBarGroupedSurface:   (barGrouping === "clusters" || barGrouping === "zones") || (isFloatingOrIsland && Boolean(cfg?.barIslandMode ?? true))
    readonly property bool   isBarUnderline:        barWidgetChrome === "underline"
    readonly property bool   isBarPills:            barWidgetChrome === "pills" || (barWidgetChrome === "grouped" && !isBarGroupedSurface && !isFloatingOrIsland)
    readonly property color  barPillBg:             isBarPills ? pillBg : "transparent"
    readonly property color  barPillHover:          (barWidgetChrome === "ghost" || isBarUnderline) ? alpha(on_surface, isLightMode ? 0.08 : 0.10) : pillHover
    readonly property color  barPillBorder:         isBarPills ? pillBorder : "transparent"
    readonly property int    barPillBorderWidth:    (barPillBorder === "transparent" || barPillBorder.a === 0) ? 0 : 1
    readonly property color  barDividerColor:       alpha(outline_variant, isLightMode ? 0.48 : 0.34)
    readonly property color  barClusterBg:          isFloatingOrIsland ? cardBg : alpha(widgetBg, isLightMode ? 0.72 : 0.62)
    readonly property color  barClusterBorder:      isOutlined ? primary : (isGlass ? glassHighlight : cardBorder)

    readonly property var _styleCtx: ({
        isLightMode: root.isLightMode,
        cfg: root.cfg,
        adaptiveAlphaBoost: root.adaptiveAlphaBoost,
        primary: root.primary,
        primary_container: root.primary_container,
        on_surface: root.on_surface,
        outline: root.outline,
        outline_variant: root.outline_variant,
        surface_container: root.surface_container,
        surface_container_low: root.surface_container_low,
        surface_container_lowest: root.surface_container_lowest,
        surface_container_high: root.surface_container_high,
        surface_container_highest: root.surface_container_highest,
        rgba: (r, g, b, al) => Qt.rgba(r, g, b, al)
    })

    function getStyleColor(role: string, bs: string): color {
        return StyleEngine.getStyleColor(role, bs, root._styleCtx);
    }

    readonly property color barBg:            alpha(getStyleColor("barBg", barStyle), barOpacity)
    readonly property color barBorderColor:   getStyleColor("barBorderColor", barStyle)
    readonly property color cornerFill: {
        let cm = StyleEngine.normalizeCornerColorMode(cfg?.cornerColorMode ?? "bar");
        if (cm === "accent") return primary;
        if (cm === "oled") return isLightMode ? "#ffffff" : "#000000";
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

    // --- popup & workspace dimensions ---
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

    // --- motion & easing (delegated to theme/motion.mjs) ---
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

    readonly property var    hyprlandBezier:            Motion.BEZIERS.hyprland
    readonly property var    hyprlandExitBezier:        Motion.BEZIERS.hyprlandExit
    readonly property var    smoothBezier:              Motion.BEZIERS.smooth
    readonly property var    snappyBezier:              Motion.BEZIERS.snappy
    readonly property var    expressiveBezier:          Motion.BEZIERS.expressive
    readonly property var    standardBezier:            Motion.BEZIERS.standard
    readonly property var    motionExpressiveFast:      Motion.BEZIERS.expressiveFast
    readonly property var    motionExpressiveDefault:   Motion.BEZIERS.expressiveDefault
    readonly property var    motionExpressiveSlow:      Motion.BEZIERS.expressiveSlow
    readonly property var    motionEmphasized:          Motion.BEZIERS.emphasized
    readonly property var    motionEmphasizedDecel:     Motion.BEZIERS.emphasizedDecel
    readonly property var    motionEmphasizedAccel:     Motion.BEZIERS.emphasizedAccel

    function getBezierPoints(curve: var): var {
        return Motion.getBezierPoints(curve);
    }

    readonly property var    animBezierPoints:      getBezierPoints(animCurve)
    readonly property real   animOvershoot:         (animCurve === "hyprland" || cfg?.animSpeed === "hyprland") ? 1.05 : ((animCurve === "expressive") ? 1.15 : 1.70158)

    function getEasing(curve: string, type: string): int {
        return Motion.getEasing(curve, type, Easing);
    }

    readonly property int    animEasing:            getEasing(animCurve, animEasingType)
    readonly property int    animExpressiveEasing:  animCurve === "back" ? getEasing("back", animEasingType) : Easing.OutBack
    readonly property int    animEasingEntrance:    (animCurve === "expressive" || animCurve === "hyprland" || animCurve === "back" || cfg?.animSpeed === "hyprland") ? Easing.OutBack : (animCurve === "snappy" ? Easing.OutQuad : Easing.OutCubic)
    readonly property int    animEasingExit:        (animCurve === "snappy") ? Easing.InQuad : Easing.InCubic
    readonly property int    animColorEasing:       Easing.OutQuad

    // --- icon fonts & glyph lookups (delegated to theme/icons.mjs) ---
    readonly property string userFontDir: (Quickshell.env("XDG_DATA_HOME") || ((Quickshell.env("HOME") || "") + "/.local/share")) + "/fonts/"

    FontLoader { id: loaderMatRounded;  source: "file://" + root.userFontDir + "MaterialSymbolsRounded.ttf" }
    FontLoader { id: loaderMatOutlined; source: "file://" + root.userFontDir + "MaterialSymbolsOutlined.ttf" }
    FontLoader { id: loaderMatSharp;    source: "file://" + root.userFontDir + "MaterialSymbolsSharp.ttf" }
    FontLoader { id: loaderSegoe;       source: "file://" + root.userFontDir + "SegoeIcons.ttf" }

    readonly property string iconSet: {
        let s = cfg?.iconSet ?? "material";
        return (s === "nerd" || s === "awesome") ? "material" : s;
    }
    readonly property bool   isMaterialIconSet:     !isTextIconSet && iconSet !== "windows"
    readonly property bool   materialFilled:        Boolean(cfg?.materialFilled ?? false)
    readonly property var    iconAxes:              isMaterialIconSet ? ({ "FILL": materialFilled ? 1 : 0 }) : ({})

    readonly property string fontMaterialRounded:  (loaderMatRounded.status === FontLoader.Ready && loaderMatRounded.name) ? loaderMatRounded.name : "Material Symbols Rounded"
    readonly property string fontMaterialOutlined: (loaderMatOutlined.status === FontLoader.Ready && loaderMatOutlined.name) ? loaderMatOutlined.name : "Material Symbols Outlined"
    readonly property string fontMaterialSharp:    (loaderMatSharp.status === FontLoader.Ready && loaderMatSharp.name) ? loaderMatSharp.name : "Material Symbols Sharp"
    readonly property string fontSegoe:            (loaderSegoe.status === FontLoader.Ready && loaderSegoe.name) ? loaderSegoe.name : (cfg?.fontWindows ?? "Segoe Fluent Icons")

    readonly property string fontIcon: {
        if (iconSet === "kaomoji" || iconSet === "text") return fontFamily;
        if (iconSet === "windows") return fontSegoe;
        if (iconSet === "material-outlined" || iconSet === "outlined" || cfg?.fontMaterial === "Material Symbols Outlined") return fontMaterialOutlined;
        if (iconSet === "material-sharp" || iconSet === "sharp" || cfg?.fontMaterial === "Material Symbols Sharp") return fontMaterialSharp;
        if (iconSet === "material-rounded" || iconSet === "rounded" || cfg?.fontMaterial === "Material Symbols Rounded") return fontMaterialRounded;
        return fontMaterialRounded;
    }

    readonly property var kaomojiMap:     Icons.KAOMOJI_MAP
    readonly property var textMap:        Icons.TEXT_MAP

    function getIcon(mat: string, win: string, key: var, kao: var, txt: var): string {
        return Icons.getIcon(iconSet, mat, win, key, kao, txt);
    }

    function getBatteryIcon(pct: int, isCharging: bool, isSaver: bool, isVertical: bool): string {
        return Icons.getBatteryIcon(iconSet, pct, isCharging, isSaver, isVertical);
    }

    function getVolumeIcon(volRatio: real, isMuted: bool): string {
        return Icons.getVolumeIcon(iconSet, volRatio, isMuted, iconVolMute);
    }

    function getBrightnessIcon(pct: int): string {
        return Icons.getBrightnessIcon(iconSet, pct, iconMoon, iconBrightness);
    }

    function getWifiIcon(signalPct: int, isConnected: bool, isEthernet: bool): string {
        return Icons.getWifiIcon(iconSet, signalPct, isConnected, isEthernet, iconEthernet, iconWifiOff);
    }

    readonly property string iconDistro:            getIcon("\uEB3B", "\uE71D", "nixos")
    readonly property string iconNix:               getIcon("\uEB3B", "\uE71D", "nix")
    readonly property string iconArch:              getIcon("\uF720", "\uE71D", "arch")
    readonly property string iconAppLauncher:       getIcon("\uE5C3", "\uE71D", "appLauncher")
    readonly property string iconWorkspaces:        getIcon("\uE1A0", "\uE7C4", "workspaces")
    readonly property string iconSearch:            getIcon("\uE8B6", "\uE721", "search")
    readonly property string iconClose:             getIcon("\uE5CD", "\uE711", "close")
    readonly property string iconCheck:             getIcon("\uE668", "\uE73E", "check")
    readonly property string iconCheckCircle:       getIcon("\uF0BE", "\uF13E", "checkCircle")
    readonly property string iconSettings:          getIcon("\uE8B8", "\uE713", "settings")
    readonly property string iconGear:              iconSettings
    readonly property string iconSave:              getIcon("\uE161", "\uE74E", "save")
    readonly property string iconRefresh:           getIcon("\uE5D5", "\uE72C", "refresh")
    readonly property string iconTrash:             getIcon("\uE92E", "\uE74D", "trash")
    readonly property string iconClipboard:         getIcon("\uE14F", "\uF0E3", "clipboard")
    readonly property string iconTray:              getIcon("\uE156", "\uE971", "tray")
    readonly property string iconGrid:              getIcon("\uE9B0", "\uF0E2", "grid")
    readonly property string iconNote:              getIcon("\uE745", "\uE70F", "note")
    readonly property string iconEdit:              getIcon("\uE3C9", "\uE70F", "edit")
    readonly property string iconCoffee:            getIcon("\uEFEF", "\uEC32", "coffee")
    readonly property string iconClock:             getIcon("\uEFD6", "\uE823", "clock")
    readonly property string iconCpu:               getIcon("\uE322", "\uEEA1", "cpu")
    readonly property string iconMem:               getIcon("\uF7A3", "\uEEA0", "mem")
    readonly property string iconThermo:            getIcon("\uE846", "\uE9CA", "thermo")
    readonly property string iconEye:               getIcon("\uE8F4", "\uE7B3", "eye")
    readonly property string iconEyeOff:            getIcon("\uE8F5", "\uED1A", "eyeOff")
    readonly property string iconHeart:             getIcon("\uE87E", "\uEB51", "heart")
    readonly property string iconPin:               getIcon("\uE6AA", "\uE718", "pin")
    readonly property string iconDownload:          getIcon("\uF090", "\uE896", "download")
    readonly property string iconFolder:            getIcon("\uE2C7", "\uE838", "folder")
    readonly property string iconGlobe:             getIcon("\uE64C", "\uE774", "globe")
    readonly property string iconCamera:            getIcon("\uE3AF", "\uE722", "camera")
    readonly property string iconCrop:              getIcon("\uE3BE", "\uE7A8", "crop")
    readonly property string iconScreenshot:        getIcon("\uF7D2", "\uE722", "screenshot")

    readonly property string iconVolMute:           getIcon("\uE04F", "\uE74F", "volMute")
    readonly property string iconVolLow:            getIcon("\uE04E", "\uE993", "volLow")
    readonly property string iconVolMid:            getIcon("\uE04D", "\uE994", "volMid")
    readonly property string iconVolHigh:           getIcon("\uE050", "\uE995", "volHigh")
    readonly property string iconMic:               getIcon("\uE31D", "\uE720", "mic")
    readonly property string iconMicMute:           getIcon("\uE02B", "\uF781", "micMute")
    readonly property string iconPalette:           getIcon("\uE40A", "\uE790", "palette")
    readonly property string iconHeadphones:        getIcon("\uF01F", "\uE7F6", "headphones")
    readonly property string iconEqualizer:         getIcon("\uE01D", "\uE9E9", "equalizer")

    readonly property string iconBatFull:           getIcon("\uE1A5", "\uE83F", "batFull")
    readonly property string iconBatHalf:           getIcon("\uF09E", "\uE855", "batHalf")
    readonly property string iconBatQuarter:        getIcon("\uF09D", "\uE852", "batQuarter")
    readonly property string iconBatEmpty:          getIcon("\uEBDC", "\uE850", "batEmpty")
    readonly property string iconBatCharge:         getIcon("\uE1A3", "\uE83E", "batCharge")
    readonly property string iconBatCharging:       iconBatCharge

    readonly property string iconSun:               getIcon("\uE518", "\uE706", "sun")
    readonly property string iconMoon:              getIcon("\uE51C", "\uE708", "moon")
    readonly property string iconBrightness:        iconSun

    readonly property string iconMusic:             getIcon("\uE405", "\uE8D6", "music")
    readonly property string iconPlay:              getIcon("\uE037", "\uE768", "play")
    readonly property string iconPause:             getIcon("\uE034", "\uE769", "pause")
    readonly property string iconNext:              getIcon("\uE044", "\uE893", "next")
    readonly property string iconPrev:              getIcon("\uE045", "\uE892", "prev")
    readonly property string iconShuffle:           getIcon("\uE043", "\uE8B1", "shuffle")
    readonly property string iconRepeat:            getIcon("\uE040", "\uE8EE", "repeat")
    readonly property string iconRepeatOne:         getIcon("\uE041", "\uE8ED", "repeatOne")

    readonly property string iconWallhaven:         getIcon("\uE1BC", "\uE91B", "wallhaven")
    readonly property string iconWallpaper:         getIcon("\uE1BC", "\uE91B", "wallpaper")
    readonly property string iconBell:              getIcon("\uE7F5", "\uEA8F", "bell")
    readonly property string iconBellOutline:       getIcon("\uE7F5", "\uEA8F", "bellOutline")
    readonly property string iconBellOff:           getIcon("\uE7F6", "\uEE79", "bellOff")

    readonly property string iconEthernet:          getIcon("\uEB2F", "\uE839", "ethernet")
    readonly property string iconWifi:              getIcon("\uE63E", "\uE701", "wifi")
    readonly property string iconWifiHigh:          getIcon("\uE63E", "\uE874", "wifiHigh")
    readonly property string iconWifiMed:           getIcon("\uE4D9", "\uE873", "wifiMed")
    readonly property string iconWifiLow:           getIcon("\uE4CA", "\uE872", "wifiLow")
    readonly property string iconWifiOff:           getIcon("\uE648", "\uE998", "wifiOff")
    readonly property string iconBluetooth:         getIcon("\uE1A7", "\uE702", "bluetooth")
    readonly property string iconBluetoothConnected:getIcon("\uE1A8", "\uE702", "bluetoothConnected")
    readonly property string iconBluetoothOff:      getIcon("\uE1A9", "\uE702", "bluetoothOff")

    readonly property string iconPower:             getIcon("\uF8C7", "\uE7E8", "power")
    readonly property string iconShutdown:          iconPower
    readonly property string iconLock:              getIcon("\uE899", "\uE72E", "lock")
    readonly property string iconLogout:            getIcon("\uE9BA", "\uF3B1", "logout")
    readonly property string iconReboot:            getIcon("\uF053", "\uE777", "reboot")
    readonly property string iconSuspend:           getIcon("\uF159", "\uE708", "suspend")
    readonly property string iconHibernate:         getIcon("\uE046", "\uE9CA", "hibernate")

    readonly property string iconChevronRight:      getIcon("\uE5CC", "\uE974", "chevronRight")
    readonly property string iconChevronLeft:       getIcon("\uE5CB", "\uE973", "chevronLeft")
    readonly property string iconChevronDown:       getIcon("\uE5CF", "\uE972", "chevronDown")
    readonly property string iconChevronUp:         getIcon("\uE5CE", "\uE971", "chevronUp")
    readonly property string iconFlame:             getIcon("\uEF55", "\uE945", "flame")
    readonly property string iconSparkles:          getIcon("\uE65F", "\uE794", "sparkles")
    readonly property string iconRadio:             getIcon("\uE03E", "\uE93E", "radio")
    readonly property string iconSliders:           getIcon("\uE429", "\uE9E9", "sliders")
    readonly property string iconTerminal:          getIcon("\uEB8E", "\uE756", "terminal")
    readonly property string iconCalendar:          getIcon("\uE935", "\uE787", "calendar")
    readonly property string iconHistory:           getIcon("\uE8B3", "\uE81C", "history")
    readonly property string iconCopy:              getIcon("\uE14D", "\uE8C8", "copy")
    readonly property string iconExternalLink:      getIcon("\uE89E", "\uE8A7", "externalLink")
    readonly property string iconSignal:            getIcon("\uE202", "\uEC3A", "signal")
    readonly property string iconFilter:            getIcon("\uE152", "\uE71C", "filter")
    readonly property string iconUser:              getIcon("\uF0D3", "\uE77B", "user")
    readonly property string iconShield:            getIcon("\uE9E0", "\uEA18", "shield")
    readonly property string iconExpand:            getIcon("\uE5D0", "\uE740", "expand")
    readonly property string iconCollapse:          getIcon("\uE94D", "\uE73F", "collapse")
    readonly property string iconKeyboard:          getIcon("\uE312", "\uEA08", "keyboard")
    readonly property string iconUndo:              getIcon("\uE166", "\uE7A7", "undo")
    readonly property string iconRedo:              getIcon("\uE15A", "\uE7A6", "redo")
    readonly property string iconBrush:             getIcon("\uE746", "\uE70F", "brush")
    readonly property string iconHighlight:         getIcon("\uF82B", "\uE76C", "highlight")
    readonly property string iconArrow:             getIcon("\uF8CE", "\uE72A", "arrow")
    readonly property string iconRect:              getIcon("\uE3C6", "\uE739", "rect")
    readonly property string iconCircle:            getIcon("\uEF4A", "\uEA3A", "circle")
    readonly property string iconBlur:              getIcon("\uE3A5", "\uE81E", "blur")
    readonly property string iconStep:              getIcon("\uE400", "\uE8FD", "step")
    readonly property string iconEyedropper:        getIcon("\uE3B8", "\uEF3C", "eyedropper")
    readonly property string iconZoom:              getIcon("\uE8FF", "\uE8A3", "zoom")
    readonly property string iconFrame:             getIcon("\uF77B", "\uE794", "frame")
    readonly property string iconText:              getIcon("\uE264", "\uE8D2", "text")

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
    readonly property string kaoAngry:              "(╯°□°)╯︵ ┻━┻"
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
    readonly property string kaoFire:               Icons.KAO_FIRE
    readonly property string kaoSparkle:            Icons.KAO_SPARKLE
    readonly property string kaoTableFlip:          "(╯°□°)╯︵ ┻━┻"
    readonly property string kaoPutBack:            "┬─┬ノ( º _ ºノ)"

    function getVibe(kao: string, iconText: string, text: string): string {
        let style = cfg?.vibeStyle ?? "text";
        if (style === "kaomoji") return kao ?? "";
        if (style === "icon" || style === "nerd") return (iconText ?? "").toLowerCase();
        return (text ?? "").toLowerCase();
    }

    // --- flavor quotes & chaotic actions (delegated to theme/quotes.mjs) ---
    readonly property var quotePool:    Quotes.QUOTES
    readonly property var actionPool:   Quotes.ACTIONS
    readonly property var flavorQuotes: Quotes.ACTIONS

    function getFlavorPool(mode: string, category: string): var {
        return Quotes.getFlavorPool(mode, category);
    }

    function rollFlavor(category: string, mode: var, currentText: var, fallback: var): string {
        let m = (typeof mode === "string" && mode !== "") ? mode : (cfg?.flavorMode ?? (cfg?.unhingedFlavor === false ? "off" : "actions"));
        return Quotes.rollFlavor(m, category, currentText ?? "", fallback ?? "");
    }

    function getFlavor(category: string, fallback: string, modeOverride: var): string {
        let m = (typeof modeOverride === "string" && modeOverride !== "")
            ? modeOverride
            : (cfg?.flavorMode ?? (cfg?.unhingedFlavor === false ? "off" : "actions"));
        return Quotes.getFlavor(m, clock.hours, clock.minutes, category, fallback, hyprSplash);
    }
}
