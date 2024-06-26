{
  description = "FrostPhoenix's nixos configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    nur.url = "github:nix-community/NUR";

    hypr-contrib.url = "github:hyprwm/contrib";
    hyprpicker.url = "github:hyprwm/hyprpicker";
  
    alejandra.url = "github:kamadorueda/alejandra/3.0.0";
  
    hyprland = {
      #url = "github:hyprwm/Hyprland";
      url = "git+https://github.com/hyprwm/Hyprland?submodules=1";
      # url = "github:hyprwm/Hyprland/fe7b748";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    qbpm = {
      url = github:pvsr/qbpm;
      inputs.nixpkgs.follows = "nixpkgs";
    };
  
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin-bat = {
      url = "github:catppuccin/bat";
      flake = false;
    };
    catppuccin-cava = {
      url = "github:catppuccin/cava";
      flake = false;
    };

    secrets = {
      url = "git+ssh://git@github.com/clementpoiret/nix-secrets.git";
      flake = false;
    };
  };

  outputs = { nixpkgs, nixpkgs-master, self, secrets, ...} @ inputs:
  let
    selfPkgs = import ./pkgs;
    username = "clementpoiret";
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
    pkgs-master = import nixpkgs-master {
      inherit system;
      config.allowUnfree = true;
    };

    lib = nixpkgs.lib;
  in
  {
    overlays.default = selfPkgs.overlay;
    nixosConfigurations = {
      desktop = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          {
            nixpkgs.overlays = [
              (final: prev: {
                # master = nixpkgs-master.legacyPackages.${prev.system};
                master = pkgs-master;
              })
            ];
          }
          (import ./hosts/desktop)
        ];
        specialArgs = { host="desktop"; inherit self inputs username ; };
      };
      laptop = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          {
            nixpkgs.overlays = [
              (final: prev: {
                master = pkgs-master;
              })
            ];
          }
          (import ./hosts/laptop)
        ];
        specialArgs = { host="laptop"; inherit self inputs username ; };
      };
    };
  };
}
