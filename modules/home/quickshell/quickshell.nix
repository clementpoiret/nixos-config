{ inputs, pkgs, ... }:
{
  home.packages = with pkgs; [
    grim
    imagemagick
  ];

  programs.quickshell = {
    enable = true;
  };

  xdg.configFile."quickshell/hyprquickshot" = {
    source = inputs.hyprquickshot;
    recursive = true;
    force = true;
  };
}
