local options = {
  formatters_by_ft = {
    lua = { "stylua" },
    javascript = { "prettier" },
    javascriptreact = { "prettier" },
    typescript = { "prettier" },
    typescriptreact = { "prettier" },
    css = { "prettier" },
    html = { "prettier" },
    json = { "prettier" },
    sh = { "shfmt" },
    elm = { "elm-format" },
    python = { "ruff_format", "ruff_organize_imports" },
    dart = { "dart_format" },
    nix = { "nixfmt" },
    tf = { "terraform_fmt" },
    terraform = { "terraform_fmt" },
    hcl = { "terraform_fmt" },
    rust = { "rustfmt" },
    markdown = { "mdformat" },
  },

  -- format_on_save = {
  --   -- These options will be passed to conform.format()
  --   timeout_ms = 500,
  --   lsp_fallback = true,
  -- },
}

return options
