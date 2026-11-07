return {
    "nvim-telescope/telescope.nvim",
    version = "*",
    dependencies = {
        "nvim-lua/plenary.nvim",
        { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    },
    config = function()
        local telescope = require("telescope")
        local builtin = require("telescope.builtin")

        telescope.setup({
            defaults = {
                mappings = {
                    i = {
                        ["<C-k>"] = "move_selection_next",
                        ["<C-p>"] = "move_selection_previous",
                    },
                },
            },
        })

        pcall(telescope.load_extension, "fzf")

        vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "telescope find files" })
        vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "telescope live grep" })
        vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "telescope buffers" })
        vim.keymap.set("n", "<leader>fh", builtin.help_tags, { desc = "telescope help tags" })
    end,
}
