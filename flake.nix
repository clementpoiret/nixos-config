{
  description = "Clement's nixos configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/release-26.05";
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";

    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";

    ucodenix.url = "github:e-tho/ucodenix";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niri = {
      # url = "github:sodiboo/niri-flake";
      url = "github:sodiboo/niri-flake/e43ef13f23c2c7ae5b10e842745cb345faff4f40"; # 26.04
      inputs.nixpkgs.follows = "nixpkgs";
    };

    bash-env-json = {
      url = "github:tesujimath/bash-env-json/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    glide-browser = {
      url = "github:glide-browser/glide.nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    bibli-ls.url = "github:clementpoiret/bibli-ls/fix/flake";

    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # hyprquickshot = {
    #   url = "github:JamDon2/hyprquickshot";
    #   flake = false;
    # };
    # quickshell = {
    #   url = "git+https://git.outfoxxed.me/quickshell/quickshell?rev=783c953987dc56ff0601abe6845ed96f1d00495a";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
    dms = {
      url = "github:AvengeMedia/DankMaterialShell/stable";
      inputs.nixpkgs.follows = "nixpkgs";
      # inputs.quickshell.follows = "quickshell";
    };
    ghosttyshaders = {
      url = "github:sahaj-b/ghostty-cursor-shaders";
      flake = false;
    };

    superfile = {
      url = "github:yorukot/superfile/v1.4.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    antigravity = {
      url = "github:Hy4ri/antigravity-flake";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };
    claude-code = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };
    codex-cli = {
      url = "github:sadjow/codex-cli-nix";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };
    codex-desktop-linux = {
      url = "github:ilysenko/codex-desktop-linux";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };

    ki-editor = {
      url = "github:ki-editor/ki-editor";
      # inputs.nixpkgs.follows = "nixpkgs-stable";
    };

    # brave-origin = {
    #   url = "github:clementpoiret/brave-origin-flake";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
    orion-browser.url = "github:dokokitsune/orion-browser-flake";

    helium = {
      url = "github:schembriaiden/helium-browser-nix-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,

      antigravity,
      bash-env-json,
      bibli-ls,
      # brave-origin,
      claude-code,
      codex-cli,
      glide-browser,
      helium,
      home-manager,
      ki-editor,
      orion-browser,
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
        antigravity-cli = antigravity.packages.${system}.antigravity-cli;
        antigravity-ide = antigravity.packages.${system}.antigravity-ide;
        bash-env-json = bash-env-json.packages.${system}.default;
        bibli-ls = bibli-ls.packages.${system}.default;
        # brave-origin-beta = brave-origin.packages.${system}.brave-origin-beta;
        claude-code = claude-code.packages.${system}.default;
        codex-cli = codex-cli.packages.${system}.default;
        glide-browser = glide-browser.packages.${system}.default;
        helium = helium.packages.${system}.default;
        ki-editor = ki-editor.packages.${system}.default;
        orion-browser = orion-browser.packages.${system}.default;
        superfile = superfile.packages.${system}.default;
        zen-browser = zen-browser.packages.${system}.default;
      };

      optimizedPackagesOverlay = final: prev: {
        # DE-related

        #   hyprland = prev.hyprland.overrideAttrs (old: {
        #     NIX_CFLAGS_COMPILE = (old.NIX_CFLAGS_COMPILE or "") + " -march=native";
        #   });
        #   xdg-desktop-portal-hyprland = prev.xdg-desktop-portal-hyprland.overrideAttrs (old: {
        #     NIX_CFLAGS_COMPILE = (old.NIX_CFLAGS_COMPILE or "") + " -march=native";
        #   });
        #   hyprcursor = prev.hyprcursor.overrideAttrs (old: {
        #     NIX_CFLAGS_COMPILE = (old.NIX_CFLAGS_COMPILE or "") + " -march=native";
        #   });
        #   hyprpicker = prev.hyprpicker.overrideAttrs (old: {
        #     NIX_CFLAGS_COMPILE = (old.NIX_CFLAGS_COMPILE or "") + " -march=native";
        #   });
        #   hyprlock = prev.hyprlock.overrideAttrs (old: {
        #     NIX_CFLAGS_COMPILE = (old.NIX_CFLAGS_COMPILE or "") + " -march=native";
        #   });
        #   hypridle = prev.hypridle.overrideAttrs (old: {
        #     NIX_CFLAGS_COMPILE = (old.NIX_CFLAGS_COMPILE or "") + " -march=native";
        #   });
        #   hyprsunset = prev.hyprsunset.overrideAttrs (old: {
        #     NIX_CFLAGS_COMPILE = (old.NIX_CFLAGS_COMPILE or "") + " -march=native";
        #   });
        #   waybar = prev.waybar.overrideAttrs (old: {
        #     NIX_CFLAGS_COMPILE = (old.NIX_CFLAGS_COMPILE or "") + " -march=native";
        #   });
      };

      customOverlays = [
        (final: prev: {
          # glide = pkgs-glide;
          # Keep master as an explicit escape hatch for fixes not yet in unstable.
          master = pkgs-master;
          stable = pkgs-stable;
          flake = pkgs-flake;
        })
        optimizedPackagesOverlay
        niri.overlays.niri
        nix-cachyos-kernel.overlays.pinned
      ];

      mkHost = import ./lib/mkHost.nix {
        inherit
          customOverlays
          inputs
          nixpkgs
          self
          stylix
          system
          username
          ;
      };
    in
    {
      overlays.default = selfPkgs.overlay;

      # nix-switch
      nixosConfigurations = {
        desktop = mkHost { host = "desktop"; };
        laptop = mkHost { host = "laptop"; };
      };
    };
}
