# plugin graveyard location (shared with root so root doesn't spam git clone on startup)
if [[ -d "/home/ashley/.local/share/zsh/plugins" ]]; then
    typeset -g _PLUGIN_DIR="/home/ashley/.local/share/zsh/plugins"
else
    typeset -g _PLUGIN_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins"
fi

# only fork mkdir if the directory actually doesn't exist
[[ -d "$_PLUGIN_DIR" ]] || mkdir -p "$_PLUGIN_DIR"

_load_plugin() {
    local repo="$1"
    local name="${repo:t}"
    local dir="$_PLUGIN_DIR/$name"

    # snatch from git if missing
    if [[ ! -d "$dir" ]]; then
        print -P "%F{cyan}󰄛 grabbing plugin:%f %F{green}$name%f..."
        git clone --depth 1 "https://github.com/$repo.git" "$dir" >/dev/null 2>&1
    fi

    # find entrypoint
    local target=""
    [[ -f "$dir/$name.plugin.zsh" ]] && target="$dir/$name.plugin.zsh"
    [[ -f "$dir/$name.zsh" ]]        && target="$dir/$name.zsh"

    if [[ -n "$target" ]]; then
        # byte-compile in background so the shell doesn't crawl like a snail
        if [[ ! -f "$target.zwc" || "$target" -nt "$target.zwc" ]]; then
            {
                zcompile -R "$target" 2>/dev/null
                for sub in "$dir"/**/*.zsh(N); do
                    [[ "$sub" == *"test-data"* || "$sub" == *"/tests/"* ]] && continue
                    [[ "$sub" != "$target" && (! -f "$sub.zwc" || "$sub" -nt "$sub.zwc") ]] && zcompile -R "$sub" 2>/dev/null
                done
            } >/dev/null 2>&1 &!
        fi
        source "$target"
    fi
}

# the holy trinity in strict load order so syntax highlighting doesn't combust
_load_plugin "zsh-users/zsh-autosuggestions"
_load_plugin "zsh-users/zsh-syntax-highlighting"
_load_plugin "zsh-users/zsh-history-substring-search"

# autosuggestion ghost colors & syntax highlighting (live ANSI slots)
export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=8"
ZSH_AUTOSUGGEST_CLEAR_WIDGETS+=(bracketed-paste)

if (( $+ZSH_HIGHLIGHT_STYLES )); then
    ZSH_HIGHLIGHT_STYLES[default]='none'
    ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=9,bold'
    ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=5,bold'
    ZSH_HIGHLIGHT_STYLES[alias]='fg=6'
    ZSH_HIGHLIGHT_STYLES[builtin]='fg=4'
    ZSH_HIGHLIGHT_STYLES[function]='fg=4'
    ZSH_HIGHLIGHT_STYLES[command]='fg=4,bold'
    ZSH_HIGHLIGHT_STYLES[precommand]='fg=5,underline'
    ZSH_HIGHLIGHT_STYLES[commandseparator]='fg=8'
    ZSH_HIGHLIGHT_STYLES[path]='fg=6,underline'
    ZSH_HIGHLIGHT_STYLES[globbing]='fg=13'
    ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=2'
    ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=2'
    ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=5'
    ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=5'
    ZSH_HIGHLIGHT_STYLES[comment]='fg=8,italic'
fi

# arrow keys & vi keys for digging up your past mistakes
if (( $+functions[history-substring-search-up] )); then
    bindkey '^[[A' history-substring-search-up
    bindkey '^[OA' history-substring-search-up
    bindkey '^[[B' history-substring-search-down
    bindkey '^[OB' history-substring-search-down
    bindkey -M vicmd 'k' history-substring-search-up
    bindkey -M vicmd 'j' history-substring-search-down

    export HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND="fg=4,bold"
    export HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND="fg=9,bold"
fi

# nuke the loader from memory
unfunction _load_plugin
