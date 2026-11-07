# editor preference linked to user_prefs.conf
export EDITOR="${PREFERRED_EDITOR:-micro}"
export VISUAL="${PREFERRED_EDITOR:-micro}"
export PAGER="less"
export LANG="en_US.UTF-8"
export TZDIR="/etc/zoneinfo"
export TZ="America/Chicago"
export QT_LOGGING_RULES="quickshell.dbus.warning=false;quickshell.service.powerprofiles.warning=false"

# less clean display
export LESS="-R -F -X -i"

# colorized man pages using bat syntax highlighting
if (( $+commands[bat] )); then
    export MANPAGER="sh -c 'col -bx | bat -l man -p'"
    export MANROFFOPT="-c"
fi

# xdg base directories
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"

# binary search path
typeset -U path
path=(
    "$HOME/.local/bin"
    "$HOME/bin"
    /run/wrappers/bin
    "$HOME/.nix-profile/bin"
    "/etc/profiles/per-user/$USER/bin"
    /run/current-system/sw/bin
    $path
)
export PATH

# nmtui / whiptail dark palette
export NEWT_COLORS="root=white,black:border=gray,black:window=white,black:shadow=black,gray:title=cyan,black:button=black,lightgray:actbutton=black,cyan:compactbutton=lightgray,black:checkbox=lightgray,black:actcheckbox=black,cyan:entry=white,gray:disentry=gray,black:label=lightgray,black:listbox=lightgray,black:actlistbox=black,cyan:sellistbox=black,cyan:actsellistbox=black,cyan:textbox=lightgray,black:acttextbox=lightgray,black:helpline=gray,black:roottext=gray,black:emptyscale=gray,black:fullscale=cyan,black"

# flatpak desktop applications and icons
export XDG_DATA_DIRS="$HOME/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

# bat syntax theme
export BAT_THEME="base16"
