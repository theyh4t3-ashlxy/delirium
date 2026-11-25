# yazi

asynchronous rust terminal file browser, chosen because scrolling through graphical file managers makes auditing neglected folders feel like pushing cold grease across a cafeteria tray.

directory trees populate in the background without hitching keyboard navigation, source previews highlight inline, archives expose layouts prior to extraction, and images render natively over kitty's graphics protocol so forgotten downloads stay visible without dragging gtk or electron onto screen.

## structure

- `theme.toml`: synced with `matugen` so file tags, selection bars, and preview borders track active wallpaper contrast.
- `keymap.toml`: direct traversal bindings.
- `package.toml`: plugin manifest.
- `plugins/`: extensions including `smart-enter` to descend trees or spawn handlers in a single stroke.
