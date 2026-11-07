# widgets

the entire circus. this is where ninety percent of the vibe lives and where your free time goes to die.

every desktop pill, flyout drawer, audio mixer, and workspace indicator lives here. if you ever wanted a desktop that looks like a cyberpunk terminal designed by a designer who drinks too much espresso, you're in the right place.

## the roster
- `AppLauncher.qml`: lightning-fast application launcher with fuzzy search, categorized directory filters, inline math calculation, and persistent pinned apps saved to `~/.config/quickshell/pinned_apps`.
- `BarStudio.qml`: the visual bar architect. a live in-engine visual editor that lets you drag, drop, and rearrange widgets between left, center, and right sections without writing a single line of json or restarting quickshell.
- `Battery.qml`: battery percentage indicator with power-profile integration. tells you exactly when your laptop is about to die during an uncommitted git push.
- `BatteryPopup.qml`: hardware battery telemetry card powered by `battery.py`. calculates true cell health from `energy_full` vs `energy_full_design`, shows cycle counts, charge start/stop thresholds, cpu load, and launches `sysmon.zsh` for nvtop and btop.
- `Bluetooth.qml`: bluez device discovery card. pairs headphones, shows battery telemetry, and handles reconnects without making you open bluetoothctl in shame.
- `Clipboard.qml`: searchable clipboard history drawer powered by `wl-clipboard` and `clipboard.py`. lets you pin snippets, search copied code blocks, and wipe history before anyone sees what you pasted.
- `Clock.qml`: elegant digital clock pill with an interactive calendar flyout because developers notoriously forget what day of the week it is.
- `IdleInhibitor.qml`: digital caffeine pill. toggles wayland idle inhibitor so your screensaver doesn't interrupt long cargo builds or video streams.
- `IdlePopup.qml`: detailed idle status dialog with lock trigger shortcuts and sleep timer info.
- `LayoutSwitcher.qml`: active window tiling layout selector for hyprland.
- `MotionSandbox.qml`: physics and animation testbed. a playground for testing spring constants, damping ratios, and easing curves until the ui feels like butter.
- `NetworkStatus.qml`: wifi and ethernet pill with an interactive ssid selector, password input, and real-time link strength indicators.
- `Notifications.qml`: slide-out notification center drawer that stores notification history with batch-clear and per-app filtering.
- `NowPlaying.qml`: mpris media player controller with dynamic album artwork palettes, smooth scrub bar, and play/pause controls for spotify or browser players.
- `PowerMenu.qml`: session management modal offering lock, sleep, reboot, and shutdown options via `session.py` before you do something reckless.
- `QuickNotes.qml`: persistent desktop scratchpad for brain dumps, temporary regex tests, and todo lists that will inevitably be ignored for months.
- `QuickSettings.qml`: unified control center panel with audio and brightness sliders, network switches, and the material symbols icon pack selector (`rounded`, `outlined`, `sharp`).
- `ScreenCapture.qml`: screenshot and screen recording drawer with output format options, audio source toggles, and direct folder links.
- `ScreenshotOverlay.qml`: layer-shell interactive snipping tool with window snapping, coordinate geometry, and direct post-capture dispatch to `screenshot.py`.
- `SystemTray.qml`: status notifier item (sni) tray hosting background applets without memory leaks or pixelated icon distortions.
- `VolumeControl.qml`: wireplumber pipewire mixer with master volume, sink selection, default routing via `wpctl`, and audio mixer launching via `open-mixer.zsh`.
- `WallpaperBrowser.qml`: visual grid wallpaper gallery with category filtering and instant palette generation without recursive binding loops.
- `WindowTitle.qml`: active hyprland window title pill that extracts app icons and window names cleanly.
- `KeybindsPreview.qml`: interactive visual keyboard cheatsheet mapping every hyprland keybind, window manipulation shortcut, and `cli` desktop action with category filtering.
- `WelcomeWizard.qml`: full 5-step interactive onboarding suite styled exclusively with `Theme.qml` tokens. features live material 3 palette previews, wallpaper dice roller, dual shell comparative inspector, editor and file manager preference sync, hardware thermal containment card, and live action key test pad.
- `Workspaces.qml`: fluid hyprland workspace switcher featuring urgent state flashing, active workspace indicators, and scroll-to-switch bindings.
