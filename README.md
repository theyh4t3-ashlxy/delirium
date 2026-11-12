> [!WARNING]
> this repo is a pile of qml, python scripts, and a nixos config taped together at 4 am because i refused to use a computer like a normal person.  
> half of this code was argued into existence with cloud models while my laptop fans screamed, and the other half was fixed by a second model after the first one broke my lockscreen.  
> if you want a polite desktop with pastel corners and a discord server full of helpful people, close this tab and go install `caelestia` or `end-4`.

links so you don't even have to search:  
[caelestia](https://github.com/caelestia-dots/caelestia) / [end4-pC](https://github.com/pctrade/end4-pC)

here is fifteen seconds of live footage recorded right before wayland choked on a bad layer-shell surface and dropped me straight into `tty1`.

> [!NOTE]
> if the video doesn't load, either your browser's media player quietly segfaulted or github decided your user-agent doesn't get mp4 streams today. not my problem.

<div align="center">
  <video src="https://github.com/user-attachments/assets/bbc2284c-7273-48a3-8108-871a036a0b3f" controls="controls" style="max-width: 100%; height: auto;">
  </video>
</div>

---

### contents
1. [other rices vs this mess](#other-rices-vs-this-mess)
2. [step 1: nixos packages](#step-1-nixos-packages)
3. [step 2: running the installer](#step-2-running-the-installer)
4. [bugs & suggestions](#bugs--suggestions)
5. [backstory (BACKSTORY.md)](#backstory)

---

## other rices vs this mess

let's be real here. you have actual options, and almost all of them are better life choices than cloning this repo.

| rice | actual stack | primary vibe | why people like it | why it beats this repo | survival rate |
|---|---|---|---|---|---|
| **[caelestia](https://github.com/caelestia-dots/caelestia)** | quickshell, typescript, lua (`hypr-vars.lua`), `caelestia-cli`. | chromebook if google hired real designers. | `"it loosk cool"` and installs straight from the AUR via `caelestia install`. | 4.7k stars and an actual community to save you when an update breaks your config. | 94% |
| **[end4-pC](https://github.com/pctrade/end4-pC)** | 87% qml fork sitting on top of `@end-4`'s `illogical-impulse` (`ii`), plus lua vars. | material 3 expressive on steroids. | one-click community preset gallery (`gh` cli), lyrics, weather, and qr code screen snipping. | stable yet wild with customization, as long as you already have `illogical-impulse` installed. | 80% |
| **[HyDE](https://github.com/HyDE-Project/HyDE)** | waybar, rofi, `wallbash`, shell + lua + python (formerly `hyprdots`). | classic arch rice ("i use arch btw"). | midwit bell curve: beginners want 50 widgets, veterans just want a bar that works and `themepatcher`. | 9.7k stars, most mature setup around, even has a nixos cousin (`hydenix`). | 90% |
| **[ml4w](https://github.com/mylinuxforwork/dotfiles)** | qml (quickshell), shell, css, lua, plus its own live ISO ("ml4w os"). | employed adult with a day job. | GUI settings app and one-line installer supporting arch, fedora, ubuntu, and opensuse. | doesn't explode five minutes before a meeting. | 99% |
| **delirium** *(this repo)* | quickshell, python, hyprland, nixos. | one ai model breaks it, a different ai model patches it, repeat forever. | population: me. built only for my specific muscle memory and ocd. | you want to try something weird that isn't mainstream, and you don't mind reading tracebacks. | 0% |

### why delirium exists anyway
the other rices are built for an audience. `delirium` was built by a 16-year-old who refused to use standard tools and wanted total keyboard control over every pixel.

if you want a painless desktop where volume sliders work on the first try and nothing yells at you in the terminal, go install **ml4w** or **caelestia**.

if you stick around anyway: steal the code, steal the bezier curves, steal `cli.py`, and take whatever qml parts work on your machine.

---

## step 1: nixos packages

before running `./install.zsh`, put this block into `/etc/nixos/configuration.nix` (or your flake). if you skip this, `./install.zsh --doctor` will call out every missing binary in red text, `quickshell` (`qs`) won't start, `matugen` will have nothing to sample, and your terminal will render hollow unicode tofu boxes (`[]`) instead of icons:

```nix
  # 1. wayland session: uwsm keeps systemd and hyprland from leaving zombie processes behind
  programs.hyprland = {
    enable = true;
    withUWSM = true; # lets install.zsh restart quickshell cleanly via 'uwsm app -- qs -d'
  };
  programs.zsh.enable = true;   # puts zsh in /etc/shells before you lock yourself out of tty1
  programs.dconf.enable = true; # needed so gtk theme switches don't fail silently

  # 2. packages checked by './install.zsh --doctor' + script glue
  environment.systemPackages = with pkgs; [
    # wayland & rice daemons
    kitty                # gpu terminal where we run git commands we barely understand
    quickshell           # qml desktop shell ('qs') replacing waybar
    matugen              # pulls material color palettes straight from wallpapers
    awww                 # wallpaper daemon that doesn't crash when wayland blinks
    mpvpaper             # video wallpaper player for when your gpu isn't warm enough
    hyprpicker           # screen color picker for grabbing hex codes
    wl-clipboard         # wl-copy and wl-paste so you can copy stackoverflow snippets
    brightnessctl        # screen brightness control so you don't blind yourself at 3 am
    playerctl            # media controller keeping spotify on a leash
    adw-gtk3             # makes old gtk3 apps look like libadwaita
    glib                 # gives you gsettings so gtk themes reload live
    dconf                # gnome config backend for dark mode toggles
    libnotify            # notify-send so background python scripts can ping you
    ffmpeg               # grabs thumbnails from video wallpapers
    rsync                # install.zsh uses this to copy gtk-3.0/4.0 folders for flatpak
    curl                 # downloads missing icon fonts and random wallhaven wallpapers
    fontconfig           # gives install.zsh fc-list and fc-cache to check installed fonts

    # cli tools
    micro                # normal text editor for when you forget how to quit neovim
    neovim               # the editor you tell people on reddit you use every day
    fastfetch            # prints your system info before the next crash
    eza                  # ls with nerd font icons
    zoxide               # smart cd that remembers where you go
    fzf                  # fuzzy finder for the interactive installer menu
    bat                  # cat with syntax highlighting
    ripgrep              # rg because regular grep takes forty business days
    fd                   # find replacement without the ugly -exec \; syntax
    jq                   # parses json payloads (install.zsh falls back to python3 if missing)
    yazi                 # fast terminal file manager with image previews
    git                  # for committing straight to main without testing
    zsh                  # runs install.zsh and loads ~/.config/zsh/sources.zsh

    # python glue & archives
    python3                # runs ~/.local/bin/cli and wallpaper.py
    python3Packages.pillow # blurs images for the lockscreen cache
    unar                   # unpacks archives without memorizing tar flags
    gh                     # github cli for yelling at bots in issue trackers
  ];

  # 3. fonts: keeps unicode tofu rectangles off your bar
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono # main monospace font with patched icons
    noto-fonts                # standard text fallback
    noto-fonts-cjk-sans       # stops asian characters on spotify from turning into boxes
    noto-fonts-color-emoji    # normal color emojis
  ];
```

switch your nixos generation before running the installer (or let `./install.zsh --rebuild` do it for you):

```zsh
sudo nixos-rebuild switch
```

> [!NOTE]
> **about the icon fonts:**  
> `install.zsh` downloads google material symbols, font awesome 6 free, and `SegoeIcons.ttf` straight into `~/.local/share/fonts` and runs `fc-cache -f`. packaging microsoft fonts in nix is a headache, and `fontconfig` checks `~/.local/share/fonts` automatically anyway. if you run `./install.zsh --doctor` before running the installer once, it will complain that those icon fonts are missing.

---

## step 2: running the installer

do **not** run `./install.zsh` with `sudo`. the script checks `(( EUID == 0 ))` right at the start and quits immediately so you don't accidentally mess up permissions in `~/.config`.

### option a: clone it normally

clone into `~/.local/share/dotfiles` so you don't clutter `~`:

```zsh
mkdir -p ~/.local/share
git clone https://github.com/theyh4t3-ashlxy/delirium.git ~/.local/share/dotfiles
cd ~/.local/share/dotfiles
chmod +x install.zsh
./install.zsh
```

just run `./install.zsh` and read the menu, or pass `--help` if you want to see the flags (`--doctor`, `--dry-run`, `--fetch-wp`, `--update`, etc.). if `fzf` is installed, you get a multi-select picker; if not, it drops down to typing comma-separated numbers like a 1994 `vt100` terminal.

### option b: one-liner

don't do `curl .../install.zsh | zsh` on its own. `install.zsh` sets `DOTS_DIR="${0:A:h}"` (the folder the script lives in) and doesn't run `git clone` itself, so piping `curl` straight into `zsh` in your home directory will make it try to symlink your `Downloads` and `Documents` folders into `~/.config`.

if you want a one-liner, clone and run it together:

```zsh
git clone https://github.com/theyh4t3-ashlxy/delirium.git ~/.local/share/dotfiles && ~/.local/share/dotfiles/install.zsh
```

the script reads interactive prompts straight from `/dev/tty`, so you have no excuses (as a certain charter school district motto once threatened. we do not speak its name).

---

## bugs & suggestions

### bugs
zero reported fires so far. either the code is holding together or the crash logger segfaulted before it could snitch.

### suggestions (no roadmap)
i don't have a roadmap. roadmaps are for product managers.
- if you have a suggestion or want to fix something weird, open an issue or send a PR.
- if a cloud runner opens a PR at 3 am rewriting half the repo, just let it cook.

---

## backstory
for why prebuilt rices annoyed me enough to make this, the arch incident, laptop thermal struggles, and rules for arguing with ai models, read [BACKSTORY.md](BACKSTORY.md).
