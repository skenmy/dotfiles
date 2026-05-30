return {
    { "lewis6991/gitsigns.nvim", opts = {} },
    { "windwp/nvim-autopairs", event = "InsertEnter", opts = {} },
    { "numToStr/Comment.nvim", opts = {} },
    { "kylechui/nvim-surround", event = "VeryLazy", opts = {} },
    {
        "nvim-lualine/lualine.nvim",
        opts = { options = { theme = "tokyonight", section_separators = "", component_separators = "" } },
    },
    {
        "nvim-tree/nvim-tree.lua",
        keys = { { "<leader>e", "<cmd>NvimTreeToggle<CR>", desc = "Explorer" } },
        opts = { renderer = { group_empty = true } },
    },
    {
        "folke/which-key.nvim",
        event = "VeryLazy",
        opts = {},
    },
    {
        "kdheepak/lazygit.nvim",
        keys = { { "<leader>gg", "<cmd>LazyGit<CR>", desc = "LazyGit" } },
    },
}
