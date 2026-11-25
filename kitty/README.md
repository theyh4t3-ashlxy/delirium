# kitty

opengl-accelerated terminal emulator used to maintain a hostile nixos flake and stare at tracebacks until dawn.

spawning a hidden chromium engine purely to paint monospace text into a box is architectural rot. kitty pushes glyph atlases directly to the GPU so bad commands render and execute with zero visible latency.

## files

- `kitty.conf`: padding, background blur, tab layout, ligatures, keybindings, and font configuration (`jetbrains mono nerd font`).
- `colors.conf`: rewritten without warning by `matugen` on every wallpaper shift.

if existing terminal panes hold onto stale colors from an earlier hour, signal `pkill -USR1 kitty` to force live scrollback buffers to accept the new registers.
