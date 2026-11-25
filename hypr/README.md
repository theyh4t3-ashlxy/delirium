# hypr

`Hyprland 0.57.2` driven by embedded lua tables because static bracket configs make it too comfortable to forget what your compositor is allocating in RAM.

runs against real `ThinkPad T16 Gen 1` hardware: `eDP-1` (`BOE 0x0A5F`, `1920x1200@60Hz`, `srgb`) paired with `HDMI-A-1` (`1920x1080@60Hz` `auto-left`) pushed across `Intel Alder Lake-P` (`i915`) while `NVIDIA TU117M` (`GeForce MX550`) stays idle on `nouveau` converting battery charge into ambient plastic warmth. if changing scale or monitor placement dumps your focused windows off-screen, read `hyprctl monitors` before opening an issue claiming your desktop vanished.

## load sequence

- `hyprland.lua`: primary entrypoint evaluating layout, rules, and bindings directly into compositor state.
- `binds.lua`: chorded `super` / `alt` / `shift` / `ctrl` permutations wired to `quickshell` IPC, terminal spawns, screenshot captures, and scratchpads.
- `rules.lua`: containment policies pinning uncooperative electron dialogs, picture-in-picture windows, and legacy portals to explicit coordinates so nothing steals focus unattended.
- `anims.lua`: tight cubic bezier curves terminating fast enough to match a `60Hz` LCD sample interval without lingering blur.
- `startup.lua`: background daemons dragged up at session start (`quickshell`, `hypridle`, polkit agent, `wireplumber`). if one stalls waiting on `dbus`, session startup hangs silently.
- `monitors.lua`: literal monitor geometry (`eDP-1` `1920x1200@60` at `0x0`, `HDMI-A-1` `1920x1080@60` `auto-left`, `srgb`).
- `colors.lua`: active border tokens overwritten continuously by `matugen`. manual changes evaporate on the next wallpaper rotation.
