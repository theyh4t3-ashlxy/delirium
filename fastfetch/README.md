# fastfetch

system readout rendering in under 3ms before thermal throttling reminds you what hardware this actually is.

configuration lives inside `matugen/templates/fastfetch-colors.jsonc`, which compiles straight into `config.jsonc` whenever palettes shift. editing `config.jsonc` directly wastes time because `matugen` overwrites it silently.

colors map strictly to terminal ANSI registers (`color0`–`color15`) owned by kitty and pushed live via `pkill -USR1 kitty` so stale hex escapes never bleed into active shells. disk usage stays anchored to `/home` (`/dev/nvme0n1p2`, `btrfs`) because `/` mounts inside a volatile `7.6G` `tmpfs` ramdisk that reports `0 B used` no matter how bad the previous night got—retrograde amnesia enforced directly in the mount table.

### sample telemetry

```
          ▗▄▄▄       ▗▄▄▄▄    ▄▄▄▖             ashley@lost  •  /home/ashley/
          ▜███▙       ▜███▙  ▟███▛             ────────────────────────────────────────────
           ▜███▙       ▜███▙▟███▛              ╭─  os     · NixOS 26.11 (Zokor) x86_64
            ▜███▙       ▜██████▛               │  󰌢 host   · ThinkPad T16 Gen 1
     ▟█████████████████▙ ▜████▛     ▟▙         │  󰌽 kernel · Linux 7.3.5
    ▟███████████████████▙ ▜███▙    ▟██▙        │  󰏖 pkgs   · 1322 nix • 25 flatpak
           ▄▄▄▄▖           ▜███▙  ▟███▛        ╰─ 󰅐 uptime · 1 h 59 m
          ▟███▛             ▜██▛ ▟███▛         ╭─ 󱂬 wm     · Hyprland 0.57.2
         ▟███▛               ▜▛ ▟███▛          │  󰞍 term   · kitty
▟███████████▛                  ▟██████████▙    ╰─ 󰞷 shell  · zsh 5.9.2
▜██████████▛                  ▟███████████▛    ╭─ 󰍛 cpu    · 12th Gen Intel(R) Core(TM) i7-1260P @ 4.70 GHz [50°C]
      ▟███▛ ▟▙               ▟███▛             │  󰢮 gpu    · GeForce MX550
     ▟███▛ ▟██▙             ▟███▛              │  󰢮 gpu    · Alder Lake-P Integrated Graphics Controller
    ▟███▛  ▜███▙           ▝▀▀▀▀               │  󰘚 mem    · 7.4 GiB / 15.3 GiB  ━━━━━───── 48%
    ▜██▛    ▜███▙ ▜██████████████████▛         │  󰋊 disk   · 57.0 GiB / 459.1 GiB  ━───────── 12%
     ▜▛     ▟████▙ ▜████████████████▛          ╰─ 󰂄 bat    · 35%  ━━━━────── [Discharging]
           ▟██████▙         ▜███▙
          ▟███▛▜███▙         ▜███▙                           ● ● ● ● ● ● ● ●
         ▟███▛  ▜███▙         ▜███▙
         ▝▀▀▀    ▀▀▀▀▘         ▀▀▀▘
```

the eight ANSI swatches at the bottom show whether kitty absorbed the current wallpaper palette or remained stranded on the prior session.
