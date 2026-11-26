# dnd: do not disturb mode controller (syncs quickshell settings.conf and GNOME banners)

dnd() {
    local arg="${1:-toggle}"
    local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell"
    local conf_file="$state_dir/settings.conf"
    local in_gnome=0
    [[ "${XDG_CURRENT_DESKTOP:l}" == *gnome* ]] && in_gnome=1

    [[ -d "$state_dir" ]] || mkdir -p "$state_dir"
    [[ -f "$conf_file" ]] || touch "$conf_file"

    local current_dnd="false"
    if (( in_gnome )) && (( $+commands[gsettings] )); then
        local banners
        banners=$(gsettings get org.gnome.desktop.notifications show-banners 2>/dev/null || true)
        [[ "$banners" == "false" ]] && current_dnd="true"
    elif grep -Eq '^dnd=(true|1)\s*$' "$conf_file" 2>/dev/null; then
        current_dnd="true"
    fi

    _dnd_write_conf() {
        local val="$1"
        if grep -q '^dnd=' "$conf_file"; then
            sed -i "s|^dnd=.*|dnd=${val}|" "$conf_file"
        else
            print -r -- "dnd=${val}" >> "$conf_file"
        fi
    }

    case "$arg" in
        on|enable|1)
            _dnd_write_conf "true"
            (( $+commands[gsettings] )) && gsettings set org.gnome.desktop.notifications show-banners false 2>/dev/null || true
            print -P "%F{magenta}󰂛 dnd enabled%f - %F{dim}notification toasts silenced%f"
            ;;
        off|disable|0)
            _dnd_write_conf "false"
            (( $+commands[gsettings] )) && gsettings set org.gnome.desktop.notifications show-banners true 2>/dev/null || true
            print -P "%F{green}󰂚 dnd disabled%f - %F{dim}notification toasts active%f"
            ;;
        status)
            if [[ "$current_dnd" == "true" ]]; then
                print -P "%F{magenta}󰂛 dnd is active%f (%F{dim}toasts muted%f)"
            else
                print -P "%F{green}󰂚 dnd is inactive%f (%F{dim}toasts unmuted%f)"
            fi
            ;;
        toggle|*)
            if [[ "$current_dnd" == "true" ]]; then
                dnd off
            else
                dnd on
            fi
            ;;
    esac
}
