# quickshell

a custom wayland desktop shell in qml and python because standard bars assume healthy batteries, single-monitor geometry, and zero curiosity about what is happening inside sysfs underneath an icon.

nothing here runs on electron. one null reference inside a popup anchor still drops the session cleanly onto `tty1`. icon lookup resolves straight through google material symbols, font awesome 6, and `SegoeIcons.ttf` instead of patched private-use codepoints that silently swap icons between font rebuilds.

## subsystems

- **adaptive status bar (`bar/StatusBar.qml`)**: docks dynamically to any monitor edge (`top`, `bottom`, `left`, `right`) without dropping wayland surfaces. supports per-zone clustering, floating islands, continuous bezier bar scoops, and live layout mutation pushed from `BarStudio`.
- **bar studio (`widgets/BarStudio.qml`, `presets.py`)**: four-tab configuration host (`layout`, `bar style`, `widgets`, `motion lab`). reorder widgets across zones, swap between nine material-derived presets (`solid`, `glass`, `frosted`, `translucent`, `tinted`, `outlined`, `oled`, `monochrome`, `islands`) stored as flat `.conf` manifests, save custom presets, and stress-test spring physics against a synthetic preview bar while listening to your GPU wake up.
- **variable font engine (`scripts/fonts.py`, `Theme.qml`)**: scans `fc-list` and parses binary SFNT `fvar` tables directly out of font files so typography controls drive real weight (`wght`), width, and optical size axes (`Segoe UI Variable`, `Google Sans Flex`, `JetBrains Mono`) instead of letting Qt fake bold weights by smearing pixels horizontally.
- **screenshot studio & redaction (`ScreenshotOverlay.qml`, `ScreenshotHud.qml`, `ScreenshotPinLayer.qml`, `scripts/screenshot.py`)**: region, window, fullscreen, delayed capture, magnifier loupe, pixel eyedropper, floating screen reference pins, ImageMagick `prettify` framing, and canvas annotations (`pen`, `highlighter`, `arrow`, `rect`, `ellipse`, `step`, `text`). ships three destructive redaction modes (`mosaic`, `blur`, `solid`) for obliterating identifying details out of an image before forwarding evidence to someone whose voice already makes your teeth ache.
- **thermal, power & battery telemetry (`Battery.qml`, `BatteryPopup.qml`, `scripts/battery.py`)**: stopped trusting `powerprofilesctl` to report honestly on thinkpad silicon (`BAT0` currently sits at `43.6 / 52.5 Wh`, `83.1%` capacity). reads and writes `tlp`, ACPI `platform_profile`, `intel_pstate` (`no_turbo`), sysfs charge start/stop thresholds, and the local `fanctl` daemon directly so `"performance"` stops sitting grayed out while the `i7-1260P` bakes behind a false `BD PROCHOT` lock.
- **network, vpn, hotspot & qr (`NetworkStatus.qml`, `scripts/network.py`)**: three-tab network panel (`wi-fi`, `vpn`, `hotspot`) pulling live ipv4, gateway, dns, and sysfs rx/tx telemetry. deletes saved network credentials cleanly, turns up a local ap hotspot with persisted credentials, and draws a pure-python byte-mode qr matrix onto qml `Canvas` so phones connect cleanly without speaking passphrases inside quiet rooms.
- **clock, weather & pomodoro (`Clock.qml`, `TimerService.qml`, `scripts/weather.py`)**: fetches open-meteo conditions, feels-like temp, humidity, wind, and daily extremes cached in `$XDG_RUNTIME_DIR/quickshell_weather_cache.json`. couples an interactive calendar and custom countdowns with a `25m focus / 5m break` pomodoro loop functioning primarily as an external nerve prompt to unclench your jaw and check whether sensation still reaches your feet.
- **notifications, tray & osd (`Notifications.qml`, `NotificationService.qml`, `SystemTray.qml`, `OSD.qml`)**: wayland alert layer with drag-dismiss physics, live search, `uniqueApps` filter chips, and timed DND quarantine presets (`30m`, `1h`, `2h`, `off`) with a ticking countdown so you can sever outside human contact on a strict clock without wondering who gave up waiting. power profile toggles, idle inhibit, and DND route straight to the OSD pill; tray collapse persists via `Settings.trayCollapsed`.
- **bluetooth & power state (`Bluetooth.qml`, `PowerMenu.qml`)**: adds paired-only filtering, discoverable state control, trust/pair actions, and PipeWire BlueZ codec switching (`hi-fi a2dp` vs `mic hfp`) over `pw-dump` and `wpctl`. power menu presents a six-card keyboard grid (`1–6`, arrows, `Enter`, `Escape`) ending in `hibernate` so dirty RAM pages serialize onto swap and preserve the exact posture of whatever hole you collapsed in without losing state.
- **pam lockscreen (`lockscreen/`)**: layer-shell auth guard rendering live pipewire spectrum bars and curated quotes while verifying PAM passwords in total isolation.
- **zero `.json` state**: json does not exist anywhere in configuration or runtime persistence. settings, presets, and caches read and write flat key-value `.conf` records through `theme/confFormat.mjs`.

## layout map

- `shell.qml`: root entrypoint registering global IPC handlers (`notifs`, `lock`, `studio`, `caffeine`, `network`, `wifi`, `screenshot`, `record`, etc.).
- `Theme.qml`: singleton watching `~/.config/quickshell/palette.css` on disk and recomputing color tokens, corner radii, material symbols, and variable font axes without restarting the shell.
- `settings.conf`: tracked repo baseline, symlinked read-only or fallen back onto via `fallbackConfPath` in `Settings.qml`. live state mutations write exclusively to `~/.local/state/quickshell/settings.conf` so dragging one opacity slider never dirties `git status`.
- `bar/`: `StatusBar.qml` edge-docking surface host and `pill` containers.
- `corners/`: `ScreenCorners.qml` and `ConcaveCorner.qml` rendering wayland subsurfaces with cubic bezier fillets and empty `Region {}` input masks so clicks pass cleanly underneath.
- `controls/`: hand-written design primitives (`PopupPanel`, `Slider`, `SliderRow`, `ToggleRow`, `ChoiceGrid`, `ScreenshotActions`) built to replace qtquick controls' default office-intranet styling.
- `widgets/`: modular pills, popups, studios, and overlays.
- `services/`: singletons coordinating dbus, pipewire, sysfs, hyprland ipc, notification queues, timers, and captures.
- `presets/`: material `.conf` manifests (`catalog.conf` + built-in style sheets scanned by `presets.py`).
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
