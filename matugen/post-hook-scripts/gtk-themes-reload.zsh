#!/usr/bin/env zsh
# gtk-themes-reload.zsh - refresh GTK3/4 themes, typography, icons, cursors, and xsettingsd

if [[ ! -f /.flatpak-info ]] && [[ "${DBUS_SESSION_BUS_ADDRESS:-}" == *"/run/flatpak/bus"* || -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
    _host_bus="${XDG_RUNTIME_DIR:-/run/user/$UID}/bus"
    [[ -S "$_host_bus" ]] && export DBUS_SESSION_BUS_ADDRESS="unix:path=$_host_bus"
fi

# 1. Detect active light/dark mode
mode="dark"
for cfg_path in "$HOME/.local/state/quickshell/settings.conf" "$HOME/.config/quickshell/settings.conf"; do
    if [[ -f "$cfg_path" ]]; then
        cfg_mode=$(grep -E '^\s*matugenMode\s*=' "$cfg_path" 2>/dev/null | head -n 1 | cut -d'=' -f2 | tr -d '"\r ')
        [[ "$cfg_mode" == "light" || "$cfg_mode" == "dark" ]] && mode="$cfg_mode" && break
    fi
done

if [[ -f "$HOME/.config/gtk-4.0/matugen.css" ]]; then
    bg_hex=$(grep -E '^\s*@define-color\s+window_bg_color\s+#' "$HOME/.config/gtk-4.0/matugen.css" | head -n 1 | sed -E 's/.*#([0-9a-fA-F]{6}).*/\1/')
    if [[ -n "$bg_hex" && ${#bg_hex} -eq 6 ]]; then
        r=$((16#${bg_hex[1,2]}))
        g=$((16#${bg_hex[3,4]}))
        b=$((16#${bg_hex[5,6]}))
        lum=$(( (r * 299 + g * 587 + b * 114) / 1000 ))
        (( lum > 128 )) && mode="light" || mode="dark"
    fi
fi

if [[ "$mode" == "light" ]]; then
    target_scheme="prefer-light"
    pulse_scheme="prefer-dark"
    target_theme="adw-gtk3"
    dark_bool="false"
else
    target_scheme="prefer-dark"
    pulse_scheme="prefer-light"
    target_theme="adw-gtk3-dark"
    dark_bool="true"
fi

icon_theme="Adwaita"
if [[ -d "/run/current-system/sw/share/icons/MoreWaita" || -d "$HOME/.local/share/icons/MoreWaita" ]]; then
    icon_theme="MoreWaita"
fi
cursor_theme="Windows-Aero"
font_name="Google Sans Flex 10"

# 2. Keep host gtk-3.0 and gtk-4.0 settings.ini clean & synced with GNOME/dconf (strip KDE pollution)
update_ini_key() {
    local file="$1" key="$2" val="$3"
    if grep -qE "^${key}=" "$file" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${val}|" "$file" 2>/dev/null || true
    else
        printf '%s=%s\n' "$key" "$val" >> "$file"
    fi
}

mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"
[[ -f "$HOME/.config/gtk-3.0/gtk.css" ]] || printf '@import url("matugen.css");\n' > "$HOME/.config/gtk-3.0/gtk.css"
[[ -f "$HOME/.config/gtk-4.0/gtk.css" ]] || printf '@import url("matugen.css");\n' > "$HOME/.config/gtk-4.0/gtk.css"
[[ -f "$HOME/.config/gtk-4.0/gtk-dark.css" ]] || printf '@import url("matugen.css");\n' > "$HOME/.config/gtk-4.0/gtk-dark.css"

if [[ -f "$HOME/.config/gtk-3.0/settings.ini" ]]; then
    sed -i '/^gtk-modules=colorreload-gtk-module/d' "$HOME/.config/gtk-3.0/settings.ini" 2>/dev/null || true
    update_ini_key "$HOME/.config/gtk-3.0/settings.ini" "gtk-theme-name" "$target_theme"
    update_ini_key "$HOME/.config/gtk-3.0/settings.ini" "gtk-application-prefer-dark-theme" "$dark_bool"
    update_ini_key "$HOME/.config/gtk-3.0/settings.ini" "gtk-icon-theme-name" "$icon_theme"
    update_ini_key "$HOME/.config/gtk-3.0/settings.ini" "gtk-font-name" "$font_name"
    update_ini_key "$HOME/.config/gtk-3.0/settings.ini" "gtk-cursor-theme-name" "$cursor_theme"
fi

if [[ -f "$HOME/.config/gtk-4.0/settings.ini" ]]; then
    sed -i '/^gtk-application-prefer-dark-theme=/d;/^gtk-theme-name=/d;/^gtk-modules=colorreload-gtk-module/d' "$HOME/.config/gtk-4.0/settings.ini" 2>/dev/null || true
    update_ini_key "$HOME/.config/gtk-4.0/settings.ini" "gtk-icon-theme-name" "$icon_theme"
    update_ini_key "$HOME/.config/gtk-4.0/settings.ini" "gtk-font-name" "$font_name"
    update_ini_key "$HOME/.config/gtk-4.0/settings.ini" "gtk-cursor-theme-name" "$cursor_theme"
fi

# 3. Sync theme tokens & settings to active Flatpak application config directories
for app_cfg in $HOME/.var/app/*/config(N/); do
    mkdir -p "$app_cfg/gtk-4.0" "$app_cfg/gtk-3.0" 2>/dev/null || continue
    cp -f "$HOME/.config/gtk-4.0/matugen.css" "$app_cfg/gtk-4.0/matugen.css" 2>/dev/null || true
    cp -f "$HOME/.config/gtk-4.0/gtk.css" "$app_cfg/gtk-4.0/gtk.css" 2>/dev/null || true
    cp -f "$HOME/.config/gtk-4.0/gtk-dark.css" "$app_cfg/gtk-4.0/gtk-dark.css" 2>/dev/null || true
    cp -f "$HOME/.config/gtk-4.0/settings.ini" "$app_cfg/gtk-4.0/settings.ini" 2>/dev/null || true

    cp -f "$HOME/.config/gtk-3.0/matugen.css" "$app_cfg/gtk-3.0/matugen.css" 2>/dev/null || true
    cp -f "$HOME/.config/gtk-3.0/gtk.css" "$app_cfg/gtk-3.0/gtk.css" 2>/dev/null || true
    cp -f "$HOME/.config/gtk-3.0/settings.ini" "$app_cfg/gtk-3.0/settings.ini" 2>/dev/null || true
done

# 4. Update xsettingsd configuration
if [[ -f "$HOME/.config/xsettingsd/xsettingsd.conf" ]]; then
    sed -i \
        -e "s|^Net/ThemeName .*|Net/ThemeName \"$target_theme\"|" \
        -e "s|^Net/IconThemeName .*|Net/IconThemeName \"$icon_theme\"|" \
        -e "s|^Gtk/CursorThemeName .*|Gtk/CursorThemeName \"$cursor_theme\"|" \
        -e "s|^Gtk/FontName .*|Gtk/FontName \"$font_name\"|" \
        "$HOME/.config/xsettingsd/xsettingsd.conf" 2>/dev/null || true
fi

# 5. Pulse portal and dconf so libadwaita and GTK4 apps reload live
if (( $+commands[dconf] )); then
    dconf write /org/gnome/desktop/interface/color-scheme "'$pulse_scheme'"
    sleep 0.08
    dconf write /org/gnome/desktop/interface/color-scheme "'$target_scheme'"

    dconf write /org/gnome/desktop/interface/gtk-theme "''"
    sleep 0.05
    dconf write /org/gnome/desktop/interface/gtk-theme "'$target_theme'"
elif (( $+commands[gsettings] )); then
    gsettings set org.gnome.desktop.interface color-scheme "$pulse_scheme" 2>/dev/null || true
    sleep 0.08
    gsettings set org.gnome.desktop.interface color-scheme "$target_scheme" 2>/dev/null || true

    gsettings set org.gnome.desktop.interface gtk-theme "" 2>/dev/null || true
    sleep 0.05
    gsettings set org.gnome.desktop.interface gtk-theme "$target_theme" 2>/dev/null || true
fi

if pgrep -x "xsettingsd" > /dev/null 2>&1; then
    pkill -HUP xsettingsd 2>/dev/null || true
fi
