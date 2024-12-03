vim.g.base46_cache = vim.fn.stdpath "data" .. "/base46/"
vim.g.mapleader = " "

-- bootstrap lazy and all plugins
local lazypath = vim.fn.stdpath "data" .. "/lazy/lazy.nvim"

if not vim.uv.fs_stat(lazypath) then
  local repo = "https://github.com/folke/lazy.nvim.git"
  vim.fn.system { "git", "clone", "--filter=blob:none", repo, "--branch=stable", lazypath }
end

vim.opt.rtp:prepend(lazypath)

local lazy_config = require "configs.lazy"

-- load plugins
require("lazy").setup({
  {
    "NvChad/NvChad",
    lazy = false,
    branch = "v2.5",
    import = "nvchad.plugins",
  },

  { import = "plugins" },
}, lazy_config)

-- load theme
dofile(vim.g.base46_cache .. "defaults")
dofile(vim.g.base46_cache .. "statusline")
dofile(vim.g.base46_cache .. "syntax")
dofile(vim.g.base46_cache .. "treesitter")

require "options"
require "nvchad.autocmds"

vim.schedule(function()
  require "mappings"
end)

-- General
vim.opt.relativenumber = true
vim.opt.colorcolumn = "80"
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*",
  callback = function(args)
    require("conform").format { bufnr = args.buf }
  end,
})

-- Settings for Neovide
if vim.g.neovide then
  -- Font configuration
  vim.o.guifont = "FiraCode Nerd Font:h11" -- Set font and size

  -- Visual settings
  -- vim.g.neovide_floating_blur_amount_x = 2.0 -- Blur for floating windows
  -- vim.g.neovide_floating_blur_amount_y = 2.0

  -- Animation settings
  -- vim.g.neovide_cursor_animation_length = 0.05 -- Cursor animation speed
  -- vim.g.neovide_cursor_trail_length = 0.8 -- Cursor trail size
  -- vim.g.neovide_cursor_antialiasing = true -- Smooth cursor movement

  -- Performance settings
  vim.g.neovide_refresh_rate = 60 -- Display refresh rate
  vim.g.neovide_refresh_rate_idle = 5 -- Refresh rate when idle
  vim.g.neovide_no_idle = false -- Continue animations when idle

  -- Window settings
  -- vim.g.neovide_remember_window_size = true -- Remember window size
  -- vim.g.neovide_fullscreen = false -- Start in fullscreen mode
end
