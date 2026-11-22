-- A small fallback for configurations that do not already provide a statusline.
local M = {}
local expression = "%!v:lua.require'config.statusline'.render()"

local modes = {
  n = "NORMAL", no = "OPERATOR", nov = "OPERATOR", noV = "OPERATOR", ["no\22"] = "OPERATOR",
  niI = "NORMAL", niR = "NORMAL", niV = "NORMAL", nt = "NORMAL",
  i = "INSERT", ic = "INSERT", ix = "INSERT",
  R = "REPLACE", Rc = "REPLACE", Rx = "REPLACE", Rv = "V-REPLACE",
  v = "VISUAL", V = "V-LINE", ["\22"] = "V-BLOCK",
  s = "SELECT", S = "S-LINE", ["\19"] = "S-BLOCK",
  c = "COMMAND", cv = "EX", ce = "EX", r = "PROMPT", rm = "MORE",
  ["r?"] = "CONFIRM", ["!"] = "SHELL", t = "TERMINAL",
}

-- Dynamic text must not be allowed to introduce statusline items or controls.
local function text(value)
  return vim.fn.strtrans(value):gsub("%%", "%%%%")
end

local function width(value)
  return vim.fn.strdisplaywidth(value)
end

local function lualine_loaded()
  if package.loaded.lualine then
    return true
  end
  -- Do not load lazy or lualine just to check; lazy records loaded plugins here.
  local config = package.loaded["lazy.core.config"]
  local plugins = type(config) == "table" and config.plugins or nil
  local plugin = type(plugins) == "table" and plugins["lualine.nvim"] or nil
  return type(plugin) == "table" and type(plugin._) == "table" and not not plugin._.loaded
end

function M.render()
  local win = tonumber(vim.g.statusline_winid)
  if not win or not vim.api.nvim_win_is_valid(win) then
    win = vim.api.nvim_get_current_win()
  end
  local buf = vim.api.nvim_win_get_buf(win)
  local columns = vim.o.laststatus == 3 and vim.o.columns or vim.api.nvim_win_get_width(win)
  local mode = modes[vim.api.nvim_get_mode().mode] or "NORMAL"
  local name = vim.api.nvim_buf_get_name(buf)
  local buftype = vim.bo[buf].buftype
  if buftype == "quickfix" then
    name = "[Quickfix]"
  elseif name == "" then
    name = "[No Name]"
  elseif buftype ~= "terminal" then
    name = vim.fn.fnamemodify(name, ":~:.")
  end
  name = vim.fn.strtrans(name)

  local flags = (vim.bo[buf].modified and " [+]" or "")
    .. (vim.bo[buf].readonly and " [RO]" or "")
  local left = "%#AshleyStatusMode# " .. mode .. " %#AshleyStatusFile#%< "
    .. name:gsub("%%", "%%%%") .. flags .. " "
  local right = {}
  -- Reserve space for a recognizable filename; %< handles longer names.
  local remaining = columns - width(mode) - math.min(width(name) + width(flags), 12) - 6
  local function add(value, highlight, cost)
    cost = cost or width(value)
    if remaining >= cost + 1 then
      right[#right + 1] = "%#" .. highlight .. "#" .. value .. " "
      remaining = remaining - cost - 1
      return true
    end
    return false
  end

  -- Native statusline items use the window being drawn, rather than the current buffer.
  if add("%l:%c", "AshleyStatusNormal", 12) then
    if add("%p%%", "AshleyStatusMuted", 4) then
      right[1], right[2] = right[2], right[1]
    end
  end
  local filetype = vim.bo[buf].filetype
  if filetype ~= "" then
    local safe = vim.fn.strtrans(filetype)
    add(text(filetype), "AshleyStatusMuted", width(safe))
  end

  if remaining >= 4 then
    local counts = vim.diagnostic.count(buf)
    local severity = vim.diagnostic.severity
    for _, item in ipairs({
      { severity.ERROR, "E", "AshleyStatusError" },
      { severity.WARN, "W", "AshleyStatusWarn" },
      { severity.INFO, "I", "AshleyStatusInfo" },
      { severity.HINT, "H", "AshleyStatusMuted" },
    }) do
      local count = counts[item[1]] or 0
      if count > 0 then
        add(item[2] .. count, item[3])
      end
    end
  end

  local branch = vim.b[buf].gitsigns_head
  if type(branch) == "string" and branch ~= "" then
    local safe = vim.fn.strtrans(branch)
    add("git:" .. text(branch), "AshleyStatusAccent", 4 + width(safe))
  end

  -- Items were selected in priority order, but read more naturally in reverse.
  local ordered = {}
  for i = #right, 1, -1 do
    ordered[#ordered + 1] = right[i]
  end
  return left .. "%=" .. table.concat(ordered) .. "%#AshleyStatusNormal#"
end

function M.setup()
  if lualine_loaded() then
    return
  end
  vim.o.laststatus = 3
  vim.go.statusline = expression

  -- Mode changes do not always cause a statusline redraw on their own.
  local group = vim.api.nvim_create_augroup("AshleyFallbackStatusline", { clear = true })
  vim.api.nvim_create_autocmd("ModeChanged", {
    group = group,
    callback = function()
      if vim.go.statusline ~= expression then
        return true -- A later statusline provider owns it now.
      end
      vim.cmd.redrawstatus()
    end,
  })
end

return M
