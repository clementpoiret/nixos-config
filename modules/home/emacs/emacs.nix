{ config, inputs, pkgs, ... }:
let
  home = config.home.homeDirectory;
  doomBin = pkgs.writeScriptBin "doom" ''
    $HOME/.config/emacs/bin/doom $@
  '';
in {
  home.packages = (with pkgs; [
    # emacs
    emacs29-pgtk
    #emacs-lsp-booster
    ispell
    libtool
    mdl
    pandoc
    shellcheck

    # python
    python312Packages.black
    python312Packages.flake8
    python312Packages.isort
    python312Packages.python-lsp-server
    python312Packages.yapf
    ruff-lsp

    # web stuff
    nodePackages_latest.prettier
    nodePackages_latest.eslint_d
    nodePackages_latest.vscode-langservers-extracted
    nodePackages_latest.typescript-language-server

    doomBin
  ]);

  home.file = {
    ".config/doom/config.el" = { source = ./doom/config.el; };
    ".config/doom/init.el" = { source = ./doom/init.el; };
    ".config/doom/packages.el" = { source = ./doom/packages.el; };
  };

  home.sessionVariables = { LSP_USE_PLISTS = "true"; };

  services.emacs = {
    enable = true;
    package = pkgs.emacs29-pgtk;
  };
}
