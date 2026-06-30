return {
    {
        "nvim-treesitter/nvim-treesitter",
        branch = "main",
        build = ":TSUpdate",
        config = function()
            require("nvim-treesitter").install({
                "lua", "vim", "vimdoc", "bash", "go", "rust", "python",
                "javascript", "typescript", "tsx", "json", "yaml", "toml",
                "html", "css", "markdown", "markdown_inline", "dockerfile",
                "hcl", "terraform", "regex", "gitcommit", "git_rebase",
            })
            -- main-branch API: highlighting and indent are enabled per-buffer.
            -- vim.treesitter.start() infers the language from the filetype;
            -- pcall makes filetypes without a parser a silent no-op.
            vim.api.nvim_create_autocmd("FileType", {
                callback = function(args)
                    if pcall(vim.treesitter.start, args.buf) then
                        vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
                        -- syntax-aware folds (window-local), start unfolded
                        local win = vim.api.nvim_get_current_win()
                        vim.wo[win][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
                        vim.wo[win][0].foldmethod = "expr"
                        vim.wo[win][0].foldlevel = 99
                    end
                end,
            })
        end,
    },
}
