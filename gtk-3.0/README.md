# gtk-3.0

residual gnome toolkit files maintained solely to stop legacy dialogs from firing white-screen light flashes into an unlit room.

unconfigured gtk3 file pickers open directly into a raw `#ffffff` slab with zero ambient scaling—closer to an unannounced clinical penlight check on dilated eyes after seventy-two hours indoors than a normal os window. css never belonged inside desktop toolkits, yet every file dialog still demands it.

## containment files

- `settings.ini`: locks `gtk-application-prefer-dark-theme`, kills light adwaita fallbacks, and enforces consistent font and cursor metrics.
- `gtk.css`: pulls generated palette tokens and amputates leftover client-side borders.
- `colors.css`: rewritten continuously by `matugen` so legacy tools inherit wallpaper luminance instead of resetting to bone white.
- `bookmarks`: pinned directory anchors preventing prolonged wandering through `/home` while searching for one path.
