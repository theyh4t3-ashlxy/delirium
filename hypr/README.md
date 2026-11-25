# hypr

`hyprland 0.57.2` driven by embedded lua tables because static bracket configs make it too easy to stop paying attention to what the compositor allocates.

runs directly on `thinkpad t16 gen 1` hardware: `eDP-1` (`BOE 0x0A5F`, `1920x1200@60hz`, `srgb`) paired with `HDMI-A-1` (`1920x1080@60hz` `auto-left`) scanned out over `intel alder lake-p` (`i915`) while `nvidia tu117m` (`geforce mx550`) stays idle on `nouveau` burning battery charge into warm plastic. if bad scaling or monitor placement strands a window off-viewport, run `hyprctl monitors` before assuming your desktop broke.

## load sequence

- `hyprland.lua`: primary entrypoint applying layouts, rules, and bindings directly into compositor state.
- `binds.lua`: chorded `super` / `alt` / `shift` / `ctrl` combinations mapped into `quickshell` ipc, terminals, screenshot captures, and scratchpads.
- `rules.lua`: containment policies pinning uncooperative electron dialogs, picture-in-picture windows, and file pickers to explicit geometry so nothing steals focus unattended.
- `anims.lua`: short cubic bezier curves terminating cleanly within a `60hz` frame interval without dragged ghosting.
- `startup.lua`: background daemons launched via `exec-once` (`quickshell`, `hypridle`, polkit agent, `wireplumber`). if one exits early or drops off `dbus`, hyprland keeps running while audio controls, locking, or polkit prompts stop answering.
- `monitors.lua`: literal monitor geometry (`eDP-1` `1920x1200@60` at `0x0`, `HDMI-A-1` `1920x1080@60` `auto-left`, `srgb`).
- `colors.lua`: active border tokens overwritten continuously by `matugen`. hand edits disappear on the next wallpaper change.
