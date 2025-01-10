-- load defaults i.e lua_lsp
require("nvchad.configs.lspconfig").defaults()

local lspconfig = require "lspconfig"

local servers = { "html", "cssls", "ruff", "nushell", "nixd", "zls" }

local nvlsp = require "nvchad.configs.lspconfig"
local cmp = require "blink.cmp"
local on_init = nvlsp.on_init
local capabilities = cmp.get_lsp_capabilities(nvlsp.capabilities)

local on_attach = function(client, bufnr)
  nvlsp.on_attach(client, bufnr)
  local map = vim.keymap.set

	-- define LSP specific key bindings
	-- stylua: ignore start
	map("n", "gd", "<cmd>Telescope lsp_definitions<CR>", { buffer = bufnr, desc = "Telescope: LSP defininitions" })
	map("n", "gr", "<cmd>Telescope lsp_references<CR>", { buffer = bufnr, desc = "Telescope: LSP references" })
	map("n", "gi", "<cmd>Telescope lsp_implementations<CR>", { buffer = bufnr, desc = "Telescope: LSP implementations" })
  -- stylua: ignore end

  if client.name == "ruff" then
    -- Disable hover in favor of basedpyright
    client.server_capabilities.hoverProvider = false
  end
end

-- lsps with default config
for _, lsp in ipairs(servers) do
  lspconfig[lsp].setup {
    on_attach = on_attach,
    on_init = on_init,
    capabilities = capabilities,
  }
end

lspconfig.basedpyright.setup {
  on_attach = on_attach,
  on_init = on_init,
  capabilities = capabilities,
  settings = {
    pyright = {
      -- Using Ruff's import organizer
      disableOrganizeImports = true,
    },
    basedpyright = {
      analysis = {
        -- Ignore all files for analysis to exclusively use Ruff for linting
        ignore = { "*" },
      },
    },
  },
}
