{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.xwayland-satellite ];
}
