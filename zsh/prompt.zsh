# prompt.zsh
#
# PROMPT_STYLE:    open-line | two-line | single-line | minimal | bracket | bash
#                  pure | robby | lambda | face-prompt | kaomoji-speech | schematic
#                  capsule | custom
# KAOMOJI_SET:     reactive | cats | cute | angry | deadpan | ascii | none
# PROMPT_ACCENT:   primary | secondary | tertiary | cyan | green | magenta | yellow | white
# PROMPT_SYMBOL:   '❯'
# SHOW_GIT_PROMPT / SHOW_CMD_TIMER / SHOW_PROMPT_BANTER / SHOW_TIMESTAMP: true | false
# PROMPT_BLANK_LINE / SHOW_PWD_ONLY / SHOW_SHLVL: true | false | CMD_TIMER_MIN: int

autoload -Uz add-zsh-hook

setopt PROMPT_SUBST PROMPT_PERCENT
unsetopt PROMPT_BANG

add-zsh-hook -d preexec _cmd_timer_start 2>/dev/null
add-zsh-hook -d precmd _prompt_precmd 2>/dev/null
add-zsh-hook -d preexec _gp_preexec 2>/dev/null
add-zsh-hook -d precmd _gp_precmd 2>/dev/null

typeset -gi _GP_EXIT=0 _GP_RAN=0 _GP_ELAPSED=0
typeset -gi _GP_DIRTY=0 _GP_CONFLICT=0
typeset -g  _GP_START="" _GP_MOOD_KEY=""
typeset -g  _GP_FACE="" _GP_BANTER=""
typeset -g  _GP_LAST_FACE="" _GP_LAST_BANTER=""
typeset -g  _GP_LEFT="" _GP_RIGHT="" _GP_GIT="" _GP_BRANCH=""
typeset -g  _GP_TRANSIENT_LEFT=""

PROMPT='${_GP_LEFT}'
RPROMPT='${_GP_RIGHT}'

_gp_literal() {
    emulate -L zsh
    REPLY="${1//[[:cntrl:]]/}"
    REPLY="${REPLY//\%/%%}"
}

_gp_colors() {
    emulate -L zsh
    typeset -g _GP_OUT='%F{8}'
    typeset -g _GP_PRI='%F{4}'
    typeset -g _GP_SEC='%F{6}'
    typeset -g _GP_TER='%F{5}'
    typeset -g _GP_ERR='%F{9}'
    typeset -g _GP_WRN='%F{3}'
    typeset -g _GP_OK='%F{2}'
    typeset -g _GP_BG='4'
    typeset -g _GP_ACC="$_GP_PRI"
    typeset -g _GP_MISS="$_GP_TER"

    case "${PROMPT_ACCENT:-primary}" in
        secondary) _GP_ACC="$_GP_SEC"; _GP_MISS="$_GP_TER" ;;
        tertiary)  _GP_ACC="$_GP_TER"; _GP_MISS="$_GP_SEC" ;;
        cyan)      _GP_ACC='%F{14}';    _GP_MISS="$_GP_TER" ;;
        green)     _GP_ACC='%F{2}';     _GP_MISS="$_GP_TER" ;;
        magenta)   _GP_ACC='%F{5}';     _GP_MISS="$_GP_SEC" ;;
        yellow)    _GP_ACC='%F{3}';     _GP_MISS="$_GP_TER" ;;
        white)     _GP_ACC='%F{15}';    _GP_MISS="$_GP_TER" ;;
    esac
}

