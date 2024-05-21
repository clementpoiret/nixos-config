return {
	{
		"stevearc/conform.nvim",
		-- event = "BufWritePre", -- uncomment for format on save
		config = function()
			require("configs.conform")
		end,
	},

	-- General
	-- {
	--   "Exafunction/codeium.vim",
	--   event = "BufEnter",
	--   config = function()
	--     vim.g.codeium_disable_bindings = 1
	--     vim.keymap.set("i", "<C-a>", function()
	--       return vim.fn["codeium#Accept"]()
	--     end, { expr = true, silent = true })
	--     vim.keymap.set("i", "<c-;>", function()
	--       return vim.fn["codeium#CycleCompletions"](1)
	--     end, { expr = true, silent = true })
	--     vim.keymap.set("i", "<c-,>", function()
	--       return vim.fn["codeium#CycleCompletions"](-1)
	--     end, { expr = true, silent = true })
	--     vim.keymap.set("i", "<c-x>", function()
	--       return vim.fn["codeium#Clear"]()
	--     end, { expr = true, silent = true })
	--     vim.keymap.set("i", "<C-ESC>", function()
	--       return vim.fn["codeium#Chat"]()
	--     end, { expr = true, silent = true })
	--   end,
	-- },
	{
		"NvChad/nvcommunity",
		{ import = "nvcommunity.git.lazygit" },
	},
	{ "rafamadriz/friendly-snippets" },
	{
		"L3MON4D3/LuaSnip",
		dependencies = { "rafamadriz/friendly-snippets" },
	},
	{
		"pwntester/octo.nvim",
		lazy = false,
		requires = {
			"nvim-lua/plenary.nvim",
			"nvim-telescope/telescope.nvim",
			-- OR 'ibhagwan/fzf-lua',
			"nvim-tree/nvim-web-devicons",
		},
		config = function()
			require("octo").setup()
		end,
	},

	-- Python
	{
		"Vigemus/iron.nvim",
		ft = "python",
		config = function()
			require("configs.iron")
		end,
	},
	{
		"AckslD/swenv.nvim",
	},
	{
		"stevearc/dressing.nvim",
	},
	{
		"heavenshell/vim-pydocstring",
	},

	-- Elm
	{
		"elmcast/elm-vim",
	},

	-- LaTeX
	{
		"lervag/vimtex",
		config = function()
			vim.g.vimtex_view_method = "zathura"
		end,
	},

	-- Flutter
	{
		"akinsho/flutter-tools.nvim",
		lazy = false,
		dependencies = {
			"nvim-lua/plenary.nvim",
			"stevearc/dressing.nvim", -- optional for vim.ui.select
		},
		config = true,
	},

	-- Obsidian
	{
		"epwalsh/obsidian.nvim",
		lazy = true,
		ft = "markdown",
		opts = {
			workspaces = {
				{
					name = "default",
					path = "~/Sync/Notes/Obsidian/Default/",
				},
			},
		},
	},

	-- Misc
	{
		"mfussenegger/nvim-jdtls",
	},
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
		"kelwin/vim-smali",
	},

	-- Overrides
	{
		"hrsh7th/nvim-cmp",
		dependencies = { "kdheepak/cmp-latex-symbols" },
		opts = function()
			local opts = require("nvchad.configs.cmp")
			local cmp = require("cmp")

			local symbols = {
				name = "latex_symbols",
				option = {
					strategy = 0,
				},
			}

			opts.mapping["<CR>"] = cmp.mapping.confirm({ select = false })
			table.insert(opts.sources, symbols)

			return opts
		end,
	},

	{
		"neovim/nvim-lspconfig",
		config = function()
			require("nvchad.configs.lspconfig").defaults()
			require("configs.lspconfig")
		end,
	},

	-- These are some examples, uncomment them if you want to see them work!
	{
		"williamboman/mason.nvim",
		opts = {
			ensure_installed = {
				"lua-language-server",
				"stylua",
				"html-lsp",
				"css-lsp",
				"prettier",
			},
		},
	},
	--
	-- {
	-- 	"nvim-treesitter/nvim-treesitter",
	-- 	opts = {
	-- 		ensure_installed = {
	-- 			"vim", "lua", "vimdoc
	--      "html", "css"
	-- 		},
	-- 	},
	-- },
}
