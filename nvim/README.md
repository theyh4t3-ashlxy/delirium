# nvim

lua-configured neovim running on `lazy.nvim`. leave with `:qa!` or pull AC power from the wall.

treesitter AST highlighting, LSP diagnostics, completion, and dynamically compiled `matugen` material tokens inject current wallpaper colors directly into syntax groups so the editor looks calm while you rewrite broken QML anchors at 03:30.

## navigation baseline

if muscle memory locks up, `:Help` or `:Cheatsheet` opens a floating reference modal scrolled via `i`/`k` or `Ctrl-u`/`Ctrl-d` and dismissed with `q` or `Esc`. `<leader>?` toggles the same window. native documentation remains intact at `:help`.

## the `ijkl` remap & `roast.lua`

maintaining `hjkl` exclusively because a 1976 ADM-3A terminal painted four arrows onto incompatible keys is anatomical inertia. modal movement here sits on an inverted T around home row:

- `i` = up
- `k` = down
- `j` = left
- `l` = right
- `I` / `K` = jump 5 lines up / down
- `J` / `L` = start / end of line

`h` and `a` inherit insert entry vacated by `i` (`h` inserts before cursor, `H` inserts at start of line).

### `roast.lua`: behavioral correction on arrow keys

reaching across the keyboard for the physical arrow cluster indicates unaddressed conditioning. `roast.lua` intercepts arrow keypresses and fires desktop warning notifications shaming the relapse until your fingers stop straying off home row.

toggle notifications off with `:RoastToggle` or `<leader>rt` if the nagging starts interfering with debugging.

## reference bindings

| keys | action |
|---|---|
| `:Help` / `:Cheatsheet` | open `ijkl` reference modal |
| `<leader>?` | toggle reference modal |
| `:RoastToggle` / `<leader>rt` | toggle arrow-key warning notifications |
| `<leader>e` | toggle `neo-tree` sidebar |
| `<leader>sv` / `<leader>sh` | vertical / horizontal split |
| `<leader>sx` | close active split |
| `Alt-i/k/j/l` | switch split focus |
| `<leader>mr` | toggle inline markdown rendering |
| `<leader>mp` | open browser markdown preview |
| `<leader>j` | join current line with next |

## file tree

- `init.lua`: bootstraps `lazy.nvim` when missing and mounts `lua/config/` and `lua/plugins/`.
- `lazy-lock.json`: pins exact plugin commits so upstream regressions cannot silently destroy half your bindings between boots.
- `lua/config/`:
  - `keybinds.lua`: `ijkl` movement, split control, buffer traversal, write shortcuts.
  - `options.lua`: relative line numbers, 4-space tab width, persistent undo history surviving restarts.
  - `lsp-keymaps.lua`: diagnostics, definitions, hover inspection, symbol renames.
  - `roast.lua`: arrow-key trap and notify spam.
  - `cheatsheet.lua`: modal overlay.
  - `statusline.lua`: minimal fallback bar.
  - `theme.lua` & `colors.lua`: material token parser; re-syncs syntax groups to wallpaper state.
  - `lazy.lua`: plugin loader spec.
- `lua/plugins/`: `lsp/lsp.lua`, `nvim-cmp.lua`, `treesitter.lua`, `telescope.lua`, `neotree.lua`, `render-markdown.lua`, `markdown-preview.lua`, `which-key.lua`, `gitsigns.lua`, `autopairs.lua`, `color.lua`.
