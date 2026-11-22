-- Pure ANSI / Kitty terminal theme for Neovim
-- Dynamically inherits colors from ~/.config/kitty/colors.conf with transparent background
local M = {}

local function load_kitty_colors()
  local colors = {
    bg = "NONE",
    fg = "#e6e0e9",
    cursor = "#d0bcff",
    black = "#141218",
    red = "#ea6962",
    green = "#9ece6a",
    yellow = "#e0af68",
    blue = "#d0bcff",
    magenta = "#ccc2dc",
    cyan = "#efb8c8",
    white = "#e6e0e9",
    bright_black = "#49454f",
    bright_red = "#ff6b6b",
    bright_green = "#b9f27c",
    bright_yellow = "#ff9e3b",
    bright_blue = "#d0bcff",
    bright_magenta = "#ccc2dc",
    bright_cyan = "#efb8c8",
    bright_white = "#ffffff",
  }

  local path = vim.fn.expand("~/.config/kitty/colors.conf")
  local f = io.open(path, "r")
  if f then
    for line in f:lines() do
      local k, v = line:match("^([%w_]+)%s+(#[%x]+)")
      if k and v then
        if k == "foreground" then colors.fg = v
        elseif k == "cursor" then colors.cursor = v
        elseif k == "color0" then colors.black = v
        elseif k == "color1" then colors.red = v
        elseif k == "color2" then colors.green = v
        elseif k == "color3" then colors.yellow = v
        elseif k == "color4" then colors.blue = v
        elseif k == "color5" then colors.magenta = v
        elseif k == "color6" then colors.cyan = v
        elseif k == "color7" then colors.white = v
        elseif k == "color8" then colors.bright_black = v
        elseif k == "color9" then colors.bright_red = v
        elseif k == "color10" then colors.bright_green = v
        elseif k == "color11" then colors.bright_yellow = v
        elseif k == "color12" then colors.bright_blue = v
        elseif k == "color13" then colors.bright_magenta = v
        elseif k == "color14" then colors.bright_cyan = v
        elseif k == "color15" then colors.bright_white = v
        end
      end
    end
    f:close()
  end
  return colors
end

