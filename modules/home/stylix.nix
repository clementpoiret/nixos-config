{ pkgs, inputs, ... }:
{
  imports = [ inputs.stylix.homeModules.stylix ];

  stylix = {
    enable = true;

    image = ../../wallpapers/wallpaper.png;

    base16Scheme = "${pkgs.base16-schemes}/share/themes/rose-pine.yaml";

    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 22;
    };

    icons = {
      enable = true;
      dark = "rose-pine";
      package = pkgs.rose-pine-icon-theme;
      # dark = "Papirus-Dark";
      # light = "Papirus-Light";
      # package = pkgs.catppuccin-papirus-folders.override {
      #   flavor = "mocha";
      #   accent = "lavender";
      # };
    };

    fonts = {
      sizes = {
        desktop = 9;
        applications = 9;
        popups = 9;
      };

      serif = {
        package = pkgs.noto-fonts;
        name = "Noto Serif";
      };

      sansSerif = {
        package = pkgs.noto-fonts;
        name = "Noto Sans";
      };

      monospace = {
        name = "TX02 Nerd Font Ret";
      };

      emoji = {
        package = pkgs.noto-fonts-emoji;
        name = "Noto Color Emoji";
      };
    };

    opacity.desktop = 0.0;

    targets.neovim.enable = false;
    targets.waybar.addCss = true;
  };
}
