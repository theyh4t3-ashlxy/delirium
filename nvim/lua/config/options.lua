-- so neovim feels like a proper modern editor
local opt = vim.opt

-- line numbers
opt.number = true
opt.relativenumber = true
opt.cursorline = true

-- tabs and indentation
opt.shiftwidth = 4
opt.tabstop = 4
opt.expandtab = true
opt.smartindent = true

-- window splits open naturally
opt.splitbelow = true
opt.splitright = true

-- no annoying swap files (persistent undo handles recovery)
opt.swapfile = false
opt.undofile = true

-- search settings
opt.ignorecase = true
opt.smartcase = true
opt.inccommand = "split"

-- display & navigation
opt.wrap = false
opt.smoothscroll = true
opt.scrolloff = 8
opt.signcolumn = "yes"
opt.termguicolors = true

-- sync clipboard with wayland (wl-copy / wl-paste)
opt.clipboard = "unnamedplus"

-- snappy response times
opt.updatetime = 50
opt.timeoutlen = 300

-- mouse support
opt.mouse = "a"
