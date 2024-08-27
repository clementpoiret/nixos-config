{ config, inputs, pkgs, ... }:
let
  home = config.home.homeDirectory;
  secrets = import "${inputs.secrets}/variables.nix";
in {
  home.file = {
    ".pypirc" = {
      text =
        builtins.replaceStrings [ "$PYPI_API_TOKEN" ] [ secrets.pypiApiToken ]
        (builtins.readFile ./files/.pypirc);
    };
  };
}
