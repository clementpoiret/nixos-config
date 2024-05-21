-- iron config
-- TODO: when skipping two lines, send a <CR>
local iron = require("iron.core")
local view = require("iron.view")
iron.setup {
  config = {
    -- Whether a repl should be discarded or not
    scratch_repl = true,
    -- Your repl definitions come here
    repl_definition = {
      sh = {
        -- Can be a table or a function that
        -- returns a table (see below)
        command = {"zsh"}
      },
      python = {
        command = {"python"}
      },
    },
    -- How the repl window will be displayed
    -- See below for more information
    repl_open_cmd = view.split("20%"),
  },
  -- Iron doesn't set keymaps by default anymore.
  -- You can set them here or manually add keymaps to the functions in iron.core
  keymaps = {
    send_motion = "<space>rc",
    visual_send = "<S-CR>",
  --   send_file = "<leader>sf",
  --   send_line = "<space>sl",
  --   send_until_cursor = "<leader>su",
  --   send_mark = "<leader>sm",
  --   mark_motion = "<leader>mc",
  --   mark_visual = "<leader>mc",
  --   remove_mark = "<leader>md",
    cr = "*",
    interrupt = "ù",
  --   exit = "<leader>sq",
  --   clear = "<leader>cl",
  },
  -- If the highlight is on, you can change how it looks
  -- For the available options, check nvim_set_hl
  highlight = {
    italic = true
  },
  ignore_blank_lines = true, -- ignore blank lines when sending visual select lines
}

-- Key bindings
-- Maps `<C-CR>` to send line and move to next line
vim.keymap.set("n", "<space>rs", "<cmd>IronRepl<cr>")
vim.keymap.set("n", "<space>rr", "<cmd>IronRestart<cr>")
vim.keymap.set("n", "<space>rf", "<cmd>IronFocus<cr>")
vim.keymap.set("n", "<space>rh", "<cmd>IronHide<cr>")

vim.keymap.set("n", "<C-CR>", function()
  -- Get last line number and current cursor position
  local last_line = vim.fn.line("$")
  local pos = vim.api.nvim_win_get_cursor(0)

  -- Send current line
  iron.send_line()

  -- Find the next non-empty line and move the cursor to it
  local next_line = pos[1] + 1
  local n_skipped = 0
  while next_line <= last_line and string.len(vim.api.nvim_buf_get_lines(0, next_line - 1, next_line, false)[1]) == 0 do
    next_line = next_line + 1
    n_skipped = n_skipped + 1

    if n_skipped == 2 then
      iron.send(nil, string.char(13))
    end
  end

  vim.api.nvim_win_set_cursor(0, { math.min(next_line, last_line), pos[2] })
end)
vim.keymap.set("i", "<C-CR>", function()
  -- Get last line number and current cursor position
  local last_line = vim.fn.line("$")
  local pos = vim.api.nvim_win_get_cursor(0)

  -- Send current line
  iron.send_line()

  -- Find the next non-empty line and move the cursor to it
  local next_line = pos[1] + 1
  local n_skipped = 0
  while next_line <= last_line and string.len(vim.api.nvim_buf_get_lines(0, next_line - 1, next_line, false)[1]) == 0 do
    next_line = next_line + 1
    n_skipped = n_skipped + 1

    if n_skipped == 2 then
      iron.send(nil, string.char(13))
    end
  end

  vim.api.nvim_win_set_cursor(0, { math.min(next_line, last_line), pos[2] })
end)

vim.keymap.set("n", "<S-CR>", function()
  local last_line = vim.fn.line("$")
  local pos = vim.api.nvim_win_get_cursor(0)
  local current_line_content = vim.api.nvim_get_current_line()

  -- Remove what's before the cursor and send it
  local line_to_send = string.sub(vim.api.nvim_get_current_line(), pos[2] + 1)
  iron.send(nil, line_to_send)

  -- Find the next non-empty line and move the cursor to it
  local next_line = pos[1] + 1
  local n_skipped = 0
  while next_line <= last_line and string.len(vim.api.nvim_buf_get_lines(0, next_line - 1, next_line, false)[1]) == 0 do
    next_line = next_line + 1
    n_skipped = n_skipped + 1

    if n_skipped == 2 then
      iron.send(nil, string.char(13))
    end
  end

  vim.api.nvim_win_set_cursor(0, { math.min(next_line, last_line), pos[2] })
end)
vim.keymap.set("i", "<S-CR>", function()
  local last_line = vim.fn.line("$")
  local pos = vim.api.nvim_win_get_cursor(0)

  -- Remove what's before the cursor and send it
  local line_to_send = string.sub(vim.api.nvim_get_current_line(), pos[2] + 1)
  iron.send(nil, line_to_send)

  -- Find the next non-empty line and move the cursor to it
  local next_line = pos[1] + 1
  local n_skipped = 0
  while next_line <= last_line and string.len(vim.api.nvim_buf_get_lines(0, next_line - 1, next_line, false)[1]) == 0 do
    next_line = next_line + 1
    n_skipped = n_skipped + 1

    if n_skipped == 2 then
      iron.send(nil, string.char(13))
    end
  end

  vim.api.nvim_win_set_cursor(0, { math.min(next_line, last_line), pos[2] })
end)
