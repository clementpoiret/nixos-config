-- load defaults i.e lua_lsp
require("nvchad.configs.lspconfig").defaults()

local lspconfig = require "lspconfig"
local configs = require "lspconfig.configs"

-- EXAMPLE
local servers = { "html", "cssls" }
local nvlsp = require "nvchad.configs.lspconfig"

-- lsps with default config
for _, lsp in ipairs(servers) do
  lspconfig[lsp].setup {
    on_attach = nvlsp.on_attach,
    on_init = nvlsp.on_init,
    capabilities = nvlsp.capabilities,
  }
end

-- Python
lspconfig.ruff.setup {
  trace = "messages",
  init_options = {
    settings = {
      logLevel = "debug",
    },
  },
}

-- nushell
lspconfig.nushell.setup {}

-- nix
lspconfig.nixd.setup {}

-- bibli-ls
if not configs.bibli_ls then
  configs.bibli_ls = {
    default_config = {
      cmd = { "bibli_ls" },
      filetypes = { "markdown" },
      root_dir = lspconfig.util.root_pattern ".bibli.toml",
      -- Optional: visit the URL of the citation with LSP DocumentImplementation
      on_attach = function(client, bufnr)
        vim.keymap.set({ "n" }, "<cr>", function()
          vim.lsp.buf.implementation()
        end)
      end,
    },
  }
end

lspconfig.bibli_ls.setup {}
