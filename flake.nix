{
  description = "FrostPhoenix's nixos configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
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

    # qbpm = {
    #   url = "github:pvsr/qbpm";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

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

    nu_plugin_bash_env = {
      url = "github:tesujimath/nu_plugin_bash_env/refs/tags/0.16.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # zen-browser.url = "github:MarceColl/zen-browser-flake";
    zen-browser.url = "github:0xc000022070/zen-browser-flake";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { alejandra, chaotic, nixpkgs, nu_plugin_bash_env, nixpkgs-master
    , self, home-manager, zen-browser, ... }@inputs:
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
        nu_plugin_bash_env = nu_plugin_bash_env.packages.${system}.default;
        zen-browser = zen-browser.packages."${system}".specific;
      };

      customOverlays = [
        (final: prev: {
          master = pkgs-master;
          flake = pkgs-flake;
        })
      ];

      lib = nixpkgs.lib;
    in {
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
          modules =
            [ { nixpkgs.overlays = customOverlays; } (import ./home-manager) ];
        };
        "clementpoiret@laptop" = home-manager.lib.homeManagerConfiguration {
          pkgs = pkgs;
          #useUserPackages = true;
          #useGlobalPkgs = true;
          extraSpecialArgs = {
            inherit self inputs username;
            host = "laptop";
          };
          modules =
            [ { nixpkgs.overlays = customOverlays; } (import ./home-manager) ];
        };
      };
    };
}
