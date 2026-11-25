# backstory

## the hardware (`thinkpad t16 gen 1`, `21BWS23200`)

none of this runs on a clean workstation. it runs on a `thinkpad t16 gen 1` (`N3BET70W` uefi) packing a 12-core `i7-1260P` (`400–4700` mhz), an `intel alder lake-p` igpu (`i915`), and an `nvidia tu117m` (`geforce mx550`) sitting idle on `nouveau` with zero useful purpose beyond warming chassis plastic and draining standby watts. `eDP-1` (`BOE 0x0A5F`, `340x220` mm) pushes `1920x1200` at `60hz` (`srgb`); `HDMI-A-1` takes `1920x1080@60`. the bottom shell has bowed slightly from sustained heat, and `BAT0` already sits worn down to `43.6 / 52.5 Wh` (`83.1%` capacity) running at `14.14 V` under load.

clean boot required fighting display firmware separately. `lanzaboote` handles secure boot with `plymouth` bgrt, and `i915` early kms (`fastboot=1`) stays pinned inside initrd solely to stop the lenovo splash from strobing across the `60hz` panel for twelve seconds during handoff.

thermal control (`pkgs/fan-control/`) started because stock lenovo ec firmware (`dytc`) prioritizes quiet office rooms where audible fan draw violates cubicle etiquette. firmware gladly lets the `i7-1260P` trip false `BD PROCHOT` latches and clamp all twelve cores down to `400 mhz` just to save an empty room twenty decibels of blower noise. `daemon.py` and `watchdog.py` yank register control away from bios and pulse `/proc/acpi/ibm/fan` back up whenever core clocks stall below `500 mhz`. if the bearing starts clicking under sustained stress, leave it.

---

## the tooling (and what survives automated runs)

half this tree is friction between one sleep-deprived human and two remaining google agent paths after google pulled the plug on **jules** (freezing it read-only before full retirement and folding agent execution into **antigravity**):

- **`ai studio`**: where raw wayland protocol headers and mangled qml bindings get dumped at 3:45 am until a model hallucinates nonexistent c++ methods and tries compiling them anyway.
- **`antigravity`**: parallel local sub-agents racing across branched workspaces while the `i7-1260P` climbs past 98°c and the desk starts smelling faintly of baked dust. one agent deletes array bounds, another invents state files nobody reads, and two burn hours arguing over border radii.

everything desktop-facing runs inside `quickshell` (`qs`) with raw qml anchors. a broken binding inside a popup widget logs type errors into `/run/user/1000/quickshell` and leaves that panel blank or unresponsive until patched and reloaded, while a full `quickshell` crash strips away the status bar and lockscreen even while `hyprland` keeps running underneath. `cli.py` replaced old shell wrappers so one dependency-free python script handles reloads, layer cleanup, screenshot triggering, vpn/hotspot tab routing, and launcher control. `hyprland` (`0.57.2`) evaluates embedded lua tables instead of bracket configs, and `.json` is barred from runtime state entirely in favor of flat `.conf` files.

if the compositor itself crashes on startup, check `coredumpctl`. nobody else is maintaining this setup.

---

## distro sequence (`windows` -> `arch` -> `gentoo` -> `nixos`)

### windows
left windows after realizing `Administrator` permissions are decorative theater. background processes throttle thermals, spawn telemetry services, and answer writes with access denied because `SYSTEM` or `TrustedInstaller` owns your own filesystem. nobody needs to beg an os for permission inside a machine they paid for.

### arch & `atomic-lockfile`
people repeat the lazy rumor that arch breaks itself on `pacman -Syu`, which is usually just user incompetence. arch worked until i decided at 3:14 am—knowing full well what the package was—to run `npm install atomic-lockfile` naked on bare metal with zero sandbox or vm just to watch what broke. there were no ssh keys worth taking, so thirty seconds later its post-install hook scraped discord session tokens straight out of `~/.config/discord/Local Storage/leveldb` and fired them off to a telegram bot while probing persistence. watching your own tokens fly out of ram in real time settles whether you can be trusted with stateful installs. i booted a live iso, ran `blkdiscard -f /dev/nvme0n1` to wipe the samsung nvme down to bare flash cells, and moved on.

### five hours of gentoo
tried gentoo for roughly five hours. listened to the cooling fan strain compiling `glibc`, realized gnome dependencies were lagging upstream anyway, and cleared the partition table out of irritation.

### nixos + volatile `tmpfs` root
nixos stayed because broken generations roll back at boot instead of costing an afternoon. after auditing another shell repo (`brain_shell`) that nested subshells via `(setsid bash -c 'systemctl poweroff' &)` just to turn off a laptop and fork-bombed `xargs -P 4` resizing jpegs, keeping stateful clutter on `/` stopped feeling tolerable.

`/` now mounts inside a volatile `7.6g` `tmpfs` ramdisk (`tmpfs[/newroot]`) alongside `16 gib` physical memory, `7.65 gib` `zram0`, and a `16.82 gib` nvme swap partition (`/dev/nvme0n1p3`). shutting down drains the capacitors and erases everything not explicitly bound inside `@persist` on btrfs (`/home`, `/persist`, `/var/log` across `/dev/nvme0n1p2`, `459.12 gib`), booting through `lanzaboote` from `/boot` (`1022 mib` vfat). chemically clean erasure every poweroff.

---

## issues & upstream pull requests

do not expect issue triage. jules is dead—frozen read-only ahead of shutdown—so nothing in github's cloud is watching your complaint. occasionally local `antigravity` runs fix open bugs, or human pull requests sit unmerged until an overnight agent commit breaks them anyway.

take whatever pieces hold together on your hardware (`cli.py`, bezier screen corners, `screenshot.py`, `fan-control`), keep the license intact, and leave the rest behind.
