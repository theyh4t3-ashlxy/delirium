#!/usr/bin/env zsh
# ptyxis-theme-reload.zsh — trigger native Ptyxis dconf palette refresh on wallpaper change

if [[ ! -f /.flatpak-info ]] && [[ "${DBUS_SESSION_BUS_ADDRESS:-}" == *"/run/flatpak/bus"* || -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
    _host_bus="${XDG_RUNTIME_DIR:-/run/user/$UID}/bus"
    [[ -S "$_host_bus" ]] && export DBUS_SESSION_BUS_ADDRESS="unix:path=$_host_bus"
fi

(( $+commands[dconf] )) || exit 0

uuid=$(dconf read /org/gnome/Ptyxis/default-profile-uuid 2>/dev/null | tr -d "'")
[[ -n "$uuid" ]] || exit 0

key="/org/gnome/Ptyxis/Profiles/${uuid}/palette"
cur=$(dconf read "$key" 2>/dev/null || true)
if [[ "$cur" == "'matugen'" ]]; then
    dconf write "$key" "'gnome'" 2>/dev/null || true
    sleep 0.05
fi
dconf write "$key" "'matugen'" 2>/dev/null || true
