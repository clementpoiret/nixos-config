{ self, pkgs, lib, inputs, ... }: {
  # imports = [ inputs.nix-gaming.nixosModules.default ];
  nix = {
    settings = {
      auto-optimise-store = true;
      experimental-features = [ "nix-command" "flakes" ];
      plugin-files = "${pkgs.nix-plugins}/lib/nix/plugins";
      extra-builtins-file = [ ../../libs/extra-builtins.nix ];
      substituters = [
        "https://nix-community.cachix.org"
        "https://nix-gaming.cachix.org"
        "https://cuda-maintainers.cachix.org"
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
        "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
      ];
      trusted-users = [ "root" "clementpoiret" ];
    };
  };
  nixpkgs = { overlays = [ self.overlays.default inputs.nur.overlay ]; };

  environment.systemPackages = with pkgs; [ wget git ];

  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [ stdenv.cc.cc ];
  };

  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = "en_US.UTF-8";
  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "24.05";
}