_gp_git() {
    emulate -L zsh
    _GP_GIT=""
    _GP_BRANCH=""
    _GP_DIRTY=0
    _GP_CONFLICT=0

    [[ "${SHOW_GIT_PROMPT:-true}" == true ]] || return 0
    (( $+commands[git] )) || return 0

    local raw line xy branch="" oid="" tracking REPLY
    local -i staged=0 unstaged=0 untracked=0 conflicts=0
    local -a counts details

    raw=$(command git --no-optional-locks status \
        --porcelain=v2 --branch --untracked-files=normal \
        --ignore-submodules=dirty 2>/dev/null) || return 0

    for line in "${(@f)raw}"; do
        case "$line" in
            '# branch.head '*) branch="${line#\# branch.head }" ;;
            '# branch.oid '*)  oid="${line#\# branch.oid }" ;;
            '# branch.ab '*)
                tracking="${line#\# branch.ab }"
                counts=(${(s: :)tracking})
                ;;
            '1 '*|'2 '*)
                xy="${line[3,4]}"
                [[ "${xy[1]}" != '.' ]] && (( ++staged ))
                [[ "${xy[2]}" != '.' ]] && (( ++unstaged ))
                ;;
            'u '*) (( ++conflicts )) ;;
            '? '*) (( ++untracked )) ;;
        esac
    done

    [[ -n "$branch" ]] || return 0
    [[ "$branch" == '(detached)' ]] && branch="@${oid[1,8]}"

    _gp_literal "$branch"
    branch="$REPLY"
    _GP_BRANCH="$branch"

    (( staged ))    && details+=("${_GP_TER}+${staged}%f")
    (( unstaged ))  && details+=("${_GP_SEC}~${unstaged}%f")
    (( untracked )) && details+=("${_GP_OUT}?${untracked}%f")
    (( conflicts )) && details+=("${_GP_ERR}!${conflicts}%f")

    if (( ${#counts} == 2 )); then
        [[ "${counts[1]}" != '+0' ]] && details+=("${_GP_PRI}↑${counts[1]#+}%f")
        [[ "${counts[2]}" != '-0' ]] && details+=("${_GP_SEC}↓${counts[2]#-}%f")
    fi

    (( staged + unstaged + untracked + conflicts )) && _GP_DIRTY=1
    (( conflicts )) && _GP_CONFLICT=1

    local color="$_GP_TER"
    (( _GP_DIRTY )) && color="$_GP_PRI"
    (( _GP_CONFLICT )) && color="$_GP_ERR"

    _GP_GIT=" ${_GP_OUT}(${color} ${branch}%f"
    (( ${#details} )) && _GP_GIT+=" ${(j: :)details}"
    _GP_GIT+="${_GP_OUT})%f"
    return 0
}

_gp_preexec() {
    emulate -L zsh
    _GP_START="${SECONDS%.*}"
    _GP_RAN=1
    return 0
}

_gp_mood() {
    emulate -L zsh
    local set="${KAOMOJI_SET:-reactive}"
    local state=happy key
    local -a faces words

    if (( EUID == 0 )); then
        state=root
    elif (( _GP_EXIT == 130 )); then
        state=cancelled
    elif (( _GP_EXIT == 127 )); then
        state=notfound
    elif (( _GP_EXIT != 0 )); then
        state=error
    elif (( _GP_CONFLICT )); then
        state=conflict
    elif (( _GP_ELAPSED >= 5 )); then
        state=slow
    elif (( _GP_DIRTY )); then
        state=dirty
    fi

    key="${set}:${state}"
    if [[ "$key" == "$_GP_MOOD_KEY" && ( -n "$_GP_FACE" || -n "$_GP_BANTER" ) ]] &&
       (( ! _GP_RAN )); then
        return 0
    fi
    _GP_MOOD_KEY="$key"

    case "$state" in
        root)
            faces=('(ಠ_ಠ)' '(눈_눈)' '(¬_¬ )')
            words=(
                'files do not have plot armor'
                'god mode. mortal judgment.'
                'one typo away from a fresh install'
                'no guardrails, just vibes'
                'the kernel is sweating'
            )
            ;;
        cancelled)
            faces=('(￣▽￣)ゞ' '( ._.)' '(；￣Д￣)')
            words=(
                'tactical retreat'
                'we saw nothing'
                'actually never mind'
                'changed my mind, valid'
                'pretend that never happened'
            )
            ;;
        notfound)
            faces=('(・_・?)' '(⊙_⊙?)' '(・・?)')
            words=(
                'never heard of her'
                'typo or hallucination?'
                'bestie that is not a command'
                'you just made that up'
                'keyboard smash detected'
            )
            ;;
        error)
            faces=('(╯°□°)╯︵ ┻━┻' '(ಥ_ಥ)' '(╥﹏╥)' '(ノಠ益ಠ)ノ')
            words=(
                'that was character development'
                'computer says no'
                'the plot thickens'
                'well shit'
                'skill issue (affectionate)'
                'certified oopsie'
                'bold move. did not pay off.'
                'the audacity of this exit code'
            )
            ;;
        conflict)
            faces=('(ง •̀_•́)ง' '(⊙_⊙;)' '(ಠ益ಠ)')
            words=(
                'git chose violence'
                'pick a timeline'
                'both sides brought receipts'
                'merge drama'
                'reality has forked'
                'two branches enter, one survives'
            )
            ;;
        slow)
            faces=('(－_－) zzZ' '(눈_눈)' '(∪｡∪)｡｡｡zzZ')
            words=(
                'finally'
                'a geological event'
                'took three business days'
                'did it walk there?'
                'thought we froze ngl'
                'welcome back from the void'
            )
            ;;
        dirty)
            faces=('(・_・;)' '(¬_¬ )' '(；・∀・)')
            words=(
                'little crimes, uncommitted'
                'the worktree has lore'
                'nothing to see here'
                'commit issues, literally'
                'chaos in the working tree'
                'future you will hate this diff'
            )
            ;;
        *)
            faces=('(◕‿◕✿)' 'ᓚᘏᗢ' '(⌐■_■)' '( ˘▽˘)っ旦' '(｡•̀ᴗ-)✧')
            words=(
                'professionally unserious'
                'it works. suspicious.'
                'certified terminal creature'
                'tiny wins count'
                'zero errors, suspiciously peaceful'
                'brain empty, shell ready'
                'suspiciously competent today'
                'running on vibes and caffeine'
                'clean slate, go break something'
            )
            ;;
    esac

    case "$set" in
        none|off|disabled|false)
            faces=()
            ;;
        cats)
            case "$state" in
                error|conflict) faces=('(=；ェ；=)' '(=ＴェＴ=)' '(=｀ェ´=)' 'ฅ(•ㅅ•;)ฅ') ;;
                notfound)       faces=('(=・ω・=?)' '/ᐠ｡ꞈ｡ᐟ\?' '(=^･ｪ･^=)?') ;;
                cancelled)      faces=('(=￣ω￣=)' '(=´∇｀=;)') ;;
                slow)           faces=('(=‐ω‐=) zzZ' '(=˘ω˘=)') ;;
                dirty)          faces=('(=｀ω´=)' '(=^･ω･^;)') ;;
                root)           faces=('(=｀ェ´=)' 'ฅ(•̀_•́ฅ)') ;;
                *)              faces=('ᓚᘏᗢ' '(=^･ω･^=)' '(=^･ｪ･^=)' '/ᐠ｡ꞈ｡ᐟ\' 'ฅ(^･ω･^)ฅ') ;;
            esac
            ;;
        cute)
            case "$state" in
                error|conflict) faces=('(╥﹏╥)' '(｡•́︿•̀｡)' '(っ- ‸ - ς)' '(｡>﹏<｡)') ;;
                notfound)       faces=('(・_・?)' '(｡•́︿•̀｡)' '(✿´・_・`)?') ;;
                cancelled)      faces=('(✿˘･_･˘)' '(っ˘̩╭╮˘̩)っ' '(；￣Д￣)') ;;
                slow)           faces=('(✿◡‿◡)' '(∪｡∪)｡｡｡zzZ') ;;
                dirty)          faces=('(；・∀・)' '(✿・_・;)') ;;
                root)           faces=('(｡•̀_•́｡)' '(✿ಠ_ಠ)') ;;
                *)              faces=('(◕‿◕✿)' '(✿◠‿◠)' '(｡♥‿♥｡)' '(≧◡≦)' '(｡•̀ᴗ-)✧') ;;
            esac
            ;;
        angry|rage)
            case "$state" in
                error|conflict) faces=('(╯°□°)╯︵ ┻━┻' '(ノಠ益ಠ)ノ' '(╬ಠ益ಠ)' '(ﾒ｀ﾛ´)') ;;
                notfound)       faces=('(╬ Ò﹏Ó)?' '(ノಠ益ಠ)ノ?') ;;
                cancelled)      faces=('┬─┬ノ( º _ ºノ)' '(눈_눈)') ;;
                slow)           faces=('(ﾒ｀ﾛ´)' '(╬ಠ益ಠ)') ;;
                dirty)          faces=('(ಠ益ಠ)' '(ﾒ｀ﾛ´)') ;;
                root)           faces=('(╬ಠ益ಠ)' '(ノಠ益ಠ)ノ') ;;
                *)              faces=('(ง •̀_•́)ง' '┻━┻ ︵ヽ(`Д´)ﾉ︵ ┻━┻' '(•̀_•́)') ;;
            esac
            ;;
        deadpan|doom)
            case "$state" in
                error|conflict) faces=('(x_x)' '(ಥ_ಥ)' '(－_ლ)') ;;
                notfound)       faces=('(⊙_⊙?)' '(¬_¬;)' '(・_・?)') ;;
                cancelled)      faces=('( ._.)' '(¬_¬ )') ;;
                slow)           faces=('(눈_눈)' '(－_－) zzZ') ;;
                dirty)          faces=('(¬_¬ )' '(；一_一)') ;;
                root)           faces=('(ಠ_ಠ)' '(⚆_⚆)') ;;
                *)              faces=('(눈_눈)' '(¬_¬ )' '(；一_一)' '(⚆_⚆)') ;;
            esac
            ;;
        ascii)
            case "$state" in
                error|conflict) faces=('(>_<)' '(x_x)' 'D:') ;;
                notfound)       faces=('(?_?)' '(o_O)') ;;
                slow)           faces=('(-_-) zzz' '(-.-)') ;;
                dirty)          faces=('(o_o;)' '(^_^;)') ;;
                root)           faces=('(-_-)') ;;
                cancelled)      faces=('(._.)') ;;
                *)              faces=('(^_^)' '(=^.^=)' '(^o^)') ;;
            esac
            ;;
    esac

    if (( ${#faces} )); then
        local -i fidx=$(( RANDOM % ${#faces} + 1 ))
        if (( ${#faces} > 1 )) && [[ "${faces[$fidx]}" == "$_GP_LAST_FACE" ]]; then
            fidx=$(( (fidx % ${#faces}) + 1 ))
        fi
        _GP_FACE="${faces[$fidx]}"
        _GP_LAST_FACE="$_GP_FACE"
    else
        _GP_FACE=""
        _GP_LAST_FACE=""
    fi

    if (( ${#words} )); then
        local -i widx=$(( RANDOM % ${#words} + 1 ))
        if (( ${#words} > 1 )) && [[ "${words[$widx]}" == "$_GP_LAST_BANTER" ]]; then
            widx=$(( (widx % ${#words}) + 1 ))
        fi
        _GP_BANTER="${words[$widx]}"
        _GP_LAST_BANTER="$_GP_BANTER"
    else
        _GP_BANTER=""
    fi
    return 0
}

_gp_render_custom() {
    emulate -L zsh
    local s="$1" out="" pre tok rep
    local c_id="$2" c_dir="$3" c_pwd="$4" c_full="$5" c_branch="$6"
    local c_ctx="$7" c_face="$8" c_sym="$9" c_dollar="${10}"
    local c_venv="${11}" c_extras="${12}" c_exit="${13}" c_timer="${14}"
    local c_banter="${15}" c_time="${16}" c_acc="${17}" c_miss="${18}"

    while [[ "$s" == *'{'*'}'* ]]; do
        pre="${s%%\{*}"
        out+="$pre"
        s="${s#*\{}"
        if [[ "$s" == *'}'* ]]; then
            tok="${s%%\}*}"
            s="${s#*\}}"
            if [[ "$tok" == *'{'* ]]; then
                out+="{${tok%%\{*}"
                s="{${tok#*\{}}${s}"
                continue
            fi
            case "$tok" in
                nl)      rep=$'\n' ;;
                pri)     rep="$_GP_PRI" ;;
                sec)     rep="$_GP_SEC" ;;
                ter)     rep="$_GP_TER" ;;
                out)     rep="$_GP_OUT" ;;
                ok)      rep="$_GP_OK" ;;
                wrn)     rep="$_GP_WRN" ;;
                err)     rep="$_GP_ERR" ;;
                acc)     rep="$c_acc" ;;
                miss)    rep="$c_miss" ;;
                rst)     rep="%f" ;;
                user)    rep="${_GP_PRI}%n%f" ;;
                host)    rep="${_GP_SEC}%m%f" ;;
                id)      rep="$c_id" ;;
                dir)     rep="$c_dir" ;;
                pwd)     rep="$c_pwd" ;;
                full)    rep="$c_full" ;;
                git)     rep="$_GP_GIT" ;;
                branch)  rep="$c_branch" ;;
                venv)    rep="$c_venv" ;;
                extras)  rep="$c_extras" ;;
                context) rep="$c_ctx" ;;
                face)    rep="$c_face" ;;
                sym)     rep="$c_sym" ;;
                dollar)  rep="$c_dollar" ;;
                exit)    rep="$c_exit" ;;
                timer)   rep="$c_timer" ;;
                banter)  rep="$c_banter" ;;
                time)    rep="$c_time" ;;
                time24)  rep="${_GP_OUT}%T%f" ;;
                time12)  rep="${_GP_OUT}%t%f" ;;
                date)    rep="${_GP_OUT}%D{%m/%d}%f" ;;
                *)       rep="{${tok}}" ;;
            esac
            out+="$rep"
        else
            out+="{${s}"
            s=""
        fi
    done

    REPLY="${out}${s}"
}

