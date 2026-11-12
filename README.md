> [!WARNING]
> this is an unholy biohazard containment zone masquerading as a wayland desktop.  
> all of the codebase was hallucinated by neural networks running on melting cloud tpus at 4 am while the human maintainer stared blankly into the middle distance fueled by cold brew and spite. if you want polite anime dotfiles with rounded pastel corners and zero mental illness, close this tab immediately and go install `caelestia` or `end-4`.

here is sixteen seconds of live footage captured moments before wayland choked on a malformed layer-shell surface and dropped straight into tty1.

> [!NOTE]
> if the video fails to load, the media player probably suffered a silent segfault or github refused to serve raw video to your pathetic user-agent. either way, not my problem.

<div align="center">
  <video src="https://github.com/user-attachments/assets/bbc2284c-7273-48a3-8108-871a036a0b3f" controls="controls" style="max-width: 100%; height: auto;">
  </video>
</div>

---

## the ecosystem comparison: why delirium is probably the worst choice for you

let us be completely realistic. you have options, and almost all of them are objectively more responsible life choices than cloning this repository.

here is how the popular hyprland rice landscape actually breaks down, and why `delirium` is by far the most hostile to your mental health:

| rice | stack & engine | primary vibe | why people love it | why it is probably better than this | survival rate |
|---|---|---|---|---|---|
| **[caelestia](https://github.com/caelestia-dots/caelestia)** | quickshell (qml) + lua hyprland + aur cli | fluid, morphing, modern material | smooth card morphing, sane quickshell without writing raw qml, managed updates | an actual managed project where you don't have to debug pam auth loops | 94% |
| **[end-4](https://github.com/end-4/dots-hyprland)** | ags (gjs/typescript) + scss + material 3 | android 14 tablet on your monitor | unbelievable unixporn screenshots, giant pill quicksettings, dynamic wallpaper swatches | polished turn-key android aesthetics if your ram can survive the gjs runtime | 78% |
| **[HyDE](https://github.com/HyDE-Project/HyDE)** | waybar + rofi + bash script forest | classic unixporn aesthetic chameleon | 20+ community themes hot-swapped by keybinds, huge userbase, automated installer | battle-tested community presets that won't require understanding nix expressions | 85% |
| **[ml4w](https://github.com/mylinuxforwork/dotfiles)** | waybar + wofi + python/gtk settings app | clean corporate daily driver | multi-distro installer, click-to-configure gui app, rock-solid stability for real work | built for adults who need their display server to survive zoom meetings | 99% |
| **delirium** *(this repo)* | quickshell (qml) + lua hyprland + python cli + nixos | chaotic digital biohazard at 4 am | zero `.json` flat state, thinkpad ec fan hacking (`fanctl`), instant nix rollbacks, pure keyboard flow | it isn't. it is objectively the worst choice unless you cope with my exact neuroses | 3% |

### if delirium is the worst, why does it exist?
because the other rices are products made for an audience. `delirium` is an obsessive, bespoke containment unit hand-carved by a 15-year-old who refused to use standard tools, declared holy war on curly braces, and needed a root daemon just to keep an alder lake thinkpad from thermal death at 400mhz.

if you want a painless desktop where volume sliders work and nobody yells at you in the terminal, go install **ml4w** or **caelestia**. 

if you choose to cope with me anyway: steal our code, steal our continuous bezier curves, steal our native python desktop controller, and enjoy absolute, uncompromising keyboard-driven control over every single byte.

---

### contents
1. [the ecosystem comparison](#the-ecosystem-comparison-why-delirium-is-probably-the-worst-choice-for-you)
2. [stage 1: declarative ransom note](#stage-1-the-declarative-ransom-note)
3. [stage 2: deployment vectors](#stage-2-deployment-vectors)
4. [desktop cli cheat sheet](#desktop-cli-cheat-sheet)
5. [installer flag reference](#installer-flag-reference)
6. [known bugs & void roadmap](#known-bugs--void-roadmap)
7. [the doctrine & lore (BACKSTORY.md)](BACKSTORY.md)

---

## stage 1: the declarative ransom note

before cloning or executing the installer, paste this block into `/etc/nixos/configuration.nix` unless you want `./install.zsh --doctor` to publicly humiliate your missing binaries in bold red ansi.

if you attempt to rawdog this desktop without declaring these packages, quickshell will suffer an existential crisis negotiating layer-shell surrender terms, matugen will throw a tantrum with zero wallpaper colors to sample, and your terminal will render hollow unicode tofu rectangles everywhere instead of rice:

```nix
  # 1. wayland session harness: held together by uwsm and unresolved emotional trauma
  programs.hyprland = {
    enable = true;
    withUWSM = true; # systemd putting hyprland on a choke chain so it stops leaking zombie procs into the void
  };
  programs.zsh.enable = true; # registers zsh in /etc/shells before you lock yourself out weeping in posix sh
  programs.dconf.enable = true; # atomic gsettings backend so gtk theme switches don't trigger visual stroke

  # 2. digital hoarder collection: terminal toys and wayland rice machinery
  environment.systemPackages = with pkgs; [
    # wayland rice tooling & compositor daemons
    kitty                # gpu-accelerated terminal where we run git commands we barely understand
    quickshell           # qml layer-shell desktop shell engineered to make waybar users cry
    matugen              # material you color generator extracting palettes from anime wallpapers
    awww                 # animated wallpaper daemon that won't panic when wayland blinks
    mpvpaper             # video wallpaper runner for when your gpu isn't sweating enough
    hyprpicker           # wayland color picker for obsessive hex code sampling
    wl-clipboard         # wl-copy and wl-paste so you can steal broken stackoverflow snippets
    brightnessctl        # backlight control so you don't burn your retinas at 3 am
    playerctl            # mpris media controller keeping spotify on a short leash
    adw-gtk3             # libadwaita styling for crusty gtk3 apps pretending to look modern
    glib                 # provides gsettings so gtk theme switches don't desync into modern art
    dconf                # gnome configuration backend for atomic dark mode toggles
    libnotify            # notify-send so background python daemons can yell at you
    ffmpeg               # zero-frame thumbnail extraction for live video wallpapers

    # terminal cosplay to pretend we understand rust cli tooling
    micro                # terminal editor for when neovim keybinds cause cognitive paralysis
    neovim               # the modal editor you tell people on reddit you use daily
    fastfetch            # neofetch rewrite to display your uptime before the next segfault
    eza                  # ls with lipstick and nerd font icons
    zoxide               # smart cd that guesses where you wanted to navigate
    fzf                  # fuzzy finder to accommodate your technological neglect
    bat                  # cat clone with syntax highlighting and wings
    ripgrep              # rg because searching files with grep takes forty business days
    fd                   # find replacement because life is too short for -exec \; syntax
    jq                   # json parser for wrangling quickshell api payloads
    yazi                 # async rust terminal file manager that goes zooom
    git                  # version control for committing straight to main without tests
    zsh                  # the interactive shell keeping you from existential dread

    # glue scripts and wallpaper manipulation contraband
    python3              # the snake language running background desktop glue
    python3Packages.pillow # image processing so lockscreen blurring actually works
    unar                 # archive unpacker for theme extraction contraband
    gh                   # github cli for screaming at autonomous bots in issue trackers
  ];

  # 3. typography: sacrificial glyphs to keep unicode tofu rectangles from infesting your desktop
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono # the holy monospace font with all patched ligatures
    noto-fonts                # standard sans-serif fallback so letters actually render
    noto-fonts-cjk-sans       # prevents asian characters from collapsing into blank boxes
    noto-fonts-color-emoji    # renders emojis in full color instead of cursed black silhouettes
  ];
```

apply generation switch before touching the installer:

```zsh
sudo nixos-rebuild switch
```

> [!NOTE]
> **the icon font heist:**
> `install.zsh` forcibly curls google material symbols, font awesome 6 free, and fluent icons directly into `~/.local/share/fonts` during installation. why? because maintaining proprietary microsoft glyphs and bespoke icon webfonts in nixpkgs is bureaucratic self-harm, and fontconfig finds them in local share anyway. if you run `./install.zsh --doctor` beforehand, it will throw a red-text fit about missing fonts. declare `material-symbols` and `font-awesome_6` in your nix config if unfree curl downloads offend your delicate declarative sensibilities.

---

## stage 2: deployment vectors

do not run this script as root. if you invoke `sudo ./install.zsh`, the script detects your complete lack of terminal survival instincts, insults your bloodline in bold red ansi, and terminates with extreme prejudice before you recursively chown `/` to root:root and turn your install into a brick.

### vector a: the civilized local clone (for cowards who like living)

clone into xdg data storage (cluttering `~` is a class-a misdemeanor punishable by public shaming):

```zsh
mkdir -p ~/.local/share
git clone https://github.com/theyh4t3-ashlxy/delirium.git ~/.local/share/dotfiles
cd ~/.local/share/dotfiles
chmod +x install.zsh
./install.zsh
```

if fzf is installed, it drops you into an interactive menu. if fzf is missing, it falls back to typing comma-separated numbers like it is 1994 on a vt100 terminal because we accommodate your severe technological self-neglect.

### vector b: the digital suicide pact (curl pipe)

if you possess zero self-preservation instinct, refuse to read shell scripts before running them, and actively want untrusted zsh code off github executing arbitrary syscalls on your workstation:

```zsh
curl -fsSL https://raw.githubusercontent.com/theyh4t3-ashlxy/delirium/main/install.zsh | zsh
```

the installer forcibly hijacks `/dev/tty` for interactive input, so piping curl straight to zsh will not panic on eof. you have no excuses. (as a certain charter school district motto once threatened. we do not speak its cursed name)

---

## desktop cli cheat sheet

all desktop actions and shell lifecycles are unified through `cli` (zero mouse required):

| command | function |
|---|---|
| `cli status` | print active shell, pids, and memory footprint |
| `cli reload` | graceful restart without layer-shell surface conflicts |
| `cli shell toggle` | switch between quickshell and brain_shell |
| `cli launcher` | toggle app launcher (`WIN + D`) |
| `cli files [dir]` | open preferred file manager (`WIN + E`) |
| `cli notifs` | toggle notification center (`WIN + N`) |
| `cli clip` | toggle clipboard history (`WIN + V`) |
| `cli wp` | roll random wallpaper & regenerate tokens (`WIN + W`) |
| `cli audio` | toggle volume & audio mixer (`WIN + A`) |
| `cli power` | open power menu (`WIN + ESCAPE`) |
| `cli lock` | lock session (`WIN + END`) |
| `cli keybinds` | launch keyboard cheatsheet |
| `cli welcome` | open onboarding wizard |
| `cli` | launch interactive fzf action picker |

---

## installer flag reference

for automated pipelines, unattended docker builds, and terminal purists who would rather eat glass than touch an interactive cursor menu:

| flag | function | damage report |
|---|---|---|
| `--all` | full deployment carpet-bomb | triggers nix rebuild, compresses existing configs into an emergency tarball graveyard, overwrites symlinks, runs matugen palette extraction, kicks quickshell. zero survivors. |
| `--rebuild`, `-r` | nix generation switch | executes `sudo nixos-rebuild switch` directly so you don't break your manic terminal typing cadence. |
| `--doctor` | forensic autopsy | inspects `systemPackages`, checks icon fonts, validates symlinks, ruthlessly exposes broken paths in saturated red text. |
| `--update`, `-u` | git upstream sync | pulls latest commits, restores python script execution bits, re-establishes broken symlinks, stashes uncommitted crimes. |
| `--reload` | compositor defibrillator | signals `hyprctl reload` and respawns quickshell inside uwsm so zero zombie processes linger to suck your battery dry. |
| `--links`, `-l` | symlink injection | violently symlinks dotfiles into `~/.config` without triggering a full twenty-minute nix generation rebuild. |
| `--fetch-wp` | wallpaper lottery | pulls a high-res wallpaper from wallhaven via curl. anime waifu preferences are aggressively ignored. |
| `--dots=<items>` | surgical symlinks | target specific configs (`quickshell,hypr,kitty,zsh,fastfetch,yazi,nvim,gtk-3.0,gtk-4.0`) if committing to the whole asylum scares you. |
| `--no-theme` | matugen boycott | bypasses color palette generation for psychopaths who crave blinding white layouts and permanent retina damage. |
| `--no-backup` | skip tarball safety net | rawdogs your home directory directly without archiving old configs. if you lose custom files, skill issue. |
| `--no-reload` | stealth write | writes config files to disk without poking the running compositor. sneaky, coward-friendly. |

---

## known bugs & void roadmap

### bugs
zero reported fires. either this stack achieved divine enlightenment or the crash logging daemon segfaulted before it could snitch.

### roadmap
- [ ] scream into the void if you want a feature. the void might reply with a pull request generated by a hallucinating cloud runner.

---

## the doctrine & lore
for why turn-key rices exist vs why we hand-carve custom shells from scratch, the full atomic arch incident autopsy, hardware thermal containment, and machine diplomacy rules, read [BACKSTORY.md](BACKSTORY.md).
