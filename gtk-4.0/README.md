# gtk-4.0

runtime overrides targeting libadwaita's institutional hostility toward configuration.

libadwaita exists because gnome maintainers openly resent users modifying software running on hardware they paid for. every default surface arrives molded in the exact sterile beige-grey of clinic drywall and modular waiting-room trays, enforcing compliance by stripping away standard theming APIs. since upstream left no sanctioned channel, this directory injects stylesheet overrides directly into runtime paths.

## overrides

- `settings.ini`: forces dark mode and icon resolution at the toolkit border.
- `gtk.css` & `gtk-dark.css`: surgical stylesheet overrides stripping libadwaita padding, flat margins, radii, and contrast values without consent.
- `colors.css`: written by `matugen` on every palette cycle so gtk4 surfaces conform whether upstream approves or not.
