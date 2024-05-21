local options = {
  formatters = {
    yapf = {
      args = { "--style", "{based_on_style: google}" },
    },
  },
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
    python = { "isort", "yapf" },
    dart = { "dart_format" },
  },
}

require("conform").setup(options)
