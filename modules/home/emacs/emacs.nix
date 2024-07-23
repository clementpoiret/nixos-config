{ config, pkgs, ... }:
let
  home = config.home.homeDirectory;
in
{
  home.packages = (with pkgs; [
    emacs
    emacs-lsp-booster
    libtool
    mdl
    pandoc
    shellcheck

    # python
    python311Packages.black
    python311Packages.flake8
    python311Packages.isort
    python311Packages.python-lsp-server
    python311Packages.yapf
    ruff-lsp

    # web stuff
    nodePackages_latest.prettier
    nodePackages_latest.eslint_d
    nodePackages_latest.vscode-langservers-extracted
    nodePackages_latest.typescript-language-server
  ]);

  home.file = {
    ".config/doom/config.el" = {
      source = ./doom/config.el;
    };
    ".config/doom/init.el" = {
      source = ./doom/init.el;
    };
    ".config/doom/packages.el" = {
      source = ./doom/packages.el;
    };
  };

  home.sessionVariables = {
    LSP_USE_PLISTS="true";
  };
}
