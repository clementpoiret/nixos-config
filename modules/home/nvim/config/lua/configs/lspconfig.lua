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
