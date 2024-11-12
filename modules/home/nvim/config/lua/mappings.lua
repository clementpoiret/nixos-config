require "nvchad.mappings"

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

-- swenv
--map("n", "<leader>ce", "<cmd>lua require('swenv.api').pick_venv()<cr>", { desc = "Choose Env" })

-- cursor
map("n", "j", "jzz", { desc = "Next line and center cursor" })
map("n", "k", "kzz", { desc = "Previous line and center cursor" })
map("n", "n", "nzzzv", { desc = "Find next and center cursor" })
map("n", "N", "Nzzzv", { desc = "Find previous and center cursor" })

-- Selection trick, useful for vimcmdline
map("n", "<leader>v", "^v$", { desc = "Select from cursor to the end of line" })

-- Remap nvimtree
map("n", "<leader>op", ":NvimTreeToggle<cr>", { desc = "Open NvimTree" })
map("n", "<leader>fp", ":NvimTreeFocus<cr>", { desc = "Focus NvimTree" })

-- Buffer navigation
map("n", "<Tab>", ":bnext<CR>", { desc = "Next buffer" })
map("n", "<S-Tab>", ":bprev<CR>", { desc = "Previous buffer" })
map("n", "<leader>x", ":bd<CR>", { desc = "Close buffer" })

-- Tab navigation
map("n", "<leader>tn", ":tabnew<CR>", { desc = "Create a new tab" })
map("n", "<leader>tx", ":tabclose<CR>", { desc = "Close the current tab" })
map("n", "<leader><Tab>", ":tabnext<CR>", { desc = "Go to the next tab" })
map("n", "<leader><S-Tab>", ":tabprevious<CR>", { desc = "Go to the previous tab" })
map("n", "<leader>tb", ":Telescope scope buffers<CR>", { desc = "Display scope buffers" })

-- projects
map(
  "n",
  "<leader>pp",
  ":lua require'telescope'.extensions.project.project{}<CR>",
  { desc = "Manage Projects", noremap = true, silent = true }
)
map("n", "<C-x>g", ":Neogit<CR>")
