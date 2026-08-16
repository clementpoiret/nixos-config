{
  self,
  lib,
  pkgs,
  username,
  ...
}:
{
  nix = {
    settings = {
      auto-optimise-store = true;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      substituters = [
        "https://nix-community.cachix.org"
        "https://niri.cachix.org"
        "https://nixpkgs-python.cachix.org"
        "https://nix-gaming.cachix.org"
        "https://cuda-maintainers.cachix.org"
        "https://devenv.cachix.org"
        "https://attic.xuyh0120.win/lantian"
        "https://clementpoiret.cachix.org"
        "https://pi.cachix.org"
      ];
      trusted-public-keys = [
        "nixpkgs-python.cachix.org-1:hxjI7pFxTyuTHn2NkvWCrAUcNZLNS3ZAvfYNuYifcEU="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
        "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
        "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
        "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
        "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
        "clementpoiret.cachix.org-1:+W8ndoDBppOP0zcLzkPYSCH6j3kKNH4ckfJCQ138PZo="
        "pi.cachix.org-1:lGeoGJaZ5ZDabuRzkcD5EBTNnDM4HJ1vqeOxlWk1Flk="
      ];
      sandbox = true;
      require-sigs = true;
      accept-flake-config = false;
      # NixOS adds root itself, but force the complete trust boundary so
      # imported modules cannot silently grant daemon-level trust to others.
      trusted-users = lib.mkForce [ "root" ];
      allowed-users = [
        "root"
        username
      ];
    };
  };
  nixpkgs = {
    overlays = [
      self.overlays.default
    ];
  };

  environment.systemPackages = with pkgs; [
    wget
    git
  ];

  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [ stdenv.cc.cc ];
  };

  # Optional strict trial. Enable only in a separate generation after testing
  # every persistent daemon and graphical/development workload.
  # environment.memoryAllocator.provider = "graphene-hardened-light";

  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = "en_US.UTF-8";
  nixpkgs.config = {
    allowUnfree = true;
    allowUnfreePredicate = true;
  };

  # To prevent getting stuck at shutdown.
  systemd.settings.Manager = {
    DefaultIOAccounting = true;
    DefaultIPAccounting = true;
    DefaultTimeoutStopSec = "10s";
  };

  system.stateVersion = "26.05";
}
