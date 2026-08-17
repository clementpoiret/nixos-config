{ pkgs, ... }:
let
  fontPackages = with pkgs; [
    nerd-fonts.fira-code
    nerd-fonts.hack
    nerd-fonts.jetbrains-mono
    nerd-fonts.monaspace
    nerd-fonts.noto
    nerd-fonts.symbols-only
    stix-two
    xits-math
    twemoji-color-font
  ];
in
{
  fonts.fontconfig.enable = true;
  home.packages = fontPackages;
  localAppArmor.sessionReadPackages = fontPackages;

  gtk = {
    enable = true;
  };

  home.pointerCursor.enable = true;
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
