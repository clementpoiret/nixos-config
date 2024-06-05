{ host, lib, ... }:
{
  services.easyeffects = lib.mkIf (host == "laptop") {
    enable = true;
  };
}
