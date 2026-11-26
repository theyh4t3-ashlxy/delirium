# settings: interactive zsh, prompt, and terminal customizer

PREFS_FILE="${PREFS_FILE:-${ZDOTDIR:-$HOME/.config/zsh}/user_prefs.conf}"

# single source of truth for stock defaults
typeset -ga DEFAULT_PREFS=(
    "SHOW_FASTFETCH=false"
    "SHOW_SESSION_CHECKIN=false"
    "SHOW_GIT_PROMPT=true"
    "SHOW_CMD_TIMER=true"
    "ENABLE_SYNTAX_CRITIC=true"
    "PROMPT_STYLE=two-line"
    "PROMPT_SYMBOL=❯"
    "PROMPT_ACCENT=primary"
    "PROMPT_BLANK_LINE=true"
    "SHOW_PWD_ONLY=false"
    "SHOW_SHLVL=true"
    "CMD_TIMER_MIN=1"
    "VI_CURSOR_SHAPE=true"
    "KEY_BIND_MODE=vi"
    "AUTO_LS=false"
    "KAOMOJI_SET=cute"
    "PREFERRED_EDITOR=micro"
    "PREFERRED_FILE_MANAGER=yazi"
    "SHOW_PROMPT_BANTER=true"
    "SHOW_TIMESTAMP=true"
    "TRANSIENT_PROMPT=false"
    "PROMPT_CUSTOM_LEFT=\$'{nl}{id} {out}in {dir}{context} {face}{nl}{sym} '"
    "PROMPT_CUSTOM_RIGHT=''"
    "PROMPT_CUSTOM_NAME=''"
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
    print -rl -- "${DEFAULT_PREFS[@]}" > "$PREFS_FILE"
}

# initialize if missing
[[ ! -f "$PREFS_FILE" ]] && _init_prefs

# load preferences into shell scope & migrate legacy variable names cleanly
source "$PREFS_FILE" 2>/dev/null || true
if [[ -n "${SHOW_GREETING_ROAST:-}" && -z "${SHOW_SESSION_CHECKIN:-}" ]]; then
    SHOW_SESSION_CHECKIN="$SHOW_GREETING_ROAST"
    sed -i 's|^SHOW_GREETING_ROAST=|SHOW_SESSION_CHECKIN=|' "$PREFS_FILE" 2>/dev/null || true
fi
if [[ -n "${ENABLE_PSYCHO_ROASTS:-}" && -z "${ENABLE_SYNTAX_CRITIC:-}" ]]; then
    ENABLE_SYNTAX_CRITIC="$ENABLE_PSYCHO_ROASTS"
    sed -i 's|^ENABLE_PSYCHO_ROASTS=|ENABLE_SYNTAX_CRITIC=|' "$PREFS_FILE" 2>/dev/null || true
fi
case "${PROMPT_STYLE:-}" in
    unhinged) PROMPT_STYLE="open-line"; sed -i 's|^PROMPT_STYLE=unhinged|PROMPT_STYLE=open-line|' "$PREFS_FILE" 2>/dev/null || true ;;
    gremlin) PROMPT_STYLE="face-prompt"; sed -i 's|^PROMPT_STYLE=gremlin|PROMPT_STYLE=face-prompt|' "$PREFS_FILE" 2>/dev/null || true ;;
    cyberpunk) PROMPT_STYLE="schematic"; sed -i 's|^PROMPT_STYLE=cyberpunk|PROMPT_STYLE=schematic|' "$PREFS_FILE" 2>/dev/null || true ;;
esac
case "${KAOMOJI_SET:-}" in
    doom) KAOMOJI_SET="deadpan"; sed -i 's|^KAOMOJI_SET=doom|KAOMOJI_SET=deadpan|' "$PREFS_FILE" 2>/dev/null || true ;;
    rage) KAOMOJI_SET="angry"; sed -i 's|^KAOMOJI_SET=rage|KAOMOJI_SET=angry|' "$PREFS_FILE" 2>/dev/null || true ;;
esac

_reload_prompt() {
    (( $+functions[_gp_reload] )) && _gp_reload 2>/dev/null || true
}

