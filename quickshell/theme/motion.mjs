// theme/motion.mjs — bezier curve tokens & Qt Easing resolver

export const BEZIERS = Object.freeze({
    hyprland:          [0.05, 0.9, 0.1, 1.05, 1.0, 1.0],
    hyprlandExit:      [0.3, 0.0, 0.8, 0.15, 1.0, 1.0],
    smooth:            [0.16, 1.0, 0.3, 1.0, 1.0, 1.0],
    snappy:            [0.2, 0.0, 0.0, 1.0, 1.0, 1.0],
    expressive:        [0.1, 1.15, 0.2, 1.0, 1.0, 1.0],
    standard:          [0.25, 0.1, 0.25, 1.0, 1.0, 1.0],
    expressiveFast:    [0.38, 1.25, 0.25, 1.0, 1.0, 1.0],
    expressiveDefault: [0.34, 1.45, 0.22, 1.0, 1.0, 1.0],
    expressiveSlow:    [0.25, 1.35, 0.15, 1.0, 1.0, 1.0],
    emphasized:        [0.20, 0.0, 0.0, 1.0, 1.0, 1.0],
    emphasizedDecel:   [0.05, 0.7, 0.1, 1.0, 1.0, 1.0],
    emphasizedAccel:   [0.30, 0.0, 0.8, 0.15, 1.0, 1.0]
});

const CURVE_ALIASES = Object.freeze({
    hyprland:             BEZIERS.hyprland,
    smooth:               BEZIERS.smooth,
    cubic:                BEZIERS.smooth,
    snappy:               BEZIERS.snappy,
    expressive:           BEZIERS.expressive,
    "expressive-fast":    BEZIERS.expressiveFast,
    "expressive-default": BEZIERS.expressiveDefault,
    "expressive-slow":    BEZIERS.expressiveSlow,
    emphasized:           BEZIERS.emphasized,
    "emphasized-decel":   BEZIERS.emphasizedDecel,
    "emphasized-accel":   BEZIERS.emphasizedAccel,
    linear:               [0.0, 0.0, 1.0, 1.0, 1.0, 1.0]
});

const EASING_FAMILY = Object.freeze({
    quad:       "Quad",
    snappy:     "Quad",
    quart:      "Quart",
    quint:      "Quint",
    sine:       "Sine",
    expo:       "Expo",
    circ:       "Circ",
    back:       "Back",
    expressive: "Back",
    elastic:    "Elastic",
    bounce:     "Bounce"
});

const EASING_DIR = Object.freeze({
    in:     "In",
    inout:  "InOut",
    in_out: "InOut",
    outin:  "OutIn",
    out_in: "OutIn"
});

/** Resolve a 6-element QML Easing.bezierCurve array from name, CSS string, or array. */
export function getBezierPoints(curve) {
    if (!curve) return BEZIERS.standard;
    if (Array.isArray(curve)) {
        if (curve.length >= 6) return [Number(curve[0]), Number(curve[1]), Number(curve[2]), Number(curve[3]), Number(curve[4]), Number(curve[5])];
        if (curve.length >= 4) return [Number(curve[0]), Number(curve[1]), Number(curve[2]), Number(curve[3]), 1.0, 1.0];
    }
    if (typeof curve !== "string") return BEZIERS.standard;

    const c = curve.trim().toLowerCase();
    if (CURVE_ALIASES[c]) return CURVE_ALIASES[c];

    const m = c.match(/^(?:cubic-bezier\s*\(\s*)?([0-9.-]+)\s*,\s*([0-9.-]+)\s*,\s*([0-9.-]+)\s*,\s*([0-9.-]+)(?:\s*\))?$/);
    if (m) {
        const p1 = parseFloat(m[1]), p2 = parseFloat(m[2]), p3 = parseFloat(m[3]), p4 = parseFloat(m[4]);
        if (!isNaN(p1) && !isNaN(p2) && !isNaN(p3) && !isNaN(p4)) {
            return [p1, p2, p3, p4, 1.0, 1.0];
        }
    }
    return BEZIERS.standard;
}

/** Map curve family + direction (`in`/`out`/`inout`/`outin`) to Qt Easing enum value. */
export function getEasing(curve, type, EasingEnum) {
    const c = (curve ?? "cubic").toLowerCase();
    const t = (type ?? "out").toLowerCase();

    if (c === "linear") return EasingEnum.Linear;
    if (c === "bezier" || c === "spline" || c === "bezierspline") return EasingEnum.BezierSpline;

    const family = EASING_FAMILY[c] ?? "Cubic";
    const dir = EASING_DIR[t] ?? "Out";
    return EasingEnum[dir + family] ?? EasingEnum.OutCubic;
}