_gp_build() {
    emulate -L zsh
    local out="$_GP_OUT" pri="$_GP_PRI" sec="$_GP_SEC"
    local ter="$_GP_TER" err="$_GP_ERR" wrn="$_GP_WRN" ok="$_GP_OK" acc="$_GP_ACC"
    local miss="${_GP_MISS:-$_GP_TER}"
    local REPLY symbol face="" identity dir dir_spec extras="" venv=""
    local elapsed="" vname style="${PROMPT_STYLE:-two-line}" nl=""
    local branch_tok="" robby_git="" custom_dollar="" exit_tok="" timer_tok="" banter_tok="" time_tok=""
    local -i timer_min=1
    local -a rparts

    [[ "${PROMPT_BLANK_LINE:-true}" == true ]] && nl=$'\n'
    if [[ "${CMD_TIMER_MIN:-1}" == <-> ]]; then
        timer_min="${CMD_TIMER_MIN:-1}"
    fi

    (( _GP_EXIT == 130 )) && acc="$wrn"
    (( _GP_EXIT != 0 && _GP_EXIT != 130 )) && acc="$miss"
    (( EUID == 0 )) && acc="$err"

    _gp_literal "${PROMPT_SYMBOL:-❯}"
    symbol="${acc}${REPLY}%f"
    custom_dollar="${acc}%(#.#.\$)%f"
    _GP_TRANSIENT_LEFT="${out}%D{%H:%M}%f ${symbol} "

    if [[ -n "$_GP_FACE" ]]; then
        _gp_literal "$_GP_FACE"
        face="${acc}${REPLY}%f"
    fi

    identity="${pri}%n${out}@${sec}%m%f"
    if [[ "${SHOW_PWD_ONLY:-false}" == true ]]; then
        dir_spec='%1~'
    else
        dir_spec='%~'
    fi
    dir="${ter}${dir_spec}%f"

    [[ -w . ]] || extras+=" ${err}%f"
    (( ${#jobstates} )) && extras+=" ${wrn}⚙ ${#jobstates}%f"

    if [[ -n "${SSH_CONNECTION-}${SSH_CLIENT-}" ]]; then
        extras+=" ${sec}[ssh]%f"
    fi

    if [[ "${SHOW_SHLVL:-true}" == true ]] && (( SHLVL > 1 )) &&
       [[ -z "${TMUX-}" && "${TERM_PROGRAM-}" != vscode ]]; then
        extras+=" ${out}[lvl:${SHLVL}]%f"
    fi

    if [[ -n "${VIRTUAL_ENV-}" ]]; then
        vname="${VIRTUAL_ENV:t}"
        [[ "$vname" == (.venv|venv) ]] && vname="${VIRTUAL_ENV:h:t}"
        _gp_literal "$vname"
        venv=" ${out}[${sec}󰌠 ${REPLY}${out}]%f"
    elif [[ -n "${CONDA_DEFAULT_ENV-}" ]]; then
        _gp_literal "$CONDA_DEFAULT_ENV"
        venv=" ${out}[${sec}󱔎 ${REPLY}${out}]%f"
    fi

    if (( EUID == 0 )); then
        identity="${err}󰀦 %n@%m [root]%f"
    fi

    local context="${_GP_GIT}${venv}${extras}"

    if [[ -n "$_GP_BRANCH" ]]; then
        branch_tok="${ter}${_GP_BRANCH}%f"
        robby_git=" ${pri}git:(%f${ter}${_GP_BRANCH}${pri})%f"
        (( _GP_DIRTY )) && robby_git+=" ${wrn}✗%f"
    fi

    if (( _GP_EXIT == 130 )); then
        exit_tok="${wrn}✘ ${_GP_EXIT}%f"
        rparts+=("$exit_tok")
    elif (( _GP_EXIT != 0 )); then
        exit_tok="${miss}✘ ${_GP_EXIT}%f"
        rparts+=("$exit_tok")
    fi

    if [[ "${SHOW_PROMPT_BANTER:-true}" == true && -n "$_GP_BANTER" ]] &&
       (( ${COLUMNS:-80} >= 110 )); then
        _gp_literal "$_GP_BANTER"
        banter_tok="${out}${REPLY}%f"
        rparts+=("$banter_tok")
    fi

    if [[ "${SHOW_CMD_TIMER:-true}" == true ]] && (( _GP_ELAPSED >= timer_min )); then
        local -i hours=$(( _GP_ELAPSED / 3600 ))
        local -i mins=$(( _GP_ELAPSED / 60 % 60 ))
        local -i secs=$(( _GP_ELAPSED % 60 ))

        (( hours )) && elapsed+="${hours}h"
        (( hours || mins )) && elapsed+="${mins}m"
        elapsed+="${secs}s"
        timer_tok="${sec}${elapsed}%f"
        rparts+=("$timer_tok")
    fi

    if [[ "${SHOW_TIMESTAMP:-true}" == true ]]; then
        time_tok="${out}%T%f"
        rparts+=("$time_tok")
    fi

    case "$style" in
        single-line)
            _GP_LEFT="${face:+${face} }${identity} ${out}in ${dir}${context} ${symbol} "
            ;;
        minimal)
            _GP_LEFT="${face:+${face} }${dir}${context} ${symbol} "
            ;;
        bracket)
            _GP_LEFT="${out}[${identity} ${dir}${out}]%f${face:+ ${face}}${context} ${symbol} "
            ;;
        bash)
            local bash_meta="${context}${face:+ ${face}}"
            _GP_LEFT="${out}[${identity}${out}:${dir}${out}]%f${bash_meta:+${bash_meta} }${custom_dollar} "
            ;;
        pure)
            _GP_LEFT="${nl}${dir}${context}${face:+ ${face}}"
            _GP_LEFT+=$'\n'"${symbol} "
            ;;
        robby)
            _GP_LEFT="${acc}➜%f ${sec}%1~%f${robby_git}${venv}${extras}${face:+ ${face}} "
            ;;
        lambda)
            _GP_LEFT="${acc}λ%f ${dir}${context}${face:+ ${face}} "
            ;;
        face-prompt|gremlin)
            _GP_LEFT="${nl}${identity} ${out}in ${dir}${context}"
            _GP_LEFT+=$'\n'"${face:-${symbol}} "
            ;;
        kaomoji-speech)
            _GP_LEFT="${nl}${face:+${face} }${out}「${dir}${out}」%f ${identity}${context}"
            _GP_LEFT+=$'\n'"${out}╰─%f ${symbol} "
            ;;
        schematic|cyberpunk)
            _GP_LEFT="${nl}${out}┌──[ ${identity} ${out}:: ${dir} ${out}]%f${face:+ ${face}}${context}"
            _GP_LEFT+=$'\n'"${out}└──╼%f ${symbol} "
            ;;
        capsule)
            _GP_LEFT="${nl}${pri}%K{4}%F{0}%B%n@%m%b%f%k${pri} ${sec}%K{6}%F{0}${dir_spec}%f%k${sec}%f${face:+ ${face}}${context}"
            _GP_LEFT+=$'\n'"${symbol} "
            ;;
        custom)
            local c_left="${PROMPT_CUSTOM_LEFT-}"
            [[ -z "$c_left" ]] && c_left='{nl}{id} {out}in {dir}{context} {face}{nl}{sym} '
            local c_right="${PROMPT_CUSTOM_RIGHT-}"
            _gp_render_custom "$c_left" "$identity" "$dir" "${ter}%1~%f" "${ter}%~%f" \
                "$branch_tok" "$context" "$face" "$symbol" "$custom_dollar" "$venv" "$extras" \
                "$exit_tok" "$timer_tok" "$banter_tok" "$time_tok" "$acc" "$miss"
            _GP_LEFT="$REPLY"

            if [[ "$c_right" == (none|off|empty) ]]; then
                _GP_RIGHT=""
                return 0
            elif [[ -n "$c_right" ]]; then
                _gp_render_custom "$c_right" "$identity" "$dir" "${ter}%1~%f" "${ter}%~%f" \
                    "$branch_tok" "$context" "$face" "$symbol" "$custom_dollar" "$venv" "$extras" \
                    "$exit_tok" "$timer_tok" "$banter_tok" "$time_tok" "$acc" "$miss"
                REPLY="${REPLY//  / }"
                REPLY="${REPLY## }"
                REPLY="${REPLY%% }"
                _GP_RIGHT="$REPLY"
                return 0
            fi
            ;;
        two-line)
            _GP_LEFT="${nl}${out}╭─[ ${identity} ${out}in ${dir}${out}]%f${face:+ ${face}}${context}"
            _GP_LEFT+=$'\n'"${out}╰─%f ${symbol} "
            ;;
        open-line|unhinged|*)
            _GP_LEFT="${nl}${out}╭── ${face:+${face} }${identity} ${out}in ${dir}${context}"
            _GP_LEFT+=$'\n'"${out}╰───%f ${symbol} "
            ;;
    esac

    _GP_RIGHT="${(j: :)rparts}"
    return 0
}

