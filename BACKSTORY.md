# backstory

## the hardware (`ThinkPad T16 Gen 1`, `21BWS23200`)

none of this runs on a clean workstation. it runs on a `ThinkPad T16 Gen 1` (`N3BET70W` UEFI) packing a 12-core `i7-1260P` (`400–4700` MHz), an `Intel Alder Lake-P` iGPU (`i915`), and an `NVIDIA TU117M` (`GeForce MX550`) sitting idle on `nouveau` with zero useful purpose beyond soaking chassis plastic and leaking standby watts. `eDP-1` (`BOE 0x0A5F`, `340x220` mm) pushes `1920x1200` at `60Hz` (`srgb`); `HDMI-A-1` takes `1920x1080@60`. the bottom shell has bowed slightly from sustained heat, and `BAT0` already sits chewed down to `43.6 / 52.5 Wh` (`83.1%` capacity) at `14.14 V` below nominal minimum voltage (`15.48 V`).

clean boot required fighting the display firmware separately. `lanzaboote` handles secure boot with `plymouth` bgrt, and `i915` early KMS (`fastboot=1`) stays pinned inside initrd solely to stop the lenovo splash from strobing across the `60Hz` panel for twelve seconds during handoff.

thermal control (`pkgs/fan-control/`) started because stock lenovo EC firmware (`dytc`) prioritizes quiet office rooms full of people who treat audible airflow like a workplace safety violation. firmware gladly lets the `i7-1260P` trip false `BD PROCHOT` latches and starve all twelve cores down to `400 MHz` just to spare an empty cubicle twenty decibels of blower noise. `daemon.py` and `watchdog.py` yank register control away from BIOS and shock `/proc/acpi/ibm/fan` into full-speed bursts whenever core clocks drop below `500 MHz`. if the bearing starts clicking under sustained stress, leave it.

---

## the tooling (and what survives automated runs)

half this tree is friction between one sleep-deprived human and two remaining google agent paths after google pulled the plug on **jules** (freezing it read-only before full retirement and folding agent execution into **antigravity**):

- **`ai studio`**: where raw wayland protocol headers and mangled QML bindings get dumped at 3:45 am until a model hallucinates non-existent C++ methods and tries compiling them anyway.
- **`antigravity`**: parallel local sub-agents racing across branched workspaces while the `i7-1260P` climbs past 98°c and the desk starts smelling faintly of cooked dust. one agent deletes array bounds, another invents state files nobody reads, and two burn hours arguing over border radii.

everything desktop-facing runs inside `quickshell` (`qs`) with raw QML anchors. one null reference inside a popup widget kills the entire graphical layer and drops the terminal cleanly onto `tty1`. `cli.py` replaced old shell wrappers so one dependency-free python script handles reloads, layer cleanup, screenshot triggering, vpn/hotspot tab routing, and launcher control. `hyprland` (`0.57.2`) evaluates embedded lua tables instead of bracket configs, and `.json` is barred from runtime state entirely in favor of flat `.conf` files.

if your compositor segfaults on boot, read `coredumpctl`. nobody else is driving this thing.

---

## distro sequence (`windows` -> `arch` -> `gentoo` -> `nixos`)

### windows
left windows after realizing `Administrator` permissions are decorative theater. software keeps throttling thermals, spawning telemetry daemons, and responding with access denied because `SYSTEM` or `TrustedInstaller` owns your own filesystem. nobody needs to beg an OS for write access inside a machine they bought outright.

### arch & `atomic-lockfile`
people repeat the lazy rumor that arch breaks itself on `pacman -Syu`, which is usually just incompetence. arch worked until I decided at 3:14 am—fully aware of what the payload was—to run `npm install atomic-lockfile` naked on bare metal with zero sandbox or VM just to watch what broke. there were no SSH keys worth taking, so thirty seconds later its post-install script scraped discord session tokens straight out of `~/.config/discord/Local Storage/leveldb` and exfiltrated them to a telegram bot while probing persistence. watching your own tokens fly out of RAM in real time settles whether you should trust yourself with stateful installs. I booted a live ISO, ran `blkdiscard -f /dev/nvme0n1` to wipe the Samsung NVMe down to raw flash cells, and moved on.

### five hours of gentoo
tried gentoo for roughly five hours. watched the cooling fan strain compiling `glibc`, realized gnome dependencies were behind upstream anyway, and wiped the partition table out of irritation.

### nixos + volatile `tmpfs` root
nixos stayed because broken generations revert at boot instead of costing an afternoon. after inspecting another shell repo (`brain_shell`) that spawned six nested subshells via `(setsid bash -c 'systemctl poweroff' &)` just to shut down and fork-bombed `xargs -P 4` resizing jpegs, keeping state on `/` at all stopped feeling tolerable.

`/` now mounts inside a volatile `7.6G` `tmpfs` ramdisk (`tmpfs[/newroot]`) alongside `16 GiB` physical memory, `7.65 GiB` `zram0`, and a `16.82 GiB` NVMe swap partition (`/dev/nvme0n1p3`). shutting down drains the capacitors and clears everything not explicitly bound inside `@persist` on btrfs (`/home`, `/persist`, `/var/log` across `/dev/nvme0n1p2`, `459.12 GiB`), booting cleanly through `lanzaboote` from `/boot` (`1022 MiB` vfat). chemically clean erasure every poweroff.

---

## issues & upstream pull requests

do not expect issue triage. jules is dead—frozen read-only ahead of full shutdown—so nothing in github's cloud is watching your complaint. occasionally local `antigravity` runs chew through bugs, or human PRs sit unmerged until an overnight agent commit breaks them anyway.

take whatever pieces hold together on your hardware (`cli.py`, bezier screen corners, `screenshot.py`, `fan-control`), keep the license intact, and leave the rest behind.
