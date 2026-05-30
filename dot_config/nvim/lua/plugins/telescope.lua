return {
    {
        "nvim-telescope/telescope.nvim",
        branch = "0.1.x",
        dependencies = {
            "nvim-lua/plenary.nvim",
            { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
        },
        config = function()
            local t = require("telescope")
            t.setup({
                defaults = { layout_strategy = "horizontal", layout_config = { prompt_position = "top" }, sorting_strategy = "ascending" },
            })
            pcall(t.load_extension, "fzf")
            local b = require("telescope.builtin")
            vim.keymap.set("n", "<leader>ff", b.find_files, { desc = "Find files" })
            vim.keymap.set("n", "<leader>fg", b.live_grep, { desc = "Live grep" })
            vim.keymap.set("n", "<leader>fb", b.buffers, { desc = "Buffers" })
            vim.keymap.set("n", "<leader>fh", b.help_tags, { desc = "Help" })
            vim.keymap.set("n", "<leader>fr", b.resume, { desc = "Resume" })
            vim.keymap.set("n", "<leader>/", b.current_buffer_fuzzy_find, { desc = "Search in buffer" })
        end,
    },
}
