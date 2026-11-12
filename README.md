> [!WARNING]
> this repository is three python daemons, a pile of qml, and a nixos config taped together at 4 am because i refused to learn how normal people use a computer.  
> half the codebase was argued into existence with cloud models while my laptop fans sounded like a boeing 737 on the runway, and the other half was patched by a rival model after the first one broke my lockscreen.  
> if you want a polite desktop with pastel corners and a discord server full of patient strangers, close this tab and install `caelestia` or `end-4`.

exit doors are right here:  
[caelestia](https://github.com/caelestia-dots/caelestia) · [end-4 (pc's fork)](https://github.com/pctrade/end4-pC)

below is fifteen seconds of live footage recorded moments before wayland choked on a malformed `zwlr_layer_shell_v1` surface and dumped me straight into `tty1`.

> [!NOTE]
> if the embed fails to render, either your browser's media decoder quietly segfaulted or github decided your user-agent doesn't deserve mp4 streams today. i am not filing a support ticket with microsoft on your behalf.

<div align="center">
  <video src="https://github.com/user-attachments/assets/bbc2284c-7273-48a3-8108-871a036a0b3f" controls="controls" style="max-width: 100%; height: auto;">
  </video>
</div>

---

### contents
1. [ecosystem reality check](#ecosystem-reality-check-why-you-should-probably-leave)
2. [stage 1: nixos ransom note](#stage-1-the-nixos-ransom-note)
3. [stage 2: deployment vectors](#stage-2-deployment-vectors)
4. [stage 3: python controller & cli flags](#stage-3-python-controller--cli-flags)
5. [known hazards & unsolicited suggestions](#known-hazards--unsolicited-suggestions)
6. [doctrine & autopsy logs (BACKSTORY.md)](#the-doctrine--lore)

---

## ecosystem reality check: why you should probably leave

let's be realistic. you have actual options, and almost every single one of them is a healthier life decision than cloning this repo.

| rice | stack & engine | primary vibe | why people use it | why you should pick it over this | survival rate |
|---|---|---|---|---|---|
| **[caelestia](https://github.com/caelestia-dots/caelestia)** | quickshell + hyprland, the current meta. | chromebook if google hired actual designers. | looks clean (`"it loosk cool"`) and works out of the box. | an actual community exists to rescue you when an update breaks it. | 94% |
| **[end-4 (pc's fork)](https://github.com/pctrade/end4-pC)** | quickshell again. everything is quickshell now. | material you cranked past eleven. | widgets everywhere, massive customization ceiling. | battle-tested by thousands of arch insomniacs. | 80% |
| **[HyDE](https://github.com/HyDE-Project/HyDE)** | classic waybar + standard hyprland script glue. | old-school arch stability ("i use arch btw"). | midwit bell curve meme: beginners overcomplicate, veterans just want a bar that renders text. | most mature shell in the ecosystem; won't randomly eat your ram. | 90% |
| **[ml4w](https://github.com/mylinuxforwork/dotfiles)** | gtk/quickshell hybrid built for people with salaries. | employed adult in a cubicle. | GUI settings app so you never touch raw config files. | zero chance of bricking your audio five minutes before a zoom call. | 99% |
| **delirium** *(you are here)* | quickshell, python, hyprland, nixos. | ouroboros of llm commits breaking and fixing each other in an infinite loop. | population: 1. tuned exclusively for my specific muscle memory and neuroses. | you shouldn't. only clone this if you read stack traces for sport. | 0% |

### why delirium exists at all
those other repos are real projects maintained for normal users. `delirium` is my personal sandbox built at 16 because i hated how everyone else handled window gaps and volume OSDs.

if you want a peaceful desktop where audio sliders work on the first try and your notification daemon doesn't judge you, go install **ml4w** or **caelestia**.

if you stay anyway: strip-mine the repo. take the cubic bezier curves, steal the native python ipc controller, and rip out whatever qml components survive on your hardware.

---

## stage 1: the nixos ransom note

before touching the installer, drop these packages into `/etc/nixos/configuration.nix`. skipping this step means `./install.zsh --doctor` will roast your missing `$PATH` binaries, `quickshell` will panic trying to bind layer surfaces, `matugen` will fail to sample a single hex code, and your bar will render nothing but hollow unicode tofu boxes (`[]`).

```nix
  # 1. wayland session harness: uwsm keeping systemd and hyprland from leaking orphan processes
  programs.hyprland = {
    enable = true;
    withUWSM = true; # wraps hyprland in a proper systemd unit so logging out actually kills child daemons
  };
  programs.zsh.enable = true;   # registers zsh in /etc/shells before chsh locks you out of tty1
  programs.dconf.enable = true; # required so gtk theme switches don't silently fail in the background

  # 2. required binaries: compositor glue, cli replacements, and python ipc dependencies
  environment.systemPackages = with pkgs; [
    # wayland plumbing & shell machinery
    kitty                # gpu terminal for running git push --force at 3 am
    quickshell           # qml desktop shell engine replacing waybar and eww
    matugen              # extracts material color palettes straight from your wallpaper
    awww                 # wallpaper daemon switching frames without dropping wayland surfaces
    mpvpaper             # loops mp4 wallpapers when your battery life is too high
    hyprpicker           # eyedropper utility for stealing hex codes off websites
    wl-clipboard         # wl-copy / wl-paste so clipboard history persists across closes
    brightnessctl        # hardware backlight control without needing root permissions
    playerctl            # mpris media daemon pausing spotify from qml widgets
    adw-gtk3             # forces stubborn gtk3 apps to match libadwaita dark mode
    glib                 # provides gsettings binary for live theme reloads
    dconf                # low-level gnome key-value store for gtk state
    libnotify            # notify-send binary for background script alerts
    ffmpeg               # extracts zero-second video frames for matugen color sampling

    # rust cli coreutils & terminal navigation
    micro                # emergency editor for when you forget how to exit neovim
    neovim               # modal editor with 40 plugins you spend more time configuring than using
    fastfetch            # prints system specs fast enough to screenshot before the compositor crashes
    eza                  # ls replacement with nerd font icons
    zoxide               # tracks directory frecency so you stop typing cd ../../../../
    fzf                  # fuzzy finder powering the interactive installer menu
    bat                  # cat clone with syntax highlighting and git diff gutters
    ripgrep              # rg because standard grep takes three geological eras on node_modules
    fd                   # sane find replacement without the archaic -exec {} \; ritual
    jq                   # parses hyprctl -j output without regex war crimes
    yazi                 # terminal file manager with kitty image previews that actually render
    git                  # version control for reverting whatever broke five minutes ago
    zsh                  # interactive shell required by the installer scripts

    # python controller & archive utilities
    python3                # runs the background desktop controller and socket listeners
    python3Packages.pillow # handles gaussian blur passes for the lockscreen cache
    unar                   # extracts tarballs and zip archives without memorizing tar flags
    gh                     # github cli for yelling at autonomous ci runners from a terminal
  ];

  # 3. typography: prevents missing glyphs from turning your workspace bar into rectangles
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono # primary monospace font with patched ligatures
    noto-fonts                # standard latin fallback
    noto-fonts-cjk-sans       # stops japanese/chinese track titles on spotify from rendering as boxes
    noto-fonts-color-emoji    # color emoji support so notifications look normal
  ];
```

rebuild your system generation prior to running the installer:

```zsh
sudo nixos-rebuild switch
```

> [!NOTE]
> **the local font bypass:**  
> `install.zsh` downloads google material symbols, font awesome 6 free, and microsoft fluent icons straight into `~/.local/share/fonts`. packaging proprietary icon webfonts inside a pure nix derivation is tedious bureaucratic pain, and `fontconfig` indexes `~/.local/share/fonts` automatically anyway. running `./install.zsh --doctor` prior to a full install flags these fonts as missing until the download step finishes. if impure downloads bother your nixos purity standards, add `material-symbols` and `font-awesome_6` directly to `fonts.packages` above.

---

## stage 2: deployment vectors

do **not** run the installer as root. invoking `sudo ./install.zsh` trips a UID check that aborts execution immediately before you accidentally `chown root:root` your entire `~/.config` tree and brick your user login.

### vector a: local clone (recommended for people with a pulse)

clone into `~/.local/share/dotfiles` rather than dumping another loose folder into `~`:

```zsh
mkdir -p ~/.local/share
git clone https://github.com/theyh4t3-ashlxy/delirium.git ~/.local/share/dotfiles
cd ~/.local/share/dotfiles
chmod +x install.zsh
./install.zsh
```

when `fzf` is present in `$PATH`, you get an interactive TUI menu. without `fzf`, the script drops down to a comma-separated number prompt like a 1994 BBS door game on a `vt100` terminal.

### vector b: curl pipe (`| zsh`)

for people who refuse to audit shell scripts before executing them and trust random github commits with write access to their home directory:

```zsh
curl -fsSL https://raw.githubusercontent.com/theyh4t3-ashlxy/delirium/main/install.zsh | zsh
```

the script binds interactive reads directly to `/dev/tty`, meaning `curl | zsh` won't choke on `EOF` when prompting for confirmation. you have *no excuses* (shoutout to that one charter school district motto etched into my brain against my will).

---

## stage 3: python controller & cli flags

since half the desktop logic lives in python sockets and custom zsh wrappers rather than standard bash spaghetti, here are the flags you will actually end up typing when something breaks:

```zsh
./install.zsh --doctor    # audits $PATH binaries, nix packages, and local font cache without touching files
./install.zsh --dry-run   # prints every symlink and backup operation before committing to disk
./install.zsh --restore   # rolls back ~/.config from the last timestamped backup snapshot
```

once inside the session, the native python controller syncs state between `hyprctl`, `matugen`, and `quickshell` over unix sockets so switching wallpapers doesn't freeze your bar for two seconds.

---

## known hazards & unsolicited suggestions

### current bug count
zero open issues—either the python ipc loop achieved nirvana, or the crash reporter segfaulted before writing to disk. (if your monitor flashes black for 40ms when switching from an mp4 wallpaper to a static png, that's just `mpvpaper` and `awww` fighting over the layer surface. blink at the exact same moment and you won't notice.)

### suggestions (not a roadmap)
there is no roadmap. roadmaps imply project managers, quarterly deliverables, and promises i have no intention of keeping.
- if you have a patch or suggestion that makes the shell faster, weirder, or cleaner, open an issue or drop a PR.
- open an issue asking for "ubuntu 22.04 support" or "how do i install this on gnome" and i will close it as `wontfix` while my local scripts laugh at you.
- if an autonomous cloud runner opens a PR at 3 am refactoring the entire python controller, do not make eye contact with it.

---

## the doctrine & lore
for the full post-mortem on why turn-key rices annoyed me enough to write this, the great arch linux partition incident, laptop thermal throttling workarounds, and rules for arguing with coding models, read [BACKSTORY.md](BACKSTORY.md).
