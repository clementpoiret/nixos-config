{
  config,
  lib,
  options,
  pkgs,
  ...
}:
let
  configureQtTheme = pkgs.writeShellApplication {
    name = "configure-qt-theme";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.crudini
    ];
    text = ''
      config_dir="$1"
      for qtct in qt5ct qt6ct; do
        config_file="$config_dir/$qtct/$qtct.conf"
        mkdir -p "$config_dir/$qtct"
        # Older generated configurations can remain read-only after DMS replaces them.
        if [[ -f "$config_file" ]]; then
          chmod u+w "$config_file"
        fi
        crudini --merge "$config_file" <<EOF
      [Appearance]
      style=Fusion
      custom_palette=true
      color_scheme_path=$config_dir/$qtct/colors/matugen.conf
      EOF
      done
    '';
  };
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

  # DMS rewrites these files, so update their values without store-backed symlinks.
  home.activation.qtTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${lib.getExe configureQtTheme} ${lib.escapeShellArg config.xdg.configHome}
  '';

  programs.dank-material-shell.package =
    options.programs.dank-material-shell.package.default.overrideAttrs
      (oldAttrs: {
        postInstall = oldAttrs.postInstall + ''
          # Standard qtct needs native palettes, not DMS's KDE color scheme.
          cat > "$out/share/quickshell/dms/scripts/qt.sh" <<'EOF'
          exec ${lib.getExe configureQtTheme} "$@"
          EOF
        '';
      });

  qt = {
    enable = true;
    platformTheme.name = "qtct";

    # Keep Kvantum available without forcing QT_STYLE_OVERRIDE on applications.
    style.package = with pkgs; [
      libsForQt5.qtstyleplugin-kvantum
      qt6Packages.qtstyleplugin-kvantum
    ];
  };
}
