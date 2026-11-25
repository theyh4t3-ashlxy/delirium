# interactive fuzzy helpers & terminal utilities

# cd into a folder or clone a repository and enter it
take() {
    if [[ -z "$1" ]]; then
        print -P "%F{3}󰀦 usage: take <dir | repo-url>%f"
        return 1
    fi
    local target="$1"
    if [[ "$target" =~ ^(https?://|git@|ssh://) ]]; then
        git clone "$target" || return 1
        local dir="${target:t}"
        dir="${dir%.git}"
        builtin cd "$dir"
    elif [[ "$target" =~ ^(github\.com|gitlab\.com|codeberg\.org)/.+ ]]; then
        git clone "https://$target" || return 1
        local dir="${target:t}"
        dir="${dir%.git}"
        builtin cd "$dir"
    else
        mkdir -p -- "$target" && cd -- "$target"
    fi
}
alias mkcd="take"

# touch with automatic parent directory creation
mkfile() {
    if [[ -z "$1" ]]; then
        print -P "%F{3}󰀦 usage: mkfile <path/to/file>%f"
        return 1
    fi
    mkdir -p -- "${1:h}" && touch -- "$1" && print -P "%F{2}󰄲 created:%f $1"
}

# climb out of nested directories
up() {
    local count="${1:-1}"
    if ! [[ "$count" =~ ^[0-9]+$ ]]; then
        print -P "%F{1}󰅚 usage: up [levels]%f"
        return 1
    fi
    local p=""
    for (( i=0; i<count; i++ )); do
        p="../$p"
    done
    cd "${p:-.}"
}

# audit PATH entries
path() {
    print -P "%F{5}󰄛 system PATH ($#path entries):%f"
    local idx=1
    for p in "${path[@]}"; do
        if [[ -d "$p" ]]; then
            print -P "  %F{8}[$idx]%f %F{6}${p}%f"
        else
            print -P "  %F{8}[$idx]%f %F{1}${p}%f %F{8}(missing)%f"
        fi
        (( idx++ ))
    done
}

# quick float/math expression evaluator in terminal
_calc() {
    if [[ -z "$1" ]]; then
        print -P "%F{3}󰀦 usage: calc <expression>  (e.g. calc '5/2', calc 'sqrt(144)')%f"
        return 1
    fi
    local expr="$*"
    if (( $+commands[python3] )); then
        local out
        if out=$(python3 -c "import math, sys
from math import *
val = eval(sys.argv[1], {'__builtins__': {}}, {k: getattr(math, k) for k in dir(math) if not k.startswith('_')} | {'hex': hex, 'bin': bin, 'oct': oct, 'round': round, 'abs': abs, 'min': min, 'max': max})
if isinstance(val, float) and val.is_integer():
    print(int(val))
else:
    print(val)
" "$expr" 2>/dev/null); then
            print -Pn "%F{2}󰄲%f "
            print -r -- "$out"
            return 0
        fi
    fi
    zmodload -i zsh/mathfunc 2>/dev/null
    print -Pn "%F{2}󰄲%f "
    print -r -- $(( $expr ))
}
alias calc="noglob _calc"

# unpack any common archive format cleanly
extract() {
    if [[ $# -eq 0 ]]; then
        print -P "%F{3}󰀦 usage: extract <archive...>%f"
        return 1
    fi
    local f rc=0
    for f in "$@"; do
        if [[ ! -f "$f" ]]; then
            print -P "%F{1}󰅚 not found:%f $f"
            rc=1
            continue
        fi
        case "${f:l}" in
            *.tar.bz2|*.tbz2) tar xjf "$f" || rc=1 ;;
            *.tar.gz|*.tgz)   tar xzf "$f" || rc=1 ;;
            *.tar.xz|*.txz)   tar xJf "$f" || rc=1 ;;
            *.tar.zst|*.tzst) tar --zstd -xf "$f" || rc=1 ;;
            *.tar)            tar xf "$f" || rc=1 ;;
            *.bz2)            bunzip2 "$f" || rc=1 ;;
            *.gz)             gunzip "$f" || rc=1 ;;
            *.xz)             unxz "$f" || rc=1 ;;
            *.zst)            unzstd "$f" || rc=1 ;;
            *.zip)            unzip "$f" || rc=1 ;;
            *.7z)             7z x "$f" || rc=1 ;;
            *.rar)            unrar x "$f" || rc=1 ;;
            *)
                print -P "%F{1}󰅚 unknown archive format:%f $f"
                rc=1
                ;;
        esac
    done
    return $rc
}
alias ex="extract"

# inspect listening TCP/UDP ports & processes
ports() {
    local filter="${1:-}"
    if (( $+commands[ss] )); then
        if [[ -n "$filter" ]]; then
            ss -tulnp 2>/dev/null | grep -iE "(Netid|$filter)"
        else
            ss -tulnp 2>/dev/null
        fi
    else
        print -P "%F{1}󰅚 'ss' utility unavailable%f"
        return 1
    fi
}

