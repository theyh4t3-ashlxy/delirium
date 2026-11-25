// theme/icons.mjs — icon lookup maps, status icon helpers, and desktop app icon resolver

export const KAOMOJI_MAP = Object.freeze({
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
    "user": "( •‿• )", "shield": "(ง •̀_•́)ง", "expand": "( ⊙_⊙ )", "collapse": "( >_< )", "keyboard": "φ(•̀ᴗ•́ )",
    "undo": "( ↺_↺ )", "redo": "( ↻_↻ )", "brush": "φ(．．)", "highlight": "( ✧_✧ )", "arrow": "↗",
    "rect": "[ ]", "circle": "( )", "blur": "( ░_░ )", "step": "(1)", "eyedropper": "( ◉_◉ )",
    "zoom": "( ⊙_⊙ )", "frame": "[✧]", "text": "[Aa]"
});

export const TEXT_MAP = Object.freeze({
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
    "user": "user", "shield": "safe", "expand": "max", "collapse": "min", "keyboard": "keys",
    "undo": "undo", "redo": "redo", "brush": "pen", "highlight": "mark", "arrow": "arr",
    "rect": "box", "circle": "oval", "blur": "blur", "step": "123", "eyedropper": "pick",
    "zoom": "zoom", "frame": "card", "text": "text"
});

export const KAO_FIRE = "(ง •̀_•́)ง";
export const KAO_SLEEPY = "( -.- )zzZ";
export const KAO_SPARKLE = "( ✧ω✧ )";

const WIN_CHARGING_V    = ["\uF5FD", "\uF5FE", "\uF5FF", "\uF600", "\uF601", "\uF602", "\uF603", "\uF604", "\uF605", "\uF606", "\uF607"];
const WIN_DISCHARGING_V = ["\uF5F2", "\uF5F3", "\uF5F4", "\uF5F5", "\uF5F6", "\uF5F7", "\uF5F8", "\uF5F9", "\uF5FA", "\uF5FB", "\uF5FC"];
const WIN_CHARGING_H    = ["\uE85A", "\uE85B", "\uE85C", "\uE85D", "\uE85E", "\uE85F", "\uE860", "\uE861", "\uE862", "\uE83E", "\uEA93"];
const WIN_SAVER_H       = ["\uE863", "\uE864", "\uE865", "\uE866", "\uE867", "\uE868", "\uE869", "\uE86A", "\uE86B", "\uEA94", "\uEA95"];
const WIN_DISCHARGING_H = ["\uE850", "\uE851", "\uE852", "\uE853", "\uE854", "\uE855", "\uE856", "\uE857", "\uE858", "\uE859", "\uE83F"];
const MAT_CHARGING      = ["\uF0A2", "\uF0A2", "\uF0A3", "\uF0A3", "\uF0A4", "\uF0A4", "\uF0A5", "\uF0A6", "\uF0A6", "\uF0A7", "\uE1A3"];
const MAT_DISCHARGING   = ["\uEBDC", "\uF09C", "\uF09D", "\uF09D", "\uF09E", "\uF09E", "\uF09F", "\uF0A0", "\uF0A0", "\uF0A1", "\uE1A5"];

export function getIcon(iconSet, mat, win, key, kao = undefined, txt = undefined) {
    if (iconSet === "kaomoji") {
        if (typeof kao === "string" && kao !== "" && kao !== "undefined") return kao;
        if (key && KAOMOJI_MAP[key]) return KAOMOJI_MAP[key];
        return mat;
    }
    if (iconSet === "text") {
        if (typeof txt === "string" && txt !== "" && txt !== "undefined") return txt;
        if (key && TEXT_MAP[key]) return TEXT_MAP[key];
        return mat;
    }
    if (iconSet === "windows") return win;
    return mat;
}

export function getBatteryIcon(iconSet, pct, isCharging, isSaver, isVertical) {
    const p = (pct === undefined || pct === null || isNaN(pct)) ? -1 : Math.max(0, Math.min(100, Math.round(pct)));
    const lvl = p < 0 ? -1 : Math.min(10, Math.floor(p / 10));

    if (iconSet === "kaomoji") {
        if (lvl < 0) return KAOMOJI_MAP.batHalf;
        if (isCharging) return KAOMOJI_MAP.batCharge;
        if (lvl >= 9) return KAOMOJI_MAP.batFull;
        if (lvl >= 5) return KAOMOJI_MAP.batHalf;
        if (lvl >= 2) return KAOMOJI_MAP.batQuarter;
        return KAOMOJI_MAP.batEmpty;
    }
    if (iconSet === "text") return isCharging ? "chg" : (lvl < 0 ? "bat" : p + "%");
    if (iconSet === "windows") {
        if (lvl < 0) return isVertical ? "\uF608" : "\uE996";
        if (isVertical) return isCharging ? WIN_CHARGING_V[lvl] : WIN_DISCHARGING_V[lvl];
        if (isCharging) return WIN_CHARGING_H[lvl];
        return isSaver ? WIN_SAVER_H[lvl] : WIN_DISCHARGING_H[lvl];
    }
    if (lvl < 0) return "\uE1A6";
    return isCharging ? MAT_CHARGING[lvl] : MAT_DISCHARGING[lvl];
}

