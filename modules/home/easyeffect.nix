{ host, lib, ... }:
{
  services.easyeffects = lib.mkIf (host == "laptop") {
    enable = true;
    preset = "easyeffect_fw16";
  };
}
