{ config, pkgs, ... }:
let
  home = config.home.homeDirectory;
in
{
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    defaultEditor = true;
    extraLuaPackages = ps: [ ps.magick ];
  };

  home.packages = with pkgs; [
    lua-language-server
    stylua

    # python
    python311Packages.flake8
    python311Packages.black
    python311Packages.python-lsp-server

    # web stuff
    nodePackages_latest.prettier
    nodePackages_latest.eslint_d
    nodePackages_latest.vscode-langservers-extracted
    nodePackages_latest.typescript-language-server
  ];

  home.file = {
    ".config/nvim/init.lua" = {
      source = ./config/init.lua;
    };
    ".config/nvim/lua/options.lua" = {
      source = ./config/lua/options.lua;
    };
    ".config/nvim/lua/mappings.lua" = {
      source = ./config/lua/mappings.lua;
    };
    ".config/nvim/lua/chadrc.lua" = {
      source = ./config/lua/chadrc.lua;
    };
    ".config/nvim/lua/configs/conform.lua" = {
      source = ./config/lua/configs/conform.lua;
    };
    ".config/nvim/lua/configs/iron.lua" = {
      source = ./config/lua/configs/iron.lua;
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
