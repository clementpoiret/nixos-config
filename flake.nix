{
  description = "FrostPhoenix's nixos configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    nur.url = "github:nix-community/NUR";

    ucodenix.url = "github:e-tho/ucodenix";

    alejandra.url = "github:kamadorueda/alejandra/3.0.0";

    hyprland = {
      #url = "github:hyprwm/Hyprland";
      url = "github:hyprwm/Hyprland/v0.45.2?submodules=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hypr-contrib.url = "github:hyprwm/contrib";
    hyprcursor = {
      url = "github:hyprwm/hyprcursor";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprpicker = {
      url = "github:hyprwm/hyprpicker";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprsunset = {
      url = "github:hyprwm/hyprsunset";
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

    spicetify-nix = {
      url = "github:gerg-l/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    bash-env-json = {
      url = "github:tesujimath/bash-env-json/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser.url = "github:0xc000022070/zen-browser-flake";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      alejandra,
      chaotic,
      nixpkgs,
      bash-env-json,
      nixpkgs-master,
      self,
      home-manager,
      zen-browser,
      ...
    }@inputs:
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
      pkgs-flake = {
        alejandra = alejandra.defaultPackage.${system};
        bash-env-json = bash-env-json.packages.${system}.default;
        zen-browser = zen-browser.packages.${system}.specific;
      };

      customOverlays = [
        (final: prev: {
          master = pkgs-master;
          flake = pkgs-flake;
        })
      ];

      lib = nixpkgs.lib;
    in
    {
      overlays.default = selfPkgs.overlay;

      # niz-switch
      nixosConfigurations = {
        desktop = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            { nixpkgs.overlays = customOverlays; }
            ./hosts/desktop
            chaotic.nixosModules.default
          ];
          specialArgs = {
            host = "desktop";
            inherit self inputs username;
          };
        };
        laptop = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            { nixpkgs.overlays = customOverlays; }
            ./hosts/laptop
            chaotic.nixosModules.default
          ];
          specialArgs = {
            host = "laptop";
            inherit self inputs username;
          };
        };
      };

      # home-manager switch --flake .#clementpoiret@desktop --impure
      homeConfigurations = {
        "clementpoiret@desktop" = home-manager.lib.homeManagerConfiguration {
          pkgs = pkgs;
          #useUserPackages = true;
          #useGlobalPkgs = true;
          extraSpecialArgs = {
            inherit self inputs username;
            host = "desktop";
          };
          modules = [
            { nixpkgs.overlays = customOverlays; }
            (import ./home-manager)
          ];
        };
        "clementpoiret@laptop" = home-manager.lib.homeManagerConfiguration {
          pkgs = pkgs;
          #useUserPackages = true;
          #useGlobalPkgs = true;
          extraSpecialArgs = {
            inherit self inputs username;
            host = "laptop";
          };
          modules = [
            { nixpkgs.overlays = customOverlays; }
            (import ./home-manager)
          ];
        };
      };
    };
}
