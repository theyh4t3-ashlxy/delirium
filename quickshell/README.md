# quickshell

welcome to the asylum. this is the crown jewel of the desktop: a qml and c++ layer-shell monstrosity engineered to make electron developers cry and waybar users question their life choices.

we threw backward compatibility into an active volcano. nerd font glyphs are dead to us; we migrated to google's official material symbols because life is too short for broken private-use-area codepoints and guessing which font patch broke your volume icon.

## what this thing actually controls
everything between your wallpaper and your retinas:
- **the chameleon status bar**: docks top, bottom, left, or right dynamically without restarting the compositor. supports hover expansions, pill groupings with spring physics, and hot-reloading widget layouts dispatched straight from `BarStudio`.
- **liquid concave screen corners**: sharp 90-degree monitor corners are an aesthetic hate crime. rendered via wayland layer-shell subsurfaces with mathematical cubic bezier curves and empty input region masks (`mask: Region {}`) so clicks pass straight through the transparency instead of trapping your cursor in blind rage.
- **recording & screencap powerhouse**: live screen capture drawer with countdown timers, persistent pulsating recording pills, mic/desktop audio routing chips, satty annotation integration, and right-click instant discard.
- **pam-authenticated layer-shell vault**: native security surface with zero flickering. features real-time pipewire audio peak wave monitors, extensionless key-value state persistence (`~/.config/quickshell/lockscreen/state`), dynamic stack ordering, and unhinged developer nihilism quotes while you type credentials at 4:18 am.
- **freedesktop toast notifications**: native wayland surfaces that glide onto your screen like silk, display rich action buttons, handle swipe-to-dismiss drag physics, and vanish without leaking zombie surfaces.
- **app launcher with fuzzy search**: directory-filtered app grid, inline math calculation, and persistent pinned apps saved to flat state files.
- **bar studio**: a live in-engine visual editor that lets you drag, drop, and rearrange widgets between left, center, and right sections without writing a single line of json or restarting quickshell.
- **zero `.json` architecture**: json has been sentenced to death. all configurations, presets, and state files use flat `.conf` or extensionless key-value definitions.

## architecture map
- `shell.qml`: root orchestrator. spawns bars, overlays, and registers ipc endpoints (`notifs`, `lock`, `studio`, `caffeine`). do not touch unless you enjoy staring into tty1 text purgatory.
- `Theme.qml`: dynamic material design token bible. generated on the fly by matugen from wallpaper colors. defines palette tokens, radii, motion constants, and official material symbol codepoints.
- `settings.conf`: persisted user state. stores bar edge, widget layout, theme mode, and font settings.
- `bar/StatusBar.qml`: the status bar engine. dynamic edge anchoring, pill layout expansion, liquid corner docking.
- `corners/`:
  - `ScreenCorners.qml`: monitor boundary anchors with continuous border lines and input passthrough masks.
  - `ConcaveCorner.qml`: high-performance canvas element rendering inverted bezier fillets with configurable tension.
- `widgets/`: modular desktop pills, sliders, drawers, and panels (launcher, clock, battery, network, bluetooth, volume, clipboard, mpris, powermenu, screencapture, quicknotes).
- `services/`: system state singletons (audio, network, battery, notifications, settings, presets, screen recording) talking directly to dbus, pipewire, and sysfs.
- `controls/`: custom design system components built from scratch (icon buttons, toggle switches, popup panels, kinetic flick lists) because qtquick controls 2 looks like a corporate intranet dashboard from 2007.
- `presets/`: native `.conf` presets (`catalog.conf`, `default.conf`, `minimal.conf`, `island.conf`) mapping 1:1 with the settings engine.
- `scripts/`: zero-dependency python and zsh backend daemons handling battery sysfs probes, color picking, session actions, clipboard history, and desktop lifecycle control.

## how to drive it from the terminal
```zsh
# inspect active shell status and memory footprint
cli status

# gracefully reload without surface conflicts or zombie layers
cli reload

# hot-swap between quickshell and legacy shells
cli shell toggle

# toggle desktop drawers and popups
cli launcher
cli quicksettings
cli notifs
cli files
```
