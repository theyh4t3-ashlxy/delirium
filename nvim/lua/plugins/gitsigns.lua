return {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
        signs = {
            add = { text = "│" },
            change = { text = "│" },
            delete = { text = "_" },
            topdelete = { text = "‾" },
            changedelete = { text = "~" },
            untracked = { text = "┆" },
        },
    },
    keys = {
        { "<leader>gp", "<cmd>Gitsigns preview_hunk<CR>", desc = "preview git hunk" },
        { "<leader>gb", "<cmd>Gitsigns blame_line<CR>", desc = "blame git line" },
    },
}
