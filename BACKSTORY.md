# backstory

## why i didn't just use caelestia or end-4

if you want a normal wayland desktop where volume sliders work on the first try, bluetooth connects without touching a terminal, and you can post clean screenshots to discord, go install `caelestia` or `end-4`. those projects have actual docs, support channels, and defaults that won't crash the whole shell if your battery reports an int instead of a float.

i built `delirium` at 16 because i hated how standard setups handled configs and hardware, and i didn't feel like adapting my muscle memory to someone else's dotfiles.

calling this repo `my_hyprland_dots` felt like lying. half of reddit copies a waybar config, changes three hex codes, and calls it a new rice. `delirium` is what happens when you refuse to use normal tools, write your own pam auth loops, calculate bezier curves for screen-corner cutouts, and wire pipewire audio peaks into your lockscreen just to watch waveforms bounce while typing your password at 4:18 am.

steal whatever you want from here. grab the corner bezier math, the `matugen` templates, `cli.py`, or the thinkpad fan daemon.

---

## the laptop (thinkpad t16 gen 1)

this whole thing runs on an alder lake i7-1260p paired with an nvidia geforce mx550 whose only real contribution is extra heat and multi-gpu buffer sync headaches on wayland. the bottom plastic cover has warped two millimeters to the left from sustained heat, and the battery health percentage reads like a timer ticking down to zero.

getting boot to look clean took its own fight. i use `lanzaboote` for secure boot with `plymouth` bgrt, and i had to force early kms modules (`i915`, `fastboot=1`) into the initrd list just to stop the lenovo splash screen from strobing like a broken fluorescent tube for twelve seconds during handoff.

then there were the fans (`pkgs/fan-control/`). the thinkpad cooler itself is fine, but lenovo tuned the factory embedded controller (`dytc`) for quiet office cubicles where hr yells at you if your fan spins past 2,200 rpm on a zoom call. stock firmware chokes cpu clock speeds just to keep the laptop quiet. i don't work in an office. if the cpu wants to boost, let it boost. i poked around the thinkpad acpi ec registers and packaged a root systemd service in `pkgs/fan-control/` that overrides the firmware cap and forces the fan to full speed (5,400 rpm) whenever temps spike. it sounds like a hair dryer eating aquarium rocks, and i don't care.

---

## the stack (and the bots breaking it)

most of this repo is a tug-of-war between me and three different google tools:
- **ai studio**: my 3:45 am rubber duck. i dump 1.8 million tokens of raw wayland c headers, unindexed quickshell commits, and broken qml bindings into gemini's context window until it invents c++ methods that don't exist in any standard and tries to compile them anyway.
- **antigravity**: four headless sub-agents running across parallel git worktrees until the thinkpad hits 104°c and the room smells like warm dust and cooked thermal paste. one agent invents a fake unix socket protocol, a second deletes working python list indexes, and the other two get stuck in a three-hour merge conflict loop over two pixels of border radius.
- **jules**: an unattended cloud runner that clones this repo into a vm while i sleep, invents bugs to fix problems nobody had, and pushes commits straight to `main` with zero human supervision.

on the desktop side, the whole shell runs in raw `quickshell` (`qs`) using qtquick and qml anchors, so a single null pointer in a battery widget drops the entire graphical session straight into `tty1`. i also deleted my old `qs-action` and `reload-qs` bash scripts and replaced them with `cli.py` so one zero-dependency python script handles shell switching, clean layer-shell restarts without leftover surfaces, file manager launches, and desktop actions.

hyprland itself runs embedded lua tables instead of standard `hyprlang` brackets so the window manager evaluates lua closures at 240hz. and `.json` is completely banned from local state. no nested curly braces, no trailing-comma syntax errors, and no quote escaping. state lives in flat key-value `.conf` files or plain text tokens.

if your compositor dumps core on login, that's between you and `coredumpctl`.

---

## how i ended up on nixos (with a 4gb ramdisk root)

### windows
i left windows because my laptop ran way hotter on it, the background bloat never shut up, and everything was locked inside proprietary black boxes. the worst part was the fake permissions: even when your account says `Administrator`, windows treats you like a guest on your own hardware and tells you "access denied" because `SYSTEM` or `TrustedInstaller` owns the actual files. i got tired of begging my own operating system for permission to touch my laptop.

### arch & the `atomic-lockfile` stunt
people love the lazy meme that arch randomly breaks itself on every `pacman -Syu`, which is fake if you actually know how to maintain your system. arch was completely fine until i did something monumentally stupid during the june 2026 `atomic-lockfile` chaos.

i didn't even get hit through an orphaned aur package like normal people. at 3:14 am, wide awake and knowing full well what the package was, i let the intrusive thoughts win and typed `npm install atomic-lockfile` directly on bare metal with no vm and no container just to see what would happen. i didn't even have ssh keys on the machine for it to steal, so thirty seconds later its hook script just scraped my discord session tokens out of `~/.config/discord/Local Storage/leveldb` and fired them straight to a telegram bot (`api.telegram.org/bot<token>/sendDocument`) while trying to load its rootkit. watching your own discord tokens get shipped off to telegram in real time is a great way to realize you shouldn't be trusted with a normal setup. i booted a live usb, ran `blkdiscard -f /dev/nvme0n1` to wipe the nvme drive down to bare flash cells, and decided i wanted to try something new anyway.

### the 5-hour gentoo detour
i tried gentoo for about five hours. spent the whole time compiling `glibc` while the fan screamed and warped the bottom case, found out the gnome packages were three minor versions behind, and wiped the partition table out of pure spite.

### nixos + ephemeral `tmpfs` root (november 2026)
nixos was the new thing that actually stuck. if a bad config or update breaks the compositor, i just reboot and pick generation `n-1` in the boot menu.

in november 2026, after reading through another shell repo (`brain_shell`) that used six nested subshells running `(setsid bash -c 'systemctl poweroff' &)` just to turn off a laptop and fork-bombed `xargs -P 4` to resize jpegs, i decided a normal root partition was still too messy. `/` is now a 4gb `tmpfs` ramdisk. every time the laptop powers off, anything written to `/` disappears when the ram capacitors drain. real state lives exclusively in `@persist` on btrfs, 5.9gb of flatpaks sit in their own isolated subvolume, and secure boot is signed with `lanzaboote`.

---

## humans vs bots in the issue tracker

### opening issues
open an issue if you want, but i'm probably not reading it. google jules will clone your complaint into a cloud vm, antigravity will spin up four sub-agents to fight over it, and whatever survives the merge will get pushed straight to `main`. roast the bots all you want in the comments; they don't have feelings.

### sending pull requests
if you are an actual human sending a PR to fix broken bot code: github actions will probably fail your lint check anyway, and there is a 90% chance i merge the bot's broken PR over yours just because it's funnier.

fork it, break it, turn it into whatever weird setup you want. keep the license file in there so the mess stays legal. you can't copyright llm output anyway, so let the models sue each other.
