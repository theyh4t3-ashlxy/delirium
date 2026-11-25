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

# nmtui / whiptail ANSI-friendly palette (overridden by matugen.zsh if present)
export NEWT_COLORS="root=white,default:window=white,default:border=blue,default:title=blue,default:button=black,blue:actbutton=black,cyan:checkbox=white,default:actcheckbox=black,blue:entry=white,default:listbox=white,default:actlistbox=black,blue:sellistbox=black,cyan:actsellistbox=black,cyan"

# flatpak desktop applications and icons
export XDG_DATA_DIRS="$HOME/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

# bat syntax theme (pure ANSI follows kitty live dark/light reloads)
export BAT_THEME="ansi"
