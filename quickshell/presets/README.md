# presets

desktop layout configurations that actually make sense.

no bloated nested json payloads or fragile parsing schemas. everything here maps 1:1 with `settings.conf` using flat `key=value` definitions that quickshell reads, applies, and writes natively.

## built-in presets
- `catalog.conf`: master catalog defining available widget modules, category classifications, names, and glyph icons.
- `default.conf`: balanced bottom bar layout with workspaces, layout indicator, centered clock, quick settings, and battery monitors.
- `minimal.conf`: compact floating top dock tailored for focused coding sessions.
- `island.conf`: dynamic centered notch layout with launcher, reactive island carousel, and sensor pills.

## user presets
custom presets exported via `BarStudio` are written to `~/.local/state/quickshell/presets/<name>.conf` using `write-file.zsh`. zero `sh -c` string interpolation or heredoc hacks.
