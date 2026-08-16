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
    codex-desktop-linux = {
      url = "github:ilysenko/codex-desktop-linux";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };
    pi = {
      url = "github:lukasl-dev/pi.nix";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };

    herdr = {
      url = "github:herdrdev/herdr/v0.8.0";
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
      # bibli-ls,
      claude-code,
      codex-cli,
      glide-browser,
      helium,
      herdr,
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
        # bibli-ls = bibli-ls.packages.${system}.default;
        claude-code =
          let
            upstream = claude-code.packages.${system}.default;
          in
          upstream.overrideAttrs (oldAttrs: {
            postFixup = (oldAttrs.postFixup or "") + ''
              wrapProgram "$out/bin/claude" \
                --set-default HERDR_AGENT claude
            '';
          });
        codex-cli =
          let
            upstream = codex-cli.packages.${system}.default;
          in
          upstream.overrideAttrs (oldAttrs: {
            postFixup = (oldAttrs.postFixup or "") + ''
              wrapProgram "$out/bin/codex" \
                --set-default HERDR_AGENT codex
            '';
          });
        glide-browser = glide-browser.packages.${system}.default;
        helium = helium.packages.${system}.default;
        herdr = herdr.packages.${system}.default;
        niri-unstable = niri.packages.${system}.niri-unstable;
        orion-browser = orion-browser.packages.${system}.default;
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

      mkAppArmorTestHost =
        mode: profileOverrides:
        mkHost {
          host = "laptop";
          extraModules = [
            nixos-hardware.nixosModules.framework-16-7040-amd
            {
              security.localAppArmor = {
                inherit mode profileOverrides;
              };
            }
          ];
        };

      appArmorTestHosts = {
        disable = mkAppArmorTestHost "disable" { };
        complain = mkAppArmorTestHost "complain" { };
        enforce = mkAppArmorTestHost "enforce" { };
        staged = mkAppArmorTestHost "staged" { };
        override = mkAppArmorTestHost "disable" {
          local-syncthing = "enforce";
        };
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

      checks.${system} = {
        host-cpu-optimizations =
          let
            desktopPkgs = self.nixosConfigurations.desktop.pkgs;
            laptopPkgs = self.nixosConfigurations.laptop.pkgs;
            desktopKernel = self.nixosConfigurations.desktop.config.boot.kernelPackages.kernel;
            laptopKernel = self.nixosConfigurations.laptop.config.boot.kernelPackages.kernel;
            desktopNiriConfig =
              self.nixosConfigurations.desktop.config.home-manager.users.${username}.xdg.configFile."niri-config".source;
            laptopNiriConfig =
              self.nixosConfigurations.laptop.config.home-manager.users.${username}.xdg.configFile."niri-config".source;

            flagsText =
              flags: if builtins.isList flags then pkgs-unstable.lib.concatStringsSep " " flags else flags;
            hasFlag = flag: flags: pkgs-unstable.lib.hasInfix flag (flagsText flags);
            rustFlags =
              package:
              if builtins.isAttrs (package.env or null) && package.env ? RUSTFLAGS then
                package.env.RUSTFLAGS
              else
                package.RUSTFLAGS or "";
            niriUsesBaselineCompletions =
              baseline: package:
              let
                baselineCommand = builtins.unsafeDiscardStringContext "${baseline}/bin/niri completions";
                postInstall = package.postInstall or "";
              in
              pkgs-unstable.lib.hasInfix baselineCommand postInstall
              && !(pkgs-unstable.lib.hasInfix "$out/bin/niri completions" postInstall);
            unwrapConfig = value: if value ? content then unwrapConfig value.content else value;
            configIs = expected: value: ((unwrapConfig value).tristate or null) == expected;
          in
          assert !(desktopPkgs.stdenv.hostPlatform ? gcc.arch);
          assert !(laptopPkgs.stdenv.hostPlatform ? gcc.arch);
          assert hasFlag "-march=znver5" (desktopPkgs.quickshell-host.NIX_CFLAGS_COMPILE or "");
          assert hasFlag "-C target-cpu=znver5" (rustFlags desktopPkgs.flake.herdr);
          assert !(desktopPkgs.flake.herdr.doCheck or true);
          assert !(desktopPkgs.flake.herdr.doInstallCheck or true);
          assert hasFlag "-C target-cpu=znver5" (rustFlags desktopPkgs.niri-host);
          assert !(desktopPkgs.niri-host.doCheck or true);
          assert !(desktopPkgs.niri-host.doInstallCheck or true);
          assert niriUsesBaselineCompletions desktopPkgs.niri-baseline desktopPkgs.niri-host;
          assert
            builtins.map builtins.toString desktopNiriConfig.buildInputs == [
              (builtins.toString desktopPkgs.niri-baseline)
            ];
          assert builtins.elem "-Dcpu=znver5" desktopPkgs.ghostty-host.zigBuildFlags;
          assert builtins.elem "-Dcpu=znver5" desktopPkgs.ghostty-host.zigCheckFlags;
          assert !(desktopPkgs.ghostty-host.doInstallCheck or true);
          assert hasFlag "-march=znver4" (laptopPkgs.quickshell-host.NIX_CFLAGS_COMPILE or "");
          assert hasFlag "-C target-cpu=znver4" (rustFlags laptopPkgs.flake.herdr);
          assert !(laptopPkgs.flake.herdr.doCheck or true);
          assert !(laptopPkgs.flake.herdr.doInstallCheck or true);
          assert desktopPkgs.flake.herdr.drvPath != laptopPkgs.flake.herdr.drvPath;
          assert hasFlag "-C target-cpu=znver4" (rustFlags laptopPkgs.niri-host);
          assert !(laptopPkgs.niri-host.doCheck or true);
          assert !(laptopPkgs.niri-host.doInstallCheck or true);
          assert niriUsesBaselineCompletions laptopPkgs.niri-baseline laptopPkgs.niri-host;
          assert
            builtins.map builtins.toString laptopNiriConfig.buildInputs == [
              (builtins.toString laptopPkgs.niri-baseline)
            ];
          assert desktopPkgs.niri-baseline.drvPath == laptopPkgs.niri-baseline.drvPath;
          assert builtins.elem "-Dcpu=znver4" laptopPkgs.ghostty-host.zigBuildFlags;
          assert builtins.elem "-Dcpu=znver4" laptopPkgs.ghostty-host.zigCheckFlags;
          assert !(laptopPkgs.ghostty-host.doInstallCheck or true);
          assert configIs "y" desktopKernel.structuredExtraConfig.MZEN4;
          assert configIs "n" desktopKernel.structuredExtraConfig.GENERIC_CPU;
          assert configIs "n" desktopKernel.structuredExtraConfig.X86_NATIVE_CPU;
          assert configIs "y" laptopKernel.structuredExtraConfig.MZEN4;
          assert configIs "n" laptopKernel.structuredExtraConfig.GENERIC_CPU;
          assert configIs "n" laptopKernel.structuredExtraConfig.X86_NATIVE_CPU;
          assert desktopKernel.drvPath != laptopKernel.drvPath;
          pkgs-unstable.runCommand "host-cpu-optimizations" { } ''
            touch "$out"
          '';

        apparmor-mode-matrix =
          let
            states =
              hostConfig:
              pkgs-unstable.lib.mapAttrs (_: policy: policy.state) hostConfig.config.security.apparmor.policies;
            allStatesAre =
              expected: hostConfig:
              builtins.all (state: state == expected) (builtins.attrValues (states hostConfig));
            stagedStates = states appArmorTestHosts.staged;
            complainPolicies = appArmorTestHosts.complain.config.security.apparmor.policies;
            enforcePolicies = appArmorTestHosts.enforce.config.security.apparmor.policies;
            disabledSyncthingService = appArmorTestHosts.disable.config.systemd.services.syncthing;
            overrideSyncthingService = appArmorTestHosts.override.config.systemd.services.syncthing;
            laptopConfig = self.nixosConfigurations.laptop.config;
            dnsService = self.nixosConfigurations.laptop.config.systemd.services.apply-secret-dns;
            desktopSyncthingPaths =
              self.nixosConfigurations.desktop.config.systemd.services.syncthing.serviceConfig.ReadWritePaths;
          in
          assert allStatesAre "disable" appArmorTestHosts.disable;
          assert allStatesAre "complain" appArmorTestHosts.complain;
          assert allStatesAre "enforce" appArmorTestHosts.enforce;
          assert stagedStates.local-apply-secret-dns == "enforce";
          assert builtins.all (name: name == "local-apply-secret-dns" || stagedStates.${name} == "complain") (
            builtins.attrNames stagedStates
          );
          assert !(disabledSyncthingService.serviceConfig ? AppArmorProfile);
          assert
            !(
              appArmorTestHosts.disable.config.systemd.services.apply-secret-dns.serviceConfig ? AppArmorProfile
            );
          assert (states appArmorTestHosts.override).local-syncthing == "enforce";
          assert overrideSyncthingService.serviceConfig.AppArmorProfile == "local-syncthing";
          assert
            !(pkgs-unstable.lib.hasInfix "audit deny owner @{HOME}/.ssh/" complainPolicies.local-brave.profile);
          assert pkgs-unstable.lib.hasInfix "audit deny owner @{HOME}/.ssh/"
            enforcePolicies.local-brave.profile;
          assert
            !(pkgs-unstable.lib.hasInfix "audit deny owner @{HOME}/.ssh/" enforcePolicies.local-codex-cli.profile);
          assert laptopConfig.programs.ssh.enableAskPassword;
          assert laptopConfig.environment.variables.SSH_ASKPASS == laptopConfig.programs.ssh.askPassword;
          assert dnsService.serviceConfig.UMask == "0077";
          assert dnsService.serviceConfig.CapabilityBoundingSet == [ "CAP_CHOWN" ];
          assert pkgs-unstable.lib.hasInfix ''
            chmod 0600 "$temporary_file"
            chown systemd-resolve:systemd-resolve "$temporary_file"
          '' dnsService.script;
          assert pkgs-unstable.lib.elem "/home/${username}/Sync" desktopSyncthingPaths;
          assert pkgs-unstable.lib.elem "/srv/syncthing" desktopSyncthingPaths;
          pkgs-unstable.runCommand "apparmor-mode-matrix" { } ''
            touch "$out"
          '';

        apparmor-policy-parser =
          let
            configurations = [
              self.nixosConfigurations.desktop
              self.nixosConfigurations.laptop
              appArmorTestHosts.enforce
            ];
            profileDirectories = map (
              configuration: configuration.config.environment.etc."apparmor.d".source
            ) configurations;
            includeDirectories = pkgs-unstable.lib.unique (
              builtins.concatMap (
                configuration:
                map (package: "${package}/etc/apparmor.d") configuration.config.security.apparmor.packages
              ) configurations
            );
            includeArguments = pkgs-unstable.lib.concatMapStringsSep " " (
              directory: "--Include ${pkgs-unstable.lib.escapeShellArg directory}"
            ) includeDirectories;
          in
          pkgs-unstable.runCommand "apparmor-policy-parser"
            {
              nativeBuildInputs = [ pkgs-unstable.apparmor-parser ];
            }
            ''
              for profile_directory in ${
                pkgs-unstable.lib.concatMapStringsSep " " pkgs-unstable.lib.escapeShellArg profileDirectories
              }; do
                for policy in "$profile_directory"/local-*; do
                  attachment="$(sed -n 's/^[[:space:]]*profile local-[^[:space:]]* \([^[:space:]]*\) flags=.*/\1/p' "$policy")"
                  if [ -n "$attachment" ]; then
                    test -x "$attachment"
                  fi
                  apparmor_parser --config-file /dev/null --quiet --skip-kernel-load --skip-cache \
                    --Include "$profile_directory" ${includeArguments} "$policy"
                done
              done
              touch "$out"
            '';

        apparmor-vm = import ./tests/apparmor.nix {
          pkgs = pkgs-unstable.extend selfPkgs.overlay;
        };
        desktop-toplevel = self.nixosConfigurations.desktop.config.system.build.toplevel;
        laptop-toplevel = self.nixosConfigurations.laptop.config.system.build.toplevel;
      };
    };
}
