{ pkgs, inputs, ... }:
{
  imports = [ inputs.stylix.homeModules.stylix ];

  stylix = {
    enable = true;
    overlays.enable = false;

    base16Scheme = "${pkgs.base16-schemes}/share/themes/rose-pine.yaml";

    cursor = {
      name = "BreezeX-RosePine-Linux";
      package = pkgs.rose-pine-cursor;
      size = 22;
    };

    icons = {
      enable = true;
      dark = "rose-pine";
      package = pkgs.rose-pine-icon-theme;
    };

    fonts = {
      sizes = {
        desktop = 9;
        applications = 9;
        popups = 9;
      };

      serif = {
        package = pkgs.nerd-fonts.noto;
        name = "NotoSerif Nerd Font";
      };

      sansSerif = {
        package = pkgs.nerd-fonts.noto;
        name = "NotoSans Nerd Font";
      };

      monospace = {
        name = "TX02 Nerd Font Ret";
      };

      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };
    };

    opacity.desktop = 0.0;

    targets.hyprpaper.enable = false;
    targets.hyprpaper.image.enable = false;
    targets.neovim.enable = false;
    targets.waybar.addCss = true;
  };
}
