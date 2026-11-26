# making zsh stop acting like it was born in 1989
setopt AUTO_CD              # typing cd every 3 seconds is for cavemen
setopt AUTO_PUSHD           # push directories to stack on cd (cd -1, cd -2, dirs -v)
setopt PUSHD_IGNORE_DUPS    # don't push duplicates to directory stack
setopt PUSHD_SILENT         # don't print directory stack after every pushd
setopt PUSHD_TO_HOME        # pushd with no args goes home
setopt INTERACTIVE_COMMENTS # paste broken snippets with # without terminal screaming
setopt NO_BEEP              # if my pc beeps at me one more time im throwing it out the window
setopt GLOB_COMPLETE        # auto-expand globs
setopt EXTENDED_GLOB        # supercharged globs (#q, ^, ~, etc)
setopt COMPLETE_IN_WORD     # tab complete from anywhere inside word
setopt ALWAYS_TO_END        # move cursor to end of word on completion
setopt MULTIOS              # pipe to multiple outputs simultaneously
setopt RM_STAR_WAIT         # 10s safety delay if executing 'rm *' or 'rm path/*'

# remembering the 50000 mistakes ive made in terminal
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000

setopt HIST_IGNORE_ALL_DUPS   # stop recording the 40 times i spammed ls in 2 seconds
setopt HIST_IGNORE_SPACE      # leading space hides secrets/tokens from history
setopt HIST_SAVE_NO_DUPS      # omit older duplicates when writing history
setopt HIST_FIND_NO_DUPS      # do not display duplicates when searching
setopt HIST_REDUCE_BLANKS     # trim useless whitespace before saving
setopt SHARE_HISTORY          # telepathically sync my bad decisions across tabs
setopt HIST_VERIFY            # show history command before executing
setopt HIST_EXPIRE_DUPS_FIRST # trim oldest duplicates first when history is full
setopt EXTENDED_HISTORY       # record timestamps and execution duration in history

# completion drip so i dont have to memorize flags
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
zstyle ':completion:*' rehash true

# category headers styled with matugen accents
zstyle ':completion:*' verbose yes
zstyle ':completion:*:*:*:*:descriptions' format '%F{cyan}󰅂 %d%f'
zstyle ':completion:*:messages' format '%F{yellow}󰅂 %d%f'
zstyle ':completion:*:warnings' format '%F{5}󰅂 no matches found: %d%f'
zstyle ':completion:*:corrections' format '%F{green}󰅂 %d (errors: %e)%f'
zstyle ':completion:*' group-name ''

# colorize completion entries using ls colors
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# case-insensitive + typo correction so i dont cry when typing fast
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|='

# ijkl because hjkl is an actual war crime
zstyle ':completion:*' menu select
zmodload zsh/complist
bindkey -M menuselect 'i' up-line-or-history
bindkey -M menuselect 'k' down-line-or-history
bindkey -M menuselect 'j' backward-char
bindkey -M menuselect 'l' forward-char
bindkey -M menuselect '^[[Z' reverse-menu-complete

# process list formatting so kill is interactive
zstyle ':completion:*:*:*:*:processes' command "ps -u $USER -o pid,user,%cpu,%mem,command -w"
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'

# lightning fast compdump caching & background bytecode compilation
autoload -Uz compinit
local zcomp_dir="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
[[ -d "$zcomp_dir" ]] || mkdir -p "$zcomp_dir"

# custom completions for dotfiles scripts (cli, wp, qs)
local _compdir="${ZDOTDIR:-$HOME/.config/zsh}/completions"
[[ -d "$_compdir" ]] && fpath=("$_compdir" $fpath)

