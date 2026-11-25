# fastfetch

system information. renders in under 3ms.

the config lives in `matugen/templates/fastfetch-colors.jsonc` as a matugen template, which compiles into `config.jsonc` on every wallpaper switch. editing `config.jsonc` directly does nothing because matugen immediately overwrites it. edit the template.

colors are 100% ansi-indexed (`color0`–`color15`) pulled from kitty's palette registers. changing the wallpaper reloads kitty via `pkill -USR1 kitty`, which picks up the new palette without restarting any open terminal windows. no hardcoded hex values anywhere in the config.

disk detection is pinned to `/home` because `/` is a 4gb tmpfs ramdisk that always reads `0 B used`. asking fastfetch to report disk usage on a ramdisk is accurate and useless.

### output

```
          ▗▄▄▄       ▗▄▄▄▄    ▄▄▄▖             ashley@lost  •  /home/ashley/
          ▜███▙       ▜███▙  ▟███▛             ────────────────────────────────────────────
           ▜███▙       ▜███▙▟███▛              ╭─  os     · NixOS 26.11 (Zokor) x86_64
            ▜███▙       ▜██████▛               │  󰌢 host   · ThinkPad T16 Gen 1
     ▟█████████████████▙ ▜████▛     ▟▙         │  󰌽 kernel · Linux 7.3.4
    ▟███████████████████▙ ▜███▙    ▟██▙        │  󰏖 pkgs   · 1322 nix • 25 flatpak
           ▄▄▄▄▖           ▜███▙  ▟███▛        ╰─ 󰅐 uptime · 10 h 15 m
          ▟███▛             ▜██▛ ▟███▛         ╭─ 󱂬 wm     · Hyprland 0.57.2
         ▟███▛               ▜▛ ▟███▛          │  󰞍 term   · kitty
▟███████████▛                  ▟██████████▙    ╰─ 󰞷 shell  · zsh 5.9.0
▜██████████▛                  ▟███████████▛    ╭─ 󰍛 cpu    · 12th Gen Intel(R) Core(TM) i7-1260P @ 4.70 GHz [65°C]
      ▟███▛ ▟▙               ▟███▛             │  󰢮 gpu    · GeForce MX550
     ▟███▛ ▟██▙             ▟███▛              │  󰢮 gpu    · Alder Lake-P Integrated Graphics Controller
    ▟███▛  ▜███▙           ▝▀▀▀▀               │  󰘚 mem    · 10.6 GiB / 15.3 GiB  ━━━━━━━─── 69%
    ▜██▛    ▜███▙ ▜██████████████████▛         │  󰋊 disk   · 57.5 GiB / 459.1 GiB  ━───────── 13%
     ▜▛     ▟████▙ ▜████████████████▛          ╰─ 󰂄 bat    · 79%  ━━━━━━━━── [AC Connected, Charging]
           ▟██████▙         ▜███▙
          ▟███▛▜███▙         ▜███▙                           ● ● ● ● ● ● ● ●
         ▟███▛  ▜███▙         ▜███▙
         ▝▀▀▀    ▀▀▀▀▘         ▀▀▀▘
```

the color circles at the bottom are your current ansi palette rendered live. they update with the wallpaper.
