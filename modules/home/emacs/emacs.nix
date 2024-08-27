{ config, inputs, pkgs, ... }:
let
  home = config.home.homeDirectory;
  secrets = import "${inputs.secrets}/variables.nix";
in {
  home.packages = (with pkgs; [
    emacs29-pgtk
    emacs-lsp-booster
    ispell
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

    # nix
    nixfmt-classic

    # web stuff
    nodePackages_latest.prettier
    nodePackages_latest.eslint_d
    nodePackages_latest.vscode-langservers-extracted
    nodePackages_latest.typescript-language-server
  ]);

  home.file = {
    ".config/doom/config.el" = {
      # source = ./doom/config.el;
      text = builtins.replaceStrings [ "$ANTHROPIC_API_KEY" ]
        [ secrets.anthropicApiKey ] (builtins.readFile ./doom/config.el);
    };
    ".config/doom/init.el" = { source = ./doom/init.el; };
    ".config/doom/packages.el" = { source = ./doom/packages.el; };
  };

  home.sessionVariables = { LSP_USE_PLISTS = "true"; };

  services.emacs = {
    enable = true;
    package = pkgs.emacs29-pgtk;
  };
}
