# zsh

frameworkless zsh compiled to `.zwc` bytecode so interactive prompts appear instantaneously before doubt reaches your prefrontal cortex.

oh-my-zsh wastes hundreds of milliseconds parsing dead plugin wrappers so newcomers feel cushioned while waiting for a prompt. everything here runs native, compiled, and openly contemptuous of hesitant typing.

## modules

- `prompt.zsh`: reactive prompt reporting git v2 state, command timing, transient line collapse, and layout switching via `settings`.
- `roast.zsh`: syntax critic hooking `command_not_found_handler` with dry, unrepeating disapproval, pure-zsh spell correction, and nixpkgs package hints whenever fatigue turns two keystrokes into gibberish.
- `nuke.zsh`: `fzf` process termination selector using live previews, multi-select marking, and batched `sudo` signal escalation to execute unresponsive daemons without offering polite `SIGTERM` negotiation.
- `dnd.zsh`: writes silence state directly into quickshell's runtime files without waiting on IPC round-trips.
- `tools.zsh`: integrates `zoxide`, `eza`, `bat`, `rg`, `fd`, `btop`, `yazi`, and `fzf`. redefines `c` to replace `cd` with immediate directory listing so dead folders cannot hide behind silent transitions.
- `functions.zsh`: interactive git inspection (`glog`, `gbr`, `gdiff`), archive extraction (`extract`), socket auditing (`ports`, `serve`), `calc`, `take`, `fif`, `fe`, and `nixs`.
- `aliases.zsh`: full-flake rebuild pipeline (`sysup` / `nixup`), generation purge (`cleanup`), interactive file guardrails (`rm -I`, `cp -iv`, `mv -iv`), `why`, `please`, and named hashes (`~qs`, `~hypr`, `~nix`).
- `settings.zsh` & `user_prefs.conf`: live terminal control panel adjusting prompt layout, syntax critic cadence, check-ins, transient prompt cleanup, and `vi`/`emacs` keymaps. `user_prefs.conf` stays gitignored so machine changes never pollute `git status`.
- `matugen.zsh`: exports runtime wallpaper colors into `fzf`, `zsh-syntax-highlighting`, and `NEWT_COLORS`.
- `help.zsh`: cheat sheet printed on `dots_help`, `cheatsheet`, or bare `help`.

## operations

```zsh
sysup              # nix flake update + nixos-rebuild switch + commit flake.lock + push
sysup "message"    # override randomized lockfile commit quote
nixup              # alias for sysup

rebuild            # sudo nixos-rebuild switch --flake .#lost
test-build         # nixos-rebuild test (volatile generation, skipped on boot menu)
boot-build         # nixos-rebuild boot (activates only after reboot)
cleanup            # purge nix generations older than 7 days across user and system
gens               # list nixos generations

settings           # terminal customization panel
dots_help          # full command reference
why                # translate previous exit status
please             # replay last command wrapped in sudo
nuke               # fzf process termination
dnd                # toggle quickshell do-not-disturb
```
