# cheatsheet: dots, shell shortcuts, and desktop controls

dots_help() {
    local c_pri="%F{4}" c_sec="%F{6}" c_ter="%F{5}"
    local c_cmd="%F{2}" c_dim="%F{8}" c_rst="%f"

    print -P "${c_pri}󰄛 hyprland + quickshell + zsh cheat sheet${c_rst}"
    print -P "${c_dim}streamlined setup. ANSI-synced across light and dark mode.${c_rst}\n"

    local -a entries=(
        "HEADER:󰞷 zsh & terminal"
        "settings / config        | customize prompt, custom builder, presets, & configs"
        "prompt-edit / save / load| build, save, or swap custom named prompt profiles"
        "Alt+S / Ctrl+X E         | toggle sudo prefix on line / edit command in \$EDITOR"
        "bak <path>               | create timestamped backup copy (.bak.YYYYMMDD_HHMMSS)"
        "copyfile / copydir       | copy file contents or current directory to wayland clipboard"
        "dots_help / cheatsheet   | display this cheat sheet ('help' too when no args)"
        "c <dir> / up [n]         | smart cd with auto-ls / jump up n levels"
        "ls / l / la / ll / tree  | eza grid, long git table, recursive tree"
        "take <dir|url>           | mkdir & cd, or git clone (supports github.com/...)"
        "mkfile <path>            | create file & missing parent directories"
        "extract / ex <archive>   | unpack .tar.*, .zip, .7z, .rar, .zst automatically"
        "ports [filter] / serve   | listening sockets (ss) / quick local http server"
        "glog / gbr / gdiff       | interactive fzf git log, branch switcher, diff viewer"
        "fif <query> / fe         | fuzzy grep inside files / fuzzy open in \$EDITOR"
        "calc <expr>              | float & math evaluator (e.g. calc '5/2')"
        "why [code]               | decode last exit code cleanly"
        "sysup / nixup [msg]      | update flake, rebuild nixos, commit lockfile & push"
        "critic                   | print a one-line developer check"
        "yz / yazi / mc / nvim    | yazi cwd sync, micro, neovim"
        "compile-zsh / unzwc      | compile .zwc bytecode cache / reset cache"
        "GAP:"
        "HEADER:󰏘 wallpaper & matugen"
        "wp random [category]     | roll random wallpaper + reload ANSI & desktop colors"
        "wp dark / light / toggle | switch matugen dark or light mode live"
        "wp scheme [name]         | change matugen palette algorithm"
        "wp select / wh [query]   | local fzf picker / random wallhaven pull"
        "color / dnd toggle       | hyprpicker hex dropper / silence desktop toasts"
        "GAP:"
        "HEADER:󰄲 cli & desktop control"
        "cli                      | interactive fzf desktop control hub"
        "cli doctor               | health check (shell, hyprland, matugen, ansi, btop, zsh)"
        "cli theme / logs [n]     | show active wallpaper/palette blocks / tail shell logs"
        "cli shell [qs|bs|toggle] | switch between quickshell and Brain_Shell"
        "cli reload / status      | reload active shell / print pids and memory"
        "cli capture / wp [...]   | screenshot/recording popup / forward wp commands"
        "nuke                     | interactive process sniper & auto-sudo kill"
        "GAP:"
        "HEADER:󰌌 hyprland hotkeys (binds.lua)"
        "Win + T / Q / F          | kitty terminal / close / fullscreen"
        "Win + Space / Shift+Spc  | toggle float / float + pin window"
        "Win + I / J / K / L      | focus window (Win + Shift + IJKL moves window)"
        "Win + Alt + W / End      | random wallpaper / lock screen"
        "Print                    | native screen capture overlay"
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

        if [[ "$cmd" == "Win "* ]]; then
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
