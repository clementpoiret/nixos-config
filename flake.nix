{
  description = "FrostPhoenix's nixos configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/release-25.11";
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    # nixpkgs-glide.url = "github:RobertCraigie/nixpkgs/feat/glide-browser";

    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";

    ucodenix.url = "github:e-tho/ucodenix";

    home-manager = {
      # url = "github:clementpoiret/home-manager/push-ozprkkyxykts";
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    bash-env-json = {
      url = "github:tesujimath/bash-env-json/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    glide-browser = {
      url = "github:clementpoiret/glide.nix/push-wzpszsmlkzlo";
      # url = "github:clementpoiret/glide.nix/push-uskuxpzywooy";
      # url = "github:clementpoiret/glide.nix/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # glide-browser.url = "github:glide-browser/glide.nix";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    bibli-ls.url = "github:clementpoiret/bibli-ls/fix/flake";

    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # hyprland.url = "github:hyprwm/Hyprland/v0.50.1";
    hyprquickshot = {
      url = "github:JamDon2/hyprquickshot";
      flake = false;
    };
    dms = {
      url = "github:AvengeMedia/DankMaterialShell/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ghosttyshaders = {
      url = "github:sahaj-b/ghostty-cursor-shaders";
      flake = false;
    };

    superfile.url = "github:yorukot/superfile/v1.4.0";

    jolt.url = "github:clementpoiret/jolt/push-suspqorpmsxk";
    # jolt.url = "github:jordond/jolt/1.1.1";
  };

  outputs =
    {
      self,

      bash-env-json,
      bibli-ls,
      glide-browser,
      home-manager,
      jolt,
      niri,
      nix-cachyos-kernel,
      nixpkgs,
      nixpkgs-master,
      nixpkgs-stable,
      # nixpkgs-glide,
      stylix,
      superfile,
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
      # pkgs-glide = import nixpkgs-glide {
      #   inherit system;
      #   config.allowUnfree = true;
      # };
      pkgs-flake = {
        bash-env-json = bash-env-json.packages.${system}.default;
        bibli-ls = bibli-ls.packages.${system}.default;
        glide-browser = glide-browser.packages.${system}.default;
        jolt = jolt.packages.${system}.default;
        superfile = superfile.packages.${system}.default;
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
        hyprpicker = prev.hyprpicker.overrideAttrs (old: {
          NIX_CFLAGS_COMPILE = (old.NIX_CFLAGS_COMPILE or "") + " -march=native";
        });
        hyprlock = prev.hyprlock.overrideAttrs (old: {
          NIX_CFLAGS_COMPILE = (old.NIX_CFLAGS_COMPILE or "") + " -march=native";
        });
        hypridle = prev.hypridle.overrideAttrs (old: {
          NIX_CFLAGS_COMPILE = (old.NIX_CFLAGS_COMPILE or "") + " -march=native";
        });
        hyprsunset = prev.hyprsunset.overrideAttrs (old: {
          NIX_CFLAGS_COMPILE = (old.NIX_CFLAGS_COMPILE or "") + " -march=native";
        });
        waybar = prev.waybar.overrideAttrs (old: {
          NIX_CFLAGS_COMPILE = (old.NIX_CFLAGS_COMPILE or "") + " -march=native";
        });
      };

      customOverlays = [
        (final: prev: {
          # glide = pkgs-glide;
          master = pkgs-master;
          stable = pkgs-stable;
          flake = pkgs-flake;
        })
        optimizedPackagesOverlay
        niri.overlays.niri
        nix-cachyos-kernel.overlays.pinned
      ];
    in
    {
      overlays.default = selfPkgs.overlay;

      # nix-switch
      nixosConfigurations = {
        desktop = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            { nixpkgs.overlays = customOverlays; }
            ./hosts/desktop
            stylix.nixosModules.stylix
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
            # fw-fanctrl.nixosModules.default
            stylix.nixosModules.stylix
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
          # useUserPackages = true;
          # useGlobalPkgs = true;
          extraSpecialArgs = {
            inherit self inputs username;
            host = "desktop";
          };
          modules = [
            # { nixpkgs.overlays = customOverlays; }
            stylix.homeModules.stylix
            (import ./home-manager)
          ];
        };
        "clementpoiret@laptop" = home-manager.lib.homeManagerConfiguration {
          pkgs = pkgs;
          # useUserPackages = true;
          # useGlobalPkgs = true;
          extraSpecialArgs = {
            inherit self inputs username;
            host = "laptop";
          };
          modules = [
            # { nixpkgs.overlays = customOverlays; }
            stylix.homeModules.stylix
            (import ./home-manager)
          ];
        };
      };
    };
}
