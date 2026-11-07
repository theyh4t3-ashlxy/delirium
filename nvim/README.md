# nvim

neovim configured cleanly in lua because vimscript belongs in a museum of ancient curses.

exit with `:qa!` or rip the power supply out of the wall. there is no middle ground.

powered by `lazy.nvim`. instantaneous startup times, zero plugin bloat, intelligent lsp auto-completion, treesitter ast parsing, and dynamically injected material 3 palette tokens from matugen so your syntax highlights match whatever wallpaper is currently glued to your display server.

## the ijkl heresy & the arrow key shame engine
we don't use `hjkl`. `hjkl` was invented on an adm-3a terminal in 1976 because the arrows were painted onto the keys. this is 2026. 

here, modal navigation is remapped to `ijkl`:
- `i` = up
- `k` = down
- `j` = left
- `l` = right

### `roast.lua`: psychological warfare on arrow key users
if you coward out and reach for the arrow cluster in the bottom right corner of your keyboard, `roast.lua` intercepts the keystroke and triggers a high-priority notify warning mocking your tactile incompetence:
> *"reaching for the arrows like a lost vscode tourist. ijkl is literally right there."*  
> *"you spent four hours configuring dotfiles just to navigate like it's windows notepad. tragic."*  
> *"every time you press an arrow key, another bloated electron app gets spawned. stop."*

toggle your suffering on or off with `:RoastToggle`.

## the armory
- `init.lua`: the bootstrap orchestrator. clones `lazy.nvim` if missing and mounts the modular lua spec tree.
- `lazy-lock.json`: deterministic lockfile pinning every plugin commit so upstream breaking changes don't incinerate your workflow mid-session.
- `lua/config/`:
  - `keybinds.lua`: home-row ijkl navigation, split management, buffer hopping, and quick save bindings.
  - `options.lua`: sensible editor defaults, relative line numbers, 4-space indentation, and persistent undofiles.
  - `lsp-keymaps.lua`: code actions, hover diagnostics, definition jumps, and refactor hooks.
  - `roast.lua`: arrow key detection and custom warning toasts.
  - `cheatsheet.lua`: instant in-editor modal cheat sheet.
- `lua/plugins/`:
  - `lsp/lsp.lua`: native language server protocols with diagnostic signs.
  - `nvim-cmp.lua`: asynchronous completion engine with snippet expansion.
  - `treesitter.lua`: syntax highlighting that understands ast nodes instead of relying on broken regex.
  - `telescope.lua`: fuzzy file finder and ripgrep grep engine.
  - `neotree.lua`: clean sidebar filesystem tree.
  - `render-markdown.lua` & `markdown-preview.lua`: live markdown rendering with formatted tables and callout alerts.
  - `which-key.lua`: popup guide reminding you what key combinations exist before you guess.
  - `gitsigns.lua`: inline git blame, diff hunks, and staging.
  - `autopairs.lua`: automatic bracket closure so you don't forget closing parentheses.
