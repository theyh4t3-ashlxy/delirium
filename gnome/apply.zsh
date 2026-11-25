#!/usr/bin/env zsh
# apply.zsh — load delirium's GNOME dconf layout and trigger Material You shell/wallpaper sync
setopt ERR_EXIT NO_UNSET PIPE_FAIL

SCRIPT_DIR="${0:A:h}"
DCONF_FILE="$SCRIPT_DIR/dconf.ini"
RELOAD_HOOK="$HOME/.local/share/dotfiles/matugen/post-hook-scripts/gnome-theme-reload.zsh"

if ! (( $+commands[dconf] )); then
    print -u2 "dconf binary not found"
    exit 1
fi

if [[ ! -f "$DCONF_FILE" ]]; then
    print -u2 "missing $DCONF_FILE"
    exit 1
fi

dconf load /org/gnome/ < "$DCONF_FILE"
print -P "%F{120}󰄲%f loaded gnome dconf profile from $DCONF_FILE"

THEME_CSS="$HOME/.local/share/themes/Matugen/gnome-shell/gnome-shell.css"
if [[ ! -f "$THEME_CSS" ]] && (( $+commands[matugen] )) && [[ -e "$HOME/.curr_wall_static.jpg" ]]; then
    matugen image "$(readlink -f "$HOME/.curr_wall_static.jpg")" -m dark -t scheme-tonal-spot --source-color-index 0 >/dev/null 2>&1 || true
fi

if [[ -x "$RELOAD_HOOK" ]]; then
    "$RELOAD_HOOK" || true
    print -P "%F{120}󰄲%f synced matugen gnome shell theme, accent, and wallpaper"
fi
