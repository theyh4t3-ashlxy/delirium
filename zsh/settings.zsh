# settings: interactive zsh, prompt, and terminal customizer

PREFS_FILE="${ZDOTDIR:-$HOME/.config/zsh}/user_prefs.conf"

# single source of truth for stock defaults
typeset -ga DEFAULT_PREFS=(
    "SHOW_FASTFETCH=false"
    "SHOW_GREETING_ROAST=false"
    "SHOW_GIT_PROMPT=true"
    "SHOW_CMD_TIMER=true"
    "ENABLE_PSYCHO_ROASTS=true"
    "PROMPT_STYLE=two-line"
    "PROMPT_SYMBOL=❯"
    "PROMPT_ACCENT=primary"
    "KEY_BIND_MODE=vi"
    "AUTO_LS=false"
    "KAOMOJI_SET=cute"
    "PREFERRED_EDITOR=micro"
    "PREFERRED_FILE_MANAGER=yazi"
    "SHOW_PROMPT_BANTER=true"
    "SHOW_TIMESTAMP=true"
)

_open_file_manager() {
    local target="${1:-$HOME}"
    local fm="${PREFERRED_FILE_MANAGER:-yazi}"
    case "$fm" in
        yazi)
            if [[ -n "$TMUX" || -n "$KITTY_WINDOW_ID" || -t 1 ]]; then
                command yazi "$target"
            else
                uwsm app -- kitty -e yazi "$target" 2>/dev/null || kitty -e yazi "$target" 2>/dev/null || true
            fi
            ;;
        dolphin|nautilus|thunar)
            uwsm app -- "$fm" "$target" 2>/dev/null || "$fm" "$target" 2>/dev/null || xdg-open "$target" 2>/dev/null || true
            ;;
        *)
            if command -v "$fm" >/dev/null 2>&1; then
                "$fm" "$target" 2>/dev/null || true
            elif command -v yazi >/dev/null 2>&1; then
                command yazi "$target"
            else
                xdg-open "$target" 2>/dev/null || true
            fi
            ;;
    esac
}

_init_prefs() {
    print -l "${DEFAULT_PREFS[@]}" > "$PREFS_FILE"
}

# initialize if missing
[[ ! -f "$PREFS_FILE" ]] && _init_prefs

# load preferences into shell scope
source "$PREFS_FILE" 2>/dev/null || true

_reload_prompt() {
    (( $+functions[set_prompt_colors] )) && set_prompt_colors 2>/dev/null
    (( $+functions[build_prompt] )) && build_prompt 2>/dev/null
}

_save_pref() {
    local key="$1"
    local val="$2"

    if grep -q "^${key}=" "$PREFS_FILE" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${val}|" "$PREFS_FILE"
    else
        echo "${key}=${val}" >> "$PREFS_FILE"
    fi

    # assign to global shell scope without polluting subprocess environment tables
    typeset -g "${key}=${val}"
    
    if [[ "$key" == "PREFERRED_EDITOR" ]]; then
        export EDITOR="$val"
        export VISUAL="$val"
    fi

    _reload_prompt
}

# generic boolean toggle using zsh indirect parameter expansion
_toggle_pref() {
    local key="$1"
    local cur="${(P)key}"
    local next="true"
    [[ "$cur" == "true" ]] && next="false"
    _save_pref "$key" "$next"
}

