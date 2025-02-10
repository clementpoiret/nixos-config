return {

  -- General
  -- -- NvChad
  {
    "hrsh7th/nvim-cmp",
    enabled = false, -- replaced by blink.cmp
  },

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
  {
    "m4xshen/autoclose.nvim",
    event = "VeryLazy",
    config = function()
      require("autoclose").setup {
        options = { pair_spaces = true },
        keys = {
          -- Because this breaks zk's LSP suggestions
          ["["] = { escape = false, close = true, pair = "[]", disabled_filetypes = { "markdown" } },
        },
      }
    end,
  },

  {
    "saghen/blink.cmp",
    event = "VeryLazy",
    dependencies = "rafamadriz/friendly-snippets",
    version = "*",

    opts = {
      keymap = { preset = "default" },

      appearance = {
        -- Will be removed in a future release
        use_nvim_cmp_as_default = true,
        nerd_font_variant = "normal",
      },

      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
      },

      signature = { enabled = true },
    },
    opts_extend = { "sources.default" },
  },

  {
    "https://github.com/fresh2dev/zellij.vim",
    -- Pin version to avoid breaking changes.
    -- tag = '0.3.*',
    -- lazy = false,
    event = "VeryLazy",
    init = function()
      -- Options:
      -- vim.g.zelli_navigator_move_focus_or_tab = 1
      -- vim.g.zellij_navigator_no_default_mappings = 1
    end,
  },

  {
    "otavioschwanck/arrow.nvim",
    event = "VeryLazy",
    dependencies = {
      { "nvim-tree/nvim-web-devicons" },
    },
    opts = {
      show_icons = true,
      leader_key = ";",        -- Recommended to be a single key
      buffer_leader_key = "m", -- Per Buffer Mappings
      window = {
        border = "rounded",
      },
    },
  },

  {
    "hiphish/rainbow-delimiters.nvim",
    event = "BufReadPost",
    config = function()
      local rainbow_delimiters = require "rainbow-delimiters"

      vim.g.rainbow_delimiters = {
        strategy = {
          [""] = rainbow_delimiters.strategy["global"],
          vim = rainbow_delimiters.strategy["local"],
        },
        query = {
          [""] = "rainbow-delimiters",
          lua = "rainbow-blocks",
        },
        highlight = {
          "RainbowDelimiterRed",
          "RainbowDelimiterYellow",
          "RainbowDelimiterBlue",
          "RainbowDelimiterOrange",
          "RainbowDelimiterGreen",
          "RainbowDelimiterViolet",
          "RainbowDelimiterCyan",
        },
      }
    end,
  },

  { "actionshrimp/direnv.nvim", config = true,      lazy = false,     opts = {} },

  { "mg979/vim-visual-multi",   event = "VeryLazy", branch = "master" },

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
      require("scope").setup {
        hooks = {
          post_tab_enter = function()
            require("arrow.persist").load_cache_file()
          end,
        },
      }
    end,
  },

  "nvim-lua/popup.nvim",
  "jvgrootveld/telescope-zoxide",
  "nvim-telescope/telescope-file-browser.nvim",
  "nvim-telescope/telescope-project.nvim",
  "nvim-telescope/telescope-bibtex.nvim",

  {
    "nvim-telescope/telescope.nvim",
    opts = {
      extensions_list = { "themes", "terms", "file_browser", "project", "zoxide", "scope", "bibtex", "zk" },
      extensions = {
        project = {
          on_project_selected = function(prompt_bufnr)
            local project_actions = require "telescope._extensions.project.actions"
            project_actions.change_working_directory(prompt_bufnr, false)
            require("arrow.persist").load_cache_file()
            vim.cmd "Telescope find_files"
          end,
        },
        bibtex = {
          global_files = { "/home/clementpoiret/Sync/Bibliography/library.bib" },
        },
      },
    },
  },

  { "mcauley-penney/visual-whitespace.nvim" },

  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    keys = {
      {
        "<leader>.",
        function()
          Snacks.scratch()
        end,
        desc = "Toggle Scratch Buffer",
      },
      {
        "<leader>S",
        function()
          Snacks.scratch.select()
        end,
        desc = "Select Scratch Buffer",
      },
    },
    opts = {
      bigfile = { enabled = true },
      bufdelete = { enabled = true },
      gitbrowse = { enabled = true },
      lazygit = { enabled = true },
      notifier = { enabled = true },
      notify = { enabled = true },
      quickfile = { enabled = true },
      scratch = { enabled = true },
      words = { enabled = true },
    },
  },

  -- Programming
  { "akinsho/git-conflict.nvim",            version = "*", config = true },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "lua", "python", "bash", "rust", "nix", "hcl" } },
    dependencies = {
      -- NOTE: additional parser for nu
      { "nushell/tree-sitter-nu", build = ":TSInstall nu" },
    },
    build = ":TSUpdate",
  },

  -- Zig
  {
    "ziglang/zig.vim",
    ft = { "zig" },
    init = function()
      -- vim.g.zig_fmt_autosave = 0 -- handled by lsp
    end,
  },

  -- Rust
  {
    "mrcjkb/rustaceanvim",
    version = "^5",
    lazy = false,
    config = function()
      -- local codelldb = vim.fn.expand "$LSP_CODELLDB"
      -- local extension_path = codelldb .. "share/vscode/extensions/vadimcn.vscode-lldb"
      -- local codelldb_path = extension_path .. "adapter/codelldb"
      -- local liblldb_path = extension_path .. "lldb/lib/liblldb.so"
      -- local cfg = require "rustaceanvim.config"

      -- vim.g.rustaceanvim = {
      --   dap = {
      --     adapter = cfg.get_codelldb_adapter(codelldb_path, liblldb_path),
      --   },
      -- }
    end,
  },
  {
    "mfussenegger/nvim-dap",
    config = function()
      local dap, dapui = require "dap", require "dapui"
      dap.listeners.before.attach.dapui_config = function()
        dapui.open()
      end
      dap.listeners.before.launch.dapui_config = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated.dapui_config = function()
        dapui.close()
      end
      dap.listeners.before.event_exited.dapui_config = function()
        dapui.close()
      end
    end,
  },
  {
    "rcarriga/nvim-dap-ui",
    dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },
    config = function()
      require("dapui").setup()
    end,
  },
  {
    "saecki/crates.nvim",
    tag = "stable",
    config = function()
      require("crates").setup { completion = { cmp = { enable = true } } }
      require("cmp").setup.buffer { sources = { { name = "crates" } } }
    end,
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

  -- -- Notes and TODOs
  {
    "atiladefreitas/dooing",
    event = "VeryLazy",
    lazy = true,
    config = function()
      require("dooing").setup {
        save_path = vim.fn.expand "$HOME/Sync/Notes/dooing_todos.json",
      }
    end,
  },

  {
    "zk-org/zk-nvim",
    event = "VeryLazy",
    config = function()
      require("zk").setup {
        picker = "telescope",
      }
    end,
  },

  -- Sometimes useful
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    lazy = true,
    version = "*", -- set this if you want to always pull the latest change
    opts = {
      -- add any opts here
    },
    -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
    -- build = "make",
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
  {
    "nvzone/typr",
    event = "VeryLazy",
    lazy = true,
  },
}
