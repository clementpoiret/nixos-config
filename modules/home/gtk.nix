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
    noto-fonts-emoji
    twemoji-color-font
  ];

  gtk = {
    enable = true;
    font = {
      name = "JetBrainsMono Nerd Font";
      size = 11;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.catppuccin-papirus-folders.override {
        flavor = "mocha";
        accent = "lavender";
      };
    };
    theme = {
      name = "catppuccin-mocha-lavender-compact";
      package = pkgs.catppuccin-gtk.override {
        accents = [ "lavender" ];
        size = "compact";
        # tweaks = [ "rimless" ];
        variant = "mocha";
      };
    };
    cursorTheme = {
      name = "Bibata-Modern-Ice";
      package = pkgs.bibata-cursors;
      size = 22;
    };
  };

  home.pointerCursor = {
    name = "Bibata-Modern-Ice";
    package = pkgs.bibata-cursors;
    size = 22;
    gtk.enable = true;
    x11.enable = true;
    hyprcursor = {
      enable = true;
      size = 22;
    };
  };

  home.sessionVariables = {
    XCURSOR_SIZE = 22;
  };

  # QT Theming
  qt = {
    enable = true;
    platformTheme.name = "kvantum";
    style = {
      package = pkgs.catppuccin-kvantum;
      name = "Catppuccin-Mocha-Lavender";
    };
  };
}
