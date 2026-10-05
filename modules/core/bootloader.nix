{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.boot.lanzaboote;
  imagesPerGeneration = 1 + builtins.length (builtins.attrNames config.specialisation);
in
{
  imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

  environment.systemPackages = [ pkgs.sbctl ];

  assertions = [
    {
      assertion =
        !(cfg.measuredBoot.enable && builtins.elem 4 cfg.measuredBoot.pcrs)
        || (
          cfg.configurationLimit != null
          && cfg.configurationLimit > 0
          && 2 * cfg.configurationLimit * imagesPerGeneration <= 8
        );
      message = ''
        Measured boot with PCR 4 must allow at most eight alternatives, including
        both bootloader versions and every specialisation. Reduce
        boot.lanzaboote.configurationLimit or the number of specialisations.
      '';
    }
  ];

  boot = {
    loader = {
      systemd-boot = {
        enable = false;
        configurationLimit = 10;
      };
      efi.canTouchEfiVariables = true;
    };

    lanzaboote = {
      enable = true;
      # Two bootloader versions × two generations × two kernel choices = eight
      # PCR 4 alternatives. Lanzaboote keeps the booted generation within this limit.
      configurationLimit = lib.mkDefault 2;
      pkiBundle = "/var/lib/sbctl";
      autoEnrollKeys = {
        enable = true;
        autoReboot = false;
      };
    };
  };
}
