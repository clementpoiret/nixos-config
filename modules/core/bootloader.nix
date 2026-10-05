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
      # Two bootloader versions × four generations × one kernel choice = eight
      # PCR 4 alternatives. Lanzaboote keeps the booted generation within this limit.
      configurationLimit = lib.mkDefault 4;
      # Retained generations still embed the retired specialisation in boot.json.
      # Skip it during installation so its entries and PCR measurements are collected.
      package = inputs.lanzaboote.packages.${pkgs.stdenv.hostPlatform.system}.lzbt.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./lanzaboote-drop-latest-nixos.patch ];
      });
      pkiBundle = "/var/lib/sbctl";
      autoEnrollKeys = {
        enable = true;
        autoReboot = false;
      };
    };
  };
}
