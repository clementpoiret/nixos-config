{
  description = "Clement's nixos configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";

    nix-cachyos-kernel.url = "github:clementpoiret/nix-cachyos-kernel/release";

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      # v1.2.0 predates protected-system and booted bootloader measurement retention.
      url = "github:nix-community/lanzaboote/4b98333073bdaf9b1b5dd7d87c2dab96883b234e";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ucodenix.url = "github:e-tho/ucodenix";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    linkctl = {
      url = "github:clementpoiret/linkctl";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lumen = {
      url = "github:jnsahaj/lumen";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niri = {
      # url = "github:sodiboo/niri-flake";
      url = "github:sodiboo/niri-flake/e43ef13f23c2c7ae5b10e842745cb345faff4f40"; # 26.04
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-stable.follows = "nixpkgs";
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
    dank-greeter = {
      url = "github:AvengeMedia/dank-greeter";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ghostty = {
      url = "github:ghostty-org/ghostty/v1.4.0";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    ghosttyshaders = {
      url = "github:sahaj-b/ghostty-cursor-shaders";
      flake = false;
    };

    superfile = {
      url = "github:yorukot/superfile/v1.6.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claude-code = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    codex-cli = {
      url = "github:sadjow/codex-cli-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    opencode = {
      url = "github:anomalyco/opencode/v2.2.6";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    clementpoiret-skills = {
      url = "github:clementpoiret/skills";
      flake = false;
    };
    herdr = {
      url = "github:herdrdev/herdr/v0.9.5";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hylki = {
      url = "github:clementpoiret/hylki-flake";
      inputs.nixpkgs.follows = "nixpkgs";
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

      # bibli-ls,
      claude-code,
      codex-cli,
      ghostty,
      # helium,
      herdr,
      home-manager,
      hylki,
      lumen,
      # orion-browser,
      niri,
      nix-cachyos-kernel,
      nixos-hardware,
      nixpkgs,
      nixpkgs-master,
      nixpkgs-stable,
      opencode,
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
      agentContainerTools = pkgs-unstable.callPackage ./pkgs/agent-container-tools { };
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
        # bibli-ls = bibli-ls.packages.${system}.default;
        claude-code = wrapAgent "claude" claude-code.packages.${system}.default;
        codex-cli = wrapAgent "codex" codex-cli.packages.${system}.default;
        ghostty = ghostty.packages.${system}.ghostty-releasefast;
        # helium = helium.packages.${system}.default;
        herdr = herdr.packages.${system}.default;
        hylki = hylki.packages.${system}.default.overrideAttrs (old: {
          buildInputs = old.buildInputs ++ [ pkgs-unstable.sqlite ];
        });
        lumen = lumen.packages.${system}.lumen.overrideAttrs (old: {
          # Nixpkgs' Rust hooks select native libraries instead of vendored copies.
          buildInputs = old.buildInputs ++ [
            pkgs-unstable.libgit2
            pkgs-unstable.zlib
          ];
        });
        opencode = opencode.packages.${system}.default.overrideAttrs (
          old:
          pkgs-unstable.lib.optionalAttrs
            (old.version == "2.2.6+dc2ffcf" && pkgs-unstable.bun.version == "1.4.4")
            {
              # This release's upstream hash differs with Bun 1.4.4; local and CI outputs match.
              node_modules = old.node_modules.override {
                hash = "sha256-O2hF8pGUSArKgYBeP99oOW3iXVVZl5bV5WPTp3E7JIA=";
              };
            }
        );
        # orion-browser = orion-browser.packages.${system}.default;
        superfile = superfile.packages.${system}.default;
      };

      customOverlays = [
        (final: prev: {
          # Keep alternate package sets available for explicit per-package fallbacks.
          master = pkgs-master;
          stable = pkgs-stable;
          flake = pkgs-flake;

          # sphinxHook reads a scalar, not a Bash array, with structured attributes.
          khal = prev.khal.overridePythonAttrs (_: {
            sphinxBuilders = "html man";
          });

          rayburst = prev.rayburst.overrideAttrs (old: {
            # The Rust setup hook forces libsqlite3-sys to use the system library.
            buildInputs = old.buildInputs ++ [ final.sqlite ];
          });

          # The pinned niri-flake package still requires libdisplay-info 0.2.
          libdisplay-info_0_2 = final.callPackage ./pkgs/libdisplay-info_0_2 { };
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

      formatter.${system} = pkgs-unstable.writeShellApplication {
        name = "nixfmt-tree";
        runtimeInputs = with pkgs-unstable; [
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
                name = "${hostName}-herdr-app";
                path = cfg.pkgs.herdr-app;
              }
              {
                name = "${hostName}-hylki";
                path = cfg.pkgs.flake.hylki;
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
                name = "${hostName}-apparmor-profiles";
                path = cfg.config.environment.etc."apparmor.d".source;
              }
            ]
            # The aggregate modules tree would pull the cached kernel into this closure.
            ++ map (package: {
              name = "${hostName}-${pkgs-unstable.lib.getName package}";
              path = package;
            }) cfg.config.boot.extraModulePackages
            ++ pkgs-unstable.lib.optional (hostName == "desktop") {
              name = "desktop-nvidia-settings";
              path = cfg.config.hardware.nvidia.package.settings;
            };

          desktopCacheEntries = mkHostEntries "desktop";
          laptopCacheEntries = mkHostEntries "laptop";
          mkCacheRoot =
            name: entries:
            (pkgs-unstable.linkFarm name entries).overrideAttrs {
              passthru.cachePaths = map (entry: entry.path) entries;
            };
          herdr-core = pkgs-unstable.callPackage ./pkgs/herdr-core { };
        in
        {
          collabora-desktop-bin = pkgs-unstable.callPackage ./pkgs/collabora-desktop-bin { };
          brave = pkgs-unstable.callPackage ./pkgs/brave {
            # Master restored Brave; instantiate its builder with the current package set's libraries.
            upstreamBrave =
              (pkgs-unstable.callPackage "${nixpkgs-master}/pkgs/applications/networking/browsers/brave" { })
              .brave;
          };
          inherit herdr-core;
          herdr-app = pkgs-unstable.callPackage ./pkgs/herdr-app { inherit herdr-core; };
          proton-pass = pkgs-unstable.callPackage ./pkgs/proton-pass { };
          proton-pass-beta = pkgs-unstable.callPackage ./pkgs/proton-pass { channel = "beta"; };
          proton-pass-cli = pkgs-unstable.callPackage ./pkgs/proton-pass-cli { };
          protonmail-bridge = pkgs-unstable.callPackage ./pkgs/protonmail-bridge { };
          protonmail-desktop = pkgs-unstable.callPackage ./pkgs/protonmail-desktop { };
          protonmail-desktop-beta = pkgs-unstable.callPackage ./pkgs/protonmail-desktop { channel = "beta"; };
          cache-root-desktop = mkCacheRoot "nixos-config-cache-root-desktop" desktopCacheEntries;
          cache-root-laptop = mkCacheRoot "nixos-config-cache-root-laptop" laptopCacheEntries;
          cache-root = mkCacheRoot "nixos-config-cache-root" (desktopCacheEntries ++ laptopCacheEntries);
        };

      devShells.${system} = {
        default = pkgs-unstable.mkShellNoCC {
          packages = with pkgs-unstable; [
            deadnix
            nil
            nixfmt
            statix
          ];
        };

        ml-rocm =
          let
            python = pkgs-unstable.python312;
            # Keep JAX's ROCm libraries on the same package set as the diagnostics.
            jaxNixRocmLibs = with pkgs-unstable.rocmPackages; [
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
