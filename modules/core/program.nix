{ pkgs, ... }: 
{
  programs.dconf.enable = true;
  programs.zsh.enable = true;

  services.udev.packages = [ pkgs.yubikey-personalization ];
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    # pinentryFlavor = "qt";
    # pinentryPackage = pkgs.pinentry-qt;
  };
  services.pcscd.enable = true;

  environment.systemPackages = with pkgs; [
    #lxqt.lxqt-openssh-askpass
    seahorse
  ];

  programs.ssh = {
    enableAskPassword = true;
    # askPassword = "${pkgs.lxqt.lxqt-openssh-askpass}/bin/lxqt-openssh-askpass";
  };
}
