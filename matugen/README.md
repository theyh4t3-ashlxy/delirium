# matugen

material palette extraction rewriting every surface on the system from a single wallpaper seed.

one `wp random` sweeps existing colors out of hyprland borders, kitty, quickshell, fastfetch, zsh, nvim, yazi, and gtk simultaneously, forcing an instant monochrome or tonal sterilization without tearing down running applications. `pkill -USR1 kitty` updates active terminal buffers mid-command so even scrollback from thirty minutes ago wakes up inside the new palette.

## pipeline structure

- `config.toml`: registry mapping every input template to its compilation output path and post-write hook.
- `templates/`: source skeletons containing `{{ variable }}` tokens expanded during palette synthesis.
  - `kitty-colors.conf` -> `kitty/colors.conf`: owns ansi slots `color0`–`color15`, cursor, selection, and background. terminal apps inherit nothing outside these 16 registers.
  - `fastfetch-colors.jsonc` -> `fastfetch/config.jsonc`: layout and ansi labels. the compiled file is gitignored because editing generated artifacts instead of templates wastes effort.
  - `zsh-colors.zsh` -> `zsh/matugen.zsh`: exports palette strings for `fzf`, `zsh-syntax-highlighting`, and `NEWT_COLORS`.
  - `palette.css` -> `quickshell/palette.css`: material 3 tokens watched live on disk by `Theme.qml`.
  - gtk3, gtk4, hyprland, nvim, and kde outputs follow identical rewrite rules.
- `post-hook-scripts/`: synchronous hooks signaling kitty (`USR1`), notifying hyprctl, and toggling gsettings dark mode right after output emission.

## operational constraints

- pass `--source-color-index 0` in automated scripts. omitting it leaves matugen blocking indefinitely on stdin for an interactive choice that will never arrive.
- templates branch via `<* if {{is_dark_mode}} *>` / `<* else *>` inside a single file rather than maintaining duplicate light/dark skeletons.
- hexadecimal color literals are stripped out of application configs wherever possible so only `kitty/colors.conf` and `palette.css` hold concrete values.