_gp_zle_line_finish() {
    if [[ "${TRANSIENT_PROMPT:-false}" == "true" ]]; then
        case "${PROMPT_STYLE:-two-line}" in
            single-line|minimal|bracket|bash|robby|lambda) ;;
            custom)
                if [[ "${PROMPT_CUSTOM_LEFT-}" == *$'\n'* || "${PROMPT_CUSTOM_LEFT-}" == *'{nl}'* ]]; then
                    PROMPT='${_GP_TRANSIENT_LEFT}'
                    RPROMPT=''
                    zle .reset-prompt 2>/dev/null || zle reset-prompt 2>/dev/null
                fi
                ;;
            *)
                PROMPT='${_GP_TRANSIENT_LEFT}'
                RPROMPT=''
                zle .reset-prompt 2>/dev/null || zle reset-prompt 2>/dev/null
                ;;
        esac
    fi
}
zle -N zle-line-finish _gp_zle_line_finish

_gp_reload() {
    _GP_MOOD_KEY=""
    _gp_colors
    _gp_git
    _gp_mood
    _gp_build
    PROMPT='${_GP_LEFT}'
    RPROMPT='${_GP_RIGHT}'
}

_gp_precmd() {
    local -i last_exit=$?
    emulate -L zsh

    PROMPT='${_GP_LEFT}'
    RPROMPT='${_GP_RIGHT}'

    if (( _GP_RAN )); then
        _GP_EXIT=$last_exit
        _GP_ELAPSED=0

        if [[ -n "$_GP_START" ]]; then
            (( _GP_ELAPSED = ${SECONDS%.*} - _GP_START ))
            (( _GP_ELAPSED < 0 )) && _GP_ELAPSED=0
        fi

        _GP_START=""
    else
        _GP_EXIT=0
        _GP_ELAPSED=0
    fi

    _gp_colors
    _gp_git
    _gp_mood
    _gp_build

    _GP_RAN=0
    return 0
}

add-zsh-hook preexec _gp_preexec
add-zsh-hook precmd _gp_precmd

_gp_precmd
