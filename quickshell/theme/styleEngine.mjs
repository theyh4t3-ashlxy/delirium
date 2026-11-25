// theme/styleEngine.mjs — color math & barStyle token resolver for Theme.qml

function parseHexColor(str, rgbaFn) {
    if (typeof str !== "string") return null;
    const m = str.trim().match(/^#([0-9a-fA-F]+)$/);
    if (!m) return null;
    const h = m[1];
    if (h.length === 3 || h.length === 4) {
        const hasA = h.length === 4;
        const a = hasA ? parseInt(h[0] + h[0], 16) / 255 : 1.0;
        const r = parseInt(h[hasA ? 1 : 0].repeat(2), 16) / 255;
        const g = parseInt(h[hasA ? 2 : 1].repeat(2), 16) / 255;
        const b = parseInt(h[hasA ? 3 : 2].repeat(2), 16) / 255;
        return rgbaFn(r, g, b, a);
    }
    if (h.length === 6) {
        return rgbaFn(
            parseInt(h.slice(0, 2), 16) / 255,
            parseInt(h.slice(2, 4), 16) / 255,
            parseInt(h.slice(4, 6), 16) / 255,
            1.0
        );
    }
    if (h.length === 8) {
        return rgbaFn(
            parseInt(h.slice(2, 4), 16) / 255,
            parseInt(h.slice(4, 6), 16) / 255,
            parseInt(h.slice(6, 8), 16) / 255,
            parseInt(h.slice(0, 2), 16) / 255
        );
    }
    return null;
}

export function resolveColor(c, rgbaFn) {
    if (c !== undefined && c !== null && c.r !== undefined) return c;
    return parseHexColor(c, rgbaFn);
}

/** Return color `c` with clamped alpha `a` (supports QML colors and #hex strings). */
export function alpha(c, a, rgbaFn) {
    const col = resolveColor(c, rgbaFn);
    if (!col) return rgbaFn(0, 0, 0, 0);
    const val = (typeof a !== "number" || isNaN(a)) ? 1.0 : Math.max(0.0, Math.min(1.0, a));
    return rgbaFn(col.r, col.g, col.b, val);
}

/** Blend `c1` -> `c2` by `t` in approximate linear RGB space. */
export function blend(c1, c2, t, rgbaFn) {
    const col1 = resolveColor(c1, rgbaFn);
    const col2 = resolveColor(c2, rgbaFn);
    if (!col1) return col2 ?? rgbaFn(0, 0, 0, 0);
    if (!col2) return col1;

    const f = (typeof t !== "number" || isNaN(t)) ? 0.0 : Math.max(0.0, Math.min(1.0, t));
    const inv = 1.0 - f;

    return rgbaFn(
        Math.sqrt((col1.r * col1.r * inv) + (col2.r * col2.r * f)),
        Math.sqrt((col1.g * col1.g * inv) + (col2.g * col2.g * f)),
        Math.sqrt((col1.b * col1.b * inv) + (col2.b * col2.b * f)),
        (col1.a * inv) + (col2.a * f)
    );
}

/** Blend state layer `contentColor` over `baseColor` at `ratio`. */
export function stateColor(baseColor, contentColor, ratio, fallbackOnSurface, rgbaFn) {
    const hasContent = contentColor !== undefined && contentColor !== null && contentColor !== "";
    return blend(baseColor, hasContent ? contentColor : fallbackOnSurface, ratio, rgbaFn);
}

/** Semantic battery fill color based on level and charging state. */
export function getBatteryColor(pct, isCharging, t) {
    if (isCharging) return t.primary;
    const p = (pct === undefined || isNaN(pct)) ? 100 : pct;
    if (p <= 15) return t.error;
    if (p <= 30) return t.warn;
    return t.on_surface;
}

const BAR_STYLE_ALIASES = Object.freeze({
    "regular": "solid",
    "glass-frost": "frosted",
    "accent-glow": "tinted",
    "cyber-neon": "outlined",
    "pure-black": "oled",
    "bento-floating": "islands"
});

export const BAR_STYLES = Object.freeze([
    { id: "solid",       label: "solid",       desc: "opaque surface container matching active palette" },
    { id: "glass",       label: "glass",       desc: "low-alpha smoked surface with top highlight" },
    { id: "frosted",     label: "frosted",     desc: "higher-density glass with firmer border contrast" },
    { id: "translucent", label: "translucent", desc: "balanced semi-transparent panel over wallpaper" },
    { id: "tinted",      label: "tinted",      desc: "primary container fill with subtle accent halo" },
    { id: "outlined",    label: "outlined",    desc: "high-contrast backing with primary accent strokes" },
    { id: "oled",        label: "oled",        desc: "neutral pitch dark or pure white monochrome contrast" },
    { id: "monochrome",  label: "monochrome",  desc: "flat matte tonal surface with subtle rules" },
    { id: "islands",     label: "islands",     desc: "detached floating zone capsules with gap spacing" }
]);

/** Normalize legacy `barStyle` names (`regular`, `cyber-neon`, etc.) to current IDs. */
export function normalizeBarStyle(bs) {
    const s = String(bs ?? "solid").trim().toLowerCase();
    return BAR_STYLE_ALIASES[s] ?? (s || "solid");
}

/** Normalize legacy `cornerColorMode` values (`pure-black` -> `oled`). */
export function normalizeCornerColorMode(cm) {
    const s = String(cm ?? "bar").trim().toLowerCase();
    if (s === "pure-black") return "oled";
    return s || "bar";
}

const OLED_PALETTE = {
    barBg:            ["#ffffff", "#000000"],
    barBorderColor:   ["#e0e0e0", "#1f1f1f"],
    widgetBg:         ["#f2f2f2", "#0a0a0a"],
    widgetHover:      ["#e6e6e6", "#181818"],
    widgetActive:     ["#d9d9d9", "#242424"],
    widgetBorder:     ["#dcdcdc", "#1f1f1f"],
    popupBg:          ["#ffffff", "#000000"],
    popupBorderColor: ["#dcdcdc", "#1f1f1f"],
    cardBg:           ["#f7f7f7", "#080808"],
    cardBorder:       ["#e2e2e2", "#1c1c1c"],
    pillBg:           ["#f2f2f2", "#0a0a0a"],
    pillHover:        ["#e6e6e6", "#181818"],
    pillBorder:       ["#dddddd", "#222222"]
};

const ROLE_RULES = {
    barBg: {
        solid:       (t, a) => a(t.surface_container_low, 0.95),
        glass:       (t, a) => a(t.surface_container_lowest, Math.min(1.0, (t.isLightMode ? 0.68 : 0.40) + t.adaptiveAlphaBoost)),
        frosted:     (t, a) => a(t.surface_container_lowest, Math.min(1.0, (t.isLightMode ? 0.78 : 0.55) + t.adaptiveAlphaBoost)),
        outlined:    (t, a) => t.isLightMode ? a(t.surface_container_lowest, 0.94) : a("#050508", 0.94),
        islands:     (t, a) => a(t.surface_container_low, Math.min(1.0, 0.88 + t.adaptiveAlphaBoost)),
        translucent: (t, a) => a(t.surface_container_low, Math.min(1.0, (t.isLightMode ? 0.80 : 0.70) + t.adaptiveAlphaBoost)),
        tinted:      (t, a) => a(t.surface_container_lowest, 0.90),
        monochrome:  (t)    => t.surface_container_highest,
        fallback:    (t)    => t.surface_container_low
    },
    barBorderColor: {
        solid:       (t, a) => a(t.outline_variant, 0.40),
        glass:       (t, a) => t.isLightMode ? a(t.outline_variant, 0.52) : t.rgba(1, 1, 1, 0.16),
        frosted:     (t, a) => t.isLightMode ? a(t.outline_variant, 0.65) : t.rgba(1, 1, 1, 0.24),
        outlined:    (t)    => t.primary,
        islands:     (t, a) => a(t.outline_variant, 0.45),
        tinted:      (t)    => t.primary,
        translucent: (t, a) => a(t.outline_variant, 0.35),
        fallback:    (t, a) => a(t.outline_variant, 0.50)
    },
    widgetBg: {
        solid:       (t, a) => a(t.surface_container_high, t.isLightMode ? 0.75 : 0.60),
        glass:       (t, a) => a(t.surface_container_high, t.isLightMode ? 0.55 : 0.28),
        frosted:     (t, a) => a(t.surface_container_high, t.isLightMode ? 0.68 : 0.38),
        outlined:    (t, a) => a(t.surface_container_lowest, 0.85),
        islands:     (t, a) => a(t.surface_container_high, t.isLightMode ? 0.65 : 0.50),
        translucent: (t, a) => a(t.surface_container_high, t.isLightMode ? 0.58 : 0.40),
        tinted:      (t, a) => a(t.primary_container, 0.65),
        monochrome:  (t)    => t.surface_container_high,
        fallback:    (t)    => t.surface_container_low
    },
    widgetHover: {
        solid:       (t, a) => a(t.surface_container_highest, 0.85),
        glass:       (t, a) => a(t.surface_container_highest, t.isLightMode ? 0.72 : 0.48),
        frosted:     (t, a) => a(t.surface_container_highest, t.isLightMode ? 0.82 : 0.60),
        outlined:    (t, a) => a(t.primary_container, 0.50),
        islands:     (t, a) => a(t.surface_container_highest, 0.70),
        translucent: (t, a) => a(t.surface_container_highest, 0.65),
        tinted:      (t, a) => a(t.primary, 0.35),
        monochrome:  (t)    => t.surface_container_highest,
        fallback:    (t)    => t.surface_container_highest
    },
    widgetActive: {
        solid:       (t, a) => a(t.primary_container, 0.90),
        glass:       (t, a) => a(t.surface_container_highest, t.isLightMode ? 0.85 : 0.65),
        frosted:     (t, a) => a(t.surface_container_highest, t.isLightMode ? 0.90 : 0.80),
        outlined:    (t, a) => a(t.primary, 0.45),
        islands:     (t, a) => a(t.surface_container_highest, 0.90),
        translucent: (t, a) => a(t.surface_container_highest, 0.85),
        tinted:      (t, a) => a(t.primary, 0.55),
        monochrome:  (t, a) => a(t.on_surface, 0.20),
        fallback:    (t)    => t.surface_container_highest
    },
    widgetBorder: {
        solid:       (t, a) => a(t.outline_variant, 0.40),
        glass:       (t, a) => t.isLightMode ? a(t.outline_variant, 0.52) : t.rgba(1, 1, 1, 0.12),
        frosted:     (t, a) => t.isLightMode ? a(t.outline_variant, 0.65) : t.rgba(1, 1, 1, 0.20),
        outlined:    (t, a) => a(t.primary, 0.60),
        islands:     (t, a) => a(t.outline_variant, 0.40),
        translucent: (t, a) => a(t.outline_variant, 0.35),
        tinted:      (t, a) => a(t.primary, 0.70),
        monochrome:  (t, a) => a(t.outline, 0.40),
        fallback:    (t, a) => a(t.outline_variant, 0.50)
    },
    popupBg: {
        solid:       (t, a) => a(t.surface_container_low, 0.96),
        glass:       (t, a) => a(t.surface_container_lowest, Math.min(1.0, (t.isLightMode ? 0.86 : 0.60) + t.adaptiveAlphaBoost)),
        frosted:     (t, a) => a(t.surface_container_lowest, Math.min(1.0, (t.isLightMode ? 0.92 : 0.75) + t.adaptiveAlphaBoost)),
        outlined:    (t, a) => t.isLightMode ? a(t.surface_container_lowest, 0.96) : a("#07070b", 0.96),
        islands:     (t, a) => a(t.surface_container_low, Math.min(1.0, 0.92 + t.adaptiveAlphaBoost)),
        translucent: (t, a) => a(t.surface_container_low, Math.min(1.0, (t.isLightMode ? 0.88 : 0.80) + t.adaptiveAlphaBoost)),
        tinted:      (t, a) => a(t.surface_container_lowest, 0.95),
        monochrome:  (t)    => t.surface_container_low,
        fallback:    (t)    => t.surface_container_low
    },
    popupBorderColor: {
        solid:       (t, a) => a(t.outline_variant, 0.45),
        glass:       (t, a) => t.isLightMode ? a(t.outline_variant, 0.65) : t.rgba(1, 1, 1, 0.18),
        frosted:     (t, a) => t.isLightMode ? a(t.outline_variant, 0.65) : t.rgba(1, 1, 1, 0.26),
        outlined:    (t)    => t.primary,
        islands:     (t, a) => a(t.outline_variant, 0.50),
        tinted:      (t, a) => a(t.primary, 0.85),
        translucent: (t, a) => a(t.outline_variant, 0.40),
        monochrome:  (t, a) => a(t.outline, 0.45),
        fallback:    (t, a) => a(t.outline_variant, 0.50)
    },
    cardBg: {
        solid:       (t, a) => a(t.surface_container_high, t.isLightMode ? 0.85 : 0.75),
        glass:       (t, a) => a(t.surface_container_high, t.isLightMode ? 0.65 : 0.30),
        frosted:     (t, a) => a(t.surface_container_high, t.isLightMode ? 0.76 : 0.45),
        outlined:    (t, a) => a(t.surface_container_low, 0.75),
        islands:     (t, a) => a(t.surface_container_high, t.isLightMode ? 0.75 : 0.60),
        translucent: (t, a) => a(t.surface_container_high, t.isLightMode ? 0.68 : 0.50),
        tinted:      (t, a) => a(t.primary_container, 0.45),
        monochrome:  (t)    => t.surface_container_high,
        fallback:    (t)    => t.surface_container_high
    },
    cardBorder: {
        solid:       (t, a) => a(t.outline_variant, 0.35),
        glass:       (t, a) => t.isLightMode ? a(t.outline_variant, 0.52) : t.rgba(1, 1, 1, 0.12),
        frosted:     (t, a) => t.isLightMode ? a(t.outline_variant, 0.65) : t.rgba(1, 1, 1, 0.20),
        outlined:    (t, a) => a(t.primary, 0.50),
        islands:     (t, a) => a(t.outline_variant, 0.35),
        translucent: (t, a) => a(t.outline_variant, 0.30),
        tinted:      (t, a) => a(t.primary, 0.60),
        monochrome:  (t, a) => a(t.outline, 0.35),
        fallback:    (t, a) => a(t.outline_variant, 0.40)
    },
    pillBg: {
        solid:       (t, a) => a(t.surface_container_high, t.isLightMode ? 0.78 : 0.65),
        glass:       (t, a) => a(t.surface_container_high, t.isLightMode ? 0.62 : 0.25),
        frosted:     (t, a) => a(t.surface_container_high, t.isLightMode ? 0.74 : 0.35),
        outlined:    (t, a) => a(t.surface_container_low, 0.60),
        islands:     (t, a) => a(t.surface_container_high, t.isLightMode ? 0.68 : 0.50),
        translucent: (t, a) => a(t.surface_container_high, t.isLightMode ? 0.62 : 0.45),
        tinted:      (t, a) => a(t.primary, 0.22),
        monochrome:  (t)    => t.surface_container,
        fallback:    (t)    => t.surface_container_high
    },
    pillHover: {
        solid:       (t, a) => a(t.surface_container_highest, 0.85),
        glass:       (t, a) => a(t.surface_container_highest, t.isLightMode ? 0.78 : 0.45),
        frosted:     (t, a) => a(t.surface_container_highest, t.isLightMode ? 0.85 : 0.55),
        outlined:    (t, a) => a(t.primary_container, 0.40),
        islands:     (t, a) => a(t.surface_container_highest, 0.65),
        translucent: (t, a) => a(t.surface_container_highest, 0.70),
        tinted:      (t, a) => a(t.primary, 0.40),
        monochrome:  (t)    => t.surface_container_highest,
        fallback:    (t)    => t.surface_container_highest
    },
    pillBorder: {
        solid:       (t, a) => a(t.outline_variant, 0.35),
        glass:       (t, a) => t.isLightMode ? a(t.outline_variant, 0.52) : t.rgba(1, 1, 1, 0.14),
        frosted:     (t, a) => t.isLightMode ? a(t.outline_variant, 0.65) : t.rgba(1, 1, 1, 0.22),
        outlined:    (t, a) => a(t.primary, 0.75),
        islands:     (t, a) => a(t.outline_variant, 0.30),
        translucent: (t, a) => a(t.outline_variant, 0.25),
        tinted:      (t, a) => a(t.primary, 0.85),
        monochrome:  (t, a) => a(t.outline, 0.35),
        fallback:    (t)    => t.rgba(0, 0, 0, 0)
    }
};

/** Resolve surface/border role color for the active `barStyle` preset `bs`. */
export function getStyleColor(role, bs, t) {
    const style = normalizeBarStyle(bs);
    const rules = ROLE_RULES[role];
    if (!rules) return t.surface_container_low;

    if (style === "oled" && OLED_PALETTE[role]) {
        const pair = OLED_PALETTE[role];
        const hex = t.isLightMode ? pair[0] : pair[1];
        return parseHexColor(hex, t.rgba);
    }

    const alphaFn = (c, op) => alpha(c, op, t.rgba);
    const fn = rules[style] ?? rules.fallback;
    return fn(t, alphaFn);
}
