{ ... }:
{
  services.xserver.xkb.layout = "fr(ergol)";
  services.libinput.enable = true;

  console.useXkbConfig = true;
}