_quote_pref_val() {
    emulate -L zsh
    local val="$1"
    if [[ -z "$val" || "$val" == *[[:space:]\'\"\\$\`\{\}\(\)\[\]\|\&\;\<\>\?\*#%]* ]]; then
        REPLY="${(qqqq)val}"
    else
        REPLY="$val"
    fi
}

_save_pref() {
    emulate -L zsh
    local key="$1"
    local val="$2"
    local REPLY line updated=0
    local -a lines=()

    _quote_pref_val "$val"
    local entry="${key}=${REPLY}"

    if [[ -f "$PREFS_FILE" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ "$line" == "${key}="* ]]; then
                (( ! updated )) && lines+=("$entry")
                updated=1
            else
                lines+=("$line")
            fi
        done < "$PREFS_FILE"
    fi
    (( ! updated )) && lines+=("$entry")

    print -r -- "${(F)lines}" > "$PREFS_FILE"

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

_prompt_presets_dir() {
    print -r -- "${XDG_STATE_HOME:-$HOME/.local/state}/zsh/prompts"
}

_prompt_preview() {
    (
        PROMPT_STYLE="${1:-custom}"
        PROMPT_CUSTOM_LEFT="${2-${PROMPT_CUSTOM_LEFT-}}"
        PROMPT_CUSTOM_RIGHT="${3-${PROMPT_CUSTOM_RIGHT-}}"
        _GP_EXIT="${4:-0}"
        if (( $+functions[_gp_colors] )); then
            _gp_colors
            _gp_git
            _gp_mood
            _gp_build
            print -P -- "${_GP_LEFT}ls -la"
            [[ -n "$_GP_RIGHT" ]] && print -P -- "%F{8}rprompt:%f ${_GP_RIGHT}"
        fi
    )
}

_prompt_save_preset() {
    emulate -L zsh
    local name="${1:-}" dir REPLY
    dir="$(_prompt_presets_dir)"

    if [[ -z "$name" ]]; then
        vared -p "preset name (e.g. chill-bar): " name || return 0
    fi
    name="${name//[^[:alnum:]_.-]/-}"
    name="${name##[-.]}"
    [[ -z "$name" ]] && { print -P "%F{red}󰅚 invalid preset name%f"; return 1; }

    mkdir -p "$dir"
    local target="$dir/${name}.prompt"
    local -a keys=(
        PROMPT_STYLE PROMPT_SYMBOL PROMPT_ACCENT PROMPT_BLANK_LINE
        SHOW_PWD_ONLY KAOMOJI_SET TRANSIENT_PROMPT
        PROMPT_CUSTOM_LEFT PROMPT_CUSTOM_RIGHT
    )
    local -a lines=("# saved prompt preset: ${name}")
    local k val
    for k in "${keys[@]}"; do
        val="${(P)k-}"
        _quote_pref_val "$val"
        lines+=("${k}=${REPLY}")
    done
    _quote_pref_val "$name"
    lines+=("PROMPT_CUSTOM_NAME=${REPLY}")

    print -r -- "${(F)lines}" > "$target"
    _save_pref "PROMPT_CUSTOM_NAME" "$name"
    print -P "%F{green}󰄲 saved prompt preset -> %B${name}%b (%F{8}${target}%f)"
}

_prompt_load_preset() {
    emulate -L zsh
    local name="${1:-}" dir target=""
    dir="$(_prompt_presets_dir)"
    [[ -d "$dir" ]] || { print -P "%F{yellow}󰀦 no saved prompt presets yet%f"; return 0; }

    if [[ -z "$name" ]]; then
        local -a files=("$dir"/*.prompt(N:t:r))
        (( ${#files} )) || { print -P "%F{yellow}󰀦 no saved prompt presets yet%f"; return 0; }
        name=$(printf "%s\n" "${files[@]}" | fzf \
            --header="[saved prompt presets - select to load]" \
            --preview="cat '$dir/{}.prompt'" \
            --preview-window=right:55%:wrap \
            --reverse --height=45%)
        [[ -z "$name" ]] && return 0
    fi

    target="$dir/${name%.prompt}.prompt"
    [[ -f "$target" ]] || { print -P "%F{red}󰅚 preset not found: ${name}%f"; return 1; }

    local raw_data k v
    raw_data=$(
        unset PROMPT_STYLE PROMPT_SYMBOL PROMPT_ACCENT PROMPT_BLANK_LINE \
            SHOW_PWD_ONLY KAOMOJI_SET TRANSIENT_PROMPT \
            PROMPT_CUSTOM_LEFT PROMPT_CUSTOM_RIGHT PROMPT_CUSTOM_NAME
        source "$target" 2>/dev/null || exit 1
        for k in PROMPT_STYLE PROMPT_SYMBOL PROMPT_ACCENT PROMPT_BLANK_LINE \
            SHOW_PWD_ONLY KAOMOJI_SET TRANSIENT_PROMPT \
            PROMPT_CUSTOM_LEFT PROMPT_CUSTOM_RIGHT PROMPT_CUSTOM_NAME; do
            if (( ${+parameters[$k]} )); then
                printf '%s\0%s\0' "$k" "${(P)k}"
            fi
        done
    ) || { print -P "%F{red}󰅚 failed to read preset: ${target}%f"; return 1; }

    local -a kv=("${(@0)raw_data}")
    local -i idx=1 loaded_name=0
    while (( idx + 1 <= ${#kv} )); do
        k="${kv[$idx]}"
        v="${kv[$((idx + 1))]}"
        [[ "$k" == "PROMPT_CUSTOM_NAME" ]] && loaded_name=1
        _save_pref "$k" "$v"
        (( idx += 2 ))
    done
    (( ! loaded_name )) && _save_pref "PROMPT_CUSTOM_NAME" "${name%.prompt}"

    print -P "%F{green}󰄲 loaded prompt preset -> %B${name%.prompt}%b%f"
    _prompt_preview "${PROMPT_STYLE:-two-line}"
}

_prompt_presets_hub() {
    emulate -L zsh
    local dir choice del_name
    dir="$(_prompt_presets_dir)"

    while true; do
        local -i pcount=0
        if [[ -d "$dir" ]]; then
            local -a pfiles=("$dir"/*.prompt(N))
            pcount=${#pfiles}
        fi
        choice=$(printf "%s\n" \
            "󰉋 load saved preset (${pcount} available)" \
            "󰆓 save current prompt as new preset" \
            "󰆴 delete a saved preset" \
            "󰈙 open presets folder (${dir})" \
            "󰁍 back" \
            | fzf --header="[saved prompt profiles - active: ${PROMPT_CUSTOM_NAME:-none}]" --reverse --height=35%)
        [[ -z "$choice" || "$choice" == *"back"* ]] && break

        case "$choice" in
            *"load saved"*)    _prompt_load_preset ;;
            *"save current"*)  _prompt_save_preset ;;
            *"open presets"*)  mkdir -p "$dir"; _open_file_manager "$dir" ;;
            *"delete a saved"*)
                if [[ -d "$dir" ]]; then
                    local -a files=("$dir"/*.prompt(N:t:r))
                    (( ${#files} )) || continue
                    del_name=$(printf "%s\n" "${files[@]}" | fzf --header="[choose preset to delete]" --reverse --height=35%)
                    if [[ -n "$del_name" && -f "$dir/${del_name}.prompt" ]]; then
                        command rm -f -- "$dir/${del_name}.prompt"
                        [[ "${PROMPT_CUSTOM_NAME:-}" == "$del_name" ]] && _save_pref "PROMPT_CUSTOM_NAME" ""
                        print -P "%F{yellow}󰆴 deleted preset: ${del_name}%f"
                    fi
                fi
                ;;
        esac
    done
}

_custom_prompt_builder() {
    emulate -L zsh
    local choice tok_choice tpl_choice edited=""
    local -a left_tokens=(
        "{nl}      newline (for multi-line prompt)"
        "{id}      user@host"
        "{user}    username only"
        "{host}    hostname only"
        "{dir}     working dir (respects shortpath setting)"
        "{pwd}     current folder name only"
        "{full}    full ~/... path"
        "{git}     git branch badge + counts"
        "{branch}  plain branch name only"
        "{venv}    python/conda env badge"
        "{extras}  lock / jobs / ssh / shlvl"
        "{context} {git}{venv}{extras} combined"
        "{face}    active kaomoji"
        "{sym}     configured prompt symbol"
        "{dollar}  classic \$ / # indicator"
        "{time24}  24h clock HH:MM:SS"
        "{pri}     primary theme color"
        "{sec}     secondary theme color"
        "{ter}     tertiary theme color"
        "{out}     muted outline color"
        "{ok}      green color"
        "{wrn}     yellow color"
        "{err}     red color"
        "{acc}     accent / exit status color"
        "{rst}     reset foreground color (%f)"
    )
    local -a right_tokens=(
        "{exit}    non-zero exit code badge"
        "{timer}   last command duration"
        "{banter}  wide-screen banter line"
        "{time}    timestamp (respects clock toggle)"
        "{time24}  24h clock always"
        "{time12}  12h clock always"
        "{date}    mm/dd date"
        "{git}     git badge"
        "{face}    active kaomoji"
    )

    while true; do
        local d_left="${PROMPT_CUSTOM_LEFT-}"
        [[ -z "$d_left" ]] && d_left='{nl}{id} {out}in {dir}{context} {face}{nl}{sym} '
        print ""
        print -P "%F{4}󰞷 live custom prompt preview:%f"
        _prompt_preview "custom"
        print -P "%F{8}left:%f  ${d_left}"
        print -P "%F{8}right:%f ${PROMPT_CUSTOM_RIGHT:-<auto default right prompt>}"

        choice=$(printf "%s\n" \
            "󰏫 edit left template" \
            "󰏫 edit right template (or 'none' to hide)" \
            "󰐕 append token to left template" \
            "󰐕 append token to right template" \
            "󰚰 load starter custom template" \
            "󰄲 apply & activate PROMPT_STYLE=custom" \
            "󰆓 save current prompt as named preset" \
            "󰉋 saved presets (load / delete)" \
            "󰁍 back" \
            | fzf --header="[custom prompt builder - tokens + zsh % codes supported]" --reverse --height=45%)
        [[ -z "$choice" || "$choice" == *"back"* ]] && break

        case "$choice" in
            *"edit left template"*)
                print -P "%F{8}tokens: {nl} {id} {user} {host} {dir} {pwd} {full} {git} {branch} {venv} {extras} {face} {sym} {dollar} {pri} {sec} {ter} {out} {acc} {rst}%f"
                edited="$d_left"
                if vared -p "left> " edited; then
                    _save_pref "PROMPT_CUSTOM_LEFT" "$edited"
                    _save_pref "PROMPT_STYLE" "custom"
                    _save_pref "PROMPT_CUSTOM_NAME" ""
                fi
                ;;
            *"edit right template"*)
                print -P "%F{8}tokens: {exit} {timer} {banter} {time} {time24} {time12} {date} (blank = default smart right prompt, 'none' = empty)%f"
                edited="${PROMPT_CUSTOM_RIGHT-}"
                if vared -p "right> " edited; then
                    _save_pref "PROMPT_CUSTOM_RIGHT" "$edited"
                    _save_pref "PROMPT_STYLE" "custom"
                    _save_pref "PROMPT_CUSTOM_NAME" ""
                fi
                ;;
            *"append token to left"*)
                tok_choice=$(printf "%s\n" "${left_tokens[@]}" | fzf --header="[choose token to append to left template]" --reverse --height=55%)
                if [[ -n "$tok_choice" ]]; then
                    local tok="${tok_choice%% *}"
                    local cur="$d_left"
                    local sep=""
                    [[ -n "$cur" && "$cur" != *" " && "$cur" != *"{nl}" && "$tok" != "{nl}" && "$tok" != "{git}" && "$tok" != "{venv}" && "$tok" != "{extras}" && "$tok" != "{context}" && "$tok" != "{rst}" ]] && sep=" "
                    _save_pref "PROMPT_CUSTOM_LEFT" "${cur}${sep}${tok}"
                    _save_pref "PROMPT_STYLE" "custom"
                    _save_pref "PROMPT_CUSTOM_NAME" ""
                fi
                ;;
            *"append token to right"*)
                tok_choice=$(printf "%s\n" "${right_tokens[@]}" | fzf --header="[choose token to append to right template]" --reverse --height=45%)
                if [[ -n "$tok_choice" ]]; then
                    local tok="${tok_choice%% *}"
                    local cur="${PROMPT_CUSTOM_RIGHT-}"
                    [[ "$cur" == "none" ]] && cur=""
                    local sep=""
                    [[ -n "$cur" && "$cur" != *" " ]] && sep=" "
                    _save_pref "PROMPT_CUSTOM_RIGHT" "${cur}${sep}${tok}"
                    _save_pref "PROMPT_STYLE" "custom"
                    _save_pref "PROMPT_CUSTOM_NAME" ""
                fi
                ;;
            *"starter custom"*)
                tpl_choice=$(printf "%s\n" \
                    "standard-two   :: {nl}{id} {out}in {dir}{context} {face}{nl}{sym} " \
                    "bash-remix     :: {ok}{user}{out}@{ok}{host}{out}:{pri}{dir}{context} {face} {dollar} " \
                    "minimal-clean  :: {pwd}{context} {face} {sym} " \
                    "wide-box       :: {nl}{out}╭─ {id} {out}:: {dir}{context} {face}{nl}{out}╰─ {sym} " \
                    "time-capsule   :: {out}[{time24}{out}] {dir}{git}{venv} {face} {sym} " \
                    "pure-kaomoji   :: {nl}{dir}{context} {face}{nl}{sym} " \
                    | fzf --header="[choose a custom starter template]" --reverse --height=40%)
                if [[ -n "$tpl_choice" ]]; then
                    _save_pref "PROMPT_CUSTOM_LEFT" "${tpl_choice#* :: }"
                    _save_pref "PROMPT_STYLE" "custom"
                    _save_pref "PROMPT_CUSTOM_NAME" ""
                fi
                ;;
            *"apply & activate"*)
                _save_pref "PROMPT_STYLE" "custom"
                ;;
            *"save current"*)
                _prompt_save_preset
                ;;
            *"saved presets"*)
                _prompt_presets_hub
                ;;
        esac
    done
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
                "roast       (neovim home-row critic)"
                "cheatsheet  (interactive floating cheatsheet)"
                "colors      (ANSI highlight overrides)"
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
                "functions   (custom utility functions & git helpers)"
                "critic      (command typo syntax critic & session check-in)"
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
                    critic|roast|roasts)    target_file="$zsh_dir/roast.zsh" ;;
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
                    critic)     target_file="$zsh_dir/roast.zsh" ;;
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
            ${EDITOR:-nvim} "$HOME/.config/micro/settings.json"
            return 0
            ;;
        btop)
            ${EDITOR:-nvim} "$HOME/.local/share/dotfiles/btop/btop.conf"
            return 0
            ;;
        kitty)
            ${EDITOR:-nvim} "$HOME/.local/share/dotfiles/kitty/kitty.conf"
            return 0
            ;;
        matugen)
            ${EDITOR:-nvim} "$HOME/.local/share/dotfiles/matugen/config.toml"
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
                _save_pref "PROMPT_CUSTOM_NAME" ""
                print -P "%F{green}󰄲 prompt style set -> %B$arg%b%f"
                return 0
            fi
            ;;
        custom|builder|prompt-edit)
            _custom_prompt_builder
            return 0
            ;;
        prompts|presets|load-prompt)
            if [[ -n "$arg" ]]; then
                _prompt_load_preset "$arg"
            else
                _prompt_presets_hub
            fi
            return 0
            ;;
        save-prompt)
            _prompt_save_preset "$arg"
            return 0
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
        blankline|newline)
            [[ -n "$arg" ]] && _save_pref "PROMPT_BLANK_LINE" "$arg" || _toggle_pref "PROMPT_BLANK_LINE"
            print -P "%F{green}󰄲 prompt blank spacer line -> %B${PROMPT_BLANK_LINE}%b%f"
            return 0
            ;;
        shortpath|pwdonly|pwd-only)
            [[ -n "$arg" ]] && _save_pref "SHOW_PWD_ONLY" "$arg" || _toggle_pref "SHOW_PWD_ONLY"
            print -P "%F{green}󰄲 short folder-only path -> %B${SHOW_PWD_ONLY}%b%f"
            return 0
            ;;
        shlvl)
            [[ -n "$arg" ]] && _save_pref "SHOW_SHLVL" "$arg" || _toggle_pref "SHOW_SHLVL"
            print -P "%F{green}󰄲 nested shell badge ([lvl:N]) -> %B${SHOW_SHLVL}%b%f"
            return 0
            ;;
        timermin|timer-min)
            if [[ -n "$arg" ]]; then
                _save_pref "CMD_TIMER_MIN" "$arg"
                print -P "%F{green}󰄲 command timer threshold -> %B${CMD_TIMER_MIN}s%b%f"
                return 0
            fi
            ;;
        vicursor|vi-cursor)
            [[ -n "$arg" ]] && _save_pref "VI_CURSOR_SHAPE" "$arg" || _toggle_pref "VI_CURSOR_SHAPE"
            print -P "%F{green}󰄲 vi cursor shape (bar/block) -> %B${VI_CURSOR_SHAPE}%b%f"
            return 0
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
        critic|roasts|roast)
            [[ -n "$arg" ]] && _save_pref "ENABLE_SYNTAX_CRITIC" "$arg" || _toggle_pref "ENABLE_SYNTAX_CRITIC"
            print -P "%F{green}󰄲 syntax critic -> %B${ENABLE_SYNTAX_CRITIC}%b%f"
            return 0
            ;;
        checkin|greeting)
            [[ -n "$arg" ]] && _save_pref "SHOW_SESSION_CHECKIN" "$arg" || _toggle_pref "SHOW_SESSION_CHECKIN"
            print -P "%F{green}󰄲 session check-in on open -> %B${SHOW_SESSION_CHECKIN}%b%f"
            return 0
            ;;
        transient)
            [[ -n "$arg" ]] && _save_pref "TRANSIENT_PROMPT" "$arg" || _toggle_pref "TRANSIENT_PROMPT"
            print -P "%F{green}󰄲 transient prompt collapse -> %B${TRANSIENT_PROMPT}%b%f"
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
            _save_pref "SHOW_SESSION_CHECKIN" "false"
            _save_pref "ENABLE_SYNTAX_CRITIC" "false"
            _save_pref "SHOW_FASTFETCH" "false"
            _save_pref "SHOW_CMD_TIMER" "false"
            _save_pref "SHOW_TIMESTAMP" "false"
            _save_pref "TRANSIENT_PROMPT" "true"
            print -P "%F{green}󰄲 focus mode enabled (zero distractions, transient prompt)%f"
            return 0
            ;;
        aesthetic|rice|expressive)
            _save_pref "KAOMOJI_SET" "reactive"
            _save_pref "SHOW_PROMPT_BANTER" "true"
            _save_pref "SHOW_SESSION_CHECKIN" "true"
            _save_pref "ENABLE_SYNTAX_CRITIC" "true"
            _save_pref "SHOW_CMD_TIMER" "true"
            _save_pref "SHOW_TIMESTAMP" "true"
            print -P "%F{magenta}󰄛 expressive preset enabled (reactive kaomoji, banter, and timer)%f"
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
            "󰈙 edit config files (nvim / hypr / zsh / qs / btop / kitty / matugen)"
            "󰞷 prompt style: [${PROMPT_STYLE:-two-line}]"
            "󰏫 custom prompt builder (${PROMPT_CUSTOM_NAME:-edit template})"
            "󰉋 saved prompt presets (save / load / delete)"
            "󰊠 prompt symbol: [${PROMPT_SYMBOL:-❯}]"
            "󰏘 prompt symbol accent: [${PROMPT_ACCENT:-primary}]"
            "󰄛 kaomoji mood set: [${KAOMOJI_SET:-reactive}]"
            "󰁕 transient prompt collapse: [${TRANSIENT_PROMPT:-false}]"
            "󰌑 blank line before multi-line prompt: [${PROMPT_BLANK_LINE:-true}]"
            "󰉋 short folder-only path: [${SHOW_PWD_ONLY:-false}]"
            "󰆍 nested shell badge ([lvl:N]): [${SHOW_SHLVL:-true}]"
            "󰏘 default editor: [${PREFERRED_EDITOR:-micro}]"
            "󰉋 preferred file manager: [${PREFERRED_FILE_MANAGER:-yazi}]"
            " git details in prompt: [${SHOW_GIT_PROMPT:-true}]"
            "󰁕 execution timer in prompt: [${SHOW_CMD_TIMER:-true}]"
            "󰔟 timer min threshold: [${CMD_TIMER_MIN:-1}s]"
            "󰉋 auto-listing (ls) on cd: [${AUTO_LS:-false}]"
            "󰄛 fastfetch on open: [${SHOW_FASTFETCH:-false}]"
            "󰄛 session check-in on open: [${SHOW_SESSION_CHECKIN:-false}]"
            "󰅚 syntax critic on typo: [${ENABLE_SYNTAX_CRITIC:-true}]"
            "󰄲 prompt banter on wide screen: [${SHOW_PROMPT_BANTER:-true}]"
            "󰥔 prompt clock/time: [${SHOW_TIMESTAMP:-true}]"
            "󰌌 keybinding mode: [${KEY_BIND_MODE:-vi}]"
            "󰇀 vi cursor shape (bar/block): [${VI_CURSOR_SHAPE:-true}]"
            "󰄲 focus mode: distraction-free preset"
            "󰄛 expressive preset: reactive prompt & banter"
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
                    "btop         (~/.local/share/dotfiles/btop/btop.conf)" \
                    "kitty        (~/.local/share/dotfiles/kitty/kitty.conf)" \
                    "matugen      (~/.local/share/dotfiles/matugen/config.toml & templates)" \
                    "nixos        (~/.local/share/dotfiles/nixos/ -> configuration.nix, flake...)" \
                    "micro        (~/.config/micro/settings.json)" \
                    "dotfiles     (open ~/.local/share/dotfiles in file manager)" \
                    | fzf --header="[choose config category to navigate]" --reverse --height=50%)
                case "$f_choice" in
                    *"neovim"*)     settings nvim ;;
                    *"hyprland"*)   settings hypr ;;
                    *"zsh"*)        settings zsh ;;
                    *"quickshell"*) settings qs ;;
                    *"btop"*)       settings btop ;;
                    *"kitty"*)      settings kitty ;;
                    *"matugen"*)    settings matugen ;;
                    *"nixos"*)      settings nixos ;;
                    *"micro"*)      ${EDITOR:-nvim} "$HOME/.config/micro/settings.json" ;;
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
                    "two-line       (╭─[ user@host in dir ] face + ╰─ ❯)" \
                    "open-line      (╭── face user@host in dir + ╰─── ❯)" \
                    "bash           ([user@host:~/dir]$ classic bash style)" \
                    "pure           (minimal two-line: ~/dir + ❯)" \
                    "robby          (➜ dir git:(branch) oh-my-zsh classic)" \
                    "lambda         (λ ~/dir (git) clean functional)" \
                    "face-prompt    (uses the active kaomoji directly as the prompt symbol)" \
                    "kaomoji-speech (face 「dir」 user@host + ╰─ ❯)" \
                    "schematic      (┌──[ user@host :: dir ] face + └──╼ ❯)" \
                    "capsule        (rounded pill segments)" \
                    "single-line    (compact user@host in dir ❯)" \
                    "minimal        (clean dir ❯)" \
                    "bracket        ([user@host dir] ❯)" \
                    "custom         (use your custom {token} template)" \
                    | fzf --header="[choose your prompt layout style]" --reverse --height=55%)
                if [[ -n "$s_choice" ]]; then
                    _save_pref "PROMPT_STYLE" "${s_choice%% *}"
                    [[ "${s_choice%% *}" == "custom" ]] || _save_pref "PROMPT_CUSTOM_NAME" ""
                fi
                ;;
            *"custom prompt builder"*)
                _custom_prompt_builder
                ;;
            *"saved prompt presets"*)
                _prompt_presets_hub
                ;;
            *"kaomoji mood set"*)
                k_choice=$(printf "%s\n" \
                    "none      (no kaomoji)" \
                    "reactive  (switches expression with exit code, git state, and slow commands)" \
                    "cats      (cat expressions: ᓚᘏᗢ, (=^･ω･^=), (=；ェ；=))" \
                    "cute      (cute expressions: (◕‿◕✿), (｡♥‿♥｡), (╥﹏╥))" \
                    "deadpan   (deadpan / tired: (눈_눈), (¬_¬ ), (x_x))" \
                    "angry     (angry / table-flip: (╯°□°)╯︵ ┻━┻, (ノಠ益ಠ)ノ, (╬ಠ益ಠ))" \
                    "ascii     (plain ascii faces: (^_^), (>_<), (?_?))" \
                    | fzf --header="[choose your kaomoji expression set]" --reverse --height=40%)
                [[ -n "$k_choice" ]] && _save_pref "KAOMOJI_SET" "${k_choice%% *}"
                ;;
            *"prompt symbol:"*)
                sym_choice=$(printf "%s\n" \
                    "❯  (default sharp arrow)" \
                    "▲  (triangle)" \
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
            *"transient prompt"*)            _toggle_pref "TRANSIENT_PROMPT" ;;
            *"blank line before"*)           _toggle_pref "PROMPT_BLANK_LINE" ;;
            *"short folder-only"*)           _toggle_pref "SHOW_PWD_ONLY" ;;
            *"nested shell badge"*)          _toggle_pref "SHOW_SHLVL" ;;
            *"git details"*)                 _toggle_pref "SHOW_GIT_PROMPT" ;;
            *"execution timer"*)             _toggle_pref "SHOW_CMD_TIMER" ;;
            *"timer min threshold"*)
                local tmin_choice
                tmin_choice=$(printf "%s\n" \
                    "0s   (always show command timer)" \
                    "1s   (default: 1 second or longer)" \
                    "2s   (2 seconds or longer)" \
                    "5s   (only long commands >= 5s)" \
                    "10s  (only heavy commands >= 10s)" \
                    | fzf --header="[minimum duration before timer shows]" --reverse --height=35%)
                [[ -n "$tmin_choice" ]] && _save_pref "CMD_TIMER_MIN" "${tmin_choice%%s*}"
                ;;
            *"auto-listing"*)                _toggle_pref "AUTO_LS" ;;
            *"fastfetch"*)                   _toggle_pref "SHOW_FASTFETCH" ;;
            *"session check-in"*)            _toggle_pref "SHOW_SESSION_CHECKIN" ;;
            *"syntax critic"*)               _toggle_pref "ENABLE_SYNTAX_CRITIC" ;;
            *"prompt banter"*)               _toggle_pref "SHOW_PROMPT_BANTER" ;;
            *"prompt clock"*)                _toggle_pref "SHOW_TIMESTAMP" ;;
            *"vi cursor shape"*)
                _toggle_pref "VI_CURSOR_SHAPE"
                (( $+functions[_vi_cursor_update] )) && _vi_cursor_update
                ;;
            *"focus mode"*)
                _save_pref "KAOMOJI_SET" "none"
                _save_pref "SHOW_PROMPT_BANTER" "false"
                _save_pref "SHOW_SESSION_CHECKIN" "false"
                _save_pref "ENABLE_SYNTAX_CRITIC" "false"
                _save_pref "SHOW_FASTFETCH" "false"
                _save_pref "SHOW_CMD_TIMER" "false"
                _save_pref "SHOW_TIMESTAMP" "false"
                _save_pref "TRANSIENT_PROMPT" "true"
                print -Pn "\n%F{green}󰄲 focus mode enabled (zero distractions, transient prompt). press enter...%f"
                read -r </dev/tty 2>/dev/null || true
                ;;
            *"expressive preset"*)
                _save_pref "KAOMOJI_SET" "reactive"
                _save_pref "SHOW_PROMPT_BANTER" "true"
                _save_pref "SHOW_SESSION_CHECKIN" "true"
                _save_pref "ENABLE_SYNTAX_CRITIC" "true"
                _save_pref "SHOW_CMD_TIMER" "true"
                _save_pref "SHOW_TIMESTAMP" "true"
                print -Pn "\n%F{magenta}󰄛 expressive preset enabled. press enter...%f"
                read -r </dev/tty 2>/dev/null || true
                ;;
            *"keybinding mode"*)
                if [[ "$KEY_BIND_MODE" == "emacs" ]]; then
                    _save_pref "KEY_BIND_MODE" "vi"
                else
                    _save_pref "KEY_BIND_MODE" "emacs"
                fi
                (( $+functions[_apply_key_binds] )) && _apply_key_binds
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
