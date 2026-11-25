# btop

terminal resource monitor kept open on an empty workspace mostly to confirm whether runaway chromium tabs or leaked qml objects will chew through `15.29 gib` of ram (`7.65 gib` `zram0` + `16.82 gib` nvme swap) before morning.

## settings

- `btop.conf`: sets `color_theme = "TTY"` so meters inherit raw terminal ansi slots directly. when `matugen` rewrites `colors.conf` and `pkill -USR1 kitty` runs, colors update mid-draw without restarting.
- `save_config_on_exit = false`: stops btop from overwriting the tracked config file with runtime window choices on exit. persistent changes belong in `btop.conf` directly.
- `theme_background = False`: leaves background cells transparent so compositor blur passes through undisturbed.
- `truecolor = true`: keeps 24-bit gradient curves inside active ansi bounds.

## `themes/`

kept only because btop checks `$HOME/.config/btop/themes` on startup. stays empty under `TTY` mode.

## runtime link

`~/.config/btop/btop.conf` points to `~/.local/share/dotfiles/btop/btop.conf`. if graph shades fail to follow a wallpaper switch, kitty missed `USR1`; run `pkill -USR1 kitty`.
