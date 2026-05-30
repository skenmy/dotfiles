return {
    {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        config = function()
            require("nvim-treesitter.configs").setup({
                ensure_installed = {
                    "lua", "vim", "vimdoc", "bash", "go", "rust", "python",
                    "javascript", "typescript", "tsx", "json", "yaml", "toml",
                    "html", "css", "markdown", "markdown_inline", "dockerfile",
                    "hcl", "terraform", "regex", "gitcommit", "git_rebase",
                },
                highlight = { enable = true },
                indent = { enable = true },
            })
        end,
    },
}
