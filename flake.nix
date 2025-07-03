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

    bibli-ls.url = "github:clementpoiret/bibli-ls/fix/flake";

    ghostty = {
      url = "github:ghostty-org/ghostty";
    };
  };

  outputs =
    {
      self,

      alejandra,
      bash-env-json,
      bibli-ls,
      chaotic,
      fw-fanctrl,
      ghostty,
      home-manager,
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
        ghostty = ghostty.packages.${system}.default;
        zen-browser = zen-browser.packages.${system}.default;
      };

      optimizedPackagesOverlay = final: prev: {
        # DE-related
        hyprland = prev.hyprland.overrideAttrs (old: {
          NIX_CFLAGS_COMPILE = (old.NIX_CFLAGS_COMPILE or "") + " -march=native";
        });
        xdg-desktop-portal-hyprland = prev.xdg-desktop-portal-hyprland.overrideAttrs (old: {
          NIX_CFLAGS_COMPILE = (old.NIX_CFLAGS_COMPILE or "") + " -march=native";
        });
        hyprcursor = prev.hyprcursor.overrideAttrs (old: {
          NIX_CFLAGS_COMPILE = (old.NIX_CFLAGS_COMPILE or "") + " -march=native";
        });
        hyprpicker = prev.master.hyprpicker.overrideAttrs (old: {
          NIX_CFLAGS_COMPILE = (old.NIX_CFLAGS_COMPILE or "") + " -march=native";
        });
        hyprlock = prev.hyprlock.overrideAttrs (old: {
          NIX_CFLAGS_COMPILE = (old.NIX_CFLAGS_COMPILE or "") + " -march=native";
        });
        hypridle = prev.hypridle.overrideAttrs (old: {
          NIX_CFLAGS_COMPILE = (old.NIX_CFLAGS_COMPILE or "") + " -march=native";
        });
        hyprsunset = prev.master.hyprsunset.overrideAttrs (old: {
          NIX_CFLAGS_COMPILE = (old.NIX_CFLAGS_COMPILE or "") + " -march=native";
        });
        waybar = prev.waybar.overrideAttrs (old: {
          NIX_CFLAGS_COMPILE = (old.NIX_CFLAGS_COMPILE or "") + " -march=native";
        });
      };

      customOverlays = [
        (final: prev: {
          master = pkgs-master;
          stable = pkgs-stable;
          flake = pkgs-flake;
        })
        optimizedPackagesOverlay
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
