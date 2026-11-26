# nixos system rebuild & package management (flake-driven)
_dotfiles_dir="${DOTFILES_DIR:-/home/ashley/.local/share/dotfiles}"
alias rebuild="sudo nixos-rebuild switch --flake '$_dotfiles_dir#lost'"
alias test-build="sudo nixos-rebuild test --flake '$_dotfiles_dir#lost'"
alias boot-build="sudo nixos-rebuild boot --flake '$_dotfiles_dir#lost'"
alias nsearch="nix search nixpkgs"
alias nshell="nix-shell -p"

# ephemeral nixpkgs command runner
nrun() {
    if [[ -z "${1:-}" ]]; then
        print -P "%F{3}󰀦 usage: nrun <package> [args...]%f"
        return 1
    fi
    local pkg="$1"
    shift
    if (( $# > 0 )); then
        nix run "nixpkgs#${pkg}" -- "$@"
    else
        nix run "nixpkgs#${pkg}"
    fi
}
alias nix-gens="nixos-rebuild list-generations"
alias neovim="nvim"

# all-in-one nixos flake update -> rebuild -> commit flake.lock -> push
sysup() {
    local dir="${DOTFILES_DIR:-/home/ashley/.local/share/dotfiles}"
    local custom_msg="$*"

    if [[ ! -d "$dir" ]]; then
        print -P "%F{1}󰅚 dotfiles directory not found:%f $dir"
        return 1
    fi

    print -P "%F{4}󰚰 updating flake inputs...%f"
    nix flake update --flake "$dir" || return 1

    print -P "%F{5}󱄅 rebuilding nixos (#lost)...%f"
    sudo nixos-rebuild switch --flake "$dir#lost" || return 1

    if git -C "$dir" diff --quiet -- flake.lock && git -C "$dir" diff --cached --quiet -- flake.lock; then
        print -P "%F{2}󰄲 system rebuilt cleanly (flake.lock unchanged, skipping push)%f"
        return 0
    fi

    local -a quotes=(
        "flakey flake"
        "flake"
        "nixos wrath"
        "fed the nix store"
        "pray the build passes"
        "nixpkgs roulette"
        "bump lockfile and hope"
        "declarative suffering"
        "another sacrifice to hydra"
        "impermanent sanity"
        "eval took 4gb for this"
        "rolling the unstable dice"
        "lockfile roulette"
        "sudo make me a generation"
    )
    local msg="${custom_msg:-${quotes[$(( RANDOM % ${#quotes[@]} + 1 ))]}}"

    print -P "%F{6}󰊢 committing & pushing flake.lock:%f %F{3}\"$msg\"%f"
    git -C "$dir" commit -m "$msg" -- flake.lock || return 1
    git -C "$dir" push || return 1
    print -P "%F{2}󰄲 system updated & pushed%f"
}
alias nixup="sysup"

# sudo with trailing space for alias expansion
alias sudo="sudo "

# purge old dead nix store paths while keeping 7 days of rollbacks
cleanup() {
    print -P "%F{cyan}󰄛 killing my own generations because i want my 512gb back ..%f"
    nix-collect-garbage --delete-older-than 7d
    if (( $+commands[sudo] )); then
        print -P "%F{cyan}󰄛 purging dead system generations older than 7d...%f"
        sudo nix-collect-garbage --delete-older-than 7d
    fi
    print -P "%F{green}󰄲 nix store cleanup complete%f"
}

# safe file operations with speed bumps
alias rm="rm -I"
alias cp="cp -iv"
alias mv="mv -iv"
alias mkdir="mkdir -pv"
alias chown="chown --preserve-root"
alias chmod="chmod --preserve-root"
alias chgrp="chgrp --preserve-root"

# launch GUI file manager without hijacking stdout
fm() {
    if (( $+commands[dolphin] )); then
        dolphin "${1:-.}" >/dev/null 2>&1 &!
    elif (( $+commands[nautilus] )); then
        nautilus "${1:-.}" >/dev/null 2>&1 &!
    else
        yz "${1:-.}"
    fi
}

# yazi wrapper with cwd sync on exit
yz() {
    local tmp cwd
    tmp="$(mktemp -t "yazi-cwd.XXXXXX")" || return 1
    command yazi "$@" --cwd-file="$tmp"
    if cwd="$(command cat -- "$tmp")" && [[ -n "$cwd" && "$cwd" != "$PWD" ]]; then
        builtin cd -- "$cwd"
    fi
    command rm -f -- "$tmp"
}

# terminal git gui
if (( $+commands[lazygit] )); then
    alias lg="lazygit"
fi

# screen color picker
alias color="hyprpicker -a"

# directory stack & jumps
alias d="dirs -v"
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias -- -='cd -'
alias dots="cd '$_dotfiles_dir'"

# quick terminal commands
alias q="exit"
alias cl="clear"
alias config="settings"
alias prompt-edit="settings custom"
alias prompt-save="settings save-prompt"
alias prompt-load="settings prompts"

# quick timestamped backup copy
bak() {
    local src="${1:-}"
    [[ -e "$src" ]] || { print -P "%F{5}󰅚 missing path: ${src:-<none>}%f"; return 1; }
    local clean="${src%/}"
    command cp -aiv -- "$clean" "${clean}.bak.$(date +%Y%m%d_%H%M%S)"
}

if (( $+commands[wl-copy] )); then
    copyfile() {
        [[ -f "${1:-}" ]] || { print -P "%F{5}󰅚 file not found: ${1:-<none>}%f"; return 1; }
        wl-copy < "$1" && print -P "%F{2}󰄲 copied file contents -> clipboard%f"
    }
    copydir() {
        print -rn -- "$PWD" | wl-copy && print -P "%F{2}󰄲 copied path -> ${PWD}%f"
    }
fi

# directory shortcuts
hash -d dots="$HOME/.local/share/dotfiles"
hash -d hypr="$HOME/.local/share/dotfiles/hypr"
hash -d qs="$HOME/.local/share/dotfiles/quickshell"
hash -d nix="$HOME/.local/share/dotfiles/nixos"
hash -d btop="$HOME/.local/share/dotfiles/btop"
hash -d wp="$HOME/.wallpapers"
hash -d conf="$HOME/.config"

# antigravity cli fallback
if (( ! $+commands[agy] )); then
    alias agy="nix run 'github:jacopone/antigravity-nix#google-antigravity-cli'"
fi

# shell reload
alias reload="exec zsh"
alias sz="source \${ZDOTDIR:-\$HOME/.config/zsh}/sources.zsh"

# explain last exit code (falls back to $_GP_EXIT recorded by prompt hook)
why() {
    local code="${1:-${_GP_EXIT:-$?}}"
    case "$code" in
        0)   print -P "%F{2}󰄲 exit 0:%f nothing failed. clean run." ;;
        1)   print -P "%F{5}󰅚 exit 1:%f general failure. something exited non-zero without specifics." ;;
        2)   print -P "%F{5}󰅚 exit 2:%f misuse / bad arguments or missing flag." ;;
        126) print -P "%F{5}󰅚 exit 126:%f permission denied. file exists but isn't executable." ;;
        127) print -P "%F{5}󰅚 exit 127:%f command not found in PATH." ;;
        130) print -P "%F{3}󰀦 exit 130:%f sigint (ctrl+c)." ;;
        134) print -P "%F{9}󰅚 exit 134:%f sigabrt. process aborted itself." ;;
        137) print -P "%F{9}󰅚 exit 137:%f sigkill (killed or out of memory)." ;;
        139) print -P "%F{9}󰅚 exit 139:%f sigsegv (segmentation fault)." ;;
        141) print -P "%F{3}󰀦 exit 141:%f sigpipe (downstream reader closed pipe early)." ;;
        143) print -P "%F{3}󰀦 exit 143:%f sigterm (graceful kill requested)." ;;
        *)   print -P "%F{5}󰅚 exit $code:%f non-zero status returned." ;;
    esac
}
alias ouch="why"

# desktop shell switching & management
alias qs-switch="cli shell"
alias qs-reload="cli reload"

# repeat last command with sudo
please() {
    local last_cmd=$(fc -ln -1 | sed 's/^[[:space:]]*//')
    if [[ -n "$last_cmd" ]]; then
        print -P "%F{3}󰀦 escalating with sudo:%f %F{6}sudo $last_cmd%f"
        eval "sudo $last_cmd"
    fi
}
