# quickshell

a custom wayland desktop shell in qml and python because standard status bars assume healthy batteries, predictable display geometry, and zero curiosity about what is happening inside sysfs underneath an icon.

nothing here runs on electron. a broken binding inside a popup emits type errors into `/run/user/1000/quickshell` and leaves that module unresponsive or empty until patched and reloaded with `cli reload`. icons resolve through google material symbols, font awesome 6, and `SegoeIcons.ttf` instead of patched private-use ranges that silently shift glyphs between font builds.

## subsystems

- **adaptive status bar (`bar/StatusBar.qml`)**: docks dynamically to any monitor edge (`top`, `bottom`, `left`, `right`) without dropping wayland surfaces. supports zone clustering, floating islands, continuous bezier bar scoops, and live layout edits dispatched from `BarStudio`.
- **bar studio (`widgets/BarStudio.qml`, `presets.py`)**: four-tab configuration workbench (`layout`, `bar style`, `widgets`, `motion lab`). reorder widgets across zones, swap between nine material-derived presets (`solid`, `glass`, `frosted`, `translucent`, `tinted`, `outlined`, `oled`, `monochrome`, `islands`) stored as flat `.conf` manifests, save custom presets, and stress-test spring physics against a live preview bar while listening to your gpu fan wake up.
- **variable font engine (`scripts/fonts.py`, `Theme.qml`)**: queries `fc-list` and parses binary sfnt `fvar` tables straight from font binaries so typography sliders drive real `wght`, width, and optical size axes (`Segoe UI Variable`, `Google Sans Flex`, `JetBrains Mono`) instead of letting qt fake bold weights by smearing glyphs sideways.
- **screenshot studio & redaction (`ScreenshotOverlay.qml`, `ScreenshotHud.qml`, `ScreenshotPinLayer.qml`, `scripts/screenshot.py`)**: region, window, fullscreen, delayed capture, magnifier loupe, pixel eyedropper, floating screen reference pins, imagemagick `prettify` framing, and canvas annotations (`pen`, `highlighter`, `arrow`, `rect`, `ellipse`, `step`, `text`). includes three destructive redaction modes (`mosaic`, `blur`, `solid`) for obliterating identifying details before forwarding evidence to someone whose voice already makes your jaw clench.
- **thermal, power & battery telemetry (`Battery.qml`, `BatteryPopup.qml`, `scripts/battery.py`)**: stopped trusting `powerprofilesctl` to report honestly on thinkpad silicon (`BAT0` currently sits at `43.6 / 52.5 Wh`, `83.1%` capacity). reads and writes `tlp`, acpi `platform_profile`, `intel_pstate` (`no_turbo`), sysfs charge start/stop thresholds, and the local `fanctl` daemon directly so `"performance"` stops sitting grayed out while the `i7-1260P` bakes behind a false `BD PROCHOT` lock.
- **network, vpn, hotspot & qr (`NetworkStatus.qml`, `scripts/network.py`)**: three-tab network panel (`wi-fi`, `vpn`, `hotspot`) pulling live ipv4, gateway, dns, and sysfs rx/tx byte throughput. removes stale saved profiles, spins up a local ap hotspot with persisted credentials, and draws an offline pure-python byte-mode qr matrix onto a qml `Canvas` so devices connect without speaking passphrases inside quiet rooms.
- **clock, weather & pomodoro (`Clock.qml`, `TimerService.qml`, `scripts/weather.py`)**: fetches open-meteo conditions, feels-like temp, humidity, wind, and daily extremes cached in `$XDG_RUNTIME_DIR/quickshell_weather_cache.json`. couples an interactive calendar and custom countdowns with a `25m focus / 5m break` pomodoro loop acting mainly as an external prompt to unclench your jaw and verify whether sensation still reaches your feet.
- **notifications, tray & osd (`Notifications.qml`, `NotificationService.qml`, `SystemTray.qml`, `OSD.qml`)**: wayland toast layer with drag dismissal, live search, `uniqueApps` chips, and timed dnd quarantine presets (`30m`, `1h`, `2h`, `off`) counting down cleanly so you can sever outside contact on a fixed timer without wondering who gave up waiting. power profile toggles, idle inhibit, and dnd push directly to the osd pill; tray collapses stay saved in `Settings.trayCollapsed`.
- **bluetooth & power state (`Bluetooth.qml`, `PowerMenu.qml`)**: paired-only filtering, discoverable state control, trust/pair triggers, and pipewire bluez codec switching (`hi-fi a2dp` vs `mic hfp`) over `pw-dump` and `wpctl`. power menu presents a six-card keyboard grid (`1–6`, arrows, `Enter`, `Escape`) ending in `hibernate` so dirty memory pages serialize onto swap and preserve whatever rabbit hole you collapsed inside without tearing down state.
- **pam lockscreen (`lockscreen/`)**: layer-shell auth guard rendering live pipewire spectrum waves and quotes while reading pam passwords in isolation.
- **zero `.json` state**: json does not appear anywhere in runtime configs or caches. settings, presets, and ipc records serialize as flat key-value `.conf` blocks through `theme/confFormat.mjs`.

## layout map

- `shell.qml`: root orchestrator registering global ipc endpoints (`notifs`, `lock`, `studio`, `caffeine`, `network`, `wifi`, `screenshot`, `record`).
- `Theme.qml`: singleton watching `~/.config/quickshell/palette.css` on disk and recomputing color tokens, corner radii, icons, and variable font axes live.
- `settings.conf`: tracked repo baseline loaded as fallback via `fallbackConfPath` in `Settings.qml`. live edits write solely to `~/.local/state/quickshell/settings.conf` so tweaking sliders never pollutes `git status`.
- `bar/`: `StatusBar.qml` edge-docking surface host and `pill` modules.
- `corners/`: `ScreenCorners.qml` and `ConcaveCorner.qml` rendering wayland subsurfaces with cubic bezier curves and empty `Region {}` masks so pointer events pass cleanly underneath.
- `controls/`: custom component library (`PopupPanel`, `Slider`, `SliderRow`, `ToggleRow`, `ChoiceGrid`, `ScreenshotActions`) written from scratch instead of resting on qtquick controls' sterile intranet defaults.
- `widgets/`: modular pills, popups, studios, and capture overlays.
- `services/`: singletons managing dbus, pipewire, sysfs, hyprland ipc, notification queues, timers, and captures.
- `presets/`: material `.conf` manifests (`catalog.conf` + built-in presets parsed by `presets.py`).
- `scripts/`: python and zsh helpers (`cli.py`, `battery.py`, `network.py`, `screenshot.py`, `weather.py`, `fonts.py`, `presets.py`, `wallpaper.py`, `clipboard.py`, `session.py`, `spectrum.py`, `lyrics.py`).

## cli surface

```zsh
cli status                    # process state, uptime, and memory usage
cli reload                    # tear down orphaned layer surfaces and spawn cleanly
cli shell toggle              # swap shell runtime

cli launcher                  # app drawer
cli studio                    # bar layout studio
cli quicksettings             # appearance & system toggles
cli notifs                    # notification queue
cli dnd                       # toggle do-not-disturb
cli vpn                       # open network popup on vpn tab
cli hotspot                   # open network popup on hotspot tab
cli ss [region|window|full]   # screenshot studio overlay
cli files                     # file manager
```
