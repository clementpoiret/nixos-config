{ config, inputs, pkgs, ... }:
let
  home = config.home.homeDirectory;
  token = builtins.readFile config.sops.secrets."api_keys/pypi".path;
in {
  home.file = {
    ".pypirc" = {
      text = builtins.replaceStrings [ "$PYPI_API_TOKEN" ] [ token ]
        (builtins.readFile ./files/.pypirc);
    };
  };
}
