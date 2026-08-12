{
  inputs,
  pkgs,
  ...
}:
{
  imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

  environment.systemPackages = [ pkgs.sbctl ];

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
      pkiBundle = "/var/lib/sbctl";
      autoEnrollKeys = {
        enable = true;
        autoReboot = false;
      };
    };
  };
}