local function apply(c)
  local function hl(name, attrs)
    vim.api.nvim_set_hl(0, name, attrs)
  end
  local function link(name, target)
    hl(name, { link = target })
  end

  -- Window & canvas (transparent)
  hl("Normal", { fg = c.fg, bg = "NONE" })
  hl("NormalNC", { fg = c.fg, bg = "NONE" })
  hl("NormalFloat", { fg = c.fg, bg = "NONE" })
  hl("FloatBorder", { fg = c.bright_black, bg = "NONE" })
  hl("FloatTitle", { fg = c.blue, bg = "NONE", bold = true })
  hl("SignColumn", { bg = "NONE" })
  hl("EndOfBuffer", { fg = c.bright_black, bg = "NONE" })
  hl("LineNr", { fg = c.bright_black, bg = "NONE" })
  hl("CursorLineNr", { fg = c.blue, bg = "NONE", bold = true })
  hl("CursorLine", { bg = "NONE" })
  hl("ColorColumn", { bg = "NONE" })
  hl("VertSplit", { fg = c.bright_black, bg = "NONE" })
  hl("WinSeparator", { fg = c.bright_black, bg = "NONE" })
  hl("Folded", { fg = c.bright_black, bg = "NONE" })
  hl("FoldColumn", { fg = c.bright_black, bg = "NONE" })

  -- Selections & popup menus
  hl("Pmenu", { fg = c.fg, bg = "NONE" })
  hl("PmenuSel", { fg = c.black, bg = c.blue, bold = true })
  hl("PmenuSbar", { bg = "NONE" })
  hl("PmenuThumb", { bg = c.bright_black })
  hl("Visual", { fg = c.black, bg = c.blue })
  hl("Search", { fg = c.black, bg = c.yellow })
  hl("IncSearch", { fg = c.black, bg = c.cyan })
  hl("Directory", { fg = c.blue, bold = true })
  hl("Title", { fg = c.blue, bold = true })
  hl("MatchParen", { fg = c.cyan, bold = true, underline = true })

  -- Syntax highlighting (Treesitter & standard)
  hl("Comment", { fg = c.bright_black, italic = true })
  hl("Constant", { fg = c.cyan })
  hl("String", { fg = c.green })
  hl("Character", { fg = c.green })
  hl("Number", { fg = c.cyan })
  link("Boolean", "Number")
  link("Float", "Number")
  hl("Identifier", { fg = c.fg })
  hl("Function", { fg = c.blue, bold = true })
  hl("Statement", { fg = c.magenta })
  link("Conditional", "Statement")
  link("Repeat", "Statement")
  link("Keyword", "Statement")
  link("Exception", "Statement")
  hl("Operator", { fg = c.cyan })
  hl("PreProc", { fg = c.cyan })
  hl("Type", { fg = c.yellow })
  link("StorageClass", "Type")
  link("Structure", "Type")
  hl("Special", { fg = c.cyan })
  hl("Delimiter", { fg = c.fg })
  hl("Underlined", { fg = c.blue, underline = true })
  hl("Error", { fg = c.red, bold = true })
  hl("Todo", { fg = c.black, bg = c.yellow, bold = true })

  -- Treesitter links
  local ts_links = {
    ["@comment"] = "Comment", ["@constant"] = "Constant", ["@constant.builtin"] = "Constant",
    ["@string"] = "String", ["@character"] = "Character", ["@number"] = "Number",
    ["@boolean"] = "Boolean", ["@function"] = "Function", ["@function.call"] = "Function",
    ["@method"] = "Function", ["@constructor"] = "Type", ["@variable"] = "Identifier",
    ["@variable.builtin"] = "Special", ["@property"] = "Identifier", ["@keyword"] = "Keyword",
    ["@operator"] = "Operator", ["@punctuation"] = "Delimiter", ["@type"] = "Type",
    ["@attribute"] = "PreProc", ["@tag"] = "Statement", ["@tag.attribute"] = "Type",
    ["@markup.heading"] = "Title", ["@markup.link"] = "Underlined",
  }
  for name, target in pairs(ts_links) do link(name, target) end

  -- Diagnostics
  hl("DiagnosticError", { fg = c.red })
  hl("DiagnosticWarn", { fg = c.yellow })
  hl("DiagnosticInfo", { fg = c.blue })
  hl("DiagnosticHint", { fg = c.cyan })
  hl("DiagnosticUnderlineError", { undercurl = true, sp = c.red })
  hl("DiagnosticUnderlineWarn", { undercurl = true, sp = c.yellow })
  hl("DiagnosticUnderlineInfo", { undercurl = true, sp = c.blue })
  hl("DiagnosticUnderlineHint", { undercurl = true, sp = c.cyan })

  -- Git signs
  hl("GitSignsAdd", { fg = c.green })
  hl("GitSignsChange", { fg = c.blue })
  hl("GitSignsDelete", { fg = c.red })

  -- Plugin styles (Telescope, WhichKey, NeoTree)
  hl("TelescopeNormal", { fg = c.fg, bg = "NONE" })
  hl("TelescopeBorder", { fg = c.bright_black, bg = "NONE" })
  hl("TelescopeTitle", { fg = c.blue, bg = "NONE", bold = true })
  hl("TelescopePromptNormal", { fg = c.fg, bg = "NONE" })
  hl("TelescopePromptBorder", { fg = c.blue, bg = "NONE" })
  hl("TelescopePromptTitle", { fg = c.blue, bg = "NONE", bold = true })
  hl("TelescopeSelection", { fg = c.black, bg = c.blue, bold = true })
  hl("TelescopeMatching", { fg = c.yellow, bold = true })

  hl("WhichKey", { fg = c.blue, bold = true })
  hl("WhichKeyGroup", { fg = c.cyan })
  hl("WhichKeyDesc", { fg = c.fg })
  hl("WhichKeySeparator", { fg = c.bright_black })
  hl("WhichKeyFloat", { bg = "NONE" })
  hl("WhichKeyBorder", { fg = c.bright_black, bg = "NONE" })

  hl("NeoTreeNormal", { fg = c.fg, bg = "NONE" })
  hl("NeoTreeNormalNC", { fg = c.fg, bg = "NONE" })
  hl("NeoTreeWinSeparator", { fg = c.bright_black, bg = "NONE" })
  hl("NeoTreeDirectoryName", { fg = c.blue, bold = true })
  hl("NeoTreeDirectoryIcon", { fg = c.blue })
  hl("NeoTreeRootName", { fg = c.cyan, bold = true })
  hl("NeoTreeFileName", { fg = c.fg })

  -- Statusline highlights
  hl("AshleyStatusMode", { fg = c.black, bg = c.blue, bold = true })
  hl("AshleyStatusFile", { fg = c.fg, bg = "NONE", bold = true })
  hl("AshleyStatusMuted", { fg = c.bright_black, bg = "NONE" })
  hl("AshleyStatusNormal", { fg = c.fg, bg = "NONE" })
  hl("AshleyStatusAccent", { fg = c.blue, bg = "NONE", bold = true })
  hl("AshleyStatusError", { fg = c.red, bg = "NONE", bold = true })
  hl("AshleyStatusWarn", { fg = c.yellow, bg = "NONE", bold = true })
  hl("AshleyStatusInfo", { fg = c.blue, bg = "NONE", bold = true })
end

function M.reload()
  apply(load_kitty_colors())
end

function M.setup()
  vim.opt.termguicolors = true
  M.reload()
  vim.api.nvim_create_user_command("ThemeReload", M.reload, { force = true, desc = "Reload Kitty ANSI theme" })
  vim.api.nvim_create_autocmd("FocusGained", {
    callback = function() M.reload() end,
    desc = "Auto-sync theme with Kitty palette",
  })
end

return M