# quick local static web server
serve() {
    local port="${1:-8000}"
    print -P "%F{4}󰄛 serving $(pwd) at %Bhttp://127.0.0.1:${port}%b%f"
    python3 -m http.server "$port"
}

# nix search shortcut
nixs() {
    if [[ -z "$1" ]]; then
        print -P "%F{3}󰀦 usage: nixs <query>%f"
        return 1
    fi
    nix search nixpkgs "$@"
}

# interactive fzf git commit browser (Enter opens commit diff, Ctrl-Y copies SHA)
glog() {
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        print -P "%F{1}󰅚 not inside a git repository%f"
        return 1
    fi
    git log --graph --color=always --format="%C(auto)%h%d %s %C(8)(%cr) %C(6)<%an>%C(reset)" "$@" |
        fzf --ansi --no-sort --reverse --tiebreak=index --height=80% \
            --header="[glog: enter=view diff, ctrl-y=copy sha]" \
            --preview='echo {} | grep -oE "[a-f0-9]{7,}" | head -n1 | xargs -r git show --color=always' \
            --preview-window='right:58%:wrap' \
            --bind='ctrl-y:execute-silent(echo {} | grep -oE "[a-f0-9]{7,}" | head -n1 | wl-copy)+abort' \
            --bind='enter:execute(echo {} | grep -oE "[a-f0-9]{7,}" | head -n1 | xargs -r git show --color=always | less -R)'
}

# interactive fzf git branch switcher
gbr() {
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        print -P "%F{1}󰅚 not inside a git repository%f"
        return 1
    fi
    local branch
    branch=$(git branch --all --color=always | sed 's/^[* ] //' | grep -v 'HEAD' |
        fzf --ansi --reverse --height=55% \
            --header="[gbr: select branch to checkout]" \
            --preview='git log -n 12 --oneline --color=always $(echo {} | sed "s#remotes/[^/]*/##") 2>/dev/null')
    [[ -z "$branch" ]] && return 0
    branch="${branch##* }"
    branch="${branch#remotes/origin/}"
    git checkout "$branch"
}

# interactive fzf modified file diff viewer (Enter edits file)
gdiff() {
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        print -P "%F{1}󰅚 not inside a git repository%f"
        return 1
    fi
    local sel
    sel=$(git status --short |
        fzf --ansi --reverse --height=75% \
            --header="[gdiff: enter=open in ${EDITOR:-nvim}]" \
            --preview='f=$(echo {} | cut -c4-); git diff --color=always -- "$f" 2>/dev/null; [[ -z $(git diff -- "$f" 2>/dev/null) ]] && bat --style=numbers --color=always --line-range :120 "$f" 2>/dev/null || true' \
            --preview-window='right:65%')
    [[ -z "$sel" ]] && return 0
    local fpath="${sel:3}"
    [[ -f "$fpath" ]] && ${EDITOR:-nvim} "$fpath"
}

# fuzzy find inside files with ripgrep and bat preview
fif() {
    if ! (( $+commands[rg] )) || ! (( $+commands[fzf] )); then
        print -P "%F{1}󰅚 rg or fzf missing%f"
        return 1
    fi
    local file_line
    file_line=$(rg --color=always --line-number --no-heading --smart-case "${*:-}" 2>/dev/null |
        fzf --ansi \
            --delimiter : \
            --preview 'bat --style=numbers --color=always {1} --highlight-line {2}' \
            --preview-window 'right,60%,border-left,+{2}+3/3,~3')
    if [[ -n "$file_line" ]]; then
        local file="${file_line%%:*}"
        local rest="${file_line#*:}"
        local line="${rest%%:*}"
        ${EDITOR:-nvim} "+${line}" "$file"
    fi
}

# fkill aliases directly to the process sniper in nuke.zsh
alias fkill="nuke"

# ephemeral nix-shell environment
try() {
    if [[ -z "$1" ]]; then
        print -P "%F{3}󰀦 usage: try <package ...>%f"
        return 1
    fi
    print -P "%F{6}󰄛 entering ephemeral nix environment for: %F{2}$*%f"
    nix-shell -p "$@"
}
alias in="try"
alias fin="try"

# package removal reminder for declarative system
un() {
    print -P "%F{3}󰀦 NixOS packages are declarative! Remove the package from ~nix/configuration.nix and run 'rebuild'.%f"
}
alias fun="un"

# fuzzy edit file
fe() {
    local file
    file=$(fzf --preview 'bat --style=numbers --color=always --line-range :100 {} 2>/dev/null || head -n 100 {}' --header="[󰈙 open file]")
    [[ -n "$file" ]] && ${EDITOR:-nvim} "$file"
}

# list nixos system generations
gens() {
    print -P "%F{6}󰋊 [nixos system generations]%f"
    nixos-rebuild list-generations
}
alias generations="gens"
alias snaps="gens"
