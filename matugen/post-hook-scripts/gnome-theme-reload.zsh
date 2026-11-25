#!/usr/bin/env zsh
# gnome-theme-reload.zsh — sync GNOME wallpaper, Material accent, extension colors, and User Theme live

if [[ ! -f /.flatpak-info ]] && [[ "${DBUS_SESSION_BUS_ADDRESS:-}" == *"/run/flatpak/bus"* || -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
    _host_bus="${XDG_RUNTIME_DIR:-/run/user/$UID}/bus"
    [[ -S "$_host_bus" ]] && export DBUS_SESSION_BUS_ADDRESS="unix:path=$_host_bus"
fi

PALETTE_CSS="$HOME/.config/quickshell/palette.css"
SAVED_WP="$HOME/.local/state/quickshell/saved_wp"
CURR_STATIC="$HOME/.curr_wall_static.jpg"

# 1. Resolve current static wallpaper image for GNOME background & screensaver
wp_path=""
if [[ -e "$CURR_STATIC" ]]; then
    wp_path=$(readlink -f "$CURR_STATIC" 2>/dev/null || true)
fi
if [[ -z "$wp_path" || ! -f "$wp_path" ]] && [[ -f "$SAVED_WP" ]]; then
    raw_cur=$(grep -m1 '^current=' "$SAVED_WP" 2>/dev/null | cut -d'=' -f2-)
    [[ -n "$raw_cur" && -f "$raw_cur" ]] && wp_path="$raw_cur"
fi

if (( $+commands[dconf] )) && [[ -n "$wp_path" && -f "$wp_path" ]]; then
    wp_uri="file://${wp_path}"
    dconf write /org/gnome/desktop/background/picture-uri "'${wp_uri}'" 2>/dev/null || true
    dconf write /org/gnome/desktop/background/picture-uri-dark "'${wp_uri}'" 2>/dev/null || true
    dconf write /org/gnome/desktop/screensaver/picture-uri "'${wp_uri}'" 2>/dev/null || true
fi

# 2. Parse Material You hex palette & sync GNOME native accent + extension tokens
if (( $+commands[python3] && $+commands[dconf] )) && [[ -f "$PALETTE_CSS" ]]; then
    python3 - "$PALETTE_CSS" <<'PY' 2>/dev/null || true
import colorsys, re, subprocess, sys
from pathlib import Path

css = Path(sys.argv[1]).read_text(encoding="utf-8", errors="ignore")
tokens = dict(re.findall(r"--([a-z0-9-]+)\s*:\s*(#[0-9a-fA-F]{6})", css))
if not tokens:
    sys.exit(0)

def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def rgba_str(h, alpha=1.0):
    r, g, b = hex_to_rgb(h)
    return f"rgba({r},{g},{b},{alpha:.2f})" if alpha < 1.0 else f"rgb({r},{g},{b})"

def closest_accent(h_hex):
    r, g, b = [c / 255.0 for c in hex_to_rgb(h_hex)]
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    if s < 0.16:
        return "slate"
    deg = h * 360.0
    if deg < 18 or deg >= 342:
        return "red"
    if deg < 42:
        return "orange"
    if deg < 68:
        return "yellow"
    if deg < 155:
        return "green"
    if deg < 195:
        return "teal"
    if deg < 252:
        return "blue"
    if deg < 305:
        return "purple"
    return "pink"

primary = tokens.get("primary", "#d0bcfe")
on_primary = tokens.get("on-primary", "#36265d")
surf_cont = tokens.get("surface-container", "#211f24")
surf_high = tokens.get("surface-container-high", "#2b292f")
on_surf = tokens.get("on-surface", "#e6e0e9")
outline = tokens.get("outline", "#948f99")
outline_var = tokens.get("outline-variant", "#49454e")

writes = {
    "/org/gnome/desktop/interface/accent-color": f"'{closest_accent(primary)}'",
    "/org/gnome/shell/extensions/space-bar/appearance/active-workspace-background-color": f"'{rgba_str(primary, 0.95)}'",
    "/org/gnome/shell/extensions/space-bar/appearance/active-workspace-text-color": f"'{rgba_str(on_primary, 1.0)}'",
    "/org/gnome/shell/extensions/space-bar/appearance/active-workspace-border-color": f"'{rgba_str(primary, 1.0)}'",
    "/org/gnome/shell/extensions/space-bar/appearance/inactive-workspace-background-color": f"'{rgba_str(surf_high, 0.70)}'",
    "/org/gnome/shell/extensions/space-bar/appearance/inactive-workspace-text-color": f"'{rgba_str(on_surf, 0.92)}'",
    "/org/gnome/shell/extensions/space-bar/appearance/inactive-workspace-border-color": f"'{rgba_str(outline_var, 0.45)}'",
    "/org/gnome/shell/extensions/space-bar/appearance/empty-workspace-background-color": "'rgba(0,0,0,0)'",
    "/org/gnome/shell/extensions/space-bar/appearance/empty-workspace-text-color": f"'{rgba_str(outline, 0.65)}'",
    "/org/gnome/shell/extensions/dash-to-dock/background-color": f"'{surf_cont}'",
    "/org/gnome/shell/extensions/dash-to-dock/custom-theme-running-dots-color": f"'{primary}'",
    "/org/gnome/shell/extensions/dash-to-dock/custom-theme-running-dots-border-color": f"'{on_primary}'",
}

# Sync rounded-window-corners-reborn hairline borderColor safely
r, g, b = [round(c / 255.0, 3) for c in hex_to_rgb(outline_var)]
rwc_val = (
    "{'padding': <{'left': <uint32 1>, 'right': <uint32 1>, 'top': <uint32 1>, 'bottom': <uint32 1>}>, "
    "'keepRoundedCorners': <{'maximized': <false>, 'fullscreen': <false>}>, "
    "'borderRadius': <uint32 16>, 'smoothing': <0>, "
    f"'borderColor': <[ {r}, {g}, {b}, 0.85 ]>, 'enabled': <true>}}"
)
writes["/org/gnome/shell/extensions/rounded-window-corners-reborn/global-rounded-corner-settings"] = rwc_val

for k, v in writes.items():
    subprocess.run(["dconf", "write", k, v], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
PY
fi

# 3. Pulse GNOME Shell user-theme so active GNOME sessions live-reload ~/.local/share/themes/Matugen
if (( $+commands[dconf] )); then
    theme_file="$HOME/.local/share/themes/Matugen/gnome-shell/gnome-shell.css"
    if [[ -f "$theme_file" ]]; then
        dconf write /org/gnome/shell/extensions/user-theme/name "''" 2>/dev/null || true
        sleep 0.08
        dconf write /org/gnome/shell/extensions/user-theme/name "'Matugen'" 2>/dev/null || true
    fi
fi
