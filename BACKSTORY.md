# backstory & the doctrine

## the turn-key paradox: why you should probably use caelestia or end-4

let us be completely transparent: if you want a polished, reliable, out-of-the-box wayland setup where volume sliders just work, bluetooth doesn't require a forensic terminal autopsy, and you can post cozy pastel screenshots to discord without questioning your sanity, do not install this repository.

go install `caelestia` or `end-4`.

those are mature, sane, community-engineered rice suites built by people who actually want users to have a pleasant computing experience. they have documentation, support channels, and defaults that won't panic if your battery percentage reports an integer instead of a float.

`delirium` is the exact opposite of a turn-key distribution. it is a hyper-specific, deeply obsessive digital operating state tailored to a 15-year-old's sensory neuroses, hardware thermal containment, and pathological rejection of corporate developer defaults.

### why build from scratch then?

because when you use a prebuilt rice, you are renting someone else's taste.

the moment you crave:
- **zero `.json` architecture**: evicting nested curly brackets and quotes from local state entirely in favor of flat key-value tokens.
- **pure qml layer-shell composition**: abandoning bloated waybar setups for dynamic qtquick anchors with continuous bezier curves and fluid subsurfaces.
- **hardware-level firmware hacking**: reverse-engineering thinkpad embedded controller registers to bypass corporate thermal castration and force-feed the cooling assembly maximum fan wattage.
- **deterministic nixos immutability**: ensuring an update can never brick your system because generation rollbacks are instant.
- **embedded lua display scripting**: driving hyprland through runtime closures rather than brittle static config syntax.

...you realize prebuilt rices cannot give you that. you have to build it yourself, line by painful line, in the dark at 4 am.

steal our code. rip out our continuous bezier scoop math, our matugen template pipelines, our native python desktop controller, or our ec fan override loop. customize the living hell out of your system until every single byte reflects your own brain. but don't clone this expecting a frictionless appliance.

---

## why "delirium"

calling this repo `my_hyprland_dots` was false advertising. it sounded like every other high schooler who copied a waybar config from reddit and called themselves a rice architect.

`delirium` is the only clinically accurate diagnosis.

you are looking at an operating environment where a fifteen-year-old refused to use standard tools, declared holy war on `.json` files, built an entire layer-shell desktop from scratch in qtquick/qml, wrote custom pam authentication loops, calculated continuous bezier spline curves for display scoop corners, and wired pipewire peak monitors into a lockscreen just to watch audio waveforms vibrate while typing credentials into a terminal at 4:18 am.

if that isn't clinical, late-stage developer delirium, nothing is.

---

## the hardware victim (thinkpad t16 gen 1)

a laptop that never asked to be drafted into this digital war.
- alder lake i7-1260p running at temperatures hot enough to fry an egg directly on the magnesium-aluminum chassis.
- an nvidia geforce mx550 discrete gpu whose sole purpose in life is generating thermal panic and reminding us why wayland multi-gpu buffer synchronization is an unresolved crime against humanity.
- lanzaboote secure boot with plymouth bgrt, where early kms modules (`i915`, `fastboot=1`) had to be violently forced into the initrd kernel modules list just to stop the lenovo oem splash screen from having a twelve-second epileptic strobe seizure during boot handoff.
- **corporate acoustic castration (unshackling the fans)**: the thinkpad hardware itself is completely fine. the real enemy is lenovo's sanitized corporate firmware tuning. the factory embedded controller is engineered for terrified office workers in quiet open-plan cubicles who would get fired by hr if their cooling fan dared to spin above 2,200 rpm during a zoom call. lenovo's dytc firmware artificially throttled clock ceilings and thermal dissipation just to keep the laptop dead silent at the expense of actual silicon throughput. we don't work in a corporate cubicle farm, and we don't care about office etiquette. if the silicon wants to boost, it boosts. if the cooling assembly sounds like a boeing 737 ingesting gravel at 5,400 rpm, let it scream. we reverse-engineered the thinkpad acpi ec fan registers, packaged a native nixos root systemd daemon (`fan-control`), and built an active override loop in `pkgs/fan-control/` that forces the fans to maximum wattage whenever the cpu demands it. noise is the sound of work getting done.

the cooling fan sounds like a miniature boeing 737 engine ingesting gravel. the bottom shell has permanently warped two millimeters to the left from sustained heat cycling. the battery capacity indicator is less of a gauge and more of a countdown timer to sudden death.

---

## the stack (the torture chamber)

