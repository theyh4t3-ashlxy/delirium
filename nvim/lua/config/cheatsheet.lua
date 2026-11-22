-- Ashley's IJKL cheatsheet
-- Put this file in ~/.config/nvim/lua/ and load it with require("cheatsheet").
-- Open it with :Help, :Cheatsheet, or <leader>?. Built-in :help stays unchanged.
local M = {}

local lines = {}
local highlights = {}
local win

local function add(text, group, start_col, end_col)
    lines[#lines + 1] = text
    if group then
        highlights[#highlights + 1] = { #lines - 1, group, start_col or 0, end_col or -1 }
    end
end

local function heading(text)
    add("")
    add("  " .. text, "Title")
end

local function item(keys, description)
    local prefix = string.format("  %-19s", keys)
    add(prefix .. description)
    highlights[#highlights + 1] = { #lines - 1, "Identifier", 2, #keys + 2 }
end

add("  ASHLEY'S NEOVIM CHEATSHEET", "Title")
add("  A little help for the keys you keep forgetting.", "Comment")
add("")
add("  i / k or arrows  scroll    Ctrl-u / Ctrl-d  page", "Comment")
add("  q or Esc         close     :help             Neovim docs", "Comment")
heading("START HERE")
item(":Help", "Open this guide again (also :Cheatsheet)")
item("<leader>?", "Toggle this guide, if the shortcut is available")
add("  Custom shortcuts below need to be set up in your config.", "Comment")
heading("GET AROUND  /  IJKL")
item("i / k", "Move up / down")
item("j / l", "Move left / right")
item("I / K", "Jump 5 lines up / down")
item("J / L", "Jump to start / end of line")
heading("START TYPING")
item("h / H", "Insert before cursor / at start of line")
item("a / A", "Append after cursor / at end of line")
item("o / O", "Open a new line below / above")
item("Esc", "Back to normal mode")
heading("EDIT THE TEXT")
item("d{motion}", "Delete or cut, e.g. dw deletes a word")
item("c{motion}", "Change text and start inserting, e.g. cw")
item("y{motion} / yy", "Yank (copy) a motion / the current line")
item("p / P", "Paste after / before")
item("u / Ctrl-r", "Undo / redo")
heading("TEXT OBJECTS")
item("ciw", "Change inside a word")
item('di"', "Delete inside quotes")
item("yi(", "Yank inside parentheses")
item("da{", "Delete around braces, including the braces")
heading("SPLITS & WINDOWS")
item("<leader>sv / sh", "Split vertically / horizontally")
item("<leader>sx", "Close the current split")
item("Alt-i / Alt-k", "Move to the window above / below")
item("Alt-j / Alt-l", "Move to the window left / right")
heading("SIDEBAR & EXTRAS")
item("<leader>e", "Toggle the Neo-tree sidebar")
item("Neo-tree i / k", "Move up / down in the sidebar")
item("Neo-tree j / l", "Collapse / open in the sidebar")
item("<leader>j", "Join the current line with the next")
item("<leader>mr / mp", "Toggle Markdown render / browser preview")
item("<leader>rt", "Toggle roast mode")
add("")
add("  That's it. Press q or Esc to get back to work.", "Comment")

local function dimensions()
    if vim.o.columns < 12 or vim.o.lines < 6 then
        return nil
    end
    local width = math.min(76, vim.o.columns - 4)
    local height = math.min(#lines, vim.o.lines - 5)
    return {
        relative = "editor",
        width = width,
        height = height,
        row = math.max(0, math.floor((vim.o.lines - height - 2) / 2)),
        col = math.max(0, math.floor((vim.o.columns - width - 2) / 2)),
        style = "minimal",
        border = "rounded",
        title = " IJKL GUIDE ",
        title_pos = "center",
    }
end

function M.close()
    if win and vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
    end
    win = nil
end

function M.open()
    if win and vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_set_current_win(win)
        return
    end

    local config = dimensions()
    if not config then
        vim.notify("The terminal is too small to open the cheatsheet.", vim.log.levels.WARN, { title = "IJKL guide" })
        return
    end

    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].filetype = "cheatsheet"
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    for _, highlight in ipairs(highlights) do
        vim.api.nvim_buf_add_highlight(buf, -1, highlight[2], highlight[1], highlight[3], highlight[4])
    end
    vim.bo[buf].modifiable = false

    win = vim.api.nvim_open_win(buf, true, config)
    vim.wo[win].wrap = true
    vim.wo[win].linebreak = true
    vim.wo[win].scrolloff = 0

    local opts = { buffer = buf, nowait = true, silent = true }
    vim.keymap.set("n", "q", M.close, opts)
    vim.keymap.set("n", "<Esc>", M.close, opts)
    -- These are buffer-local, so the guide works with IJKL and even if
    -- arrow keys are blocked by the roast module. They don't alter your editor mappings.
    vim.keymap.set("n", "i", "k", opts)
    vim.keymap.set("n", "k", "j", opts)
    vim.keymap.set("n", "<Up>", "k", opts)
    vim.keymap.set("n", "<Down>", "j", opts)
    vim.keymap.set("n", "<C-u>", "<C-u>", opts)
    vim.keymap.set("n", "<C-d>", "<C-d>", opts)
end

function M.toggle()
    if win and vim.api.nvim_win_is_valid(win) then
        M.close()
    else
        M.open()
    end
end

vim.api.nvim_create_user_command("Help", M.open, { desc = "Open the IJKL cheatsheet" })
vim.api.nvim_create_user_command("Cheatsheet", M.open, { desc = "Open the IJKL cheatsheet" })

-- Don't take over an existing shortcut. Set mapleader before loading this file.
if vim.fn.maparg("<leader>?", "n") == "" then
    vim.keymap.set("n", "<leader>?", M.toggle, { desc = "Toggle the IJKL cheatsheet", silent = true })
end

local group = vim.api.nvim_create_augroup("IJKLCheatsheet", { clear = true })
vim.api.nvim_create_autocmd("VimResized", {
    group = group,
    callback = function()
        if not win or not vim.api.nvim_win_is_valid(win) then
            return
        end
        local config = dimensions()
        if config then
            vim.api.nvim_win_set_config(win, config)
        else
            M.close()
        end
    end,
})

return M
