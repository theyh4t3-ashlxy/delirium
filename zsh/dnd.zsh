# dnd: do not disturb mode controller (synced with quickshell state settings.conf)

dnd() {
    local arg="${1:-toggle}"
    local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell"
    local conf_file="$state_dir/settings.conf"
    [[ -d "$state_dir" ]] || mkdir -p "$state_dir"
    [[ -f "$conf_file" ]] || touch "$conf_file"

    local current_dnd="false"
    if grep -Eq '^dnd=(true|1)\s*$' "$conf_file" 2>/dev/null; then
        current_dnd="true"
    fi

    case "$arg" in
        on|enable|1)
            if grep -q '^dnd=' "$conf_file"; then
                sed -i 's|^dnd=.*|dnd=true|' "$conf_file"
            else
                print -r -- 'dnd=true' >> "$conf_file"
            fi
            print -P "%F{magenta}󰂛 dnd enabled%f - %F{dim}notification toasts silenced%f"
            ;;
        off|disable|0)
            if grep -q '^dnd=' "$conf_file"; then
                sed -i 's|^dnd=.*|dnd=false|' "$conf_file"
            else
                print -r -- 'dnd=false' >> "$conf_file"
            fi
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
