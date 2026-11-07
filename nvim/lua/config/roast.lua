-- dynamic roast engine for breaking arrow key habits and learning IJKL
local M = {}

M.enabled = true
M.cooldown_ms = 2500
M.last_roast = 0

local roasts = {
    "reaching for the arrows like a lost vscode tourist. ijkl is literally right there.",
    "you customized a whole modal editor just to navigate like it's windows notepad. tragic.",
    "muscle memory failed. hand drifted six inches to the right into pure digital shame.",
    "cold terminal, stale coffee, and you're still clicking arrow keys. bram moolenaar is sighing.",
    "arrow keys detected. your home row is weeping. use i (up), j (left), k (down), l (right).",
    "you spent hours configuring dotfiles just to use arrow keys. let that sink in.",
    "the arrow cluster is for people who enjoy wrist pain and 500ms latency. get back on ijkl.",
    "what are you doing over there on the arrow keys. there is nothing for you there. go back.",
    "the grim reality of modal editing is that your hands shouldn't leave the home row. use ijkl.",
    "four arrow keys won't save your codebase. ijkl will at least save your dignity.",
    "arrow key reflex detected. tactile shame initiated. use ijkl.",
    "why did we remap your entire editor to ijkl if you're gonna crawl back to the arrows like that.",
    "every time you press an arrow key, another bloated electron app gets spawned. stop.",
    "that physical reach to the bottom right corner of your keyboard just took two years off my lifespan.",
    "arrow keys. genuinely embarrassing. hands back on ijkl.",
    "congratulations, you defeated the entire purpose of a modal text editor in one keystroke.",
}

function M.roast()
    if not M.enabled then return end

    local now = vim.uv.now()
    if now - M.last_roast < M.cooldown_ms then
        return
    end
    M.last_roast = now

    local idx = math.random(1, #roasts)
    local msg = roasts[idx]
    vim.notify(msg, vim.log.levels.WARN, { title = "grim reality" })
end

function M.toggle()
    M.enabled = not M.enabled
    local state = M.enabled and "enabled. suffer." or "disabled. coward."
    vim.notify("roast mode is now " .. state, vim.log.levels.INFO, { title = "grim reality" })
end

-- command and user mapping
vim.api.nvim_create_user_command("RoastToggle", M.toggle, { desc = "Toggle arrow key roasting" })

-- bind arrow keys across normal, visual, and insert modes to trigger roast
local modes = { "n", "v", "i" }
local arrows = { "<Up>", "<Down>", "<Left>", "<Right>" }

for _, mode in ipairs(modes) do
    for _, arrow in ipairs(arrows) do
        vim.keymap.set(mode, arrow, function()
            M.roast()
        end, { desc = "arrow key roast reminder", silent = true })
    end
end

return M
