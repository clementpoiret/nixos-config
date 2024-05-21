{ pkgs, ... }: 
{
  programs.dconf.enable = true;
  programs.zsh.enable = true;

  services.udev.packages = [ pkgs.yubikey-personalization ];
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    # pinentryFlavor = "";
  };
}
