# cheatsheet: dots, shell shortcuts, and desktop controls

dots_help() {
    local c_pri="%F{141}" c_sec="%F{117}" c_ter="%F{221}"
    local c_cmd="%F{120}" c_dim="%F{244}" c_rst="%f"

    print -P "${c_pri}󰄛 hyprland + quickshell + zsh cheat sheet${c_rst}"
    print -P "${c_dim}streamlined setup. zero corporate bloat.${c_rst}\n"

    local -a entries=(
        "HEADER:󰞷 zsh & terminal"
        "settings / config        | customize prompt, edit configs & tweak roasts"
        "help / cheatsheet        | display this cheat sheet"
        "c <dir> / up [n]         | smart cd with auto-ls / jump up n levels"
        "ls / l / la              | eza compact grid (l is identical to ls, la = all)"
        "ll                       | table view with sizes and git metadata"
        "Rlah / tree              | recursive listing / tree hierarchy view"
        "take <dir|url>           | smart mkdir & cd, or git clone & cd"
        "mkfile <path>            | create file & missing parent directories"
        "d                        | directory stack history (jump with cd -1)"
        "cat <file> / preview     | bat syntax highlighted / numbered view"
        "fif <query> / fe         | fuzzy grep inside files / fuzzy open file"
        "fdd / fdf / fdh          | fd fast search (directories/files/hidden)"
        "rgs / rgh / rgf          | ripgrep (smart-case, hidden, files)"
        "dus / df / free          | sorted dir sizes / disk usage / memory"
        "mc / edit                | micro editor"
        "yz / yazi                | terminal file manager with cwd sync on exit"
        "lg                       | lazygit terminal UI"
        "sz / reload              | re-source zsh config / restart shell"
        "compile-zsh              | recompile .zwc bytecode caches"
        "GAP:"
        "HEADER:󰏘 wallpaper & matugen"
        "wp random [category]     | roll random wallpaper + matugen color refresh"
        "wp select                | interactive wallpaper chooser via fzf"
        "wp fetch <query>         | download live wallpaper loop from giphy"
        "wp color <hex>           | set custom hex color scheme"
        "wp scan                  | rescan ~/.wallpapers directory"
        "color                    | hyprpicker screen hex color dropper"
        "dnd toggle               | toggle do not disturb (silence toasts)"
        "GAP:"
        "HEADER:󰄲 quickshell & session"
        "cli                      | interactive shell & desktop action control hub"
        "cli shell [qs|bs|toggle] | switch between quickshell and brain_shell"
        "cli reload               | gracefully restart active desktop shell"
        "cli status               | show active shell name, pids, and memory"
        "qs -d                    | launch quickshell background daemon"
        "quickshell kill          | murder running quickshell instance"
        "quickshell log -t 30     | tail live quickshell logs before it crashes"
        "nuke                     | interactive process sniper & auto-sudo guillotine"
        "GAP:"
        "HEADER:󰌌 hyprland hotkeys (binds.lua)"
        "Win + T                  | open kitty terminal (uwsm)"
        "Win + Q                  | close active window"
        "Win + F                  | toggle fullscreen"
        "Win + Space              | toggle floating window"
        "Win + Shift + Space      | toggle float and pin window"
        "Win + I / J / K / L      | focus window (the wrist-sparing layout)"
        "Win + Shift + IJKL       | move window (same layout, more adrenaline)"
        "Win + 1..9, 0            | switch to workspace 1..10"
        "Win + Alt + W            | roll random wallpaper on the fly"
        "Win + End                | lock screen (quickshell / hyprlock)"
        "Win + Shift + End        | exit session (graceful uwsm stop)"
        "Print                    | quickshell screenshot tool"
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

    print -P "\n${c_dim}type 'settings' to tweak your prompt and shell vibe.${c_rst}"
}

alias dots-help="dots_help"
alias cheatsheet="dots_help"
alias help="dots_help"
