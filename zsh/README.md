# zsh

an over-engineered zsh environment compiled to bytecode (`.zwc`) because life is too short to watch a shell prompt load for forty business days.

if your interactive shell takes more than five milliseconds to render a prompt, you have failed as an engineer and your ancestors are disappointed in you. zero heavy oh-my-zsh frameworks, zero twelve-layer ruby plugins, zero corporate node prompts. just pure compiled zsh bytecode, ruthless alias muscle memory, and psychological warfare against typos.

## the modules of doom
- `prompt.zsh`: dynamic two-line prompt engine with git status branches, execution timers, and hot-switchable aesthetic modes without restarting your session.
- `roast.zsh`: the existential executioner. hooks into `command_not_found_handler` to track your cognitive decline across terminal sessions. if you typo a binary, it won't just fail; it will publicly roast your lack of sleep, your 40 open arch wiki tabs, and your broken muscle memory directly in stdout.
- `nuke.zsh`: interactive fzf-powered process assassin. search rogue pids with live cpu/memory previews, select multiple victims with tab, and send `SIGKILL` with automatic sudo fallback.
- `dnd.zsh`: instant do-not-disturb toggle switch right from the terminal prompt so notifications stop interrupting your late-night debugging spirals.
- `tools.zsh`: rust and modern cli accelerators. aliases `zoxide` to `cd`, wraps `eza` for instant tree and file badge views, and sets up `bat` for colorized pager previews.
- `functions.zsh`: desktop helper utilities, instant extraction routines, and cli shortcuts.
- `aliases.zsh`: hundreds of muscle-memory shortcuts saving thousands of keystrokes per session so you can pretend you're working faster than you actually are.
- `settings.zsh` & `user_prefs.conf`: persistent terminal customization engine. toggle git prompt badges, execution timers, or psycho roasts on the fly.
- `matugen.zsh`: shell prompt gradient chips and highlight tokens extracted straight from the active wallpaper via matugen.
- `help.zsh`: instant terminal cheat sheet for when you forget what keybinds you mapped at 3:15 am.
