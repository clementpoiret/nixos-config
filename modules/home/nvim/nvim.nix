{ config, pkgs, ... }:
let home = config.home.homeDirectory;
in {
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    defaultEditor = false;
    extraLuaPackages = ps: [ ps.magick ];
  };

  home.sessionVariables.EDITOR = "neovide";

  home.packages = with pkgs; [
    lua-language-server
    stylua

    # python
    python312Packages.black
    python312Packages.flake8
    python312Packages.isort
    python312Packages.python-lsp-server
    ruff

    # gui if needed
    neovide
  ];

  home.file = {
    ".config/nvim/init.lua" = { source = ./config/init.lua; };
    ".config/nvim/lua/options.lua" = { source = ./config/lua/options.lua; };
    ".config/nvim/lua/mappings.lua" = { source = ./config/lua/mappings.lua; };
    ".config/nvim/lua/chadrc.lua" = { source = ./config/lua/chadrc.lua; };
    ".config/nvim/lua/configs/conform.lua" = {
      source = ./config/lua/configs/conform.lua;
    };
    ".config/nvim/lua/configs/lazy.lua" = {
      source = ./config/lua/configs/lazy.lua;
    };
    ".config/nvim/lua/configs/lspconfig.lua" = {
      source = ./config/lua/configs/lspconfig.lua;
    };
    ".config/nvim/lua/plugins/init.lua" = {
      source = ./config/lua/plugins/init.lua;
    };
  };
}
