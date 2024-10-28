require "nvchad.mappings"

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

-- swenv
map("n", "<leader>ce", "<cmd>lua require('swenv.api').pick_venv()<cr>", { desc = "Choose Env" })

-- cursor
map("n", "j", "jzz", { desc = "Next line and center cursor" })
map("n", "k", "kzz", { desc = "Previous line and center cursor" })
map("n", "n", "nzzzv", { desc = "Find next and center cursor" })
map("n", "N", "Nzzzv", { desc = "Find previous and center cursor" })

-- projects
map("n", "<leader>pp", ":lua require'telescope'.extensions.project.project{}<CR>", { noremap = true, silent = true })
map("n", "<C-x>g", ":Neogit<CR>")
-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")
