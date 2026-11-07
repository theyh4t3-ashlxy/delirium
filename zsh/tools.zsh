# modern cli tools replacing ancient gnu relics with rust/go power

# zoxide: smart directory jumping
if (( $+commands[zoxide] )); then
    eval "$(zoxide init zsh)"
    alias cd="z"
fi

# cd and immediately show directory contents
c() {
    if [[ $# -eq 0 ]]; then
        builtin cd "$HOME" && ls
    elif (( $+commands[z] )); then
        z "$@" && ls
    else
        builtin cd "$@" && ls
    fi
}

# automatic ls on cd if enabled in user_prefs.conf
_auto_ls_chpwd() {
    if [[ "${AUTO_LS:-false}" == "true" && -o interactive ]]; then
        ls
    fi
}
autoload -Uz add-zsh-hook
add-zsh-hook chpwd _auto_ls_chpwd

# eza: clean directory listing
if (( $+commands[eza] )); then
    alias ls="eza --color=auto --group-directories-first --icons=auto"
    alias l="ls"
    alias la="ls -a"
    alias ll="ls -lh --git"
    alias Rlah="ls -Rlah --git"
    alias tree="ls --tree --level=3"
else
    alias ls="command ls --color=auto --group-directories-first"
    alias l="ls"
    alias la="ls -A"
    alias ll="ls -lh"
    alias Rlah="ls -lahR"
    alias tree="ls -R"
fi

# bat: cat with syntax highlights
if (( $+commands[bat] )); then
    alias cat="bat --style=plain --paging=never"
    alias preview="bat --style=numbers --color=always"
    alias b="bat"
    alias batp="bat --paging=always"
else
    alias preview="less -N"
fi

# ripgrep
if (( $+commands[rg] )); then
    alias rgs="rg --smart-case"
    alias rgh="rg --hidden"
    alias rgf="rg --files"
fi
alias grep="command grep --color=auto"

# fd
if (( $+commands[fd] )); then
    alias fdd="fd -t d"
    alias fdf="fd -t f"
    alias fdh="fd -H"
fi

# storage and memory stats
alias df="df -h"
alias du="du -h"
alias dus="du -sh * 2>/dev/null | sort -h"
alias free="free -h"

# process lookup
alias psg="ps aux | grep -v grep | grep -i"

# resource monitor
if (( $+commands[btop] )); then
    alias top="btop"
    alias htop="btop"
fi

# wayland clipboard sync
if (( $+commands[wl-copy] )); then
    alias copy="wl-copy"
    alias paste="wl-paste"
    alias pbcopy="wl-copy"
    alias pbpaste="wl-paste"
fi

# system stats
if (( $+commands[fastfetch] )); then
    alias ff="fastfetch"
    alias fetch="fastfetch"
fi

# micro editor
if (( $+commands[micro] )); then
    alias mc="micro"
    alias edit="micro"
fi

# yazi file manager
if (( $+commands[yazi] )); then
    alias y="yz"
    alias yazi="yz"
fi

# fzf fuzzy finder
if (( $+commands[fzf] )); then
    eval "$(fzf --zsh 2>/dev/null || fzf --shell=zsh 2>/dev/null || true)"
    if [[ "$FZF_DEFAULT_OPTS" != *"--layout="* ]]; then
        export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border=none --inline-info ${FZF_DEFAULT_OPTS:-}"
    fi
    export FZF_CTRL_T_OPTS="--preview 'bat --style=numbers --color=always --line-range :50 {} 2>/dev/null || eza --tree --level=2 --icons {} 2>/dev/null || head -200 {}' --bind 'ctrl-/:toggle-preview'"
    export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --icons --color=always {} 2>/dev/null || ls {}'"
fi