settings() {
    local cmd="${1:-}"
    local arg="${2:-}"
    local choice="" f_choice="" ed_choice="" s_choice="" k_choice="" sym_choice="" acc_choice=""
    local -a items

    case "$cmd" in
        # fast config file launching
        dots)
            builtin cd "$HOME/.local/share/dotfiles" && ls
            return 0
            ;;
        nvim|neovim)
            local nvim_dir="$HOME/.local/share/dotfiles/nvim"
            local -a nvim_modules=(
                "init        (init.lua root entrypoint)"
                "keybinds    (custom IJKL home row binds, insert mode, shortcuts)"
                "options     (tabs, line numbers, smoothscroll, split settings)"
                "roast       (grim reality neovim roaster)"
                "cheatsheet  (interactive floating cheatsheet)"
                "colors      (catppuccin theme & highlight overrides)"
                "lazy        (lazy.lua package manager bootstrap)"
                "lsp         (language server configurations)"
                "treesitter  (syntax treesitter parsers & indent)"
                "telescope   (fuzzy finder & fzf native mappings)"
                "markdown    (render-markdown & live preview)"
                "gitsigns    (git diff hunks, blame, signs)"
                "directory   (browse ~/.local/share/dotfiles/nvim in file manager)"
            )
            local target_file=""

            if [[ -n "$arg" ]]; then
                case "$arg" in
                    init|root|main)             target_file="$nvim_dir/init.lua" ;;
                    keys|keybinds|binds|bind)   target_file="$nvim_dir/lua/config/keybinds.lua" ;;
                    opt|options|settings)       target_file="$nvim_dir/lua/config/options.lua" ;;
                    roast|roasts)               target_file="$nvim_dir/lua/config/roast.lua" ;;
                    cheat|cheatsheet|help)      target_file="$nvim_dir/lua/config/cheatsheet.lua" ;;
                    color|colors|theme)         target_file="$nvim_dir/lua/config/colors.lua" ;;
                    lazy|plugins|pkg)           target_file="$nvim_dir/lua/config/lazy.lua" ;;
                    lsp)                        target_file="$nvim_dir/lua/plugins/lsp/lsp.lua" ;;
                    treesitter|ts|tree)         target_file="$nvim_dir/lua/plugins/treesitter.lua" ;;
                    telescope|tele|find)        target_file="$nvim_dir/lua/plugins/telescope.lua" ;;
                    markdown|render|md)         target_file="$nvim_dir/lua/plugins/render-markdown.lua" ;;
                    preview|mp)                 target_file="$nvim_dir/lua/plugins/markdown-preview.lua" ;;
                    git|gitsigns|diff)          target_file="$nvim_dir/lua/plugins/gitsigns.lua" ;;
                    dir|directory|all)
                        _open_file_manager "$nvim_dir"
                        return 0
                        ;;
                    *)
                        if [[ -f "$nvim_dir/$arg" ]]; then
                            target_file="$nvim_dir/$arg"
                        elif [[ -f "$nvim_dir/lua/config/$arg" ]]; then
                            target_file="$nvim_dir/lua/config/$arg"
                        elif [[ -f "$nvim_dir/lua/config/${arg}.lua" ]]; then
                            target_file="$nvim_dir/lua/config/${arg}.lua"
                        elif [[ -f "$nvim_dir/lua/plugins/$arg" ]]; then
                            target_file="$nvim_dir/lua/plugins/$arg"
                        elif [[ -f "$nvim_dir/lua/plugins/${arg}.lua" ]]; then
                            target_file="$nvim_dir/lua/plugins/${arg}.lua"
                        fi
                        ;;
                esac
            fi

            if [[ -z "$target_file" ]]; then
                local n_choice
                n_choice=$(printf "%s\n" "${nvim_modules[@]}" | fzf --header="[neovim lua configs - choose module to edit]" --reverse --height=50%)
                [[ -z "$n_choice" ]] && return 0
                local sel="${n_choice%% *}"
                case "$sel" in
                    init)        target_file="$nvim_dir/init.lua" ;;
                    keybinds)    target_file="$nvim_dir/lua/config/keybinds.lua" ;;
                    options)     target_file="$nvim_dir/lua/config/options.lua" ;;
                    roast)       target_file="$nvim_dir/lua/config/roast.lua" ;;
                    cheatsheet)  target_file="$nvim_dir/lua/config/cheatsheet.lua" ;;
                    colors)      target_file="$nvim_dir/lua/config/colors.lua" ;;
                    lazy)        target_file="$nvim_dir/lua/config/lazy.lua" ;;
                    lsp)         target_file="$nvim_dir/lua/plugins/lsp/lsp.lua" ;;
                    treesitter)  target_file="$nvim_dir/lua/plugins/treesitter.lua" ;;
                    telescope)   target_file="$nvim_dir/lua/plugins/telescope.lua" ;;
                    markdown)    target_file="$nvim_dir/lua/plugins/render-markdown.lua" ;;
                    gitsigns)    target_file="$nvim_dir/lua/plugins/gitsigns.lua" ;;
                    directory)
                        _open_file_manager "$nvim_dir"
                        return 0
                        ;;
                esac
            fi

            if [[ -n "$target_file" && -f "$target_file" ]]; then
                ${EDITOR:-micro} "$target_file"
            else
                print -P "%F{red}󰅚 file not found: ${target_file}%f"
            fi
            return 0
            ;;
        zsh)
            local zsh_dir="$HOME/.local/share/dotfiles/zsh"
            local -a zsh_modules=(
                "aliases     (cli aliases, shorthand commands)"
                "prompt      (two-line reactive kaomoji prompt engine)"
                "settings    (interactive configuration hub & user preferences)"
                "tools       (modern cli tool enhancements - bat, eza, fzf)"
                "exports     (environment variables, path, default pager)"
                "core        (history, completion, directory options)"
                "functions   (custom utility functions & helpers)"
                "roast       (command typo psychological roaster)"
                "help        (quick cheatsheet & reference guide)"
                "prefs       (raw user_prefs.conf key-value pairs)"
                "directory   (browse ~/.local/share/dotfiles/zsh in file manager)"
            )
            local target_file=""

            if [[ -n "$arg" ]]; then
                case "$arg" in
                    aliases|alias)          target_file="$zsh_dir/aliases.zsh" ;;
                    prompt|theme)           target_file="$zsh_dir/prompt.zsh" ;;
                    settings|config)        target_file="$zsh_dir/settings.zsh" ;;
                    tools|tool)             target_file="$zsh_dir/tools.zsh" ;;
                    exports|export|env)     target_file="$zsh_dir/exports.zsh" ;;
                    core)                   target_file="$zsh_dir/core.zsh" ;;
                    functions|func)         target_file="$zsh_dir/functions.zsh" ;;
                    roast|roasts)           target_file="$zsh_dir/roast.zsh" ;;
                    help)                   target_file="$zsh_dir/help.zsh" ;;
                    prefs|user)             target_file="$PREFS_FILE" ;;
                    dir|directory|all)
                        _open_file_manager "$zsh_dir"
                        return 0
                        ;;
                    *)
                        if [[ -f "$zsh_dir/$arg" ]]; then
                            target_file="$zsh_dir/$arg"
                        elif [[ -f "$zsh_dir/${arg}.zsh" ]]; then
                            target_file="$zsh_dir/${arg}.zsh"
                        fi
                        ;;
                esac
            fi

            if [[ -z "$target_file" ]]; then
                local z_choice
                z_choice=$(printf "%s\n" "${zsh_modules[@]}" | fzf --header="[zsh configs - choose module to edit]" --reverse --height=45%)
                [[ -z "$z_choice" ]] && return 0
                local sel="${z_choice%% *}"
                case "$sel" in
                    aliases)    target_file="$zsh_dir/aliases.zsh" ;;
                    prompt)     target_file="$zsh_dir/prompt.zsh" ;;
                    settings)   target_file="$zsh_dir/settings.zsh" ;;
                    tools)      target_file="$zsh_dir/tools.zsh" ;;
                    exports)    target_file="$zsh_dir/exports.zsh" ;;
                    core)       target_file="$zsh_dir/core.zsh" ;;
                    functions)  target_file="$zsh_dir/functions.zsh" ;;
                    roast)      target_file="$zsh_dir/roast.zsh" ;;
                    help)       target_file="$zsh_dir/help.zsh" ;;
                    prefs)      target_file="$PREFS_FILE" ;;
                    directory)
                        _open_file_manager "$zsh_dir"
                        return 0
                        ;;
                esac
            fi

            if [[ -n "$target_file" && -f "$target_file" ]]; then
                ${EDITOR:-micro} "$target_file"
            else
                print -P "%F{red}󰅚 file not found: ${target_file}%f"
            fi
            return 0
            ;;
        hypr|hyprland)
            local hypr_dir="$HOME/.local/share/dotfiles/hypr"
            local -a hypr_modules=(
                "binds      (keybindings, mouse binds, hardware toggles)"
                "anims      (window animations & bezier curves)"
                "config     (general gaps, borders, layout, decoration)"
                "monitors   (display resolution, refresh rate, position)"
                "rules      (window rules, float rules, layer rules)"
                "startup    (autostart daemons, wallpaper, polkit)"
                "colors     (matugen theme color mappings)"
                "gestures   (touchpad workspace swipes)"
                "main       (hyprland.lua root loader)"
                "directory  (browse ~/.local/share/dotfiles/hypr in file manager)"
            )
            local target_file=""

            if [[ -n "$arg" ]]; then
                case "$arg" in
                    binds|bind|keys)        target_file="$hypr_dir/binds.lua" ;;
                    anims|anim|animations)  target_file="$hypr_dir/anims.lua" ;;
                    config|conf|general)    target_file="$hypr_dir/config.lua" ;;
                    monitors|monitor|mon)   target_file="$hypr_dir/monitors.lua" ;;
                    rules|rule)             target_file="$hypr_dir/rules.lua" ;;
                    startup|start|exec)     target_file="$hypr_dir/startup.lua" ;;
                    colors|color|theme)     target_file="$hypr_dir/colors.lua" ;;
                    gestures|gesture|swipe) target_file="$hypr_dir/gestures.lua" ;;
                    main|init|root)         target_file="$hypr_dir/hyprland.lua" ;;
                    dir|directory|all)
                        _open_file_manager "$hypr_dir"
                        return 0
                        ;;
                    *)
                        if [[ -f "$hypr_dir/$arg" ]]; then
                            target_file="$hypr_dir/$arg"
                        elif [[ -f "$hypr_dir/${arg}.lua" ]]; then
                            target_file="$hypr_dir/${arg}.lua"
                        fi
                        ;;
                esac
            fi

            if [[ -z "$target_file" ]]; then
                local h_choice
                h_choice=$(printf "%s\n" "${hypr_modules[@]}" | fzf --header="[hyprland lua configs - choose module to edit]" --reverse --height=45%)
                [[ -z "$h_choice" ]] && return 0
                local sel="${h_choice%% *}"
                case "$sel" in
                    binds)     target_file="$hypr_dir/binds.lua" ;;
                    anims)     target_file="$hypr_dir/anims.lua" ;;
                    config)    target_file="$hypr_dir/config.lua" ;;
                    monitors)  target_file="$hypr_dir/monitors.lua" ;;
                    rules)     target_file="$hypr_dir/rules.lua" ;;
                    startup)   target_file="$hypr_dir/startup.lua" ;;
                    colors)    target_file="$hypr_dir/colors.lua" ;;
                    gestures)  target_file="$hypr_dir/gestures.lua" ;;
                    main)      target_file="$hypr_dir/hyprland.lua" ;;
                    directory)
                        _open_file_manager "$hypr_dir"
                        return 0
                        ;;
                esac
            fi

            if [[ -n "$target_file" && -f "$target_file" ]]; then
                ${EDITOR:-micro} "$target_file"
            else
                print -P "%F{red}󰅚 file not found: ${target_file}%f"
            fi
            return 0
            ;;
        qs|quickshell)
            local qs_dir="$HOME/.local/share/dotfiles/quickshell"
            local -a qs_modules=(
                "shell       (shell.qml root desktop composition)"
                "theme       (Theme.qml matugen tokens & dimensions)"
                "settings    (settings.conf quickshell runtime state)"
                "widgets     (browse widgets folder)"
                "scripts     (cli.py, wallpaper.py, etc.)"
                "bar         (status bar components)"
                "directory   (browse ~/.local/share/dotfiles/quickshell in file manager)"
            )
            local target_file=""

            if [[ -n "$arg" ]]; then
                case "$arg" in
                    shell|main|root)        target_file="$qs_dir/shell.qml" ;;
                    theme|colors)           target_file="$qs_dir/Theme.qml" ;;
                    settings|conf)          target_file="$qs_dir/settings.conf" ;;
                    widgets|widget)         _open_file_manager "$qs_dir/widgets"; return 0 ;;
                    scripts|script)         _open_file_manager "$qs_dir/scripts"; return 0 ;;
                    bar)                    _open_file_manager "$qs_dir/bar"; return 0 ;;
                    dir|directory|all)
                        _open_file_manager "$qs_dir"
                        return 0
                        ;;
                    *)
                        if [[ -f "$qs_dir/$arg" ]]; then
                            target_file="$qs_dir/$arg"
                        elif [[ -f "$qs_dir/widgets/$arg" ]]; then
                            target_file="$qs_dir/widgets/$arg"
                        fi
                        ;;
                esac
            fi

            if [[ -z "$target_file" ]]; then
                local q_choice
                q_choice=$(printf "%s\n" "${qs_modules[@]}" | fzf --header="[quickshell configs - choose module to edit]" --reverse --height=40%)
                [[ -z "$q_choice" ]] && return 0
                local sel="${q_choice%% *}"
                case "$sel" in
                    shell)      target_file="$qs_dir/shell.qml" ;;
                    theme)      target_file="$qs_dir/Theme.qml" ;;
                    settings)   target_file="$qs_dir/settings.conf" ;;
                    widgets)    _open_file_manager "$qs_dir/widgets"; return 0 ;;
                    scripts)    _open_file_manager "$qs_dir/scripts"; return 0 ;;
                    bar)        _open_file_manager "$qs_dir/bar"; return 0 ;;
                    directory)  _open_file_manager "$qs_dir"; return 0 ;;
                esac
            fi

            if [[ -n "$target_file" && -f "$target_file" ]]; then
                ${EDITOR:-micro} "$target_file"
            fi
            return 0
            ;;
        nix|nixos)
            local nix_dir="$HOME/.local/share/dotfiles/nixos"
            local -a nix_modules=(
                "config      (configuration.nix - system packages, tlp, fan daemon)"
                "hardware    (hardware-configuration.nix - mount points & cpu drivers)"
                "flake       (flake.nix - inputs & system outputs)"
                "fan         (pkgs/fan-control/default.nix - fan control derivation)"
                "directory   (browse ~/.local/share/dotfiles/nixos in file manager)"
            )
            local target_file=""

            if [[ -n "$arg" ]]; then
                case "$arg" in
                    config|configuration|conf)  target_file="$nix_dir/configuration.nix" ;;
                    hardware|hw)                target_file="$nix_dir/hardware-configuration.nix" ;;
                    flake)                      target_file="$HOME/.local/share/dotfiles/flake.nix" ;;
                    fan|fancontrol)             target_file="$HOME/.local/share/dotfiles/pkgs/fan-control/default.nix" ;;
                    dir|directory|all)
                        _open_file_manager "$nix_dir"
                        return 0
                        ;;
                esac
            fi

            if [[ -z "$target_file" ]]; then
                local nx_choice
                nx_choice=$(printf "%s\n" "${nix_modules[@]}" | fzf --header="[nixos configs - choose file to edit]" --reverse --height=40%)
                [[ -z "$nx_choice" ]] && return 0
                local sel="${nx_choice%% *}"
                case "$sel" in
                    config)    target_file="$nix_dir/configuration.nix" ;;
                    hardware)  target_file="$nix_dir/hardware-configuration.nix" ;;
                    flake)     target_file="$HOME/.local/share/dotfiles/flake.nix" ;;
                    fan)       target_file="$HOME/.local/share/dotfiles/pkgs/fan-control/default.nix" ;;
                    directory) _open_file_manager "$nix_dir"; return 0 ;;
                esac
            fi

            if [[ -n "$target_file" && -f "$target_file" ]]; then
                ${EDITOR:-micro} "$target_file"
            fi
            return 0
            ;;
        micro)
            ${EDITOR:-micro} "$HOME/.config/micro/settings.json"
            return 0
            ;;
        list|show)
            print -P "%F{141}󰄛 zsh preferences (%B${PREFS_FILE}%b)%f"
            command cat "$PREFS_FILE"
            return 0
            ;;
        editor)
            if [[ -n "$arg" ]]; then
                _save_pref "PREFERRED_EDITOR" "$arg"
            else
                local next="nvim"
                [[ "${PREFERRED_EDITOR:-micro}" == "nvim" ]] && next="micro"
                _save_pref "PREFERRED_EDITOR" "$next"
            fi
            print -P "%F{green}󰄲 default editor set -> %B${PREFERRED_EDITOR}%b%f"
            return 0
            ;;
        fm|files|filemanager)
            if [[ -n "$arg" ]]; then
                _save_pref "PREFERRED_FILE_MANAGER" "$arg"
                print -P "%F{green}󰄲 preferred file manager set -> %B$arg%b%f"
            else
                local fm_pick
                fm_pick=$(printf "%s\n" \
                    "yazi      (terminal file manager with image previews & vim keybinds)" \
                    "dolphin   (kde plasma powerhouse gui)" \
                    "nautilus  (gnome modern minimal gui)" \
                    "thunar    (xfce classic lightweight gui)" \
                    | fzf --header="[choose your preferred file manager]" --reverse --height=35%)
                if [[ -n "$fm_pick" ]]; then
                    _save_pref "PREFERRED_FILE_MANAGER" "${fm_pick%% *}"
                    print -P "%F{green}󰄲 preferred file manager set -> %B${PREFERRED_FILE_MANAGER}%b%f"
                fi
            fi
            return 0
            ;;
        prompt|style)
            if [[ -n "$arg" ]]; then
                _save_pref "PROMPT_STYLE" "$arg"
                print -P "%F{green}󰄲 prompt style set -> %B$arg%b%f"
                return 0
            fi
            ;;
        symbol)
            if [[ -n "$arg" ]]; then
                _save_pref "PROMPT_SYMBOL" "$arg"
                print -P "%F{green}󰄲 prompt symbol set -> %B$arg%b%f"
                return 0
            fi
            ;;
        accent)
            if [[ -n "$arg" ]]; then
                _save_pref "PROMPT_ACCENT" "$arg"
                print -P "%F{green}󰄲 prompt accent set -> %B$arg%b%f"
                return 0
            fi
            ;;
        git)
            [[ -n "$arg" ]] && _save_pref "SHOW_GIT_PROMPT" "$arg" || _toggle_pref "SHOW_GIT_PROMPT"
            print -P "%F{green}󰄲 git prompt details -> %B${SHOW_GIT_PROMPT}%b%f"
            return 0
            ;;
        timer)
            [[ -n "$arg" ]] && _save_pref "SHOW_CMD_TIMER" "$arg" || _toggle_pref "SHOW_CMD_TIMER"
            print -P "%F{green}󰄲 execution timer -> %B${SHOW_CMD_TIMER}%b%f"
            return 0
            ;;
        roasts|roast)
            [[ -n "$arg" ]] && _save_pref "ENABLE_PSYCHO_ROASTS" "$arg" || _toggle_pref "ENABLE_PSYCHO_ROASTS"
            print -P "%F{green}󰄲 typo psychological roaster -> %B${ENABLE_PSYCHO_ROASTS}%b%f"
            return 0
            ;;
        greeting)
            [[ -n "$arg" ]] && _save_pref "SHOW_GREETING_ROAST" "$arg" || _toggle_pref "SHOW_GREETING_ROAST"
            print -P "%F{green}󰄲 existential greeting on open -> %B${SHOW_GREETING_ROAST}%b%f"
            return 0
            ;;
        fastfetch)
            [[ -n "$arg" ]] && _save_pref "SHOW_FASTFETCH" "$arg" || _toggle_pref "SHOW_FASTFETCH"
            print -P "%F{green}󰄲 fastfetch on open -> %B${SHOW_FASTFETCH}%b%f"
            return 0
            ;;
        autols|auto-ls)
            [[ -n "$arg" ]] && _save_pref "AUTO_LS" "$arg" || _toggle_pref "AUTO_LS"
            print -P "%F{green}󰄲 auto-ls on cd -> %B${AUTO_LS}%b%f"
            return 0
            ;;
        kaomoji|mood)
            if [[ -n "$arg" ]]; then
                _save_pref "KAOMOJI_SET" "$arg"
                print -P "%F{green}󰄲 kaomoji mood set -> %B$arg%b%f"
                return 0
            fi
            ;;
        banter)
            [[ -n "$arg" ]] && _save_pref "SHOW_PROMPT_BANTER" "$arg" || _toggle_pref "SHOW_PROMPT_BANTER"
            print -P "%F{green}󰄲 prompt banter -> %B${SHOW_PROMPT_BANTER}%b%f"
            return 0
            ;;
        clock|time)
            [[ -n "$arg" ]] && _save_pref "SHOW_TIMESTAMP" "$arg" || _toggle_pref "SHOW_TIMESTAMP"
            print -P "%F{green}󰄲 right prompt clock -> %B${SHOW_TIMESTAMP}%b%f"
            return 0
            ;;
        focus)
            _save_pref "KAOMOJI_SET" "none"
            _save_pref "SHOW_PROMPT_BANTER" "false"
            _save_pref "SHOW_GREETING_ROAST" "false"
            _save_pref "ENABLE_PSYCHO_ROASTS" "false"
            _save_pref "SHOW_FASTFETCH" "false"
            _save_pref "SHOW_CMD_TIMER" "false"
            _save_pref "SHOW_TIMESTAMP" "false"
            print -P "%F{green}󰄲 focus mode enabled (zero distractions, zero kaomoji)%f"
            return 0
            ;;
        aesthetic|rice)
            _save_pref "KAOMOJI_SET" "reactive"
            _save_pref "SHOW_PROMPT_BANTER" "true"
            _save_pref "SHOW_GREETING_ROAST" "true"
            _save_pref "ENABLE_PSYCHO_ROASTS" "true"
            _save_pref "SHOW_CMD_TIMER" "true"
            _save_pref "SHOW_TIMESTAMP" "true"
            print -P "%F{magenta}󰄛 aesthetic mode enabled (full personality restored)%f"
            return 0
            ;;
        reset)
            _init_prefs
            source "$PREFS_FILE"
            _reload_prompt
            print -P "%F{green}󰄲 reset zsh settings to factory stock%f"
            return 0
            ;;
    esac

    if ! (( $+commands[fzf] )); then
        print -P "%F{141}󰄛 zsh preferences%f"
        command cat "$PREFS_FILE"
        print -P "%F{244}tip: install fzf for the interactive menu or use 'config <key> <val>'%f"
        return 0
    fi

    while true; do
        items=(
            "󰈙 edit config files (nvim / hypr / zsh / qs / micro)"
            "󰞷 prompt style: [${PROMPT_STYLE:-two-line}]"
            "󰊠 prompt symbol: [${PROMPT_SYMBOL:-❯}]"
            "󰏘 prompt symbol accent: [${PROMPT_ACCENT:-primary}]"
            "󰄛 kaomoji mood set: [${KAOMOJI_SET:-reactive}]"
            "󰏘 default editor: [${PREFERRED_EDITOR:-micro}]"
            "󰉋 preferred file manager: [${PREFERRED_FILE_MANAGER:-yazi}]"
            " git details in prompt: [${SHOW_GIT_PROMPT:-true}]"
            "󰁕 execution timer in prompt: [${SHOW_CMD_TIMER:-true}]"
            "󰉋 auto-listing (ls) on cd: [${AUTO_LS:-false}]"
            "󰄛 fastfetch on open: [${SHOW_FASTFETCH:-false}]"
            "󰄛 existential greeting on open: [${SHOW_GREETING_ROAST:-false}]"
            "󰅚 psychological roaster on typo: [${ENABLE_PSYCHO_ROASTS:-true}]"
            "󰄲 prompt banter on wide screen: [${SHOW_PROMPT_BANTER:-true}]"
            "󰥔 prompt clock/time: [${SHOW_TIMESTAMP:-true}]"
            "󰌌 keybinding mode: [${KEY_BIND_MODE:-vi}]"
            "󰄲 focus mode: distraction-free preset"
            "󰄛 aesthetic mode: full rice preset"
            "󰄲 view help cheatsheet"
            "󰚰 recompile zsh bytecode (.zwc speedup)"
            "󰀦 purge .zwc bytecode cache (reset)"
            "󰅚 exit settings"
        )

        choice=$(printf "%s\n" "${items[@]}" | fzf --header="[󰄛 settings & config center - select to customize]" --reverse --height=60%)
        [[ -z "$choice" || "$choice" == *"exit settings"* ]] && break

        case "$choice" in
            *"edit config files"*)
                f_choice=$(printf "%s\n" \
                    "neovim       (~/.local/share/dotfiles/nvim/ -> keys, options, lsp...)" \
                    "hyprland     (~/.local/share/dotfiles/hypr/ -> binds, anims, rules...)" \
                    "zsh          (~/.local/share/dotfiles/zsh/  -> aliases, prompt, tools...)" \
                    "quickshell   (~/.local/share/dotfiles/quickshell/ -> shell.qml, Theme.qml...)" \
                    "nixos        (~/.local/share/dotfiles/nixos/ -> configuration.nix, flake...)" \
                    "micro        (~/.config/micro/settings.json)" \
                    "dotfiles     (open ~/.local/share/dotfiles in file manager)" \
                    | fzf --header="[choose config category to navigate]" --reverse --height=45%)
                case "$f_choice" in
                    *"neovim"*)     settings nvim ;;
                    *"hyprland"*)   settings hypr ;;
                    *"zsh"*)        settings zsh ;;
                    *"quickshell"*) settings qs ;;
                    *"nixos"*)      settings nixos ;;
                    *"micro"*)      ${EDITOR:-micro} "$HOME/.config/micro/settings.json" ;;
                    *"dotfiles"*)   _open_file_manager "$HOME/.local/share/dotfiles" ;;
                esac
                ;;
            *"default editor"*)
                ed_choice=$(printf "%s\n" "micro (quick & lightweight)" "nvim  (modal power editor)" | fzf --header="[choose default editor]" --reverse --height=30%)
                [[ -n "$ed_choice" ]] && _save_pref "PREFERRED_EDITOR" "${ed_choice%% *}"
                ;;
            *"preferred file manager"*)
                local fm_choice
                fm_choice=$(printf "%s\n" \
                    "yazi      (terminal file manager with image previews & vim keybinds)" \
                    "dolphin   (kde plasma powerhouse gui)" \
                    "nautilus  (gnome modern minimal gui)" \
                    "thunar    (xfce classic lightweight gui)" \
                    | fzf --header="[choose default file manager]" --reverse --height=35%)
                [[ -n "$fm_choice" ]] && _save_pref "PREFERRED_FILE_MANAGER" "${fm_choice%% *}"
                ;;
            *"prompt style"*)
                s_choice=$(printf "%s\n" \
                    "unhinged       (reactive kaomoji: flips table on error, side-eyes dirty git)" \
                    "gremlin        (the prompt symbol IS the reactive kaomoji)" \
                    "kaomoji-speech (kaomoji speaking your path in japanese quotes)" \
                    "cyberpunk      (sci-fi coordinates, power glyphs, neon delimiters)" \
                    "capsule        (modern rounded nerd font pills)" \
                    "two-line       (classic 2-line box with system, directory, and arrow)" \
                    "single-line    (compact user@host in path ❯)" \
                    "minimal        (clean path ❯)" \
                    "bracket        ([user@host path] ❯)" \
                    | fzf --header="[choose your prompt layout style]" --reverse --height=45%)
                [[ -n "$s_choice" ]] && _save_pref "PROMPT_STYLE" "${s_choice%% *}"
                ;;
            *"kaomoji mood set"*)
                k_choice=$(printf "%s\n" \
                    "none      (distraction-free: zero kaomoji, pure focus)" \
                    "reactive  (dynamic: melts down on error, side-eyes dirty git, sleeps on slow cmds)" \
                    "cats      (always cats: ᓚᘏᗢ, (=^･ω･^=), (=^･ｪ･^=))" \
                    "cute      (always cute: (◕‿◕✿), ( ˶•̀֊•́˶), (｡♥‿♥｡))" \
                    "doom      (cynical/burned out: (눈_눈), (x_x), (¬_¬ ))" \
                    "rage      (always angry: (╯°□°)╯彡┻━┻, (ノಠ益ಠ)ノ, (╬ಠ益ಠ))" \
                    "ascii     (classic text-only: (^_^), (>_<), (-_-))" \
                    | fzf --header="[choose your kaomoji mood personality]" --reverse --height=40%)
                [[ -n "$k_choice" ]] && _save_pref "KAOMOJI_SET" "${k_choice%% *}"
                ;;
            *"prompt symbol:"*)
                sym_choice=$(printf "%s\n" \
                    "❯  (default sharp arrow)" \
                    "▲  (cyberpunk triangle)" \
                    "⚡ (high voltage)" \
                    "󰄛  (hypr cat)" \
                    "λ  (lambda)" \
                    "$  (unix classic)" \
                    ">  (simple chevron)" \
                    "%  (zsh percent)" \
                    ">> (double chevron)" \
                    "󰊠 (diamond)" \
                    | fzf --header="[choose your prompt symbol character]" --reverse --height=40%)
                [[ -n "$sym_choice" ]] && _save_pref "PROMPT_SYMBOL" "${sym_choice%% *}"
                ;;
            *"prompt symbol accent"*)
                acc_choice=$(printf "%s\n" \
                    "primary    (wallpaper matugen primary accent)" \
                    "secondary  (wallpaper matugen secondary accent)" \
                    "tertiary   (wallpaper matugen tertiary accent)" \
                    "cyan       (bright cyan accent)" \
                    "green      (neon green accent)" \
                    "magenta    (lavender magenta accent)" \
                    "yellow     (golden yellow accent)" \
                    "white      (crisp white)" \
                    | fzf --header="[choose your prompt arrow color accent]" --reverse --height=40%)
                [[ -n "$acc_choice" ]] && _save_pref "PROMPT_ACCENT" "${acc_choice%% *}"
                ;;
            *"git details"*)               _toggle_pref "SHOW_GIT_PROMPT" ;;
            *"execution timer"*)           _toggle_pref "SHOW_CMD_TIMER" ;;
            *"auto-listing"*)              _toggle_pref "AUTO_LS" ;;
            *"fastfetch"*)                 _toggle_pref "SHOW_FASTFETCH" ;;
            *"existential greeting"*)      _toggle_pref "SHOW_GREETING_ROAST" ;;
            *"psychological roaster"*)      _toggle_pref "ENABLE_PSYCHO_ROASTS" ;;
            *"prompt banter"*)             _toggle_pref "SHOW_PROMPT_BANTER" ;;
            *"prompt clock"*)              _toggle_pref "SHOW_TIMESTAMP" ;;
            *"focus mode"*)
                _save_pref "KAOMOJI_SET" "none"
                _save_pref "SHOW_PROMPT_BANTER" "false"
                _save_pref "SHOW_GREETING_ROAST" "false"
                _save_pref "ENABLE_PSYCHO_ROASTS" "false"
                _save_pref "SHOW_FASTFETCH" "false"
                _save_pref "SHOW_CMD_TIMER" "false"
                _save_pref "SHOW_TIMESTAMP" "false"
                print -Pn "\n%F{green}󰄲 focus mode enabled (zero distractions, zero kaomoji). press enter...%f"
                read -r </dev/tty 2>/dev/null || true
                ;;
            *"aesthetic mode"*)
                _save_pref "KAOMOJI_SET" "reactive"
                _save_pref "SHOW_PROMPT_BANTER" "true"
                _save_pref "SHOW_GREETING_ROAST" "true"
                _save_pref "ENABLE_PSYCHO_ROASTS" "true"
                _save_pref "SHOW_CMD_TIMER" "true"
                _save_pref "SHOW_TIMESTAMP" "true"
                print -Pn "\n%F{magenta}󰄛 aesthetic mode enabled (full personality restored). press enter...%f"
                read -r </dev/tty 2>/dev/null || true
                ;;
            *"keybinding mode"*)
                if [[ "$KEY_BIND_MODE" == "emacs" ]]; then
                    _save_pref "KEY_BIND_MODE" "vi"
                    bindkey -v
                else
                    _save_pref "KEY_BIND_MODE" "emacs"
                    bindkey -e
                fi
                ;;
            *"view help cheatsheet"*)
                (( $+functions[dots_help] )) && dots_help || (( $+functions[help] )) && help
                print -Pn "\n%F{244}press enter to return to settings...%f"
                read -r </dev/tty 2>/dev/null || true
                ;;
            *"recompile zsh"*)
                (( $+functions[zrecompile] )) && zrecompile 2>/dev/null || (( $+functions[compile-zsh] )) && compile-zsh 2>/dev/null || true
                print -Pn "\n%F{green}󰄲 compiled. press enter to continue...%f"
                read -r </dev/tty 2>/dev/null || true
                ;;
            *"purge .zwc"*)
                (( $+functions[zclean] )) && zclean 2>/dev/null || true
                print -Pn "\n%F{yellow}󰀦 purged. press enter to continue...%f"
                read -r </dev/tty 2>/dev/null || true
                ;;
        esac
    done

    print -P "%F{green}󰄲 zsh preferences synced -> ${PREFS_FILE}%f"
}

alias config="settings"
