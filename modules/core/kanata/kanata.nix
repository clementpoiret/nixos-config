{ ... }:
{
  hardware.uinput.enable = true;
  services.kanata = {
    enable = true;
    keyboards.default = {
      config = (builtins.readFile ./config.kbd);
    };
  };
}
