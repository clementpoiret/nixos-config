{
  description = "Clement's nixos configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";

    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # v1.1.0 predates autoEnrollKeys.includeFirmwareBuiltinKeys, which the
    # Framework laptop needs to retain its OEM certificates. TODO: Pin the
    # first stable release after v1.1.0 once it includes this option.
    lanzaboote = {
      url = "github:nix-community/lanzaboote/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ucodenix.url = "github:e-tho/ucodenix";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    linkctl.url = "github:clementpoiret/linkctl";

    niri = {
      # url = "github:sodiboo/niri-flake";
      url = "github:sodiboo/niri-flake/e43ef13f23c2c7ae5b10e842745cb345faff4f40"; # 26.04
      # Match the package set built by niri.cachix.org.
      inputs.nixpkgs.url = "github:NixOS/nixpkgs/0726a0ecb6d4e08f6adced58726b95db924cef57";
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

    # bibli-ls = {
    #   url = "github:clementpoiret/bibli-ls/fix/flake";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

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
      url = "github:yorukot/superfile/v1.6.0";
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
    clementpoiret-skills = {
      url = "github:clementpoiret/skills";
      flake = false;
    };
    codex-desktop-linux = {
      url = "github:ilysenko/codex-desktop-linux";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };
    pi = {
      url = "github:lukasl-dev/pi.nix";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };

    herdr = {
      url = "github:herdrdev/herdr/v0.8.2";
    };

    # orion-browser = {
    #   url = "github:dokokitsune/orion-browser-flake";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

    # helium = {
    #   url = "github:schembriaiden/helium-browser-nix-flake";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
  };

  outputs =
    {
      self,

      antigravity,
      bash-env-json,
      # bibli-ls,
      claude-code,
      codex-cli,
      glide-browser,
      # helium,
      herdr,
      home-manager,
      # orion-browser,
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
      agentContainerTools = pkgs-stable.callPackage ./pkgs/agent-container-tools { };
      wrapAgent =
        name: upstream:
        upstream.overrideAttrs (oldAttrs: {
          postFixup = (oldAttrs.postFixup or "") + ''
            wrapProgram "$out/bin/${name}" \
              --prefix PATH : ${agentContainerTools}/bin \
              --set-default HERDR_AGENT ${name}
          '';
        });
      pkgs-flake = {
        agent-container-tools = agentContainerTools;
        antigravity-cli = antigravity.packages.${system}.antigravity-cli;
        antigravity-ide = antigravity.packages.${system}.antigravity-ide;
        bash-env-json = bash-env-json.packages.${system}.default;
        # bibli-ls = bibli-ls.packages.${system}.default;
        claude-code = wrapAgent "claude" claude-code.packages.${system}.default;
        codex-cli = wrapAgent "codex" codex-cli.packages.${system}.default;
        glide-browser = glide-browser.packages.${system}.default;
        # helium = helium.packages.${system}.default;
        herdr = herdr.packages.${system}.default;
        niri-unstable = niri.packages.${system}.niri-unstable;
        # orion-browser = orion-browser.packages.${system}.default;
        superfile = superfile.packages.${system}.default;
      };

      customOverlays = [
        (final: prev: {
          # Keep master as an explicit escape hatch for fixes not yet in unstable.
          master = pkgs-master;
          stable = pkgs-stable;
          flake = pkgs-flake;

          # The pinned niri-flake package still requires libdisplay-info 0.2.
          libdisplay-info_0_2 = pkgs-stable.libdisplay-info_0_2;
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

      packages.${system} =
        let
          mkHostEntries =
            hostName:
            let
              cfg = self.nixosConfigurations.${hostName};
              kernel = cfg.config.boot.kernelPackages.kernel;
              virtualbox =
                pkgs-unstable.lib.findFirst (package: pkgs-unstable.lib.getName package == "virtualbox")
                  (throw "virtualbox is missing from ${hostName} environment.systemPackages")
                  cfg.config.environment.systemPackages;
              virtualboxExtensionPack =
                if (virtualbox.extensionPack or null) != null then
                  virtualbox.extensionPack
                else
                  throw "virtualbox extension pack is missing for ${hostName}";
            in
            [
              {
                name = "${hostName}-ghostty";
                path = cfg.pkgs.ghostty-host;
              }
              {
                name = "${hostName}-herdr";
                path = cfg.pkgs.flake.herdr;
              }
              {
                name = "${hostName}-niri";
                path = cfg.pkgs.niri-host;
              }
              {
                name = "${hostName}-quickshell";
                path = cfg.pkgs.quickshell-host;
              }
              {
                name = "${hostName}-virtualbox";
                path = virtualbox;
              }
              {
                name = "${hostName}-virtualbox-extpack";
                path = virtualboxExtensionPack;
              }
              {
                name = "${hostName}-kernel";
                path = kernel.out;
              }
              {
                name = "${hostName}-kernel-dev";
                path = kernel.dev;
              }
              {
                name = "${hostName}-kernel-modules";
                path = kernel.modules;
              }
              {
                name = "${hostName}-modules-tree";
                path = cfg.config.system.modulesTree;
              }
            ]
            ++ pkgs-unstable.lib.optional (hostName == "desktop") {
              name = "desktop-nvidia-settings";
              path = cfg.config.hardware.nvidia.package.settings;
            };

          desktopCacheEntries = mkHostEntries "desktop";
          laptopCacheEntries = mkHostEntries "laptop";
          mkCacheRoot = name: entries: pkgs-unstable.linkFarm name entries;
        in
        {
          cache-root-desktop = mkCacheRoot "nixos-config-cache-root-desktop" desktopCacheEntries;
          cache-root-laptop = mkCacheRoot "nixos-config-cache-root-laptop" laptopCacheEntries;
          cache-root = mkCacheRoot "nixos-config-cache-root" (desktopCacheEntries ++ laptopCacheEntries);
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
            # JAX ROCm plugin runtime libraries. Use the stable input here
            # because the current unstable/master MIOpen output is not cached,
            # while stable MIOpen 7.2.3 is available from cache.nixos.org.
            jaxNixRocmLibs = with pkgs-unstable.stable.rocmPackages; [
              hipblaslt
              hipfft
              miopen
              rccl
              rocm-smi
              rocprofiler-sdk
              roctracer
            ];
            mlRuntimeLibPath = pkgs-unstable.lib.makeLibraryPath (
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
              ++ jaxNixRocmLibs
            );
            rocmSmi = pkgs-unstable.writeShellScriptBin "rocm-smi" ''
              export LD_LIBRARY_PATH="${mlRuntimeLibPath}''${LD_LIBRARY_PATH:+:}''${LD_LIBRARY_PATH:-}"
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

            LD_LIBRARY_PATH = mlRuntimeLibPath;
            PYTHONNOUSERSITE = "1";
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

      checks.${system} = import ./tests/flake-checks.nix {
        inherit
          self
          pkgs-unstable
          username
          home-manager
          nixos-hardware
          mkHost
          selfPkgs
          ;
      };
    };
}
