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

      mkAppArmorTestHost =
        mode: profileOverrides:
        mkHost {
          host = "laptop";
          extraModules = [
            nixos-hardware.nixosModules.framework-16-7040-amd
            ({ lib, ... }: {
              security.localAppArmor = {
                mode = lib.mkForce mode;
                inherit profileOverrides;
              };
            })
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
            bravePolicy = complainPolicies.local-brave.profile;
            codexPolicy = complainPolicies.local-codex-cli.profile;
            drawioPolicy = complainPolicies.local-drawio.profile;
            disabledSyncthingService = appArmorTestHosts.disable.config.systemd.services.syncthing;
            overrideSyncthingService = appArmorTestHosts.override.config.systemd.services.syncthing;
            laptopConfig = self.nixosConfigurations.laptop.config;
            laptopPkgs = self.nixosConfigurations.laptop.pkgs;
            laptopHomeAppArmor = laptopConfig.home-manager.users.${username}.localAppArmor;
            laptopServiceRegistry = laptopConfig.security.localAppArmor.services;
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
          assert bravePolicy != enforcePolicies.local-brave.profile;
          assert laptopHomeAppArmor.applications.brave.package == laptopPkgs.brave;
          assert builtins.elem "network" laptopHomeAppArmor.applications.brave.capabilities;
          assert builtins.elem "credential-broker" laptopHomeAppArmor.applications.brave.sensitiveAccess;
          assert builtins.elem "developer-exec" laptopHomeAppArmor.applications.codex-cli.capabilities;
          assert builtins.elem "ssh-identities" laptopHomeAppArmor.applications.codex-cli.sensitiveAccess;
          assert builtins.elem laptopPkgs.stable.helix laptopHomeAppArmor.developerPackages;
          assert laptopServiceRegistry.syncthing.packageRoots == [ laptopConfig.services.syncthing.package ];
          assert laptopServiceRegistry.apply-secret-dns.stagedState == "enforce";
          assert builtins.hasAttr "broad-launchers" laptopHomeAppArmor.inventory;
          assert builtins.hasAttr "network-control-plane" laptopConfig.security.localAppArmor.inventory;
          assert pkgs-unstable.lib.hasInfix "/bin/brave flags=(attach_disconnected,mediate_deleted)"
            bravePolicy;
          assert pkgs-unstable.lib.hasInfix "Cx -> namespace-bootstrap" codexPolicy;
          assert pkgs-unstable.lib.hasInfix "profile namespace-bootstrap" codexPolicy;
          assert pkgs-unstable.lib.hasInfix "capability setpcap," codexPolicy;
          assert pkgs-unstable.lib.hasInfix "capability sys_admin," codexPolicy;
          assert pkgs-unstable.lib.hasInfix "capability sys_ptrace," codexPolicy;
          assert pkgs-unstable.lib.hasInfix "Cx -> namespace-bootstrap" drawioPolicy;
          assert pkgs-unstable.lib.hasInfix "profile namespace-bootstrap" drawioPolicy;
          assert pkgs-unstable.lib.hasInfix "capability sys_admin," drawioPolicy;
          assert pkgs-unstable.lib.hasInfix "capability sys_ptrace," drawioPolicy;
          assert pkgs-unstable.lib.hasInfix "owner /proc/[0-9]*/{gid_map,setgroups,uid_map} w," drawioPolicy;
          assert !(pkgs-unstable.lib.hasInfix "/nix/store/** ix" bravePolicy);
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

        apparmor-report =
          let
            reportPackage =
              pkgs-unstable.lib.findFirst (package: pkgs-unstable.lib.getName package == "apparmor-report")
                (throw "apparmor-report is missing from environment.systemPackages")
                self.nixosConfigurations.laptop.config.environment.systemPackages;
          in
          pkgs-unstable.runCommand "apparmor-report"
            {
              nativeBuildInputs = [
                pkgs-unstable.python3
                reportPackage
              ];
            }
            ''
              APPARMOR_REPORT_SOURCE=${./modules/core/apparmor_report.py} \
                python ${./tests/test_apparmor_report.py}

              printf '%s\n' \
                'apparmor="ALLOWED" operation="open" class="file" profile="local-test" name="/tmp/test" requested_mask="r" denied_mask="r"' \
                | apparmor-report --input - --json > report.json
              grep -F '"profile": "local-test"' report.json
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
            enforceProfileDirectory = appArmorTestHosts.enforce.config.environment.etc."apparmor.d".source;
            includeDirectories = pkgs-unstable.lib.unique (
              builtins.concatMap (
                configuration:
                map (package: "${package}/etc/apparmor.d") configuration.config.security.apparmor.packages
              ) configurations
            );
            includeArguments = pkgs-unstable.lib.concatMapStringsSep " " (
              directory: "--Include ${pkgs-unstable.lib.escapeShellArg directory}"
            ) includeDirectories;
            executablePatterns = pkgs-unstable.lib.unique (
              builtins.concatMap (
                configuration:
                builtins.concatMap (app: app.extraExecutables ++ app.namespaceExecutables) (
                  builtins.attrValues (
                    pkgs-unstable.lib.filterAttrs (
                      _: app: app.enable
                    ) configuration.config.home-manager.users.${username}.localAppArmor.applications
                  )
                )
              ) configurations
            );
          in
          pkgs-unstable.runCommand "apparmor-policy-parser"
            {
              nativeBuildInputs = [ pkgs-unstable.apparmor-parser ];
            }
            ''
              while IFS= read -r executable_pattern; do
                [ -n "$executable_pattern" ] || continue
                executable_matched=false
                for executable_match in $executable_pattern; do
                  [ -e "$executable_match" ] || continue
                  executable_matched=true
                  if [ ! -x "$executable_match" ]; then
                    echo "AppArmor executable match is not executable: $executable_match" >&2
                    exit 1
                  fi
                done
                if [ "$executable_matched" != true ]; then
                  echo "AppArmor executable pattern has no match: $executable_pattern" >&2
                  exit 1
                fi
              done <<'EXECUTABLE_PATTERNS'
              ${pkgs-unstable.lib.concatStringsSep "\n" executablePatterns}
              EXECUTABLE_PATTERNS

              for profile_directory in ${
                pkgs-unstable.lib.concatMapStringsSep " " pkgs-unstable.lib.escapeShellArg profileDirectories
              }; do
                brave_common="$(sed -n 's/^[[:space:]]*include "\([^"]*apparmor-local-brave-common\)"/\1/p' "$profile_directory/local-brave")"
                test -r "$brave_common"
                session_rules="$(sed -n 's/^[[:space:]]*include "\([^"]*apparmor-local-session-read-only\)"/\1/p' "$brave_common")"
                test -r "$session_rules"
                grep -F '/share/** mr,' "$session_rules"
                if awk '$NF ~ /^[a-z]+,$/ && $NF ~ /[wxkl]/ { bad=1 } END { exit !bad }' "$session_rules"; then
                  echo "read-only session rules unexpectedly grant write or execution" >&2
                  exit 1
                fi

                closure_rules="$(sed -n 's/^[[:space:]]*include "\([^"]*apparmor-closure-rules-local-brave\)"/\1/p' "$brave_common")"
                test -r "$closure_rules"
                if grep -F ' ixr,' "$closure_rules"; then
                  echo "read-only application closure unexpectedly grants execution" >&2
                  exit 1
                fi

                grep -F '${self.nixosConfigurations.laptop.pkgs.brave}/bin/** ixr,' "$brave_common"
                grep -F '${self.nixosConfigurations.laptop.pkgs.brave}/opt/** ixr,' "$brave_common"

                file_roller_common="$(sed -n 's/^[[:space:]]*include "\([^"]*apparmor-local-file-roller-common\)"/\1/p' "$profile_directory/local-file-roller")"
                grep -F '${pkgs-unstable.unzip}/bin/** ixr,' "$file_roller_common"

                motrix_common="$(sed -n 's/^[[:space:]]*include "\([^"]*apparmor-local-motrix-common\)"/\1/p' "$profile_directory/local-motrix")"
                grep -F '${pkgs-unstable.glibc.bin}/bin/getconf ixr,' "$motrix_common"

                logseq_common="$(sed -n 's/^[[:space:]]*include "\([^"]*apparmor-local-logseq-common\)"/\1/p' "$profile_directory/local-logseq")"
                grep -F '/nix/store/*-${self.nixosConfigurations.laptop.pkgs.logseq-appimage.name}-bwrap ixr,' "$logseq_common"

                pqiv_common="$(sed -n 's/^[[:space:]]*include "\([^"]*apparmor-local-pqiv-common\)"/\1/p' "$profile_directory/local-pqiv")"
                if grep -F 'owner @{HOME}/** rwkl,' "$pqiv_common" \
                  || grep -F '/proc/{,**}' "$pqiv_common" \
                  || grep -F '/run/user/[0-9]*/{,**}' "$pqiv_common" \
                  || grep -F 'include <abstractions/nameservice>' "$pqiv_common" \
                  || grep -F 'include <abstractions/audio>' "$pqiv_common" \
                  || grep -F '/dev/video[0-9]* rw,' "$pqiv_common"; then
                  echo "minimal desktop capability set leaked broad host access" >&2
                  exit 1
                fi

                grep -F 'Cx -> namespace-bootstrap,' "$profile_directory/local-drawio"
                grep -F 'profile namespace-bootstrap' "$profile_directory/local-drawio"

                for policy in "$profile_directory"/local-*; do
                  attachment="$(sed -n 's/^[[:space:]]*profile local-[^[:space:]]* \([^[:space:]]*\) flags=.*/\1/p' "$policy")"
                  if [ -n "$attachment" ]; then
                    test -x "$attachment"
                  fi
                  apparmor_parser --config-file /dev/null --quiet --skip-kernel-load --skip-cache \
                    --Include "$profile_directory" ${includeArguments} "$policy"
                done
              done

              enforce_brave_common="$(sed -n 's/^[[:space:]]*include "\([^"]*apparmor-local-brave-common\)"/\1/p' ${pkgs-unstable.lib.escapeShellArg enforceProfileDirectory}/local-brave)"
              grep -F 'audit deny owner @{HOME}/.ssh/id_* rwklm,' "$enforce_brave_common"
              grep -F 'audit deny owner @{HOME}/.ssh/config.secrets rwklm,' "$enforce_brave_common"
              grep -F 'audit deny owner @{HOME}/.ssh/{cm,sockets}/{,**} rwklm,' "$enforce_brave_common"
              grep -F 'dbus send bus=session peer=(name=org.freedesktop.secrets),' "$enforce_brave_common"
              if grep -F 'audit deny dbus send bus=session peer=(name=org.freedesktop.secrets),' "$enforce_brave_common"; then
                echo "explicit Brave credential-broker access was overridden by a deny" >&2
                exit 1
              fi

              enforce_codex_common="$(sed -n 's/^[[:space:]]*include "\([^"]*apparmor-local-codex-cli-common\)"/\1/p' ${pkgs-unstable.lib.escapeShellArg enforceProfileDirectory}/local-codex-cli | head -n 1)"
              grep -F 'owner @{HOME}/.ssh/id_* r,' "$enforce_codex_common"
              if grep -F 'audit deny owner @{HOME}/.ssh/id_* rwklm,' "$enforce_codex_common"; then
                echo "explicit Codex SSH identity access was overridden by a deny" >&2
                exit 1
              fi
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
