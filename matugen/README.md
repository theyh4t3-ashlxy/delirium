# matugen

material you color engine. reads a wallpaper, extracts palette tokens, and writes them simultaneously across hyprland, kitty, quickshell, fastfetch, zsh, nvim, yazi, and gtk.

one `wp random` and every surface on the desktop recolors live, including open terminal windows via `pkill -USR1 kitty` without restarting them.

## components

- `config.toml`: defines input templates, output paths, and post-compile reload hooks. everything matugen touches is listed here.
- `templates/`: skeleton configs with `{{ variable }}` placeholders. matugen fills these and writes the compiled outputs to their target paths.
  - `kitty-colors.conf` → `kitty/colors.conf`: ansi registers `color0`–`color15` plus foreground, background, cursor, selection. all terminal color in the setup flows from these 16 slots.
  - `fastfetch-colors.jsonc` → `fastfetch/config.jsonc`: fastfetch layout and ansi color names. the generated file is gitignored; edit the template.
  - `zsh-colors.zsh` → `zsh/matugen.zsh`: hex exports for fzf, zsh-syntax-highlighting, and NEWT_COLORS.
  - `palette.css` → `quickshell/palette.css`: material 3 tokens read live by the quickshell theme engine.
  - gtk3/gtk4, hyprland, nvim, kde: same pattern.
- `post-hook-scripts/`: shell scripts that run after template compilation. `pkill -USR1 kitty` for live terminal reload, hyprctl for border recolor, gsettings for gtk dark mode sync.

## notes

- always pass `--source-color-index 0` in scripts. without it, matugen waits for stdin input that will never arrive.
- templates use `<* if {{is_dark_mode}} *>` / `<* else *>` blocks for dark/light conditional output. one template, two modes, no duplicate files.
- kitty colors are pure ansi indices with zero hardcoded hex values in app configs. the hex lives only in `kitty/colors.conf` where matugen controls it.
