# scripts

bash scripts are simply too stupid.
python and zsh resolve that without the headache.

## the workforce
- `battery.py`: silently probes sysfs battery health, charge thresholds, cpu load, and gpu counts without running an 18-line concatenated bash horror show.
- `colorpicker.py`: grabs single-pixel geometry via slurp and grim, extracting hex values without piping through od and awk.
- `screenshot.py`: handles native screencopy region, window, and full captures with direct clipboard, editor (swappy/satty), and notification pipelines without intermediate shell wrapping.
- `session.py`: dispatches session power actions (lock, suspend, reboot, shutdown, logout) with robust ipc output verification, lock token detection, and timeouts.
- `clipboard.py`: interfaces with `wl-clipboard` to manage clipboard history, search filters, favorite pins, and atomic cache wipes.
- `wallpaper.py`: selects wallpapers, calls matugen to generate color palettes from the image, and writes dynamic tokens system-wide without burning your cpu.
- `open-mixer.zsh`: walks through audio mixer binaries and launches the first one installed.
- `sysmon.zsh`: launches system monitoring tools in terminal with cascading fallback (nvtop/top or btop/htop/top).
- `detect-backlight.zsh`: auto-detects primary backlight device from sysfs.
- `detect-brainshell.zsh`: checks whether brain_shell is installed in local paths.
- `write-file.zsh`: writes or touches state and config files while guaranteeing parent directories exist.
- `cli.py`: unified desktop controller for shell switching, instant reloads, and desktop action ipc dispatching.
