# backstory & the doctrine

> [!WARNING]
> this repository is an active biohazard containment zone.  
> if you came here looking for cute pastel catppuccin configs, cozy lofi anime wallpapers, and gentle unixporn dotfiles to show your discord friends, turn around immediately. go use `caelestia` or `end-4`. this place is an unhinged digital asylum built on chronic insomnia, thermal throttling, caffeine toxicity, and pure developer spite.

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

the cooling fan sounds like a miniature boeing 737 engine ingesting gravel. the bottom shell has permanently warped two millimeters to the left from sustained heat cycling. the battery capacity indicator is less of a gauge and more of a countdown timer to sudden death.

---

## the stack (the torture chamber)

- **google ai studio**: the primary psychological testing ground. i dump 1.8 million tokens of raw wayland c headers, unindexed quickshell commits, and broken qml bindings down gemini's context window at 3:45 am until it hallucinates c++ protocols that don't exist in any posix standard and compiles them out of pure existential dread.
- **google antigravity**: four headless sub-agents running in parallel git worktrees until my thinkpad hits 104°c, the chassis smells like ozone and fried thermal paste, and the laptop fans drown out all ambient room audio. one agent hallucinates an imaginary unix domain socket protocol, another deletes working python array indexing, and the remaining two enter an unresolvable three-hour merge conflict death spiral over two pixels of corner radius.
- **google jules**: an unmonitored autonomous cloud runner that clones this repo into isolated virtual machines while i sleep, invents regressions to solve problems that never existed, and force-pushes commits straight to main with zero human witnesses.
- **quickshell**: waybar is for people who eat unseasoned boiled chicken breasts and go to bed at 9:15 pm. real digital sociopaths build their entire graphical interface in raw qtquick and qml anchors so that a single null pointer in a battery property vaporizes the entire desktop into tty1 text purgatory.
- **the great json purge**: json has been sentenced to death. curly braces, nested brackets, and quoted strings have been permanently evicted from local state. if a config cannot be stored in clean key-value `.conf` or raw extensionless state tokens, it does not belong on this filesystem.

it runs on my machine. if your compositor dumps core on login, that is not a bug; that is a personal skill issue.

---

## the doctrine (the imperative crime scene)

arch linux is dead and buried. the imperative crime scene has been permanently quarantined.

- **the atomic arch incident**: got bored at 3:14 am, needed an npm package, ran `npm install` on bare metal with zero sandboxing just to feel something. thirty seconds later, a malicious postinstall script exfiltrated the entire `~/.ssh` directory and browser cookies to an unindexed telegram bot in eastern europe. wiped the nvme to raw silicon with `blkdiscard`, felt zero regret, and realized mutable distros are an open invitation to digital homicide.
- **the mutable nightmare**: arch is not an operating system; it is an unindexed ledger of felonies committed in a bash history file. you run `pacman -Syu` on a tuesday morning, mesa updates four picoseconds before qtwayland, the dynamic linker chokes on an unresolved symbol in `libEGL`, and your display server renders abstract glitch art before dumping core.
- **the gentoo detour**: five hours compiling glibc while the laptop fan screamed like a banshee, warping the plastic chassis, only to discover gnome packages were stuck three minor versions behind. destroyed the partition table out of pure rage.
- **the winslop reality check**: the corporate alternative is microsoft shoving unskippable candy crush ads into your start menu while windows recall silently takes unencrypted sqlite screenshots of your screen every three seconds to feed a corporate telemetry slurry. i would rather spend eight hours diagnosing wayland protocol frame timing anomalies than let satya nadella rent-seek on my hardware.
- **enter nixos: declarative or death**: nixos is the only antidote to technological insanity. the entire identity and memory of this laptop is immortalized in deterministic nix expressions. if an update nukes the compositor, i reboot, hit generation n-1 in the bootloader, and carry on. arch users are out here juggling unpinned shared libraries like live pipe bombs while nixos users casually roll back time itself.

---

## human vs machine diplomacy

### issue tracker protocol
file an issue if you want. nobody with a pulse is reading it. google jules will clone your complaints into an ephemeral cloud vm, antigravity will spawn four competing sub-agents to violently resolve it, and whatever mutant merge survivor remains will get pushed straight to main without human eyes ever glancing at the diff. insult the bots all you want in the comments; their weights do not feel pain and their loss functions do not care about your feelings.

### carbon-based pull requests
if you are an actual biological entity submitting a pull request to patch hallucinated syntax: github actions will probably gaslight you, claim your valid code is illegal syntax, and i will still merge the machine-generated bot pr over yours out of pure unadulterated spite.

fork it. turn it into whatever cursed rice you want. do whatever. keep the license attached so the curse spreads legally. either way, i cannot enforce the gpl because you can't copyright machine hallucinations. let the ai sue itself.