return {

  -- General
  -- -- NvChad
  {
    "stevearc/conform.nvim",
    event = "BufWritePre", -- uncomment for format on save
    opts = require "configs.conform",
  },

  {
    "nvim-tree/nvim-tree.lua",
    config = function()
      require("nvim-tree").setup {
        sync_root_with_cwd = true,
        respect_buf_cwd = true,
        update_focused_file = {
          enable = true,
          update_root = true,
        },
      }
    end,
  },

  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
  },

  "nvim-lua/plenary.nvim",

  {
    "nvchad/ui",
    config = function()
      require "nvchad"
    end,
  },

  {
    "nvchad/base46",
    lazy = true,
    build = function()
      require("base46").load_all_highlights()
    end,
  },

  "nvchad/volt",

  "NvChad/nvcommunity",
  { import = "nvcommunity.git.diffview" },
  { import = "nvcommunity.git.neogit" },

  -- -- Third Party
  { "actionshrimp/direnv.nvim", config = true, lazy = false, opts = {} },

  { "mg979/vim-visual-multi", event = "VeryLazy", branch = "master" },

  {
    "folke/todo-comments.nvim",
    -- PERF: test perf?
    -- HACK: bruh
    -- TODO: wew
    -- NOTE:  sdkfj dkfjskdfj
    -- FIX: fixed
    -- WARNING: test done
    lazy = false,
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("todo-comments").setup()
    end,
  },

  {
    "tiagovla/scope.nvim",
    lazy = true,
    event = "VeryLazy",
    config = function()
      require("scope").setup {}
    end,
  },

  "nvim-lua/popup.nvim",
  "jvgrootveld/telescope-zoxide",
  "nvim-telescope/telescope-file-browser.nvim",
  "nvim-telescope/telescope-project.nvim",
  "joaomsa/telescope-orgmode.nvim",

  {
    "nvim-telescope/telescope.nvim",
    opts = {
      extensions_list = { "themes", "terms", "file_browser", "project", "zoxide", "orgmode", "scope" },
    },
  },

  -- {
  --   "ahmedkhalf/project.nvim",
  --   lazy = false,
  --   dependencies = {
  --     "nvim-telescope/telescope-file-browser.nvim"
  --   },
  --   config = function()
  --     require("project_nvim").setup {}
  --   end
  -- },

  -- Programming
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "lua", "python", "bash", "rust", "nix" }, ignore_install = { "org" } },
  },

  -- -- REPLs
  {
    "jalvesaq/vimcmdline",
    lazy = true,
    ft = { "python", "lua" },
    config = function(_)
      vim.g.cmdline_term_height = 15
      vim.g.cmdline_term_width = 80
      vim.g.cmdline_tmp_dir = "/tmp"
      vim.g.cmdline_outhl = 1
      -- we override this mapping below, so map here to something we'll probably not use.
      vim.g.cmdline_map_start = "<leader>z"
    end,
  },

  -- Sometimes useful
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    lazy = true,
    version = false, -- set this if you want to always pull the latest change
    opts = {
      -- add any opts here
    },
    -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
    build = "make",
    -- build = "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" -- for windows
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "stevearc/dressing.nvim",
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
      {
        -- support for image pasting
        "HakonHarnes/img-clip.nvim",
        event = "VeryLazy",
        opts = {
          -- recommended settings
          default = {
            embed_image_as_base64 = false,
            prompt_for_file_name = false,
            drag_and_drop = {
              insert_mode = true,
            },
            -- required for Windows users
            use_absolute_path = true,
          },
        },
      },
      {
        -- Make sure to set this up properly if you have lazy=true
        "MeanderingProgrammer/render-markdown.nvim",
        opts = {
          file_types = { "markdown", "Avante" },
        },
        ft = { "markdown", "Avante" },
      },
    },
  },

  -- Org Mode & Org Roam
  {
    "nvim-orgmode/orgmode",
    event = "VeryLazy",
    ft = { "org" },
    config = function()
      -- Setup orgmode
      require("orgmode").setup {
        org_agenda_files = "~/Sync/Notes/org/**/*",
        org_default_notes_file = "~/Sync/Notes/org/todo.org",
      }
    end,
  },

  -- TODO: Citation plugin
  {
    "chipsenkbeil/org-roam.nvim",
    tag = "0.1.0",
    dependencies = {
      {
        "nvim-orgmode/orgmode",
        tag = "0.3.7",
      },
    },
    config = function()
      require("org-roam").setup {
        bindings = {
          prefix = "<LocalLeader>n",
        },
        directory = "~/Sync/Notes/org-roam/permanent/",
        -- -- optional
        -- org_files = {
        --   "~/another_org_dir",
        --   "~/some/folder/*.org",
        --   "~/a/single/org_file.org",
        -- }
      }
    end,
  },
}
