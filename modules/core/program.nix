{ pkgs, ... }:
{
  programs.dconf.enable = true;
  programs.zsh.enable = true;

  services.udev.packages = with pkgs; [
    libfido2
    qmk-udev-rules
    yubikey-personalization
  ];
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = false;
    # pinentryFlavor = "qt";
    # pinentryPackage = pkgs.pinentry-qt;
  };
  services.pcscd.enable = true;

  environment.systemPackages = with pkgs; [
    kdePackages.ksshaskpass
    kdePackages.kwallet
    kdePackages.kwalletmanager
    kdePackages.kwallet-pam
  ];

  programs.ssh = {
    # enableAskPassword = true;
    # askPassword = "${pkgs.lxqt.lxqt-openssh-askpass}/bin/lxqt-openssh-askpass";
    # startAgent = true;
    askPassword = "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";
  };

  environment.variables = {
    EDITOR = "hx";
    SSH_ASKPASS_REQUIRE = "prefer";
  };
}
