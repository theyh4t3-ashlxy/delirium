# btop

terminal resource monitor. watches your cpu melt, your ram disappear, and your processes do things you did not ask for.

## config

- `btop.conf`: the main config. `color_theme = "TTY"` tells btop to inherit the terminal's ansi palette directly instead of loading a theme file. this means every time matugen regenerates `colors.conf` and kitty reloads via `pkill -USR1 kitty`, btop's colors update too. no separate theme file required.
- `save_config_on_exit = false` keeps btop from overwriting the repo copy when you close it. if you want to change a persistent setting, edit `btop.conf` directly and commit it.
- `theme_background = False` makes btop's background transparent so it respects your terminal's background color instead of painting a solid box over it.
- `truecolor = true` even though the theme is TTY — btop still uses 24-bit for its own graph gradients within the ansi palette constraints.

## themes

the `themes/` directory is here because btop looks for theme files relative to the binary or `$HOME/.config/btop/themes`. it's empty by default because `TTY` mode doesn't need one. if you want a custom theme file (`.theme`), drop it here and change `color_theme` in `btop.conf` to match the filename without extension.

## usage note

btop reads the symlinked config from `~/.config/btop/btop.conf` → `~/.local/share/dotfiles/btop/btop.conf`. if btop's colors look wrong after a wallpaper switch, the terminal palette hasn't reloaded yet. run `pkill -USR1 kitty` or switch your wallpaper again.
