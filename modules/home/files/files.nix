{
  config,
  lib,
  pkgs,
  ...
}:
let
  writePypirc = pkgs.writeShellScript "write-pypirc" ''
    set -eu

    token_file=${lib.escapeShellArg config.sops.secrets."api_keys/pypi".path}
    target="''${HOME}/.pypirc"
    tmp="''${target}.tmp"

    ${pkgs.gnused}/bin/sed \
      "s|\\$PYPI_API_TOKEN|$(tr -d '\r\n' < "$token_file")|g" \
      ${lib.escapeShellArg ./files/.pypirc} > "$tmp"
    chmod 600 "$tmp"
    mv "$tmp" "$target"
  '';
in
{
  systemd.user.services.write-pypirc = {
    Unit = {
      Description = "Write .pypirc generated from sops secrets";
      After = [ "sops-nix.service" ];
      Requires = [ "sops-nix.service" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${writePypirc}";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
