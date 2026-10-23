{ pkgs, ... }:
let
  fontPackages = with pkgs; [
    inter
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

    theme = {
      name = "adw-gtk3";
      package = pkgs.adw-gtk3;
    };

    # Importing a GTK4 theme would make Home Manager own gtk.css again.
    gtk4.theme = null;
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
    platformTheme.name = "qtct";

    # Keep the existing style available without managing qtct or Kvantum settings.
    style.package = with pkgs; [
      libsForQt5.qtstyleplugin-kvantum
      qt6Packages.qtstyleplugin-kvantum
    ];
  };
}
