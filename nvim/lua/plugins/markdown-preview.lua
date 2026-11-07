return {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    ft = { "markdown" },
    build = function()
        vim.fn["mkdp#util#install"]()
        local bin = vim.fn.stdpath("data") .. "/lazy/markdown-preview.nvim/app/bin/markdown-preview-linux"
        if vim.uv.fs_stat(bin) then
            vim.uv.fs_unlink(bin)
        end
        vim.fn.system("cd " .. vim.fn.stdpath("data") .. "/lazy/markdown-preview.nvim/app && npm install")
    end,
    init = function()
        vim.g.mkdp_filetypes = { "markdown" }
    end,
    keys = {
        { "<leader>mp", "<cmd>MarkdownPreviewToggle<CR>", desc = "markdown preview in browser", ft = "markdown" },
    },
    config = function()
        vim.g.mkdp_auto_close = 1
        vim.g.mkdp_theme = "dark"
    end,
}
