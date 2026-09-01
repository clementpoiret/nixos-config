{ inputs, pkgs, ... }:
let
  linkctlPackage = inputs.linkctl.packages.${pkgs.stdenv.hostPlatform.system}.linkctl;
in
{
  environment.systemPackages = [ linkctlPackage ];

  programs.dconf.enable = true;
  programs.fish.enable = true;

  services.udev.packages = [
    linkctlPackage
    pkgs.libfido2
    pkgs.yubikey-personalization
  ];
  systemd.packages = [ linkctlPackage ];

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = false;
    # pinentryFlavor = "qt";
    # pinentryPackage = pkgs.pinentry-qt;
  };
  programs.yubikey-touch-detector = {
    enable = true;
    libnotify = true;
  };
  services.pcscd.enable = true;

  programs.ssh = {
    enableAskPassword = true;
    askPassword = "${pkgs.seahorse}/libexec/seahorse/ssh-askpass";
    # startAgent = true;
    # askPassword = "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";
  };

  environment.variables = {
    EDITOR = "hx";
    SSH_ASKPASS_REQUIRE = "prefer";
  };
}