local zcomp="$zcomp_dir/zcompdump-${ZSH_VERSION}"
if [[ -n ${zcomp}(#qN.mh-24) ]]; then
    compinit -C -d "$zcomp"
else
    compinit -d "$zcomp"
    touch "$zcomp"
    { zcompile -R "$zcomp" } >/dev/null 2>&1 &!
fi

# compile all zsh configs and plugins to .zwc bytecode on demand
zrecompile() {
    local zdir="${ZDOTDIR:-$HOME/.config/zsh}"
    local pdir="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins"
    local count=0
    for f in "$zdir"/*.zsh(N); do
        zcompile -R "$f" 2>/dev/null && (( count++ ))
    done
    for f in "$pdir"/*/*.zsh(N) "$pdir"/*/*/*.zsh(N); do
        [[ "$f" == *"test-data"* || "$f" == *"/tests/"* ]] && continue
        zcompile -R "$f" 2>/dev/null && (( count++ ))
    done
    [[ -f "$HOME/.zcompdump" ]] && zcompile -R "$HOME/.zcompdump" 2>/dev/null
    print -P "%F{green}󰄲 compiled ${count} scripts into fresh .zwc bytecode%f"
}

# wipe all .zwc bytecode caches if anything gets cursed
zclean() {
    local zdir="${ZDOTDIR:-$HOME/.config/zsh}"
    local pdir="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins"
    rm -f "$zdir"/*.zwc(N) "$pdir"/**/*.zwc(N) "$HOME"/.zcompdump*.zwc(N)
    print -P "%F{yellow}󰀦 purged all .zwc bytecode caches%f"
}

alias zwc="zrecompile"
alias unzwc="zclean"
alias recompile="zrecompile"
alias compile-zsh="zrecompile"

# keys that actually work when i press them (respect KEY_BIND_MODE from user_prefs.conf)
KEYTIMEOUT=5

_vi_cursor_update() {
    [[ -t 1 ]] || return 0
    if [[ "${KEY_BIND_MODE:-vi}" != "vi" || "${VI_CURSOR_SHAPE:-true}" != "true" ]]; then
        printf '\e[0 q'
        return 0
    fi
    case "${1:-${KEYMAP:-main}}" in
        vicmd)      printf '\e[2 q' ;;
        viins|main) printf '\e[6 q' ;;
    esac
}

_vi_cursor_keymap_select() { _vi_cursor_update "${KEYMAP:-main}" }
_vi_cursor_line_init()     { _vi_cursor_update viins }
_vi_cursor_preexec() {
    [[ -t 1 && "${KEY_BIND_MODE:-vi}" == "vi" && "${VI_CURSOR_SHAPE:-true}" == "true" ]] && printf '\e[0 q'
}

_toggle_sudo_line() {
    [[ -z "$BUFFER" ]] && zle up-history
    if [[ "$BUFFER" == sudo\ * ]]; then
        BUFFER="${BUFFER#sudo }"
        (( CURSOR = CURSOR > 5 ? CURSOR - 5 : 0 ))
    else
        BUFFER="sudo $BUFFER"
        (( CURSOR += 5 ))
    fi
}

autoload -Uz add-zsh-hook
add-zsh-hook -d preexec _vi_cursor_preexec 2>/dev/null
add-zsh-hook preexec _vi_cursor_preexec

autoload -Uz bracketed-paste-magic && zle -N bracketed-paste bracketed-paste-magic
autoload -Uz url-quote-magic && zle -N self-insert url-quote-magic
autoload -Uz select-word-style && select-word-style bash
autoload -Uz edit-command-line && zle -N edit-command-line
zle -N zle-keymap-select _vi_cursor_keymap_select
zle -N zle-line-init _vi_cursor_line_init
zle -N _toggle_sudo_line

_apply_key_binds() {
    if [[ "${KEY_BIND_MODE:-vi}" == "vi" ]]; then
        bindkey -v
    else
        bindkey -e
    fi

    local _km
    for _km in emacs viins; do
        bindkey -M "$_km" '^[[H'    beginning-of-line
        bindkey -M "$_km" '^[OH'    beginning-of-line
        bindkey -M "$_km" '^[[F'    end-of-line
        bindkey -M "$_km" '^[OF'    end-of-line
        bindkey -M "$_km" '^[[3~'   delete-char
        bindkey -M "$_km" '^?'      backward-delete-char
        bindkey -M "$_km" '^[[1;5D' backward-word
        bindkey -M "$_km" '^[[1;5C' forward-word
        bindkey -M "$_km" '^X^E'    edit-command-line
        bindkey -M "$_km" '^[s'     _toggle_sudo_line
    done
    bindkey -M emacs '\e\e' _toggle_sudo_line
    bindkey -M vicmd '^[s'  _toggle_sudo_line
    _vi_cursor_update
}

_apply_key_binds

# avoid leaving autosuggest ghost fragments during bracketed paste
typeset -ga ZSH_AUTOSUGGEST_CLEAR_WIDGETS
ZSH_AUTOSUGGEST_CLEAR_WIDGETS+=(bracketed-paste)

