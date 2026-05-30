-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    vim.fn.system({
        "git", "clone", "--filter=blob:none", "--branch=stable",
        "https://github.com/folke/lazy.nvim.git", lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

-- Leader before plugins
vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("options")
require("keymaps")
require("lazy").setup("plugins", {
    install = { colorscheme = { "tokyonight" } },
    change_detection = { notify = false },
})
