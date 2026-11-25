> [!WARNING]
> if anyone in your contacts would actually look for you after three days of silence, close this tab.  
> this repository is what remains on a `thinkpad t16 gen 1` (`i7-1260P`, `mx550` idling on `nouveau`, `1920x1200@60hz`) once sleep turns optional and local agents spend the night editing broken qml anchors until dawn.  
> install [caelestia](https://github.com/caelestia-dots/caelestia) or [end4-pC](https://github.com/pctrade/end4-pC) if you want a desktop where widgets work out of the box without reading runtime logs.

captured right before hyprland dropped an orphaned layer-shell surface and terminated back to `tty1`:

> [!NOTE]
> if github refuses to stream the mp4 or your browser codec drops out mid-decode, nothing of value was lost. keep scrolling.

<div align="center">
  <video src="https://github.com/user-attachments/assets/bbc2284c-7273-48a3-8108-871a036a0b3f" controls="controls" style="max-width: 100%; height: auto;">
  </video>
</div>

---

### contents
1. [other configurations vs this](#other-configurations-vs-this)
2. [step 1: nixos base packages](#step-1-nixos-base-packages)
3. [step 2: installation](#step-2-installation)
4. [defects & patches](#defects--patches)
5. [record (BACKSTORY.md)](#record)

---

## other configurations vs this

there is no practical justification for cloning someone else's compulsions onto your own ssd. balanced adults install software maintained for more than one head.

| setup | stack | posture | primary audience | reason to use it instead | expected stability |
|---|---|---|---|---|---|
| **[caelestia](https://github.com/caelestia-dots/caelestia)** | quickshell, typescript, lua (`hypr-vars.lua`), `caelestia-cli`. | sanitized material symmetry. | people with appointments, social plans, and regular sleep cycles. | maintainers patch breaking updates before modules rot. | high |
| **[end4-pC](https://github.com/pctrade/end4-pC)** | qml fork stacked onto `illogical-impulse`, lua vars. | expressive widgets, community gallery, lyrics. | people who want visual density without debugging c++/qml bindings at 4 am. | coherent upstream layout and preset curation. | moderate |
| **[HyDE](https://github.com/HyDE-Project/HyDE)** | waybar, rofi, `wallbash`, shell, lua, python. | conventional tiling minimalism. | users who want theme patching without inspecting `dbus` internals. | mature across distros (`hydenix` on nixos) with minimal triage. | high |
| **[ml4w](https://github.com/mylinuxforwork/dotfiles)** | quickshell, shell, css, lua, dedicated live iso. | appliance predictability. | anyone who cannot lose their bar or audio panel five minutes before a call. | gui installers and tested release channels. | very high |
| **delirium** *(this repo)* | quickshell, python, hyprland lua, nixos on `7.6g` `tmpfs`. | friction between user, lenovo embedded controller, and unattended agents. | population: 1. tuned strictly around stiff knuckles and bad habits. | none. strip individual scripts for parts and leave the rest alone. | none |

### why i didn't just use `caelestia` or `end-4`

if you want volume sliders that bind cleanly, bluetooth codecs that negotiate without reading `pw-dump`, and clean screenshots ready for coworkers without redacting a traceback, install `caelestia` or `end-4`. they assume you are healthy enough to expect coherent defaults.

this repo exists strictly as cold offsite backup so when impulse wins at 4:10 am and `/dev/nvme0n1` gets wiped back down to bare flash, whatever still works survives somewhere off the drive. take `cli.py`, the bezier screen corners, `screenshot.py`, `battery.py`, or the fan watchdog and walk away.

---

## step 1: nixos base packages

add these definitions into `/etc/nixos/configuration.nix` (or your flake module) before running `./install.zsh`. skipping them causes `./install.zsh --doctor` to complain in red, leaves `quickshell` unable to spawn if `qs` is absent, turns ui symbols into hollow tofu rectangles (`[]`), and breaks widgets wired to `wl-copy`, `hyprpicker`, or `playerctl`:

```nix
  # 1. wayland session: uwsm keeps systemd and hyprland from abandoning orphan daemons
  programs.hyprland = {
    enable = true;
    withUWSM = true; # required so install.zsh can respawn quickshell via 'uwsm app -- qs -d'
  };
  programs.zsh.enable = true;   # prevents locking yourself out of tty1 on chsh
  programs.dconf.enable = true; # required so gtk dark-mode toggles write through

  # 2. packages verified by './install.zsh --doctor' + script runtime glue
  environment.systemPackages = with pkgs; [
    # wayland & shell runtime
    kitty                # opengl terminal
    quickshell           # qml/c++ layer-shell host ('qs')
    matugen              # wallpaper palette compiler
    awww                 # wallpaper daemon
    mpvpaper             # video wallpaper host for burning spare power
    hyprpicker           # screen pixel sampler
    wl-clipboard         # wl-copy / wl-paste
    brightnessctl        # backlight sysfs control
    playerctl            # mpris transport control
    adw-gtk3             # gtk3 dark theme parity
    glib                 # gsettings cli
    dconf                # gnome settings backend
    libnotify            # notify-send for background failure alerts
    ffmpeg               # video wallpaper frame extraction
    rsync                # flatpak gtk-3.0/4.0 folder sync
    curl                 # downloads icon fonts during initial setup
    fontconfig           # fc-list / fc-cache inspection

    # terminal utilities
    micro                # fallback editor for people who panic inside vi
    neovim               # configured with ijkl navigation
    fastfetch            # hardware summary readout
    eza                  # ls replacement
    zoxide               # directory frequency index
    fzf                  # interactive picker backend
    bat                  # syntax-highlighted cat
    ripgrep              # regex search
    fd                   # file traversal
    jq                   # json parsing fallback
    yazi                 # terminal file browser
    git                  # version control
    zsh                  # shell runtime

    # python glue & archives
    python3                # executes cli.py, battery.py, network.py, screenshot.py, weather.py
    python3Packages.pillow # lockscreen wallpaper blur preprocessing
    unar                   # archive extraction
    gh                     # github cli
  ];

  # 3. fonts: keeps missing codepoints from rendering as empty rectangles
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
  ];
```

apply the nixos generation before running the installer (or pass `--rebuild`):

```zsh
sudo nixos-rebuild switch
```

> [!NOTE]
> **on proprietary and icon fonts:**  
> `install.zsh` downloads google material symbols, font awesome 6 free, and `SegoeIcons.ttf` into `~/.local/share/fonts` and refreshes `fc-cache -f`. packaging proprietary icon fonts cleanly inside nix derivations creates needless churn when `fontconfig` resolves `~/.local/share/fonts` natively. running `--doctor` before a first `./install.zsh` run will flag them missing.

---

## step 2: installation

never execute `./install.zsh` with `sudo`. the script traps `(( EUID == 0 ))` immediately and exits rather than poisoning file ownership across `~/.config`.

### standard clone

keep the checkout under `~/.local/share/dotfiles` rather than cluttering `~`:

```zsh
mkdir -p ~/.local/share
git clone https://github.com/theyh4t3-ashlxy/delirium.git ~/.local/share/dotfiles
cd ~/.local/share/dotfiles
chmod +x install.zsh
./install.zsh
```

run `./install.zsh --help` for `--doctor`, `--dry-run`, `--fetch-wp`, `--update`, and `--rebuild`. with `fzf` on `$PATH` it renders a multi-select prompt; otherwise it drops to comma-separated numbers.

### single-line bootstrap

do not pipe `curl .../install.zsh | zsh` alone from `$HOME`. `install.zsh` resolves `DOTS_DIR="${0:A:h}"` from its own path and performs no `git clone`, so an unanchored pipe inside `~` will attempt linking `Downloads` and `Documents` straight into `~/.config`:

```zsh
git clone https://github.com/theyh4t3-ashlxy/delirium.git ~/.local/share/dotfiles && ~/.local/share/dotfiles/install.zsh
```

interactive prompts read straight from `/dev/tty`.

---

## defects & patches

### bugs
an empty issue tracker does not prove stability; either nothing broke locally or `quickshell` rotated its runtime log before anyone checked `/run/user/1000/quickshell`.

### patches
there is no roadmap or triage schedule. google shut down jules for active execution and folded its workflow into antigravity, so no cloud agent is sitting around watching issues anyway. open a pull request if a defect bothers you enough to patch it yourself; understand that late-night local agent passes against `main` may overwrite your diff before morning.

---

## record
for the hardware decay notes, the `atomic-lockfile` nvme wipe, `lanzaboote`, and why `/` drains itself inside a volatile `7.6g` `tmpfs` mount on poweroff, read [BACKSTORY.md](BACKSTORY.md).
