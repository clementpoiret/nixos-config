{ host, lib, ... }:
{
  services.easyeffects = lib.mkIf (host == "laptop") {
    enable = true;
    preset = ../../misc/easyeffect_fw16.json;
  }
}
