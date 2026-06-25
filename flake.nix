{
  description = "Clement's nixos configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/release-26.05";
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";

    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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

    glide-browser = {
      url = "github:glide-browser/glide.nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    bibli-ls = {
      url = "github:clementpoiret/bibli-ls/fix/flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dms = {
      url = "github:AvengeMedia/DankMaterialShell/stable";
      inputs.nixpkgs.follows = "nixpkgs";
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

    orion-browser = {
      url = "github:dokokitsune/orion-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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
      claude-code,
      codex-cli,
      glide-browser,
      helium,
      home-manager,
      orion-browser,
      niri,
      nix-cachyos-kernel,
      nixos-hardware,
      nixpkgs,
      nixpkgs-master,
      nixpkgs-stable,
      stylix,
      superfile,
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
      pkgs-flake = {
        antigravity-cli = antigravity.packages.${system}.antigravity-cli;
        antigravity-ide = antigravity.packages.${system}.antigravity-ide;
        bash-env-json = bash-env-json.packages.${system}.default;
        bibli-ls = bibli-ls.packages.${system}.default;
        claude-code = claude-code.packages.${system}.default;
        codex-cli = codex-cli.packages.${system}.default;
        glide-browser = glide-browser.packages.${system}.default;
        helium = helium.packages.${system}.default;
        orion-browser = orion-browser.packages.${system}.default;
        superfile = superfile.packages.${system}.default;
      };

      customOverlays = [
        (final: prev: {
          # Keep master as an explicit escape hatch for fixes not yet in unstable.
          master = pkgs-master;
          stable = pkgs-stable;
          flake = pkgs-flake;
        })
        niri.overlays.niri
        nix-cachyos-kernel.overlays.pinned
      ];

      pkgs-unstable = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = customOverlays;
      };

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

      formatter.${system} = pkgs-stable.writeShellApplication {
        name = "nixfmt-tree";
        runtimeInputs = with pkgs-stable; [
          findutils
          nixfmt
        ];
        text = ''
          if [ "$#" -eq 0 ]; then
            set -- .
          fi

          find "$@" -name '*.nix' -type f -not -path '*/.git/*' -not -path './secrets/*' -not -path 'secrets/*' -print0 | xargs -0 -r nixfmt
        '';
      };

      devShells.${system} = {
        default = pkgs-stable.mkShellNoCC {
          packages = with pkgs-stable; [
            deadnix
            nil
            nixfmt
            statix
          ];
        };

        ml-rocm =
          let
            python = pkgs-unstable.python312;
            wheelRuntimeLibPath = pkgs-unstable.lib.makeLibraryPath (
              with pkgs-unstable;
              [
                bzip2
                libdrm
                libelf
                numactl
                stdenv.cc.cc.lib
                xz
                zlib
                zstd
              ]
            );
            rocmSmi = pkgs-unstable.writeShellScriptBin "rocm-smi" ''
              export LD_LIBRARY_PATH="${wheelRuntimeLibPath}''${LD_LIBRARY_PATH:+:}''${LD_LIBRARY_PATH:-}"
              exec ${pkgs-unstable.rocmPackages.rocm-smi}/bin/rocm-smi "$@"
            '';
          in
          pkgs-unstable.mkShell {
            packages = [
              python
              pkgs-unstable.uv
              pkgs-unstable.clinfo
              pkgs-unstable.rocmPackages.rocminfo
              rocmSmi
            ];

            LD_LIBRARY_PATH = wheelRuntimeLibPath;
            PYTHONNOUSERSITE = "1";
            ROCM_JAX_WHEELHOUSE_URL = "https://github.com/ROCm/rocm-jax/releases/download/rocm-jax-v0.9.1/wheelhouse_post5_generic_archs_theRock7.12.zip";
            PYTORCH_ROCM_INDEX_URL = "https://download.pytorch.org/whl/rocm7.2";
            UV_LINK_MODE = "copy";
            ROCR_VISIBLE_DEVICES = "0";
            HIP_VISIBLE_DEVICES = "0";
            GPU_DEVICE_ORDINAL = "0";
          };
      };

      nixosConfigurations = {
        desktop = mkHost { host = "desktop"; };
        laptop = mkHost {
          host = "laptop";
          extraModules = [ nixos-hardware.nixosModules.framework-16-7040-amd ];
        };
      };

      checks.${system} = {
        desktop-toplevel = self.nixosConfigurations.desktop.config.system.build.toplevel;
        laptop-toplevel = self.nixosConfigurations.laptop.config.system.build.toplevel;
      };
    };
}
