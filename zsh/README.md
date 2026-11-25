# zsh

an over-engineered zsh environment compiled to bytecode (`.zwc`) so interactive startup stays instant.

zero heavy frameworks, zero bloated prompt wrappers. just compiled zsh bytecode, fast muscle-memory aliases, ANSI-synced colors across light and dark mode, and dry feedback when things break.

## modules
- `prompt.zsh`: reactive prompt engine with git v2 status, command timers, optional transient collapse, and instant layout/mood switching via `settings`.
- `roast.zsh`: syntax critic & session check-in engine. hooks into `command_not_found_handler` with non-repeating dry commentary, pure-zsh typo suggestions, and nix hints.
- `nuke.zsh`: interactive fzf process sniper with live preview, multi-select, and batched sudo escalation.
- `dnd.zsh`: do-not-disturb toggle synced directly with quickshell's `settings.conf`.
- `tools.zsh`: `zoxide`, `eza`, `bat`, `rg`, `fd`, `btop`, `yazi`, and `fzf` integration.
- `functions.zsh`: interactive `glog` / `gbr` / `gdiff` git tools, `extract`, `ports`, `serve`, `calc`, `take`, `fif`, `fe`, and `nixs`.
- `aliases.zsh`: nixos rebuild/update (`sysup`), gc shortcuts, safe file ops, `why`, `please`, and directory hashes.
- `settings.zsh` & `user_prefs.conf`: live terminal customization hub (`syntax critic`, `session check-in`, prompt layout, transient prompt, vi/emacs mode, config quick-jump).
- `matugen.zsh`: wallpaper-synced palette exports, ANSI `fzf` colors, `zsh-syntax-highlighting`, and `NEWT_COLORS`.
- `help.zsh`: quick cheat sheet (`dots_help` / `cheatsheet` / bare `help`).
