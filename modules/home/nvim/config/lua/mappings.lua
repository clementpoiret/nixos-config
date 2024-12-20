require "nvchad.mappings"

local map = vim.keymap.set

map("i", "jk", "<ESC>")

-- swenv
--map("n", "<leader>ce", "<cmd>lua require('swenv.api').pick_venv()<cr>", { desc = "Choose Env" })

-- cursor
map("n", "j", "jzz", { desc = "Next line and center cursor" })
map("n", "k", "kzz", { desc = "Previous line and center cursor" })
map("n", "n", "nzzzv", { desc = "Find next and center cursor" })
map("n", "N", "Nzzzv", { desc = "Find previous and center cursor" })

-- Selection trick, useful for vimcmdline
map("n", "vl", "^v$", { desc = "Select from cursor to the end of line" })

vim.cmd [[
function! SendLineNoWhitespace()
    " First check if we're in a valid cmdline buffer
    if !exists('b:cmdline_filetype') || cmdline#QuartoLng() == 'none'
        return
    endif

    " Check if global variables are initialized
    if !exists('g:cmdline_job') || !exists('g:cmdline_tmuxsname')
        call cmdline#Init()
    endif

    " Check for active session
    let has_active_job = exists('g:cmdline_job') && has_key(g:cmdline_job, b:cmdline_filetype) && g:cmdline_job[b:cmdline_filetype]
    let has_active_tmux = exists('g:cmdline_tmuxsname') && has_key(g:cmdline_tmuxsname, b:cmdline_filetype) && g:cmdline_tmuxsname[b:cmdline_filetype] != ""
    let has_active_pane = exists('s:cmdline_app_pane') && s:cmdline_app_pane != ''

    if !has_active_job && !has_active_tmux && !has_active_pane
        return
    endif

    " Store cursor position
    let save_pos = getpos('.')

    " Get current line and trim leading whitespace
    let line = getline('.')
    let trimmed_line = substitute(line, '^\s*', '', '')

    " Send the trimmed line
    call cmdline#SendCmd(trimmed_line)
    call cmdline#Down()
endfunction
]]

map(
  "n",
  "<C-Space>",
  ":call SendLineNoWhitespace()<CR>",
  { desc = "Send current line (trimmed) to REPL and move to next line", silent = true }
)

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

-- Nvim DAP
map("n", "<Leader>dl", "<cmd>lua require'dap'.step_into()<CR>", { desc = "Debugger step into" })
map("n", "<Leader>dj", "<cmd>lua require'dap'.step_over()<CR>", { desc = "Debugger step over" })
map("n", "<Leader>dk", "<cmd>lua require'dap'.step_out()<CR>", { desc = "Debugger step out" })
map("n", "<Leader>dc", "<cmd>lua require'dap'.continue()<CR>", { desc = "Debugger continue" })
map("n", "<Leader>db", "<cmd>lua require'dap'.toggle_breakpoint()<CR>", { desc = "Debugger toggle breakpoint" })
map(
  "n",
  "<Leader>dd",
  "<cmd>lua require'dap'.set_breakpoint(vim.fn.input('Breakpoint condition: '))<CR>",
  { desc = "Debugger set conditional breakpoint" }
)
map("n", "<Leader>de", "<cmd>lua require'dap'.terminate()<CR>", { desc = "Debugger reset" })
map("n", "<Leader>dr", "<cmd>lua require'dap'.run_last()<CR>", { desc = "Debugger run last" })

-- rustaceanvim
map("n", "<Leader>dt", "<cmd>lua vim.cmd('RustLsp testables')<CR>", { desc = "Debugger testables" })

-- Citations
map("n", "<leader>ci", "<cmd>Telescope bibtex<cr>", { desc = "Search citations" })

-- Arrow
map("n", "<C-S-P>", function()
  require("arrow.persist").previous()
end, { desc = "Arrow prev file" })
map("n", "<C-S-N>", function()
  require("arrow.persist").next()
end, { desc = "Arrow next file" })

-- Zk
-- Add the key mappings only for Markdown files in a zk notebook.
if require("zk.util").notebook_root(vim.fn.expand "%:p") ~= nil then
  local opts = { noremap = true, silent = false }

  -- Open the link under the caret.
  map("n", "<CR>", "<Cmd>lua vim.lsp.buf.definition()<CR>", opts)

  -- Create a new note after asking for its title.
  -- This overrides the global `<leader>zn` mapping to create the note in the same directory as the current buffer.
  map("n", "<leader>zn", "<Cmd>ZkNew { dir = vim.fn.expand('%:p:h'), title = vim.fn.input('Title: ') }<CR>", opts)
  -- Create a new note in the same directory as the current buffer, using the current selection for title.
  map("v", "<leader>znt", ":'<,'>ZkNewFromTitleSelection { dir = vim.fn.expand('%:p:h') }<CR>", opts)
  -- Create a new note in the same directory as the current buffer, using the current selection for note content and asking for its title.
  map(
    "v",
    "<leader>znc",
    ":'<,'>ZkNewFromContentSelection { dir = vim.fn.expand('%:p:h'), title = vim.fn.input('Title: ') }<CR>",
    opts
  )

  -- Open notes linking to the current buffer.
  map("n", "<leader>zb", "<Cmd>ZkBacklinks<CR>", opts)
  -- Alternative for backlinks using pure LSP and showing the source context.
  --map('n', '<leader>zb', '<Cmd>lua vim.lsp.buf.references()<CR>', opts)
  -- Open notes linked by the current buffer.
  map("n", "<leader>zl", "<Cmd>ZkLinks<CR>", opts)

  -- Preview a linked note.
  map("n", "K", "<Cmd>lua vim.lsp.buf.hover()<CR>", opts)
  -- Open the code actions for a visual selection.
  map("v", "<leader>za", ":'<,'>lua vim.lsp.buf.range_code_action()<CR>", opts)
end
