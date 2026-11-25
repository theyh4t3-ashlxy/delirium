# gnome

declarative `gnome 51` skinning layered onto the `thinkpad t16 gen 1` session so leaving `hyprland` under `sddm` drops into the same wallpaper palette and variable fonts instead of stock adwaita drywall.

no fake tiling window manager replication (`forge` / `paperwm` / `tiling-shell` omitted on purpose). gnome remains a standard mouse-and-overview desktop while `matugen` rewrites `gnome-shell.css`, panel workspace pills, dock dots, rounded corner borders, accent color, and `dconf` wallpaper pointers dynamically on every `wp` run.

## stack

- **shell theme (`matugen/templates/gnome-shell.css`)**: imports `resource:///org/gnome/shell/theme/gnome-shell-{dark,light}.css` cleanly and re-skins `#panel`, `.quick-settings`, `.popup-menu-content`, `.calendar`, `.message`, `.notification-banner`, `.osd-window`, `.search-entry`, `#dash`, and `.unlock-dialog` with compiled material 3 tokens and `Google Sans Flex` / `Segoe UI Variable` typography.
- **extensions (`nixos/configuration.nix`)**: `user-themes`, `blur-my-shell`, `dash-to-dock`, `just-perfection`, `rounded-window-corners-reborn` (`16px` radii with `tweak-kitty-terminal`), `space-bar` workspace pills, `caffeine`, `clipboard-indicator` (`<Super>v`), `appindicator`, `alphabetical-app-grid`, plus `MoreWaita` icons and `Windows-Aero` cursors.
- **live sync (`matugen/post-hook-scripts/gnome-theme-reload.zsh`)**: updates `/org/gnome/desktop/background/picture-uri*`, `screensaver/picture-uri`, closest `accent-color` enum, `space-bar` pill colors, `dash-to-dock` dots, `rounded-window-corners-reborn` `borderColor`, and toggles `user-theme` (`Matugen`).

## apply

```zsh
~/.local/share/dotfiles/gnome/apply.zsh   # load dconf.ini + sync active palette
wp random                                 # recolor shell + wallpaper under gnome or hyprland
```
