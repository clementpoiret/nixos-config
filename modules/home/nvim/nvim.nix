{ pkgs, ... }:
{
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    defaultEditor = false;
    extraLuaPackages = ps: [ ps.magick ];
  };

  # home.sessionVariables.EDITOR = "nvim";

  home.packages = with pkgs; [
    lua-language-server
    stylua

    # gui if needed
    neovide
  ];

  home.sessionVariables = {
    # LSP_CODELLDB = "${pkgs.vscode-extensions.vadimcn.vscode-lldb}";
  };

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
