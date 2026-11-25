# zsh

zero-framework zsh environment. configs compile to `.zwc` bytecode so interactive startup is instant regardless of module count.

## modules

- `prompt.zsh`: reactive prompt engine. git v2 status, command timers, transient collapse, and instant layout switching via `settings`.
- `roast.zsh`: syntax critic and session check-in engine. hooks `command_not_found_handler` with non-repeating dry commentary, pure-zsh typo correction, and nix package hints.
- `nuke.zsh`: fzf process sniper with live preview, multi-select, and batched sudo escalation.
- `dnd.zsh`: do-not-disturb toggle that writes directly into quickshell's state without ipc.
- `tools.zsh`: `zoxide`, `eza`, `bat`, `rg`, `fd`, `btop`, `yazi`, and `fzf` integration. `c` replaces `cd` with auto-ls on arrival.
- `functions.zsh`: `glog` / `gbr` / `gdiff` interactive git tools, `extract`, `ports`, `serve`, `calc`, `take`, `fif`, `fe`, and `nixs`.
- `aliases.zsh`: nixos rebuild/update (`sysup`/`nixup`), gc shortcuts (`cleanup`), safe file ops, `why`, `please`, and named directory hashes (`~qs`, `~hypr`, `~nix`, etc.).
- `settings.zsh` & `user_prefs.conf`: live terminal customization hub. prompt style, syntax critic toggle, session check-in, transient mode, vi/emacs bind mode, and config quick-jump. `user_prefs.conf` is gitignored — it's yours.
- `matugen.zsh`: wallpaper-synced palette exports. injects ansi hex codes into `fzf`, `zsh-syntax-highlighting`, and `NEWT_COLORS` on every matugen run.
- `help.zsh`: cheat sheet rendered by `dots_help`, `cheatsheet`, or bare `help` with no arguments.

## commands worth knowing

```zsh
sysup              # nix flake update + nixos-rebuild switch + commit flake.lock + push
sysup "my message" # same but with a custom commit message instead of a random one
nixup              # alias for sysup

rebuild            # sudo nixos-rebuild switch --flake .#lost
test-build         # nixos-rebuild test  (doesn't set boot entry)
boot-build         # nixos-rebuild boot  (staged, activates on next reboot)
cleanup            # nix-collect-garbage --delete-older-than 7d (user + system)
gens               # list nixos generations

settings           # interactive prompt/config customization menu
dots_help          # full cheat sheet
why                # decode the last exit code
please             # re-run the last command with sudo
nuke               # interactive process sniper (fzf multi-select)
dnd                # toggle do-not-disturb in quickshell
```
