-- load defaults i.e lua_lsp
require("nvchad.configs.lspconfig").defaults()

local lspconfig = require "lspconfig"

-- TODO: Try pylyzer
local servers = { "html", "cssls", "ruff", "nushell", "nixd" }
local nvlsp = require "nvchad.configs.lspconfig"
local cmp = require "blink.cmp"

-- lsps with default config
for _, lsp in ipairs(servers) do
  lspconfig[lsp].setup {
    on_attach = nvlsp.on_attach,
    on_init = nvlsp.on_init,
    capabilities = cmp.get_lsp_capabilities(nvlsp.capabilities),
  }
end
