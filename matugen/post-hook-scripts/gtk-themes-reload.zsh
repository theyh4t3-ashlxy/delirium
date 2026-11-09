#!/usr/bin/env zsh
# gtk-themes-reload.zsh - refresh GTK3/4 themes, toggle light/dark modes, and notify xsettingsd

# 1. Detect active light/dark mode
mode="dark"
if [[ -f "$HOME/.config/quickshell/settings.conf" ]]; then
    cfg_mode=$(grep -E '^\s*matugenMode\s*=' "$HOME/.config/quickshell/settings.conf" 2>/dev/null | head -n 1 | cut -d'"' -f2)
    [[ "$cfg_mode" == "light" || "$cfg_mode" == "dark" ]] && mode="$cfg_mode"
fi

# Validate against compiled matugen background luminance if available
if [[ -f "$HOME/.config/gtk-4.0/matugen.css" ]]; then
    bg_hex=$(grep -E '^\s*@define-color\s+window_bg_color\s+#' "$HOME/.config/gtk-4.0/matugen.css" | head -n 1 | sed -E 's/.*#([0-9a-fA-F]{6}).*/\1/')
    if [[ -n "$bg_hex" && ${#bg_hex} -eq 6 ]]; then
        r=$((16#${bg_hex[1,2]}))
        g=$((16#${bg_hex[3,4]}))
        b=$((16#${bg_hex[5,6]}))
        lum=$(( (r * 299 + g * 587 + b * 114) / 1000 ))
        if (( lum > 128 )); then
            mode="light"
        else
            mode="dark"
        fi
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

# 2. Sync theme tokens to active flatpak application config directories
for app_gtk4 in $HOME/.var/app/*/config/gtk-4.0(N/); do
    cp -f "$HOME/.config/gtk-4.0/matugen.css" "$app_gtk4/matugen.css" 2>/dev/null || true
    cp -f "$HOME/.config/gtk-4.0/gtk.css" "$app_gtk4/gtk.css" 2>/dev/null || true
    cp -f "$HOME/.config/gtk-4.0/gtk-dark.css" "$app_gtk4/gtk-dark.css" 2>/dev/null || true
done

for app_gtk3 in $HOME/.var/app/*/config/gtk-3.0(N/); do
    cp -f "$HOME/.config/gtk-3.0/matugen.css" "$app_gtk3/matugen.css" 2>/dev/null || true
    cp -f "$HOME/.config/gtk-3.0/gtk.css" "$app_gtk3/gtk.css" 2>/dev/null || true
done

# 3. Update host GTK settings.ini files
# GTK3 uses adw-gtk3 and gtk-application-prefer-dark-theme
if [[ -f "$HOME/.config/gtk-3.0/settings.ini" ]]; then
    sed -i "s/^gtk-theme-name=.*/gtk-theme-name=$target_theme/" "$HOME/.config/gtk-3.0/settings.ini" 2>/dev/null || true
    sed -i "s/^gtk-application-prefer-dark-theme=.*/gtk-application-prefer-dark-theme=$dark_bool/" "$HOME/.config/gtk-3.0/settings.ini" 2>/dev/null || true
fi

# GTK4 / Libadwaita relies on AdwStyleManager (dconf color-scheme) and hates gtk-application-prefer-dark-theme
if [[ -f "$HOME/.config/gtk-4.0/settings.ini" ]]; then
    sed -i '/^gtk-application-prefer-dark-theme=/d' "$HOME/.config/gtk-4.0/settings.ini" 2>/dev/null || true
    sed -i '/^gtk-theme-name=/d' "$HOME/.config/gtk-4.0/settings.ini" 2>/dev/null || true
fi

# 4. Update xsettingsd configuration
if [[ -f "$HOME/.config/xsettingsd/xsettingsd.conf" ]]; then
    sed -i "s/^Net\/ThemeName .*/Net\/ThemeName \"$target_theme\"/" "$HOME/.config/xsettingsd/xsettingsd.conf" 2>/dev/null || true
fi

# 5. Pulse portal and dconf so libadwaita and GTK4 apps drop their cache
if (( $+commands[dconf] )); then
    dconf write /org/gnome/desktop/interface/color-scheme "'$pulse_scheme'"
    sleep 0.1
    dconf write /org/gnome/desktop/interface/color-scheme "'$target_scheme'"

    dconf write /org/gnome/desktop/interface/gtk-theme "''"
    sleep 0.05
    dconf write /org/gnome/desktop/interface/gtk-theme "'$target_theme'"
elif (( $+commands[gsettings] )); then
    gsettings set org.gnome.desktop.interface color-scheme "$pulse_scheme" 2>/dev/null || true
    sleep 0.1
    gsettings set org.gnome.desktop.interface color-scheme "$target_scheme" 2>/dev/null || true

    gsettings set org.gnome.desktop.interface gtk-theme "" 2>/dev/null || true
    sleep 0.05
    gsettings set org.gnome.desktop.interface gtk-theme "$target_theme" 2>/dev/null || true
fi

# 6. Poke xsettingsd if running
if pgrep -x "xsettingsd" > /dev/null 2>&1; then
    pkill -HUP xsettingsd 2>/dev/null || true
fi
