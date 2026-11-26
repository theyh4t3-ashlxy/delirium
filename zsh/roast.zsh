# syntax critic & session check-in — dry terminal feedback without repeating itself
zmodload -i zsh/datetime 2>/dev/null

typeset -gi _CRITIC_STREAK=0
typeset -gi _IN_CNF=0
typeset -g  _LAST_CRITIC_CMD=""
typeset -ga _CRITIC_RECENT=()
typeset -ga _CHECKIN_RECENT=()

# normalize legacy preference variable names cleanly if old config is loaded
: "${ENABLE_SYNTAX_CRITIC:=${ENABLE_PSYCHO_ROASTS:-true}}"
: "${SHOW_SESSION_CHECKIN:=${SHOW_GREETING_ROAST:-false}}"

# draw a random index from array length $1 avoiding indices stored in $2 (name of recent array)
_critic_pick() {
    emulate -L zsh
    local count=$1
    local hist_name=$2
    local keep=${3:-10}
    (( count <= 0 )) && { REPLY=1; return; }
    (( count <= 1 )) && { REPLY=1; return; }

    local -a recent=( ${(P)hist_name} )
    local -a candidates=()
    local -i i
    for (( i=1; i<=count; i++ )); do
        (( ${recent[(Ie)$i]} == 0 )) && candidates+=( $i )
    done

    if (( ${#candidates} == 0 )); then
        # retain only the most recent index so we never repeat back-to-back
        recent=( ${recent[-1]:-} )
        for (( i=1; i<=count; i++ )); do
            (( $i != ${recent[1]:-0} )) && candidates+=( $i )
        done
    fi

    local picked="${candidates[$(( RANDOM % ${#candidates} + 1 ))]}"
    recent+=( "$picked" )
    if (( ${#recent} > keep )); then
        recent=( "${recent[@]: -$keep}" )
    fi
    set -A "$hist_name" "${recent[@]}"
    REPLY="$picked"
}

# fast pure-zsh typo hint against $commands, aliases, functions, and builtins
_critic_suggest_cmd() {
    emulate -L zsh
    local raw="$1"
    REPLY=""
    [[ -z "$raw" || ${#raw} -lt 2 || ${#raw} -gt 24 ]] && return 1

    # immediate missing-space shortcuts (cd.., ls-la)
    case "$raw" in
        cd..) REPLY="cd .."; return 0 ;;
        cd...) REPLY="cd ../.."; return 0 ;;
        ls-la|ls-al|ls-l) REPLY="${raw/ls-/ls -}"; return 0 ;;
        gitstatus) REPLY="git status"; return 0 ;;
        gitdiff) REPLY="git diff"; return 0 ;;
    esac

    local -a pool=(
        ${(k)commands} ${(k)aliases} ${(k)functions} ${(k)builtins}
        git nix rebuild sysup gens try in nshell nrun nixs zoxide bat eza rg fd fzf btop yazi nvim micro kitty cli wp qs
        settings dnd nuke glog gbr gdiff ports extract calc clear exit ls cd cat grep
    )
    typeset -U pool

    local len=${#raw}
    local cand clen d diff=0 i
    local -a matches=()

    # single-character transposition check (e.g. gti -> git, claer -> clear)
    for (( i=1; i<len; i++ )); do
        local swapped="${raw[1,$((i-1))]}${raw[i+1]}${raw[i]}${raw[$((i+2)),$len]}"
        if (( ${pool[(Ie)$swapped]} > 0 )); then
            REPLY="$swapped"
            return 0
        fi
    done

    # length +/- 1 prefix/suffix overlap heuristic for rapid suggestions
    for cand in "${pool[@]}"; do
        clen=${#cand}
        (( clen < len - 1 || clen > len + 1 )) && continue
        if (( len == clen )); then
            diff=0
            for (( i=1; i<=len; i++ )); do
                [[ "${raw[i]}" != "${cand[i]}" ]] && (( ++diff ))
                (( diff > 1 )) && break
            done
            (( diff == 1 )) && matches+=( "$cand" )
        elif (( len == clen + 1 )) && [[ "${raw[2,-1]}" == "$cand" || "${raw[1,-2]}" == "$cand" ]]; then
            matches+=( "$cand" )
        elif (( clen == len + 1 )) && [[ "${cand[2,-1]}" == "$raw" || "${cand[1,-2]}" == "$raw" ]]; then
            matches+=( "$cand" )
        fi
        (( ${#matches} >= 3 )) && break
    done

    if (( ${#matches} > 0 )); then
        REPLY="${(j:, :)matches}"
        return 0
    fi
    return 1
}

command_not_found_handler() {
    local cmd="$1"
    local safe_cmd="${cmd//\%/%%}"

    if (( _IN_CNF > 0 )); then
        return 127
    fi
    _IN_CNF=1

    (( _CRITIC_STREAK++ ))

    local hour=12
    if (( $+EPOCHSECONDS )); then
        hour=$(strftime "%-H" "$EPOCHSECONDS" 2>/dev/null || echo 12)
    fi

    local -a notes=(
        "command '${safe_cmd}' not found. bold guess, zero return."
        "'${safe_cmd}' isn't a binary. tab completion exists specifically to save you from this."
        "exit 127 on '${safe_cmd}'. fast typing doesn't count if the words are imaginary."
        "zsh couldn't find '${safe_cmd}' anywhere in PATH. check your spelling or your assumptions."
        "'${safe_cmd}' failed before it even started. try --help on something real."
        "nothing called '${safe_cmd}' lives on this machine. check 'which' or 'nix search'."
        "command '${safe_cmd}' missing. your fingers clearly outran your brain on that line."
        "'${safe_cmd}' doesn't exist. treating the prompt like autocomplete isn't working out."
        "no binary named '${safe_cmd}'. check if it's tucked behind a flake or typoed."
        "zsh: '${safe_cmd}' undefined. maybe slow down half a beat before hitting enter."
        "'${safe_cmd}' bounced off PATH cleanly. try again with valid syntax."
        "failed to resolve '${safe_cmd}'. your up-arrow history isn't going to rescue this one."
        "command '${safe_cmd}' doesn't register. clear the buffer and look at the home row."
        "exit 127 for '${safe_cmd}'. great cadence, wrong letters."
        "'${safe_cmd}' is not in nixpkgs or your aliases. at least not spelled like that."
        "zsh refused '${safe_cmd}' politely with a 127. backspace is still free."
        "you ran '${safe_cmd}' with full conviction and zero verification."
        "'${safe_cmd}' isn't executable or doesn't exist. check typos before blaming nixos."
        "no luck with '${safe_cmd}'. six alias files and you still invented a new verb."
        "command '${safe_cmd}' missed the mark completely. take a breath and retype."
        "'${safe_cmd}' failed lookup. maybe look at what's actually in '~/.local/bin'."
        "zsh found air instead of '${safe_cmd}'."
        "error 127: '${safe_cmd}'. this is why interactive comments exist—should've prefixed '#'."
        "cannot execute '${safe_cmd}'. syntax denial isn't a valid PATH directory."
    )

    if (( hour >= 0 && hour < 5 )); then
        notes+=(
            "'${safe_cmd}' missing at ${hour}am. your motor accuracy has officially clocked out."
            "exit 127 at ${hour}am. the terminal isn't broken, you just need actual sleep."
            "'${safe_cmd}' failed. staring harder at the screen at ${hour}am won't compile your typos."
            "it's ${hour}am and '${safe_cmd}' isn't real. wrap it up for tonight."
        )
    fi

    if (( _CRITIC_STREAK >= 8 )); then
        notes+=(
            "streak of ${_CRITIC_STREAK} misses in a row. seriously, take your hands off the desk for ten seconds."
            "${_CRITIC_STREAK} consecutive 127s. clear the terminal, sit back, reset."
        )
    elif (( _CRITIC_STREAK >= 5 )); then
        notes+=(
            "${_CRITIC_STREAK} consecutive misses ending in '${safe_cmd}'. home row check."
            "miss #${_CRITIC_STREAK}: '${safe_cmd}'. you're typing on autopilot."
        )
    elif (( _CRITIC_STREAK >= 3 )); then
        notes+=(
            "that's ${_CRITIC_STREAK} errors back to back ('${safe_cmd}'). slow down."
            "${_CRITIC_STREAK} misses straight. check your hands before hitting enter."
        )
    fi

    if [[ "${ENABLE_SYNTAX_CRITIC:-true}" == "true" ]]; then
        _critic_pick ${#notes[@]} _CRITIC_RECENT 12
        print -P "\n%F{5}󰅚%f %F{8}${notes[$REPLY]}%f"
    else
        print -Pn "\n%F{5}󰅚%f %F{8}command not found:%f "
        print -r -- "$cmd"
    fi

    if _critic_suggest_cmd "$cmd"; then
        print -Pn "  %F{4}󰁕%f %F{8}did you mean:%f "
        print -r -- "$REPLY"
    fi

    if (( ${#cmd} >= 2 )) && [[ "$cmd" != */* ]]; then
        print -Pn "  %F{6}󰄛 nix:%f "
        print -r -- "nshell $cmd   •   nrun $cmd   •   nixs $cmd"
    fi
    print ""

    _IN_CNF=0
    return 127
}

autoload -Uz add-zsh-hook

_critic_preexec() {
    _LAST_CRITIC_CMD="$1"
}
add-zsh-hook -d preexec _roast_preexec 2>/dev/null
add-zsh-hook -d precmd  _roast_precmd  2>/dev/null
add-zsh-hook -d preexec _critic_preexec 2>/dev/null
add-zsh-hook -d precmd  _critic_precmd  2>/dev/null
add-zsh-hook preexec _critic_preexec

_critic_precmd() {
    local -i last_status=$?

    if (( last_status == 0 )); then
        _CRITIC_STREAK=0
    elif [[ -n "$_LAST_CRITIC_CMD" && "$last_status" -ne 127 ]]; then
        if [[ "${ENABLE_SYNTAX_CRITIC:-true}" == "true" ]]; then
            local head_cmd="${${(z)_LAST_CRITIC_CMD}[1]:-}"
            case "$last_status" in
                139)
                    print -P "\n%F{9}󰅚%f %F{8}segfault (exit 139). memory stepped out of bounds and vanished.%f"
                    ;;
                137)
                    print -P "\n%F{9}󰅚%f %F{8}killed by kernel / oom (exit 137). something ate every megabyte of ram.%f"
                    ;;
                134)
                    print -P "\n%F{9}󰅚%f %F{8}sigabrt (exit 134). process raised its hands and walked out.%f"
                    ;;
                130)
                    # don't nag when cancelling interactive pickers/pagers/TUIs
                    case "$head_cmd" in
                        fzf|settings|config|cli|nuke|fkill|btop|top|htop|yazi|yz|y|nvim|micro|less|bat|man|glog|gbr|gdiff|fe|fif|lazygit|lg) ;;
                        *)
                            print -P "\n%F{3}󰀦%f %F{8}sigint (exit 130). clean abort before things got worse.%f"
                            ;;
                    esac
                    ;;
                126)
                    print -P "\n%F{5}󰅚%f %F{8}permission denied (exit 126). missing +x bit or blocked execution.%f"
                    ;;
            esac
        fi
    fi
    _LAST_CRITIC_CMD=""
}
add-zsh-hook precmd _critic_precmd

session_checkin() {
    zmodload -i zsh/datetime 2>/dev/null
    local hour=12 dow="Thu"
    if (( $+EPOCHSECONDS )); then
        hour=$(strftime "%-H" "$EPOCHSECONDS" 2>/dev/null || echo 12)
        dow=$(strftime "%a" "$EPOCHSECONDS" 2>/dev/null || echo "Thu")
    fi

    local -a checkins=(
        "fresh shell. try finishing one task before opening three more splits."
        "new session ready. what are we actually fixing, or are we just browsing dotfiles again."
        "terminal open. remind yourself what you clicked into here for before muscle memory types 'ls'."
        "clean buffer, fresh exit code. don't spend the next forty minutes bikeshedding config indentation."
        "shell spun up in milliseconds. now let's see if the code runs half as fast."
        "new tab allocated. check 'git status' before you forget what you changed half an hour ago."
        "session live. remember 'why' explains the last weird exit code if things go sideways."
        "ready for input. keep your commits smaller than your terminal scrollback."
        "another shell open. hydrate once before diving straight back into stack traces."
        "new workspace slice. if a command blocks, don't immediately open a second tab to ignore it."
        "buffer waiting. try actually closing the background tabs you haven't looked at since tuesday."
        "check-in: posture check. unfold your neck out of shrimp mode and sit back properly."
        "session started. if you're refactoring config again, test it before restarting everything."
        "clean prompt, zero warnings. let's try to keep the exit code at 0 this time."
        "new tty ready. reminder that 'cli doctor' checks system & theme state in one shot."
        "terminal online. your dotfiles have lore; your side project still needs actual commits."
        "opened cleanly. try 'glog' or 'gdiff' if you already forgot what you touched yesterday."
        "fresh shell. don't run 'clear' five times in a row while thinking—just run something."
        "ready. remember 'nuke' exists instead of grepping ps for rogue PIDs."
        "check-in: check battery percentage before untethering from the desk."
    )

    if (( hour >= 0 && hour < 5 )); then
        checkins+=(
            "it's ${hour}am. dim the brightness before your eyes melt through your skull."
            "${hour}am check-in. save your edits cleanly—future-you won't remember this context in the morning."
            "late session (${hour}am). wrap up the current bug and actually get real rest."
            "${hour}am terminal check-in. don't touch 'nixos-rebuild' when half asleep."
        )
    elif (( hour >= 13 && hour <= 16 )); then
        checkins+=(
            "afternoon slump check-in. drink actual water instead of running on dry caffeine."
            "mid-afternoon session. good time for smaller, boring cleanup fixes."
        )
    fi

    if [[ "$dow" == (Mon|Tue|Wed|Thu) ]] && (( hour >= 0 && hour < 6 )); then
        checkins+=(
            "${hour}am on a school night. tomorrow's alarm isn't negotiating with your uptime."
            "early weekday morning check-in. close the config after one last check."
        )
    elif [[ "$dow" == "Mon" ]] && (( hour >= 7 && hour < 11 )); then
        checkins+=(
            "monday morning check-in. ease into the week before breaking production dotfiles."
        )
    elif [[ "$dow" == "Fri" ]] && (( hour >= 18 )); then
        checkins+=(
            "friday night shell open. zero pressure, build whatever looks fun."
        )
    elif [[ "$dow" == "Sun" ]] && (( hour >= 20 )); then
        checkins+=(
            "sunday night check-in. finish up early so monday doesn't hit like a freight train."
        )
    fi

    _critic_pick ${#checkins[@]} _CHECKIN_RECENT 10
    print -P "%F{5}󰄛%f %F{8}${checkins[$REPLY]}%f\n"
}

greeting_roast() {
    session_checkin "$@"
}

critic() {
    local -a pool=(
        "your git history reads like a live transcript of mild panic followed by 'final_fix_real'."
        "spent more time tuning prompt padding this week than shipping actual code."
        "you run nixos for reproducibility and still break dotfiles by editing generated files."
        "hitting up arrow 30 times instead of pressing ctrl+r is pure stubbornness."
        "three uncommitted repos, zero readmes, spotless monospace ligatures."
        "you open 'nvim' to check one line, then spend twenty minutes adjusting plugins."
        "typing 'clear' every ten seconds doesn't clear your mental stack."
        "half your terminal tabs are just idle prompts waiting for a command you forgot."
        "check 'dots_help'—half the aliases you keep wishing existed are already installed."
        "if 'cli doctor' comes back green, maybe go write actual software next."
        "your posture just lost another two inches toward the keyboard."
        "remember ctrl+x ctrl+e drops long cursed one-liners straight into your editor."
    )
    _critic_pick ${#pool[@]} _CRITIC_RECENT 8
    print -P "%F{4}󰅚%f %F{8}${pool[$REPLY]}%f"
}

alias roast="critic"
