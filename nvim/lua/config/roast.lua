-- A little encouragement to stop reaching for the arrow keys.
-- IJKL: up, left, down, right.
local M = {}

M.enabled = true
M.cooldown_ms = 2500
M.last_roast = nil

local roasts = {
    "reaching for the arrows like a lost vscode tourist. ijkl is literally right there.",
    "you customized a whole modal editor just to navigate like it's windows notepad. tragic.",
    "muscle memory failed. hand drifted six inches to the right into pure digital shame.",
    "cold terminal, stale coffee, and you're still pressing arrow keys. bram moolenaar is sighing.",
    "arrow keys detected. your home row is weeping. use i (up), j (left), k (down), l (right).",
    "you spent hours configuring dotfiles just to use arrow keys. let that sink in.",
    "the arrow cluster called. it said you need to spend some time with ijkl.",
    "what are you doing over there on the arrow keys. there is nothing for you there. go back.",
    "the grim reality of modal editing is that your hands shouldn't leave the home row. use ijkl.",
    "four arrow keys won't save your codebase. ijkl will at least save your dignity.",
    "arrow key reflex detected. tactile shame initiated. use ijkl.",
    "why did we remap your entire editor to ijkl if you're gonna crawl back to the arrows like that.",
    "every time you press an arrow key, another bloated electron app gets spawned. stop.",
    "that physical reach to the bottom right corner of your keyboard just took two years off my lifespan.",
    "arrow keys. genuinely embarrassing. hands back on ijkl.",
    "congratulations, you defeated the entire purpose of a modal text editor in one keystroke.",
    "your fingers just went on a field trip without permission. bring them back to ijkl.",
    "the arrow keys are not a safety blanket. put them down gently and return to ijkl.",
    "you have a carefully curated editor and the navigation habits of a remote control.",
    "ijkl is right there. we talked about this. the keyboard is getting concerned.",
    "that wasn't navigation. that was a cry for help from your muscle memory.",
    "the arrow cluster is your ex. stop texting it.",
    "your home row filed a missing fingers report.",
    "ah yes, the scenic route across the keyboard. meanwhile, ijkl is standing right there.",
    "imagine configuring modal navigation and then immediately choosing the tiny direction buttons.",
    "you can leave the arrows alone. they're not going anywhere. unlike your hand, apparently.",
    "i for up, j for left, k for down, l for right. your hand has a map now. use it.",
    "this is an intervention. the arrow keys are enabling your bad habits.",
    "your keyboard just watched you reach for the arrows and quietly lost respect for you.",
    "the arrows are a decoy. the real treasure was ijkl all along.",
    "did you just cross the entire keyboard for one line. in this economy.",
    "new achievement unlocked: went all that way to avoid pressing k.",
    "your hand drifted off home row like it had somewhere better to be.",
    "be honest. was that arrow key worth the journey.",
    "ijkl is not a suggestion. okay it is, but it's a really good one.",
    "the cursor moved. your training arc did not.",
    "your dotfiles deserve better than this. your dotfiles know what you did.",
    "not the arrows again. we were doing so well for at least four seconds.",
    "your hand just took the long way home. ijkl is right there on the map.",
    "arrow key detected. deploying one disappointed but supportive notification.",
    "you don't need four little arrows when you have four perfectly good letters.",
    "the distance between you and greatness is apparently one arrow cluster.",
    "your fingers know ijkl. they're just being dramatic about it.",
    "step away from the arrow keys. nobody has to get hurt. especially the home row.",
    "your editor has modes. your fingers have one: panic and reach right.",
    "the arrows are for maps, not your character development.",
    "somewhere in your config, an ijkl mapping is feeling very underappreciated.",
    "you made navigation ergonomic and then chose the side quest instead.",
    "a wild arrow key appeared. unfortunately, you used it.",
    "the home row misses you. it made your favorite keymaps and everything.",
    "i up, j left, k down, l right. four letters. one less expedition.",
    "your fingers are running legacy navigation software. please update to ijkl.",
    "the arrow keys would like to thank you for your continued patronage. please stop.",
    "muscle memory is a work in progress. unfortunately, so is your dignity.",
    "this is your daily reminder that ijkl did not install itself for decoration.",
    "your cursor has places to be. your hand does not need a sightseeing tour.",
    "one arrow press closer to becoming the exact user your config warned you about.",
    "you know what's closer than the arrow keys? inner peace. also ijkl.",
    "your keyboard layout has sent a strongly worded letter about that reach.",
    "if the arrow cluster is so great, why did you spend all night configuring ijkl.",
    "you can do this. i believe in you. the arrow keys don't, but i do.",
    "every ijkl journey starts with a single keypress. preferably not that one.",
    "we don't shame the mistake. we just notify it loudly with a custom title.",
    "take a breath. find ijkl. pretend that arrow key never happened.",
}

local last_index = nil
local uv = vim.uv or vim.loop

function M.roast()
    if not M.enabled then
        return
    end

    local now = uv.now()
    if M.last_roast and now - M.last_roast < M.cooldown_ms then
        return
    end
    M.last_roast = now

    -- Draw from every message except the previous one, without retrying.
    local index
    if last_index and #roasts > 1 then
        index = math.random(1, #roasts - 1)
        if index >= last_index then
            index = index + 1
        end
    else
        index = math.random(1, #roasts)
    end
    last_index = index

    vim.notify(roasts[index], vim.log.levels.WARN, { title = "grim reality" })
end

function M.toggle()
    M.enabled = not M.enabled
    local state = M.enabled and "enabled. suffer." or "disabled. coward."
    vim.notify("roast mode is now " .. state, vim.log.levels.INFO, { title = "grim reality" })
end

vim.api.nvim_create_user_command("RoastToggle", M.toggle, { desc = "Toggle arrow key roasting" })

-- Intercept the arrow keys in normal, visual, and insert modes.
local modes = { "n", "v", "i" }
local arrows = { "<Up>", "<Down>", "<Left>", "<Right>" }

for _, mode in ipairs(modes) do
    for _, arrow in ipairs(arrows) do
        vim.keymap.set(mode, arrow, M.roast, { desc = "arrow key roast reminder", silent = true })
    end
end

return M
