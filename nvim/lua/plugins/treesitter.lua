return {
    "nvim-treesitter/nvim-treesitter",
    branch = "master",
    lazy = false,
    build = ":TSUpdate",
    config = function()
        local ok, configs = pcall(require, "nvim-treesitter.configs")
        if not ok then
            return
        end

        local has_compiler = vim.fn.executable("cc") == 1
            or vim.fn.executable("gcc") == 1
            or vim.fn.executable("clang") == 1
            or vim.fn.executable("zig") == 1

        configs.setup({
            highlight = { enable = true },
            indent = { enable = true },
            ensure_installed = has_compiler and {
                "lua",
                "nix",
                "python",
                "bash",
                "markdown",
                "markdown_inline",
                "json",
                "toml",
            } or {},
            auto_install = has_compiler,
        })
    end,
}