export function getVolumeIcon(iconSet, volRatio, isMuted, fallbackMuteIcon) {
    if (isMuted || volRatio === undefined || isNaN(volRatio) || volRatio <= 0.001) {
        if (iconSet === "kaomoji") return KAOMOJI_MAP.volMute;
        if (iconSet === "text") return TEXT_MAP.volMute;
        return fallbackMuteIcon;
    }
    const pct = Math.round(volRatio * 100);
    if (iconSet === "kaomoji") {
        if (pct > 100) return KAO_FIRE;
        return pct <= 33 ? KAOMOJI_MAP.volLow : (pct <= 66 ? KAOMOJI_MAP.volMid : KAOMOJI_MAP.volHigh);
    }
    if (iconSet === "text") {
        if (pct > 100) return "max+";
        return pct <= 33 ? TEXT_MAP.volLow : (pct <= 66 ? TEXT_MAP.volMid : TEXT_MAP.volHigh);
    }
    if (iconSet === "windows") return pct <= 33 ? "\uE993" : (pct <= 66 ? "\uE994" : "\uE995");
    return pct <= 33 ? "\uE04E" : (pct <= 66 ? "\uE04D" : "\uE050");
}

export function getBrightnessIcon(iconSet, pct, iconMoon, iconBrightness) {
    const p = (pct === undefined || isNaN(pct)) ? 50 : pct;
    if (iconSet === "kaomoji") return p <= 20 ? KAO_SLEEPY : (p >= 85 ? KAO_SPARKLE : KAOMOJI_MAP.brightness);
    if (iconSet === "text") return p <= 25 ? "dim" : (p >= 85 ? "max" : TEXT_MAP.brightness);
    return p <= 25 ? iconMoon : iconBrightness;
}

export function getWifiIcon(iconSet, signalPct, isConnected, isEthernet, iconEthernet, iconWifiOff) {
    if (isEthernet) return iconSet === "kaomoji" ? KAOMOJI_MAP.ethernet : (iconSet === "text" ? "eth" : iconEthernet);
    if (!isConnected) return iconSet === "kaomoji" ? KAOMOJI_MAP.wifiOff : (iconSet === "text" ? "off" : iconWifiOff);
    const sig = (signalPct === undefined || signalPct === null || isNaN(signalPct)) ? 0 : signalPct;
    if (iconSet === "kaomoji") return sig < 35 ? KAOMOJI_MAP.wifiLow : (sig < 70 ? KAOMOJI_MAP.wifiMed : KAOMOJI_MAP.wifiHigh);
    if (iconSet === "text") return sig < 35 ? "low" : (sig < 70 ? "med" : "high");
    if (iconSet === "windows") return sig < 25 ? "\uE871" : (sig < 50 ? "\uE872" : (sig < 75 ? "\uE873" : "\uE874"));
    return sig < 35 ? "\uE4CA" : (sig < 70 ? "\uE4D9" : "\uE63E");
}

export function resolveAppIcon(winClass, apps, quickshellObj) {
    if (!winClass || !quickshellObj) return "";
    const base = winClass.trim().toLowerCase();
    if (!base) return "";

    if (apps) {
        for (let i = 0; i < apps.length; i++) {
            const a = apps[i];
            if (!a) continue;
            const aid = (a.id ?? "").toLowerCase().replace(/\.desktop$/, "");
            const wm = (a.startupWmClass ?? "").toLowerCase();
            if ((aid === base || wm === base) && a.icon) {
                const p = quickshellObj.iconPath(a.icon);
                if (p) return p;
            }
        }
    }

    const candidates = [
        base,
        base.replace(/-/g, ""),
        base.replace(/_bin$/, ""),
        base.replace(/-bin$/, "")
    ];
    if (quickshellObj.hasThemeIcon && quickshellObj.hasThemeIcon(base + "-browser")) {
        candidates.unshift(base + "-browser");
    }
    const parts = base.split(".");
    if (parts.length > 1) candidates.push(parts[parts.length - 1]);

    for (let i = 0; i < candidates.length; i++) {
        const cand = candidates[i];
        if (!cand) continue;
        if (quickshellObj.hasThemeIcon && !quickshellObj.hasThemeIcon(cand)) continue;
        const p = quickshellObj.iconPath(cand);
        if (p) return p;
    }
    if (quickshellObj.hasThemeIcon && quickshellObj.hasThemeIcon("application-x-executable")) {
        return quickshellObj.iconPath("application-x-executable");
    }
    return "";
}
