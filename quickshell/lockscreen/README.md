# lockscreen

keep out unless you know the magic words.

hyprlock is fine if you like plaintext configs, but having your lockscreen wired directly into the quickshell layer-shell engine means zero flickering, seamless token sharing, and total aesthetic continuity.

## the bouncer
- `LockScreen.qml`: full-screen security surface backed by native pam authentication. includes a live digital clock, material battery and wifi status pills, media playback controls with mpris album art, and a password field that shivers aggressively when you fat-finger your credentials. hooks into `qs ipc call lock lock` for instant manual locking from keybindings.

## new internals
- **extensionless state persistence**: no more `.json` garbage. user tweaks live in `~/.config/quickshell/lockscreen/state` using clean `key=value` definitions that quickshell loads and debounces atomically.
- **pipewire peak visualizer**: native `PwNodePeakMonitor` hooked directly into the active audio sink. renders real-time wave oscillations across the lockscreen media card.
- **dynamic layout geometry**: custom stack ordering (`clock,media,password`), freeform dragging mode, normalized coordinates (`customNormX`, `customNormY`), and preset alignments (`center`, `top`, `bottom`, `left`, `right`).
- **typography & seconds styling**: customizable second digits (`badge`, `supersub`, `tower`, `inline`) and stack orientations (`inline`, `stacked`, `minimal`).
- **unhinged quotes**: displays randomized dry dev nihilism or hyprland splash text while you ponder why you compiled another kernel at 3 am.