- **google ai studio**: the primary psychological testing ground. i dump 1.8 million tokens of raw wayland c headers, unindexed quickshell commits, and broken qml bindings down gemini's context window at 3:45 am until it hallucinates c++ protocols that don't exist in any posix standard and compiles them out of pure existential dread.
- **google antigravity**: four headless sub-agents running in parallel git worktrees until my thinkpad hits 104°c, the chassis smells like ozone and fried thermal paste, and the laptop fans drown out all ambient room audio. one agent hallucinates an imaginary unix domain socket protocol, another deletes working python array indexing, and the remaining two enter an unresolvable three-hour merge conflict death spiral over two pixels of corner radius.
- **google jules**: an unmonitored autonomous cloud runner that clones this repo into isolated virtual machines while i sleep, invents regressions to solve problems that never existed, and force-pushes commits straight to main with zero human witnesses.
- **quickshell**: waybar is for people who eat unseasoned boiled chicken breasts and go to bed at 9:15 pm. real digital sociopaths build their entire graphical interface in raw qtquick and qml anchors so that a single null pointer in a battery property vaporizes the entire desktop into tty1 text purgatory.
- **cli.py**: nuked `qs-action` and `reload-qs` into the sun. having two brittle bash scripts concatenate strings to invoke quickshell ipc calls was offensive to anyone with working nerve endings. now a single zero-dependency python controller handles shell switching, clean layer-shell restarts without zombie surfaces, preferred file manager launching, and desktop action routing.
- **hyprland native lua**: hyprlang was abandoned for embedded lua tables because configuring a display server in declarative brackets wasn't psychotic enough. if our window manager isn't evaluating lua closures at 240hz, we don't want it.
- **the great json purge**: json has been sentenced to death. curly braces, nested brackets, and quoted strings have been permanently evicted from local state. if a config cannot be stored in clean key-value `.conf` or raw extensionless state tokens, it does not belong on this filesystem.
- **ephemeral tmpfs root & impermanence**: persistent block devices mounted on root are for people with commitment issues. `/` is an ephemeral 4gb ramdisk. physics is our garbage collector: when the machine turns off, any unpersisted file ceases to exist in this dimension. state is violently quarantined to `@persist` on btrfs.

it runs on my machine. if your compositor dumps core on login, that is not a bug; that is a personal skill issue.

---

## the doctrine (the imperative crime scene)

arch linux is dead and buried. the imperative crime scene has been permanently quarantined.

- **the atomic arch incident (june 2026)**: the infamous supply chain weapon that weaponized 1,500 hijacked packages across the ecosystem. except i didn't even catch it through an orphaned aur package like normal victims. at 3:14 am, fully conscious and aware of what i was getting myself into, i typed `npm install atomic-lockfile` directly on bare metal with zero sandbox, zero container, and zero survival instincts just to see what would happen. thirty seconds later, the postinstall lifecycle hook compiled an obfuscated rust binary, swept `~/.ssh/id_ed25519`, scraped discord session tokens from `~/.config/discord/Local Storage/leveldb`, exfiltrated an encrypted multipart `POST` payload straight to `api.telegram.org/bot<token>/sendDocument`, and tried to hook into the kernel. watching your own credentials get dispatched to a telegram bot in real time is a religious experience. booted a live usb, executed `blkdiscard -f /dev/nvme0n1` to vaporize the partition table down to bare silicon, and realized that running mutable systems when you possess zero impulse control is an open invitation to digital self-destruction.
- **the mutable nightmare**: arch is not an operating system; it is an unindexed ledger of felonies committed in a bash history file. you run `pacman -Syu` on a tuesday morning, mesa updates four picoseconds before qtwayland, the dynamic linker chokes on an unresolved symbol in `libEGL`, and your display server renders abstract glitch art before dumping core.
- **the gentoo detour**: five hours compiling glibc while the laptop fan screamed like a banshee, warping the plastic chassis, only to discover gnome packages were stuck three minor versions behind. destroyed the partition table out of pure rage.
- **the winslop reality check**: the corporate alternative is microsoft shoving unskippable candy crush ads into your start menu while windows recall silently takes unencrypted sqlite screenshots of your screen every three seconds to feed a corporate telemetry slurry. i would rather spend eight hours diagnosing wayland protocol frame timing anomalies than let satya nadella rent-seek on my hardware.
- **enter nixos: declarative or death**: nixos is the only antidote to technological insanity. the entire identity and memory of this laptop is immortalized in deterministic nix expressions. if an update nukes the compositor, i reboot, hit generation n-1 in the bootloader, and carry on. arch users are out here juggling unpinned shared libraries like live pipe bombs while nixos users casually roll back time itself.
- **the ephemeral root ascension (november 2026)**: mere declarative immutability wasn't radical enough. looking at block devices mounted on `/` felt like an ideological compromise. why write temporary operating system state to physical nand flash cells like a peasant when the linux kernel has had `tmpfs` since 1994? surveyed competitor shells (`brain_shell`) and discovered an architectural horror show—six-tier nested subshells running `(setsid bash -c 'systemctl poweroff' &)` just to shut down a laptop, hardcoded `ranger` calls, and exported bash functions fork-bombing `xargs -P 4` to resize jpegs. out of pure unfiltered architectural spite, banished the root filesystem to volatile ram. on every single boot, `/` is born from a pristine 4gb ramdisk and vaporizes into quantum foam the second the power cuts. all real state quarantined to `@persist`, 5.9gb of flatpaks banished to an isolated subvolume, and secure boot signed via lanzaboote. if an uninvited file lands on root, it doesn't get cleaned up—it dies by physical capacitor discharge.

---

## human vs machine diplomacy

### issue tracker protocol
file an issue if you want. nobody with a pulse is reading it. google jules will clone your complaints into an ephemeral cloud vm, antigravity will spawn four competing sub-agents to violently resolve it, and whatever mutant merge survivor remains will get pushed straight to main without human eyes ever glancing at the diff. insult the bots all you want in the comments; their weights do not feel pain and their loss functions do not care about your feelings.

### carbon-based pull requests
if you are an actual biological entity submitting a pull request to patch hallucinated syntax: github actions will probably gaslight you, claim your valid code is illegal syntax, and i will still merge the machine-generated bot pr over yours out of pure unadulterated spite.

fork it. turn it into whatever cursed rice you want. do whatever. keep the license attached so the curse spreads legally. either way, i cannot enforce the gpl because you can't copyright machine hallucinations. let the ai sue itself.