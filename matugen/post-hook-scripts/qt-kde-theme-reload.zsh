#!/usr/bin/env zsh
# qt-kde-theme-reload.zsh - sync Matugen color-scheme directly into kdeglobals (no Plasma daemon required) & notify running Qt/KDE apps

if [[ ! -f /.flatpak-info ]] && [[ "${DBUS_SESSION_BUS_ADDRESS:-}" == *"/run/flatpak/bus"* || -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
    _host_bus="${XDG_RUNTIME_DIR:-/run/user/$UID}/bus"
    [[ -S "$_host_bus" ]] && export DBUS_SESSION_BUS_ADDRESS="unix:path=$_host_bus"
fi

COLORS_FILE="$HOME/.local/share/color-schemes/Matugen.colors"
KDEGLOBALS="$HOME/.config/kdeglobals"

if [[ -f "$COLORS_FILE" ]] && (( $+commands[python3] )); then
    python3 - "$COLORS_FILE" "$KDEGLOBALS" <<'PY' 2>/dev/null || true
import configparser
import os
import pathlib
import sys
import tempfile

colors_path = pathlib.Path(sys.argv[1])
kde_path = pathlib.Path(sys.argv[2])
kde_path.parent.mkdir(parents=True, exist_ok=True)

src = configparser.ConfigParser(interpolation=None)
src.optionxform = str
src.read(colors_path, encoding="utf-8")

dst = configparser.ConfigParser(interpolation=None)
dst.optionxform = str
if kde_path.exists():
    try:
        dst.read(kde_path, encoding="utf-8")
    except Exception:
        pass

for sec in src.sections():
    if not dst.has_section(sec):
        dst.add_section(sec)
    for k, v in src.items(sec):
        dst.set(sec, k, v)

# Use Qt5-compatible weight=50 so Qt6 KConfig maps cleanly to Regular (400), never Black (900)
ui_font = "Google Sans Flex,10,-1,5,50,0,0,0,0,0"
sm_font = "Google Sans Flex,8,-1,5,50,0,0,0,0,0"
mono_font = "JetBrainsMono Nerd Font,10,-1,5,50,0,0,0,0,0"

if not dst.has_section("General"):
    dst.add_section("General")
dst.set("General", "ColorScheme", "Matugen")
dst.set("General", "Name", "Matugen")
dst.set("General", "font", ui_font)
dst.set("General", "menuFont", ui_font)
dst.set("General", "toolBarFont", ui_font)
dst.set("General", "smallestReadableFont", sm_font)
dst.set("General", "fixed", mono_font)

if not dst.has_section("KDE"):
    dst.add_section("KDE")
dst.set("KDE", "widgetStyle", "Breeze")
dst.set("KDE", "contrast", src.get("KDE", "contrast", fallback="4"))

icon_theme = "MoreWaita" if (
    pathlib.Path("/run/current-system/sw/share/icons/MoreWaita").exists()
    or (pathlib.Path.home() / ".local/share/icons/MoreWaita").exists()
) else "breeze-dark"

if not dst.has_section("Icons"):
    dst.add_section("Icons")
dst.set("Icons", "Theme", icon_theme)

fd, tmp_name = tempfile.mkstemp(prefix=".kdeglobals.", dir=str(kde_path.parent))
try:
    with os.fdopen(fd, "w", encoding="utf-8") as fh:
        dst.write(fh, space_around_delimiters=False)
    os.replace(tmp_name, kde_path)
except Exception:
    try:
        os.unlink(tmp_name)
    except OSError:
        pass
    raise
PY
fi

# Fallback Plasma tools when present
if (( $+commands[plasma-apply-colorscheme] )); then
    plasma-apply-colorscheme Matugen >/dev/null 2>&1 || true
fi

# Broadcast global settings change signal over DBus so running Qt/KDE apps reload live
if (( $+commands[dbus-send] )); then
    dbus-send --type=signal /KGlobalSettings org.kde.KGlobalSettings.notifyChange int32:0 int32:0 2>/dev/null || true
    dbus-send --type=signal /KWin org.kde.KWin.reloadConfig 2>/dev/null || true
fi

# Sync color scheme & kdeglobals into Flatpak application configs
if [[ -f "$COLORS_FILE" ]]; then
    for app_data in $HOME/.var/app/*/data(N/); do
        mkdir -p "$app_data/color-schemes" 2>/dev/null || continue
        cp -f "$COLORS_FILE" "$app_data/color-schemes/Matugen.colors" 2>/dev/null || true
    done
fi

if [[ -f "$KDEGLOBALS" ]]; then
    for app_cfg in $HOME/.var/app/*/config(N/); do
        cp -f "$KDEGLOBALS" "$app_cfg/kdeglobals" 2>/dev/null || true
    done
fi
