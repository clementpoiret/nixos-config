{ pkgs, ... }:
{
  fonts.fontconfig.enable = true;
  home.packages = with pkgs; [
    # nerd fonts
    nerd-fonts.fira-code
    nerd-fonts.hack
    nerd-fonts.jetbrains-mono
    nerd-fonts.monaspace
    nerd-fonts.noto
    nerd-fonts.symbols-only

    # others
    stix-two
    xits-math
    # hack-font
    # noto-fonts-color-emoji
    # noto-fonts

    # source-sans
    # source-sans-pro
    twemoji-color-font
  ];

  gtk = {
    enable = true;
  };

  # home.pointerCursor = {
  #   hyprcursor = {
  #     enable = true;
  #     size = 22;
  #   };
  # };

  home.sessionVariables = {
    XCURSOR_SIZE = 22;
  };

  qt = {
    enable = true;
  };
}
