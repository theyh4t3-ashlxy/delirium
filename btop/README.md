# btop

terminal resource witness left running inside an empty workspace mostly to confirm whether runaway Chromium tabs or leaked QML objects will finish eating the `15.29 GiB` of RAM (`7.65 GiB` `zram0` + `16.82 GiB` NVMe swap) before morning.

## settings

- `btop.conf`: sets `color_theme = "TTY"` so graphs inherit raw terminal ANSI slots directly. when `matugen` rewrites `colors.conf` and `pkill -USR1 kitty` runs, colors update mid-draw without a restart.
- `save_config_on_exit = false`: prevents closing btop from writing transient window choices back over the tracked config file. persistent changes go into `btop.conf` directly.
- `theme_background = False`: leaves background cells transparent so compositor blur passes through undisturbed.
- `truecolor = true`: retains 24-bit gradient curves bounded inside the active ANSI registers.

## `themes/`

exists only because btop checks `$HOME/.config/btop/themes` on startup. stays empty in `TTY` mode.

## runtime link

`~/.config/btop/btop.conf` links to `~/.local/share/dotfiles/btop/btop.conf`. if graph shades fail to update on wallpaper switch, kitty missed `USR1`; run `pkill -USR1 kitty`.
