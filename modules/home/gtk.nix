{ pkgs, ... }:
{
  fonts.fontconfig.enable = true;
  home.packages = with pkgs; [
    julia-mono
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono
    nerd-fonts.monaspace
    nerd-fonts.noto
    nerd-fonts.symbols-only
    noto-fonts-color-emoji
    twemoji-color-font
  ];

  gtk = {
    enable = true;
  };

  home.pointerCursor = {
    hyprcursor = {
      enable = true;
      size = 22;
    };
  };

  home.sessionVariables = {
    XCURSOR_SIZE = 22;
  };

  qt = {
    enable = true;
  };
}
