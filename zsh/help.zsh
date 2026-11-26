# cheatsheet: dots, shell shortcuts, and desktop controls

dots_help() {
    local c_pri="%F{4}" c_sec="%F{6}" c_ter="%F{5}"
    local c_cmd="%F{2}" c_dim="%F{8}" c_rst="%f"

    print -P "${c_pri}󰄛 hyprland + quickshell + zsh cheat sheet${c_rst}"
    print -P "${c_dim}streamlined setup. ansi-synced across light and dark mode.${c_rst}\n"

    local -a entries=(
        "HEADER:󰞷 zsh & terminal"
        "settings / config        | customize prompt, custom builder, presets, & configs"
        "prompt-edit / save       | build, save, or swap custom named prompt profiles"
        "alt+s / ctrl+x e         | toggle sudo prefix on line / edit command in editor"
        "confirm / safe-rm / push | interactive [y]es/[n]o/[a]bort/[e]dit command guard"
        "mark / jump / marks      | quick folder bookmarks (fzf preview jump)"
        "scratch / undo / topcpu  | temp markdown note / soft-reset last commit / top procs"
        "bak <path>               | create timestamped backup copy (.bak.yyyymmdd_hhmmss)"
        "copyfile / copydir       | copy file contents or current directory to wayland clipboard"
        "dots_help / cheatsheet   | display this cheat sheet ('help' too when no args)"
        "c <dir> / up [n]         | smart cd with auto-ls / jump up n levels"
        "ls / l / la / ll / tree  | eza grid, long git table, recursive tree"
        "take <dir|url>           | mkdir & cd, or git clone (supports github.com/...)"
        "mkfile <path>            | create file & missing parent directories"
        "extract / ex <archive>   | unpack .tar.*, .zip, .7z, .rar, .zst automatically"
        "ports [filter] / serve   | listening sockets (ss) / quick local http server"
        "glog / gbr / gdiff       | interactive fzf git log, branch switcher, diff viewer"
        "fif [query] / fe [dir]   | live ripgrep finder / fd file open (kitty image preview)"
        "ctrl+t / alt+c           | fd fuzzy jumper with kitty image / bat preview"
        "calc <expr>              | float & math evaluator (e.g. calc '5/2')"
        "why [code]               | decode last exit code cleanly"
        "sysup / nixup [msg]      | update flake, rebuild nixos, commit lockfile & push"
        "critic                   | print a one-line developer check"
        "yz / yazi / mc / nvim    | yazi cwd sync, micro, neovim"
        "compile-zsh / unzwc      | compile .zwc bytecode cache / reset cache"
        "GAP:"
        "HEADER:󰏘 wallpaper, clipboard & theme"
        "wp / wp random [cat]     | fzf picker w/ kitty preview, or roll + reload theme"
        "wp preview / toggle      | inline kitty wallpaper thumb / toggle dark or light mode"
        "wp scheme [name] / wh    | change matugen scheme / random wallhaven pull"
        "wp gnome-sync            | sync ~/.wallpapers xml entries for gnome settings"
        "clip / pick / dnd toggle | fzf clipboard + kitty images / eyedropper / silence toasts"
        "GAP:"
        "HEADER:󰄲 cli & system scripts"
        "cli                      | interactive python control hub (hyprland & gnome)"
        "cli doctor [--fix]       | health check (shell/gnome, matugen, ptyxis, ansi, btop, zsh)"
        "cli theme / logs [n]     | palette blocks + kitty wallpaper thumb / tail shell logs"
        "cli shell [qs|bs|toggle] | switch between quickshell and brain_shell (hyprland)"
        "cli reload / status      | reload active shell or gnome themes / print session status"
        "cli capture / wp [...]   | screenshot/recording popup / forward wp commands"
        "cli lock / stats / power | lock session, btop, or power controls (hyprland & gnome)"
        "pwr / net [qr] / wx      | battery & fanctl box / network + wi-fi qr / open-meteo"
        "session / shot / fanctl  | lock, suspend, caffeine / screen capture / thinkpad fan"
        "nuke                     | interactive process sniper & auto-sudo kill"
        "GAP:"
        "HEADER:󰌌 hyprland hotkeys (binds.lua)"
        "win + t / q / f          | kitty terminal / close / fullscreen"
        "win + space / shift+spc  | toggle float / float + pin window"
        "win + i / j / k / l      | focus window (win + shift + ijkl moves window)"
        "win + alt + w / end      | random wallpaper / lock screen"
        "print                    | native screen capture overlay"
        "GAP:"
        "HEADER:󰍹 gnome hotkeys (dconf.ini)"
        "super + t / q / f        | kitty terminal / close / toggle fullscreen"
        "super + e / v / b        | nautilus files / clipboard / do-not-disturb"
        "super + alt + w          | roll random wallpaper & matugen theme"
        "super + l / super + end  | lock session"
    )

    local line cmd desc
    for line in "${entries[@]}"; do
        if [[ "$line" == "GAP:" ]]; then
            print ""
            continue
        fi

        if [[ "$line" == HEADER:* ]]; then
            print -P "${c_sec}${line#HEADER:}${c_rst}"
            continue
        fi

        cmd="${line%% | *}"
        desc="${line#* | }"

        if [[ "$cmd" == "win "* || "$cmd" == "print"* ]]; then
            print -P "  ${c_ter}${(r:24:)cmd}${c_rst} ${c_dim}${desc}${c_rst}"
        else
            print -P "  ${c_cmd}${(r:24:)cmd}${c_rst} ${c_dim}${desc}${c_rst}"
        fi
    done

    print -P "\n${c_dim}type 'settings' to tweak prompt, critic, transient mode, or configs.${c_rst}"
}

help() {
    if (( $# == 0 )); then
        dots_help
    else
        autoload -Uz run-help 2>/dev/null || true
        if (( $+functions[run-help] )); then
            run-help "$@"
        else
            man "$@"
        fi
    fi
}

alias dots-help="dots_help"
alias cheatsheet="dots_help"
