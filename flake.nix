{
  description = "FrostPhoenix's nixos configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/release-24.11";
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    nur.url = "github:nix-community/NUR";

    fw-fanctrl = {
      url = "github:TamtamHero/fw-fanctrl/packaging/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ucodenix.url = "github:e-tho/ucodenix";

    alejandra = {
      url = "github:kamadorueda/alejandra/3.1.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland = {
      # url = "github:hyprwm/Hyprland/?submodules=1";
      url = "github:hyprwm/Hyprland/v0.47.1?submodules=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hypr-contrib.url = "github:hyprwm/contrib";
    hyprcursor = {
      url = "github:hyprwm/hyprcursor";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprlock = {
      url = "github:hyprwm/hyprlock";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hypridle = {
      url = "github:hyprwm/hypridle";
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

    # TODO: Remove once fixed
    espanso-fix.url = "github:pitkling/nixpkgs/espanso-fix-capabilities-export";

    bibli-ls.url = "github:clementpoiret/bibli-ls/fix/flake";
  };

  outputs =
    {
      self,

      alejandra,
      bash-env-json,
      bibli-ls,
      chaotic,
      espanso-fix,
      fw-fanctrl,
      home-manager,
      hyprlock,
      nixpkgs,
      nixpkgs-master,
      nixpkgs-stable,
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
      pkgs-stable = import nixpkgs-stable {
        inherit system;
        config.allowUnfree = true;
      };
      pkgs-flake = {
        alejandra = alejandra.defaultPackage.${system};
        bash-env-json = bash-env-json.packages.${system}.default;
        bibli-ls = bibli-ls.packages.${system}.default;
        hyprlock = hyprlock.packages.${system}.default;
        zen-browser = zen-browser.packages.${system}.default;
      };

      customOverlays = [
        (final: prev: {
          master = pkgs-master;
          stable = pkgs-stable;
          flake = pkgs-flake;
        })
      ];
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
            espanso-fix.nixosModules.espanso-capdacoverride
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
            fw-fanctrl.nixosModules.default
            chaotic.nixosModules.default
            espanso-fix.nixosModules.espanso-capdacoverride
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
