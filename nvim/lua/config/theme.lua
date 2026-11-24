-- Pure ANSI ctermfg/ctermbg theme for Neovim
-- Colors live in kitty's color registers (0-15). Matugen updates them on
-- wallpaper change → kitty repaints → nvim inherits without any reload.
--
-- ANSI slot map (matches kitty colors.conf / matugen template):
--   0  = background (surface / black)
--   1  = red (error)
--   2  = green  (strings — fixed calibrated)
--   3  = yellow (types / warnings — fixed calibrated)
--   4  = blue   = primary accent (follows wallpaper via matugen)
--   5  = magenta = secondary (keywords)
--   6  = cyan   = tertiary (constants, operators)
--   7  = white  = foreground (on_surface)
--   8  = bright_black = muted / outline (comments, borders)
--   9  = bright_red
--  10  = bright_green
--  11  = bright_yellow
--  12  = bright_blue
--  13  = bright_magenta
--  14  = bright_cyan
--  15  = bright_white

local M = {}

local function apply()
  local function hl(name, attrs)
    vim.api.nvim_set_hl(0, name, attrs)
  end
  local function link(name, target)
    hl(name, { link = target })
  end

  -- Window & canvas (transparent)
  hl("Normal",       { ctermbg = "NONE", ctermfg = 7 })
  hl("NormalNC",     { ctermbg = "NONE", ctermfg = 7 })
  hl("NormalFloat",  { ctermbg = "NONE", ctermfg = 7 })
  hl("FloatBorder",  { ctermbg = "NONE", ctermfg = 8 })
  hl("FloatTitle",   { ctermbg = "NONE", ctermfg = 4, bold = true })
  hl("SignColumn",   { ctermbg = "NONE" })
  hl("EndOfBuffer",  { ctermbg = "NONE", ctermfg = 8 })
  hl("LineNr",       { ctermbg = "NONE", ctermfg = 8 })
  hl("CursorLineNr", { ctermbg = "NONE", ctermfg = 4, bold = true })
  hl("CursorLine",   { ctermbg = "NONE" })
  hl("ColorColumn",  { ctermbg = "NONE" })
  hl("VertSplit",    { ctermbg = "NONE", ctermfg = 8 })
  hl("WinSeparator", { ctermbg = "NONE", ctermfg = 8 })
  hl("Folded",       { ctermbg = "NONE", ctermfg = 8 })
  hl("FoldColumn",   { ctermbg = "NONE", ctermfg = 8 })

  -- Selections & popup menus
  hl("Pmenu",     { ctermbg = "NONE", ctermfg = 7 })
  hl("PmenuSel",  { ctermbg = 4,      ctermfg = 0, bold = true })
  hl("PmenuSbar", { ctermbg = "NONE" })
  hl("PmenuThumb",{ ctermbg = 8 })
  hl("Visual",    { ctermbg = 4,      ctermfg = 0 })
  hl("Search",    { ctermbg = 3,      ctermfg = 0 })
  hl("IncSearch", { ctermbg = 6,      ctermfg = 0 })
  hl("Directory", { ctermbg = "NONE", ctermfg = 4, bold = true })
  hl("Title",     { ctermbg = "NONE", ctermfg = 4, bold = true })
  hl("MatchParen",{ ctermbg = "NONE", ctermfg = 6, bold = true, underline = true })

  -- Syntax (Treesitter & standard)
  hl("Comment",   { ctermbg = "NONE", ctermfg = 8, italic = true })
  hl("Constant",  { ctermbg = "NONE", ctermfg = 6 })
  hl("String",    { ctermbg = "NONE", ctermfg = 2 })
  hl("Character", { ctermbg = "NONE", ctermfg = 2 })
  hl("Number",    { ctermbg = "NONE", ctermfg = 6 })
  link("Boolean", "Number")
  link("Float",   "Number")
  hl("Identifier",{ ctermbg = "NONE", ctermfg = 7 })
  hl("Function",  { ctermbg = "NONE", ctermfg = 4, bold = true })
  hl("Statement", { ctermbg = "NONE", ctermfg = 5 })
  link("Conditional", "Statement")
  link("Repeat",      "Statement")
  link("Keyword",     "Statement")
  link("Exception",   "Statement")
  hl("Operator",  { ctermbg = "NONE", ctermfg = 6 })
  hl("PreProc",   { ctermbg = "NONE", ctermfg = 6 })
  hl("Type",      { ctermbg = "NONE", ctermfg = 3 })
  link("StorageClass", "Type")
  link("Structure",    "Type")
  hl("Special",   { ctermbg = "NONE", ctermfg = 6 })
  hl("Delimiter", { ctermbg = "NONE", ctermfg = 7 })
  hl("Underlined",{ ctermbg = "NONE", ctermfg = 4, underline = true })
  hl("Error",     { ctermbg = "NONE", ctermfg = 1, bold = true })
  hl("Todo",      { ctermbg = 3,      ctermfg = 0, bold = true })

  -- Treesitter links
  local ts_links = {
    ["@comment"]          = "Comment",    ["@constant"]         = "Constant",
    ["@constant.builtin"] = "Constant",   ["@string"]           = "String",
    ["@character"]        = "Character",  ["@number"]           = "Number",
    ["@boolean"]          = "Boolean",    ["@function"]         = "Function",
    ["@function.call"]    = "Function",   ["@method"]           = "Function",
    ["@constructor"]      = "Type",       ["@variable"]         = "Identifier",
    ["@variable.builtin"] = "Special",    ["@property"]         = "Identifier",
    ["@keyword"]          = "Keyword",    ["@operator"]         = "Operator",
    ["@punctuation"]      = "Delimiter",  ["@type"]             = "Type",
    ["@attribute"]        = "PreProc",    ["@tag"]              = "Statement",
    ["@tag.attribute"]    = "Type",       ["@markup.heading"]   = "Title",
    ["@markup.link"]      = "Underlined",
  }
  for name, target in pairs(ts_links) do link(name, target) end

  -- Diagnostics
  hl("DiagnosticError",          { ctermfg = 1 })
  hl("DiagnosticWarn",           { ctermfg = 3 })
  hl("DiagnosticInfo",           { ctermfg = 4 })
  hl("DiagnosticHint",           { ctermfg = 6 })
  hl("DiagnosticUnderlineError", { undercurl = true })
  hl("DiagnosticUnderlineWarn",  { undercurl = true })
  hl("DiagnosticUnderlineInfo",  { undercurl = true })
  hl("DiagnosticUnderlineHint",  { undercurl = true })

  -- Git signs
  hl("GitSignsAdd",    { ctermfg = 2 })
  hl("GitSignsChange", { ctermfg = 4 })
  hl("GitSignsDelete", { ctermfg = 1 })

  -- Telescope
  hl("TelescopeNormal",       { ctermbg = "NONE", ctermfg = 7 })
  hl("TelescopeBorder",       { ctermbg = "NONE", ctermfg = 8 })
  hl("TelescopeTitle",        { ctermbg = "NONE", ctermfg = 4, bold = true })
  hl("TelescopePromptNormal", { ctermbg = "NONE", ctermfg = 7 })
  hl("TelescopePromptBorder", { ctermbg = "NONE", ctermfg = 4 })
  hl("TelescopePromptTitle",  { ctermbg = "NONE", ctermfg = 4, bold = true })
  hl("TelescopeSelection",    { ctermbg = 4,      ctermfg = 0, bold = true })
  hl("TelescopeMatching",     { ctermbg = "NONE", ctermfg = 3, bold = true })

  -- WhichKey
  hl("WhichKey",          { ctermbg = "NONE", ctermfg = 4, bold = true })
  hl("WhichKeyGroup",     { ctermbg = "NONE", ctermfg = 6 })
  hl("WhichKeyDesc",      { ctermbg = "NONE", ctermfg = 7 })
  hl("WhichKeySeparator", { ctermbg = "NONE", ctermfg = 8 })
  hl("WhichKeyFloat",     { ctermbg = "NONE" })
  hl("WhichKeyBorder",    { ctermbg = "NONE", ctermfg = 8 })

  -- NeoTree
  hl("NeoTreeNormal",        { ctermbg = "NONE", ctermfg = 7 })
  hl("NeoTreeNormalNC",      { ctermbg = "NONE", ctermfg = 7 })
  hl("NeoTreeWinSeparator",  { ctermbg = "NONE", ctermfg = 8 })
  hl("NeoTreeDirectoryName", { ctermbg = "NONE", ctermfg = 4, bold = true })
  hl("NeoTreeDirectoryIcon", { ctermbg = "NONE", ctermfg = 4 })
  hl("NeoTreeRootName",      { ctermbg = "NONE", ctermfg = 6, bold = true })
  hl("NeoTreeFileName",      { ctermbg = "NONE", ctermfg = 7 })

  -- Statusline
  hl("AshleyStatusMode",   { ctermbg = 4,      ctermfg = 0, bold = true })
  hl("AshleyStatusFile",   { ctermbg = "NONE", ctermfg = 7, bold = true })
  hl("AshleyStatusMuted",  { ctermbg = "NONE", ctermfg = 8 })
  hl("AshleyStatusNormal", { ctermbg = "NONE", ctermfg = 7 })
  hl("AshleyStatusAccent", { ctermbg = "NONE", ctermfg = 4, bold = true })
  hl("AshleyStatusError",  { ctermbg = "NONE", ctermfg = 1, bold = true })
  hl("AshleyStatusWarn",   { ctermbg = "NONE", ctermfg = 3, bold = true })
  hl("AshleyStatusInfo",   { ctermbg = "NONE", ctermfg = 4, bold = true })
end

function M.setup()
  -- termguicolors stays OFF — nvim defers to kitty's ANSI registers (0-15)
  -- which matugen updates live on every wallpaper change
  vim.opt.termguicolors = false
  apply()
  -- :ThemeReload kept as a manual escape hatch (e.g. after :set termguicolors)
  vim.api.nvim_create_user_command("ThemeReload", apply, { force = true, desc = "Reapply ANSI theme" })
end

return M
