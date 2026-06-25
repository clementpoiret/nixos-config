{ pkgs, ... }:
{
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    defaultEditor = false;
    extraLuaPackages = ps: [ ps.magick ];
  };

  home.packages = with pkgs; [
    lua-language-server
    stylua

    # gui if needed
    neovide
  ];

}
