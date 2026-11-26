typeset -g MATUGEN_PRIMARY="{{colors.primary.default.hex}}"
typeset -g MATUGEN_SECONDARY="{{colors.secondary.default.hex}}"
typeset -g MATUGEN_TERTIARY="{{colors.tertiary.default.hex}}"
typeset -g MATUGEN_ERROR="{{colors.error.default.hex}}"
typeset -g MATUGEN_OUTLINE="{{colors.outline.default.hex}}"
typeset -g MATUGEN_SURFACE="{{colors.surface.default.hex}}"
typeset -g MATUGEN_ON_SURFACE="{{colors.on_surface.default.hex}}"
typeset -g MATUGEN_IS_DARK="<* if {{is_dark_mode}} *>true<* else *>false<* endif *>"

# ANSI-indexed fzf + zsh + newt styles adapt instantaneously across open tabs on kitty SIGUSR1
export FZF_DEFAULT_OPTS="--height 45% --layout=reverse --border=rounded --inline-info --color=bg:-1,bg+:-1,gutter:-1,spinner:4,hl:5,fg:7,fg+:15,header:6,info:4,pointer:12,marker:12,prompt:4,hl+:13,border:8"
export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=8"
export NEWT_COLORS="root=white,default:window=white,default:shadow=black,default:border=blue,default:title=blue,default:button=black,blue:actbutton=black,cyan:compactbutton=blue,default:checkbox=white,default:actcheckbox=black,blue:entry=white,default:disentry=gray,default:label=white,default:listbox=white,default:actlistbox=black,blue:sellistbox=black,cyan:actsellistbox=black,cyan:textbox=white,default:acttextbox=white,default:helpline=gray,default:roottext=gray,default:emptyscale=gray,default:fullscale=blue,default"

typeset -gA ZSH_HIGHLIGHT_STYLES
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
