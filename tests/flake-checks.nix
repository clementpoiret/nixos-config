{
  self,
  pkgs-unstable,
  username,
  home-manager,
  nixos-hardware,
  mkHost,
  selfPkgs,
}:
let
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
  invalidAppArmorTestHosts = {
    globHomePath = mkHost {
      host = "laptop";
      extraModules = [
        nixos-hardware.nixosModules.framework-16-7040-amd
        ({ lib, ... }: {
          home-manager.users.${username}.localAppArmor.applications.brave.homePaths = lib.mkForce [
            "Documents/*"
          ];
        })
      ];
    };
    missingRationale = mkHost {
      host = "laptop";
      extraModules = [
        nixos-hardware.nixosModules.framework-16-7040-amd
        ({ lib, ... }: {
          home-manager.users.${username}.localAppArmor.applications.codex-cli.elevatedAccessRationale =
            lib.mkForce "";
        })
      ];
    };
    hostDiagnosticsWithoutDeveloper = mkHost {
      host = "laptop";
      extraModules = [
        nixos-hardware.nixosModules.framework-16-7040-amd
        ({ lib, ... }: {
          home-manager.users.${username}.localAppArmor.applications.brave.capabilities = lib.mkAfter [
            "host-diagnostics"
          ];
        })
      ];
    };
  };
in
{
  host-cpu-optimizations =
    let
      desktopPkgs = self.nixosConfigurations.desktop.pkgs;
      laptopPkgs = self.nixosConfigurations.laptop.pkgs;
      desktopKernel = self.nixosConfigurations.desktop.config.boot.kernelPackages.kernel;
      laptopKernel = self.nixosConfigurations.laptop.config.boot.kernelPackages.kernel;
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
      checkHost =
        hostName: cpuTarget:
        let
          host = self.nixosConfigurations.${hostName};
          hostPkgs = host.pkgs;
          kernel = host.config.boot.kernelPackages.kernel;
          niriConfig = host.config.home-manager.users.${username}.xdg.configFile."niri-config".source;
          check =
            condition:
            pkgs-unstable.lib.assertMsg condition "CPU optimization check failed for ${hostName} (${cpuTarget})";
        in
        assert check (!(hostPkgs.stdenv.hostPlatform ? gcc.arch));
        assert check (hasFlag "-march=${cpuTarget}" (hostPkgs.quickshell-host.NIX_CFLAGS_COMPILE or ""));
        assert check (hasFlag "-C target-cpu=${cpuTarget}" (rustFlags hostPkgs.flake.herdr));
        assert check (!(hostPkgs.flake.herdr.doCheck or true));
        assert check (!(hostPkgs.flake.herdr.doInstallCheck or true));
        assert check (hasFlag "-C target-cpu=${cpuTarget}" (rustFlags hostPkgs.niri-host));
        assert check (!(hostPkgs.niri-host.doCheck or true));
        assert check (!(hostPkgs.niri-host.doInstallCheck or true));
        assert check (niriUsesBaselineCompletions hostPkgs.niri-baseline hostPkgs.niri-host);
        assert check (
          builtins.map builtins.toString niriConfig.buildInputs == [
            (builtins.toString hostPkgs.niri-baseline)
          ]
        );
        assert check (builtins.elem "-Dcpu=${cpuTarget}" hostPkgs.ghostty-host.zigBuildFlags);
        assert check (builtins.elem "-Dcpu=${cpuTarget}" hostPkgs.ghostty-host.zigCheckFlags);
        assert check (!(hostPkgs.ghostty-host.doInstallCheck or true));
        assert check (configIs "y" kernel.structuredExtraConfig.MZEN4);
        assert check (configIs "n" kernel.structuredExtraConfig.GENERIC_CPU);
        assert check (configIs "n" kernel.structuredExtraConfig.X86_NATIVE_CPU);
        true;
    in
    assert checkHost "desktop" "znver5";
    assert checkHost "laptop" "znver4";
    assert desktopPkgs.flake.herdr.drvPath != laptopPkgs.flake.herdr.drvPath;
    assert desktopPkgs.niri-baseline.drvPath == laptopPkgs.niri-baseline.drvPath;
    assert desktopKernel.drvPath != laptopKernel.drvPath;
    pkgs-unstable.runCommand "host-cpu-optimizations" { } ''
      touch "$out"
    '';

  credential-forwarding =
    let
      desktopConfig = self.nixosConfigurations.desktop.config;
      laptopConfig = self.nixosConfigurations.laptop.config;
      desktopHome = desktopConfig.home-manager.users.${username};
      laptopHome = laptopConfig.home-manager.users.${username};
      desktopSsh = desktopHome.programs.ssh.settings;
      laptopSsh = laptopHome.programs.ssh.settings;
      desktopSecretWriter = builtins.head desktopHome.systemd.user.services.write-ssh-secret-config.Service.ExecStart;
      laptopSecretWriter = builtins.head laptopHome.systemd.user.services.write-ssh-secret-config.Service.ExecStart;
      desktopAgentLoader = desktopHome.systemd.user.services.ssh-agent.Service.ExecStartPost;
      laptopAgentLoader = laptopHome.systemd.user.services.ssh-agent.Service.ExecStartPost;
      desktopAgentEnvironment = desktopHome.systemd.user.services.ssh-agent.Service.Environment;
      laptopAgentEnvironment = laptopHome.systemd.user.services.ssh-agent.Service.Environment;
      desktopAgentAskpass = pkgs-unstable.lib.removePrefix "SSH_ASKPASS=" (
        builtins.head (builtins.filter (pkgs-unstable.lib.hasPrefix "SSH_ASKPASS=") desktopAgentEnvironment)
      );
      laptopAgentAskpass = pkgs-unstable.lib.removePrefix "SSH_ASKPASS=" (
        builtins.head (builtins.filter (pkgs-unstable.lib.hasPrefix "SSH_ASKPASS=") laptopAgentEnvironment)
      );
      desktopGpgSync = desktopHome.systemd.user.services.sync-forwarded-gpg-home;
      laptopGpgSync = laptopHome.systemd.user.services.sync-forwarded-gpg-home;
      desktopGpgSyncScript = builtins.head desktopGpgSync.Service.ExecStart;
      gpgSyncIsSessionOneShot =
        home: service:
        !(home.home.activation ? syncForwardedGpgHome)
        && service.Service.Type == "oneshot"
        && !(service.Service.RemainAfterExit)
        && service.Install.WantedBy == [ "default.target" ];
      serverForwardingIsRestricted =
        config:
        config.services.openssh.settings.AllowAgentForwarding
        && !(config.services.openssh.settings.AllowTcpForwarding)
        && config.services.openssh.settings.AllowStreamLocalForwarding == "remote"
        && config.services.openssh.settings.StreamLocalBindUnlink
        && config.services.openssh.settings.AcceptEnv == [ "GNUPGHOME" ];
    in
    assert
      desktopSsh.defaultAuth.data.IdentityFile == [
        "~/.ssh/id_ed25519_sk_yk2"
        "~/.ssh/id_ed25519_sk_yk1"
      ];
    assert
      laptopSsh.defaultAuth.data.IdentityFile == [
        "~/.ssh/id_ed25519_sk_yk1"
        "~/.ssh/id_ed25519_sk_yk2"
      ];
    assert desktopSsh."github.com".data.IdentityAgent == "SSH_AUTH_SOCK";
    assert desktopSsh."github.com".data.IdentityFile == "none";
    assert desktopSsh."gitlab.com".data.IdentityAgent == "SSH_AUTH_SOCK";
    assert desktopSsh."gitlab.com".data.IdentityFile == "none";
    assert serverForwardingIsRestricted desktopConfig;
    assert serverForwardingIsRestricted laptopConfig;
    assert desktopHome.services.gpg-agent.enableExtraSocket;
    assert laptopHome.services.gpg-agent.enableExtraSocket;
    assert desktopConfig.programs.yubikey-touch-detector.enable;
    assert desktopConfig.programs.yubikey-touch-detector.libnotify;
    assert laptopConfig.programs.yubikey-touch-detector.enable;
    assert laptopConfig.programs.yubikey-touch-detector.libnotify;
    assert builtins.elem "SSH_ASKPASS_REQUIRE=force" desktopAgentEnvironment;
    assert builtins.elem "SSH_ASKPASS_REQUIRE=force" laptopAgentEnvironment;
    assert desktopAgentAskpass == laptopAgentAskpass;
    assert gpgSyncIsSessionOneShot desktopHome desktopGpgSync;
    assert gpgSyncIsSessionOneShot laptopHome laptopGpgSync;
    assert desktopHome.programs.jujutsu.settings.signing.behavior == "drop";
    assert laptopHome.programs.jujutsu.settings.signing.behavior == "drop";
    assert desktopHome.programs.jujutsu.settings.git.sign-on-push;
    assert laptopHome.programs.jujutsu.settings.git.sign-on-push;
    pkgs-unstable.runCommand "credential-forwarding" { nativeBuildInputs = [ pkgs-unstable.gnugrep ]; }
      ''
        grep -F 'Host laptop-forwarded' ${desktopSecretWriter}
        grep -F 'Host desktop-forwarded' ${laptopSecretWriter}
        grep -F 'ForwardAgent \''${SSH_AUTH_SOCK}' ${desktopSecretWriter}
        grep -F 'RemoteForward $forwarded_gpg_socket $local_gpg_extra_socket' ${desktopSecretWriter}
        grep -F 'ControlMaster no' ${desktopSecretWriter}
        grep -F 'Host * !github.com !gitlab.com' ${desktopSecretWriter}
        grep -F 'laptop>git@[ssh.github.com]:443' ${desktopAgentLoader}
        grep -F 'desktop>git@[altssh.gitlab.com]:443' ${laptopAgentLoader}
        grep -F 'systemctl --user show-environment' ${desktopAgentAskpass}
        grep -F 'DISPLAY=*|WAYLAND_DISPLAY=*' ${desktopAgentAskpass}
        grep -F 'seahorse/ssh-askpass "$@"' ${desktopAgentAskpass}
        grep -F 'gpg --batch --export 71F084CEA427B23537934233CC6B0EED323A6C13' ${desktopGpgSyncScript}
        grep -F 'Refusing to forward a GPG key file that is not a smartcard stub' ${desktopGpgSyncScript}
        touch "$out"
      '';

  apparmor-mode-matrix =
    let
      states =
        hostConfig:
        pkgs-unstable.lib.mapAttrs (_: policy: policy.state) hostConfig.config.security.apparmor.policies;
      containerInfrastructurePolicyNames = [
        "local-agent-container-denied"
        "local-agent-container-payload"
        "local-claude-code-container-engine"
        "local-codex-cli-container-engine"
      ];
      bubblewrapInfrastructurePolicyNames = [
        "bwrap"
        "local-claude-code-bwrap"
      ];
      alwaysEnforcedPolicyNames =
        bubblewrapInfrastructurePolicyNames ++ containerInfrastructurePolicyNames;
      workloadStates = hostConfig: removeAttrs (states hostConfig) alwaysEnforcedPolicyNames;
      allStatesAre =
        expected: hostConfig:
        builtins.all (state: state == expected) (builtins.attrValues (workloadStates hostConfig));
      stagedStates = states appArmorTestHosts.staged;
      complainPolicies = appArmorTestHosts.complain.config.security.apparmor.policies;
      enforcePolicies = appArmorTestHosts.enforce.config.security.apparmor.policies;
      bwrapPolicy = complainPolicies.bwrap.profile;
      claudeBwrapPolicy = complainPolicies.local-claude-code-bwrap.profile;
      bravePolicy = complainPolicies.local-brave.profile;
      codexPolicy = complainPolicies.local-codex-cli.profile;
      claudePolicy = complainPolicies.local-claude-code.profile;
      codexContainerEnginePolicy = complainPolicies.local-codex-cli-container-engine.profile;
      claudeContainerEnginePolicy = complainPolicies.local-claude-code-container-engine.profile;
      containerPayloadPolicy = complainPolicies.local-agent-container-payload.profile;
      drawioPolicy = complainPolicies.local-drawio.profile;
      logseqPolicy = complainPolicies.local-logseq.profile;
      disabledSyncthingService = appArmorTestHosts.disable.config.systemd.services.syncthing;
      overrideSyncthingService = appArmorTestHosts.override.config.systemd.services.syncthing;
      laptopConfig = self.nixosConfigurations.laptop.config;
      laptopPkgs = self.nixosConfigurations.laptop.pkgs;
      laptopHomeAppArmor = laptopConfig.home-manager.users.${username}.localAppArmor;
      claudeManagedSettings =
        builtins.fromJSON
          laptopConfig.environment.etc."claude-code/managed-settings.d/20-sandbox.json".text;
      laptopServiceRegistry = laptopConfig.security.localAppArmor.services;
      containerRegistriesConfig = laptopConfig.environment.etc."containers/registries.conf".source;
      containerRegistriesConfigPath = builtins.unsafeDiscardStringContext (
        toString containerRegistriesConfig
      );
      appArmorDebugService = laptopConfig.systemd.services.apparmor-debug-report;
      appArmorDebugTimer = laptopConfig.systemd.timers.apparmor-debug-report;
      dnsService = self.nixosConfigurations.laptop.config.systemd.services.apply-secret-dns;
      desktopSyncthingPaths =
        self.nixosConfigurations.desktop.config.systemd.services.syncthing.serviceConfig.ReadWritePaths;
    in
    assert allStatesAre "disable" appArmorTestHosts.disable;
    assert allStatesAre "complain" appArmorTestHosts.complain;
    assert allStatesAre "enforce" appArmorTestHosts.enforce;
    assert builtins.all (
      hostConfig:
      builtins.all (name: (states hostConfig).${name} == "enforce") bubblewrapInfrastructurePolicyNames
    ) (builtins.attrValues appArmorTestHosts);
    assert builtins.all (
      hostConfig:
      builtins.all (name: (states hostConfig).${name} == "enforce") containerInfrastructurePolicyNames
    ) (builtins.attrValues appArmorTestHosts);
    assert stagedStates.local-apply-secret-dns == "enforce";
    assert builtins.all (
      name:
      builtins.elem name alwaysEnforcedPolicyNames
      || name == "local-apply-secret-dns"
      || stagedStates.${name} == "complain"
    ) (builtins.attrNames stagedStates);
    assert !(disabledSyncthingService.serviceConfig ? AppArmorProfile);
    assert
      !(
        appArmorTestHosts.disable.config.systemd.services.apply-secret-dns.serviceConfig ? AppArmorProfile
      );
    assert (states appArmorTestHosts.override).local-syncthing == "enforce";
    assert overrideSyncthingService.serviceConfig.AppArmorProfile == "local-syncthing";
    assert bravePolicy != enforcePolicies.local-brave.profile;
    assert
      !(builtins.tryEval invalidAppArmorTestHosts.globHomePath.config.system.build.toplevel.drvPath)
      .success;
    assert
      !(builtins.tryEval invalidAppArmorTestHosts.missingRationale.config.system.build.toplevel.drvPath)
      .success;
    assert
      !(builtins.tryEval invalidAppArmorTestHosts.hostDiagnosticsWithoutDeveloper.config.system.build.toplevel.drvPath)
      .success;
    assert laptopHomeAppArmor.applications.brave.package == laptopPkgs.brave;
    assert builtins.elem "network" laptopHomeAppArmor.applications.brave.capabilities;
    assert builtins.elem "device-discovery" laptopHomeAppArmor.applications.brave.capabilities;
    assert builtins.elem "credential-broker" laptopHomeAppArmor.applications.brave.sensitiveAccess;
    assert builtins.elem ".pki/nssdb" laptopHomeAppArmor.applications.brave.homePaths;
    assert builtins.elem "${laptopPkgs.thunderbird.unwrapped}/lib/thunderbird/pingsender"
      laptopHomeAppArmor.applications.thunderbird.extraExecutables;
    assert builtins.elem "${laptopPkgs.thunderbird.unwrapped}/lib/thunderbird/vaapitest"
      laptopHomeAppArmor.applications.thunderbird.extraExecutables;
    assert builtins.elem "developer-exec" laptopHomeAppArmor.applications.codex-cli.capabilities;
    assert builtins.elem "containers" laptopHomeAppArmor.applications.codex-cli.capabilities;
    assert builtins.elem "containers" laptopHomeAppArmor.applications.claude-code.capabilities;
    assert builtins.elem "bubblewrap" laptopHomeAppArmor.applications.codex-cli.capabilities;
    assert builtins.elem "bubblewrap" laptopHomeAppArmor.applications.claude-code.capabilities;
    assert builtins.elem "host-diagnostics" laptopHomeAppArmor.applications.codex-cli.capabilities;
    assert builtins.elem "host-diagnostics" laptopHomeAppArmor.applications.claude-code.capabilities;
    assert builtins.elem "ssh-identities" laptopHomeAppArmor.applications.codex-cli.sensitiveAccess;
    assert builtins.elem "forge-auth" laptopHomeAppArmor.applications.codex-cli.sensitiveAccess;
    assert builtins.elem "forge-auth" laptopHomeAppArmor.applications.claude-code.sensitiveAccess;
    assert builtins.elem "netrc" laptopHomeAppArmor.applications.codex-cli.sensitiveAccess;
    assert !(builtins.elem "netrc" laptopHomeAppArmor.applications.claude-code.sensitiveAccess);
    assert builtins.elem "nixos-config-writable"
      laptopHomeAppArmor.applications.codex-cli.sensitiveAccess;
    assert builtins.elem "user-files" laptopHomeAppArmor.applications.codex-cli.capabilities;
    assert laptopHomeAppArmor.applications.codex-cli.elevatedAccessRationale != "";
    assert laptopServiceRegistry.syncthing.packageRoots == [ laptopConfig.services.syncthing.package ];
    assert builtins.elem "runtime-introspection" laptopServiceRegistry.syncthing.capabilities;
    assert builtins.elem "/proc/bus/pci/devices" laptopServiceRegistry.syncthing.readOnlyPaths;
    assert builtins.elem "/proc/modules" laptopServiceRegistry.syncthing.readOnlyPaths;
    assert laptopServiceRegistry.apply-secret-dns.stagedState == "enforce";
    assert pkgs-unstable.lib.hasInfix "owner /proc/[0-9]*/stat r,"
      laptopServiceRegistry.apply-secret-dns.extraRules;
    assert laptopConfig.security.localAppArmor.debug.enable;
    assert laptopConfig.security.localAppArmor.debug.path == "~/.local/state/apparmor-reports";
    assert
      appArmorDebugService.unitConfig.RequiresMountsFor == [
        "/home/${username}/.local/state/apparmor-reports"
      ];
    assert
      appArmorDebugService.serviceConfig.ReadWritePaths == [
        "/home/${username}/.local/state/apparmor-reports"
      ];
    assert appArmorDebugTimer.timerConfig.OnCalendar == "*:0/30";
    assert appArmorDebugTimer.timerConfig.Persistent;
    assert builtins.elem "/run/secrets.d/[0-9]*/dns/laptop"
      laptopServiceRegistry.apply-secret-dns.readOnlyPaths;
    assert builtins.elem ".config/enchant" laptopHomeAppArmor.applications.inkscape.homePaths;
    assert builtins.elem ".local/share/com.motrix.next"
      laptopHomeAppArmor.applications.motrix.homePaths;
    assert builtins.elem laptopPkgs.webkitgtk_4_1
      laptopHomeAppArmor.applications.motrix.executionPackages;
    assert builtins.elem ".logseq" laptopHomeAppArmor.applications.logseq.homePaths;
    assert builtins.elem ".claude.lock" laptopHomeAppArmor.applications.claude-code.homePaths;
    assert builtins.elem ".config/anthropic" laptopHomeAppArmor.applications.claude-code.homePaths;
    assert builtins.elem ".local/share/protonmail"
      laptopHomeAppArmor.applications.protonmail-bridge.homePaths;
    assert builtins.elem laptopPkgs.electron.unwrapped
      laptopHomeAppArmor.applications.drawio.executionPackages;
    assert builtins.elem laptopPkgs.electron.unwrapped
      laptopHomeAppArmor.applications.proton-pass.executionPackages;
    assert laptopHomeAppArmor.applications.drawio.userNamespaceRules == "";
    assert laptopHomeAppArmor.applications.codex-cli.userNamespaceRules == "";
    assert !(builtins.elem "userns" laptopHomeAppArmor.applications.codex-cli.capabilities);
    assert laptopHomeAppArmor.applications.codex-cli.profileReentryExecutables == [ ];
    assert laptopHomeAppArmor.applications.codex-cli.bubblewrapPackage == laptopPkgs.stable.bubblewrap;
    assert
      laptopHomeAppArmor.applications.codex-cli.containerToolsPackage
      == laptopPkgs.flake.agent-container-tools;
    assert
      laptopHomeAppArmor.applications.claude-code.containerToolsPackage
      == laptopPkgs.flake.agent-container-tools;
    assert
      laptopHomeAppArmor.applications.claude-code.bubblewrapPackage == laptopPkgs.stable.bubblewrap;
    assert laptopHomeAppArmor.applications.logseq.executionPackages == [ ];
    assert laptopHomeAppArmor.applications.logseq.profileReentryExecutables == [ ];
    assert pkgs-unstable.lib.isDerivation laptopPkgs.logseq-appimage.appimageContents;
    assert pkgs-unstable.lib.isDerivation laptopPkgs.logseq-appimage.fhsEnv;
    assert builtins.elem laptopPkgs.util-linux
      laptopHomeAppArmor.applications.textmaker.extraClosureRoots;
    assert builtins.elem "${laptopPkgs.util-linux}/bin/whereis"
      laptopHomeAppArmor.applications.textmaker.extraExecutables;
    assert builtins.hasAttr "broad-launchers" laptopHomeAppArmor.inventory;
    assert builtins.hasAttr "network-control-plane" laptopConfig.security.localAppArmor.inventory;
    assert builtins.hasAttr "apparmor-debug-report" laptopConfig.security.localAppArmor.inventory;
    assert pkgs-unstable.lib.hasInfix "/bin/brave flags=(attach_disconnected,mediate_deleted)"
      bravePolicy;
    assert pkgs-unstable.lib.hasInfix "/bin/bwrap Px -> bwrap" codexPolicy;
    assert pkgs-unstable.lib.hasInfix "/bin/bwrap Px -> local-claude-code-bwrap" claudePolicy;
    assert pkgs-unstable.lib.hasInfix "apparmor-claude-code-bwrap" claudeBwrapPolicy;
    assert pkgs-unstable.lib.hasInfix "/bin/podman Px -> local-codex-cli-container-engine" codexPolicy;
    assert pkgs-unstable.lib.hasInfix "/bin/buildah Px -> local-claude-code-container-engine"
      claudePolicy;
    assert pkgs-unstable.lib.hasInfix "profile local-codex-cli-container-engine"
      codexContainerEnginePolicy;
    assert pkgs-unstable.lib.hasInfix "profile local-claude-code-container-engine"
      claudeContainerEnginePolicy;
    assert pkgs-unstable.lib.hasInfix "priority=50 /** px -> local-agent-container-payload,"
      codexContainerEnginePolicy;
    assert pkgs-unstable.lib.hasInfix "priority=50 /** px -> local-agent-container-payload,"
      claudeContainerEnginePolicy;
    assert pkgs-unstable.lib.hasInfix "ptrace (read) peer=local-agent-container-payload,"
      codexContainerEnginePolicy;
    assert pkgs-unstable.lib.hasInfix "ptrace (read) peer=local-agent-container-payload,"
      claudeContainerEnginePolicy;
    assert pkgs-unstable.lib.hasInfix "signal (send) peer=local-agent-container-payload,"
      codexContainerEnginePolicy;
    assert pkgs-unstable.lib.hasInfix "signal (send) peer=local-agent-container-payload,"
      claudeContainerEnginePolicy;
    assert pkgs-unstable.lib.hasInfix "/nix/store/*-etc-os-release r," claudeContainerEnginePolicy;
    assert pkgs-unstable.lib.hasInfix "/proc/uptime r," claudeContainerEnginePolicy;
    assert pkgs-unstable.lib.hasInfix "ip_forward" claudeContainerEnginePolicy;
    assert pkgs-unstable.lib.hasInfix "conf/*/{arp_notify,forwarding,route_localnet,rp_filter} rw,"
      claudeContainerEnginePolicy;
    assert pkgs-unstable.lib.hasInfix "conf/*/{accept_dad,accept_ra,autoconf,forwarding} rw,"
      claudeContainerEnginePolicy;
    assert pkgs-unstable.lib.hasInfix "net/{tcp,tcp6,udp,udp6}" claudeContainerEnginePolicy;
    assert pkgs-unstable.lib.hasInfix "oom_score_adj" claudeContainerEnginePolicy;
    assert pkgs-unstable.lib.hasInfix "/proc/[0-9]*/stat r," codexContainerEnginePolicy;
    assert pkgs-unstable.lib.hasInfix "/proc/[0-9]*/stat r," claudeContainerEnginePolicy;
    assert pkgs-unstable.lib.hasInfix "owner /proc/[0-9]*/mounts r," codexContainerEnginePolicy;
    assert pkgs-unstable.lib.hasInfix "owner /proc/[0-9]*/mounts r," claudeContainerEnginePolicy;
    assert pkgs-unstable.lib.hasInfix "/var/tmp/ r," codexContainerEnginePolicy;
    assert pkgs-unstable.lib.hasInfix "/var/tmp/ r," claudeContainerEnginePolicy;
    assert pkgs-unstable.lib.hasInfix
      "attach_disconnected.path=/apparmor-disconnected/agent-container-engine/"
      codexContainerEnginePolicy;
    assert pkgs-unstable.lib.hasInfix "audit deny @{HOME}/.netrc rwklm," codexContainerEnginePolicy;
    assert pkgs-unstable.lib.hasInfix "\"${containerRegistriesConfigPath}\" r,"
      codexContainerEnginePolicy;
    assert pkgs-unstable.lib.hasInfix "\"${containerRegistriesConfigPath}\" r,"
      claudeContainerEnginePolicy;
    assert pkgs-unstable.lib.hasInfix "profile local-agent-container-payload" containerPayloadPolicy;
    assert pkgs-unstable.lib.hasInfix "/** rwkl," containerPayloadPolicy;
    assert pkgs-unstable.lib.hasInfix "apparmor-bwrap-userns-restrict" bwrapPolicy;
    assert !(pkgs-unstable.lib.hasInfix "profile namespace-bootstrap" codexPolicy);
    assert pkgs-unstable.lib.hasInfix "Px -> local-drawio" drawioPolicy;
    assert !(pkgs-unstable.lib.hasInfix "profile namespace-bootstrap" drawioPolicy);
    assert !(pkgs-unstable.lib.hasInfix "Px -> local-logseq" logseqPolicy);
    assert !(pkgs-unstable.lib.hasInfix "pivot_root" logseqPolicy);
    assert !(pkgs-unstable.lib.hasInfix "/newroot" logseqPolicy);
    assert !(pkgs-unstable.lib.hasInfix "/nix/store/** ix" bravePolicy);
    assert !(pkgs-unstable.lib.hasInfix "/nix/store/** mr" bravePolicy);
    assert claudeManagedSettings.sandbox.enabled;
    assert claudeManagedSettings.sandbox.failIfUnavailable;
    assert !(claudeManagedSettings.sandbox.allowUnsandboxedCommands);
    assert
      claudeManagedSettings.sandbox.excludedCommands == [
        "podman *"
        "buildah *"
      ];
    assert laptopConfig.programs.ssh.enableAskPassword;
    assert laptopConfig.environment.variables.SSH_ASKPASS == laptopConfig.programs.ssh.askPassword;
    assert dnsService.serviceConfig.UMask == "0077";
    assert dnsService.serviceConfig.CapabilityBoundingSet == [ "CAP_CHOWN" ];
    assert pkgs-unstable.lib.hasInfix ''
      chmod 0600 "$temporary_file"
      chown systemd-resolve:systemd-resolve "$temporary_file"
    '' dnsService.script;
    assert !(pkgs-unstable.lib.elem "/home/${username}/Sync" desktopSyncthingPaths);
    assert
      builtins.length (pkgs-unstable.lib.filter (path: path == "/srv/syncthing") desktopSyncthingPaths)
      == 1;
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
        APPARMOR_REPORT_SOURCE=${../modules/core/apparmor_report.py} \
          python ${./test_apparmor_report.py}

        printf '%s\n' \
          'apparmor="ALLOWED" operation="open" class="file" profile="local-test" name="/tmp/test" requested_mask="r" denied_mask="r"' \
          'apparmor="AUDIT" operation="open" class="file" profile="local-test" name="/tmp/audited" requested_mask="w" denied_mask="w"' \
          'apparmor="DENIED" operation="open" class="file" profile="upstream-test" name="/tmp/test" requested_mask="r" denied_mask="r"' \
          | apparmor-report --input - --profile '*' --json > report.json
        grep -F '"profile": "local-test"' report.json
        grep -F '"profile": "upstream-test"' report.json
        grep -F '"profile_patterns": [' report.json
        grep -F '"audited": 1' report.json
        touch "$out"
      '';

  agent-container-guard =
    let
      containerTools = self.nixosConfigurations.laptop.pkgs.flake.agent-container-tools;
    in
    pkgs-unstable.runCommand "agent-container-guard"
      {
        nativeBuildInputs = [
          containerTools
          pkgs-unstable.python3
        ];
      }
      ''
        AGENT_CONTAINER_GUARD_SOURCE=${../pkgs/agent-container-tools/guard.py} \
          python ${./test_agent_container_guard.py}

        test -x ${containerTools}/bin/podman
        test -x ${containerTools}/bin/buildah
        test -x ${containerTools.composeProvider}/bin/docker-compose
        grep -F \
          'compose_providers = ["${containerTools.composeProvider}/bin/docker-compose"]' \
          ${containerTools.containersConf}
        printf '%s\n' '${containerTools.safePath}' | \
          tr : '\n' | grep -Fx '${containerTools.composeProvider}/bin'
        grep -F 'image_copy_tmp_dir = "storage"' ${containerTools.containersConf}
        grep -a -F 'OPERCORD_' ${containerTools}/bin/podman >/dev/null
        if ${containerTools}/bin/podman version >podman.stdout 2>podman.stderr; then
          echo "guarded Podman unexpectedly ran outside an agent broker" >&2
          exit 1
        else
          test "$?" = 126
        fi
        grep -F 'enforced agent broker profile' podman.stderr

        mkdir pythonpath
        printf '%s\n' \
          'from pathlib import Path' \
          'Path(__file__).parent.parent.joinpath("pythonpath-loaded").touch()' \
          > pythonpath/csv.py
        if PYTHONPATH="$PWD/pythonpath" \
          ${containerTools}/bin/podman version >poisoned.stdout 2>poisoned.stderr; then
          echo "guarded Podman unexpectedly ran with a poisoned Python path" >&2
          exit 1
        fi
        test ! -e pythonpath-loaded
        touch "$out"
      '';

  apparmor-application-smoke =
    let
      laptopPkgs = self.nixosConfigurations.laptop.pkgs;
    in
    pkgs-unstable.runCommand "apparmor-application-smoke"
      {
        nativeBuildInputs = [
          pkgs-unstable.binutils
          pkgs-unstable.strace
        ];
      }
      ''
        export HOME="$TMPDIR/home"
        mkdir -p "$HOME"
        cd "$TMPDIR"

        logseq_result="$(ELECTRON_RUN_AS_NODE=1 ${laptopPkgs.logseq-appimage}/bin/logseq-appimage -e 'process.stdout.write("logseq-direct-runtime")')"
        test "$logseq_result" = "logseq-direct-runtime"
        ${laptopPkgs.logseq-appimage}/bin/logseq --help >/dev/null
        strace -f -e trace=execve -o "$TMPDIR/codex-execve.log" \
          ${laptopPkgs.flake.codex-cli}/bin/codex sandbox -- ${pkgs-unstable.coreutils}/bin/true
        grep -F '"${laptopPkgs.stable.bubblewrap}/bin/bwrap"' "$TMPDIR/codex-execve.log"
        if grep -F -- 'use_legacy_landlock' ${laptopPkgs.flake.codex-cli}/bin/codex; then
          echo "Codex wrapper still forces deprecated Landlock" >&2
          exit 1
        fi
        strings ${laptopPkgs.flake.claude-code}/bin/.claude-wrapped \
          | grep -F '${laptopPkgs.stable.bubblewrap}/bin'

        touch "$out"
      '';

  nixos-config-agent =
    pkgs-unstable.runCommand "nixos-config-agent"
      {
        nativeBuildInputs = [
          pkgs-unstable.git
          pkgs-unstable.jujutsu
          pkgs-unstable.openssh
          pkgs-unstable.python3
        ];
      }
      ''
        NIXOS_CONFIG_AGENT_SOURCE=${../modules/home/scripts/nixos_config_agent.py} \
          python ${./test_nixos_config_agent.py}
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
      complainProfileDirectory = appArmorTestHosts.complain.config.environment.etc."apparmor.d".source;
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
          builtins.concatMap (app: app.extraExecutables ++ app.profileReentryExecutables) (
            builtins.attrValues (
              pkgs-unstable.lib.filterAttrs (
                _: app: app.enable
              ) configuration.config.home-manager.users.${username}.localAppArmor.applications
            )
          )
        ) configurations
      );
      laptopApplications = pkgs-unstable.lib.filterAttrs (
        _: app: app.enable
      ) self.nixosConfigurations.laptop.config.home-manager.users.${username}.localAppArmor.applications;
      applicationNames = builtins.attrNames laptopApplications;
      applicationNamesWith =
        capability:
        builtins.attrNames (
          pkgs-unstable.lib.filterAttrs (_: app: builtins.elem capability app.capabilities) laptopApplications
        );
      applicationNamesWithout =
        capability:
        builtins.attrNames (
          pkgs-unstable.lib.filterAttrs (
            _: app: !(builtins.elem capability app.capabilities)
          ) laptopApplications
        );
      desktopApplicationNames = applicationNamesWith "desktop";
      deviceDiscoveryApplicationNames = applicationNamesWith "device-discovery";
      gpuApplicationNames = applicationNamesWith "gpu";
      networkApplicationNames = applicationNamesWith "network";
      usernsApplicationNames = applicationNamesWith "userns";
      bubblewrapApplicationNames = applicationNamesWith "bubblewrap";
      developerApplicationNames = applicationNamesWith "developer-exec";
      hostDiagnosticApplicationNames = applicationNamesWith "host-diagnostics";
      nonTerminalApplicationNames = applicationNamesWithout "terminal";
      userFilesApplicationNames = applicationNamesWith "user-files";
    in
    pkgs-unstable.runCommand "apparmor-policy-parser"
      {
        nativeBuildInputs = [ pkgs-unstable.apparmor-parser ];
      }
      ''
        common_rules() {
          local profile="$1" common
          common="$(sed -n 's/^[[:space:]]*include "\([^"]*apparmor-local-[^"]*-common\)"/\1/p' "$profile")"
          if [[ "$common" != *"-apparmor-''${profile##*/}-common" || ! -r "$common" ]]; then
            echo "Missing readable common rules for $profile: $common" >&2
            return 1
          fi
          printf '%s\n' "$common"
        }

        require_rule() {
          if ! grep -F -- "$1" "$2"; then
            printf 'Missing required rule in %s: %s\n' "$2" "$1" >&2
            return 1
          fi
        }

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
          bwrap_policy="$profile_directory/bwrap"
          bwrap_profile="$(sed -n 's/^[[:space:]]*include "\([^"]*apparmor-bwrap-userns-restrict\)"/\1/p' "$bwrap_policy")"
          test -r "$bwrap_profile"
          require_rule 'profile bwrap ${self.nixosConfigurations.laptop.pkgs.stable.bubblewrap}/bin/bwrap flags=(attach_disconnected,mediate_deleted)' "$bwrap_profile"
          require_rule 'allow userns,' "$bwrap_profile"
          require_rule 'allow mount,' "$bwrap_profile"
          require_rule 'allow pivot_root,' "$bwrap_profile"
          require_rule 'allow pix /** -> &bwrap//&unpriv_bwrap,' "$bwrap_profile"
          require_rule 'profile unpriv_bwrap flags=(attach_disconnected,mediate_deleted)' "$bwrap_profile"
          require_rule 'audit deny capability,' "$bwrap_profile"

          claude_bwrap_policy="$profile_directory/local-claude-code-bwrap"
          claude_bwrap_profile="$(sed -n 's/^[[:space:]]*include "\([^"]*apparmor-claude-code-bwrap\)"/\1/p' "$claude_bwrap_policy")"
          test -r "$claude_bwrap_profile"
          require_rule 'profile local-claude-code-bwrap flags=(attach_disconnected,mediate_deleted)' "$claude_bwrap_profile"
          require_rule 'allow pix /** -> &local-claude-code-bwrap//&local-claude-code-bwrap-payload,' "$claude_bwrap_profile"
          require_rule 'profile local-claude-code-bwrap-payload flags=(attach_disconnected,mediate_deleted)' "$claude_bwrap_profile"
          require_rule 'allow pix /** -> &local-claude-code-bwrap-payload,' "$claude_bwrap_profile"
          require_rule 'allow capability sys_admin,' "$claude_bwrap_profile"
          if grep -F 'audit deny capability,' "$claude_bwrap_profile" \
            || grep -F 'profile local-claude-code-bwrap ${self.nixosConfigurations.laptop.pkgs.stable.bubblewrap}/bin/bwrap' "$claude_bwrap_profile"; then
            echo "Claude Bubblewrap compatibility profile is not narrowly named" >&2
            exit 1
          fi

          brave_common="$(common_rules "$profile_directory/local-brave")"
          test -r "$brave_common"
          session_rules="$(sed -n 's/^[[:space:]]*include "\([^"]*apparmor-local-session-read-only\)"/\1/p' "$brave_common")"
          test -r "$session_rules"
          session_closure_rules="$(sed -n 's/^[[:space:]]*include "\([^"]*apparmor-closure-rules-local-session-read-only\)"/\1/p' "$session_rules")"
          test -r "$session_closure_rules"
          require_rule '/share/** mr,' "$session_closure_rules"
          require_rule '${self.nixosConfigurations.laptop.config.services.gvfs.package}/lib/**.so* mr,' "$session_closure_rules"
          require_rule '${self.nixosConfigurations.laptop.pkgs.libsForQt5.qt5ct}/lib/**.so* mr,' "$session_closure_rules"
          require_rule '${self.nixosConfigurations.laptop.pkgs.libsForQt5.qtstyleplugin-kvantum}/lib/**.so* mr,' "$session_closure_rules"
          require_rule '${self.nixosConfigurations.laptop.pkgs.qt6Packages.qt6ct}/lib/**.so* mr,' "$session_closure_rules"
          require_rule '${self.nixosConfigurations.laptop.pkgs.qt6Packages.qtstyleplugin-kvantum}/lib/**.so* mr,' "$session_closure_rules"
          require_rule '${self.nixosConfigurations.laptop.pkgs.libXxf86vm}/lib/**.so* mr,' "$session_closure_rules"
          if awk '$NF ~ /^[a-z]+,$/ && $NF ~ /[wxkl]/ { bad=1 } END { exit !bad }' "$session_rules" "$session_closure_rules"; then
            echo "read-only session rules unexpectedly grant write or execution" >&2
            exit 1
          fi

          closure_rules="$(sed -n 's/^[[:space:]]*include "\([^"]*apparmor-closure-rules-local-brave\)"/\1/p' "$brave_common")"
          test -r "$closure_rules"
          if grep -F ' ixr,' "$closure_rules"; then
            echo "read-only application closure unexpectedly grants execution" >&2
            exit 1
          fi
          require_rule '/**.node mr,' "$closure_rules"

          require_rule '${self.nixosConfigurations.laptop.pkgs.brave}/bin/** ixr,' "$brave_common"
          require_rule '${self.nixosConfigurations.laptop.pkgs.brave}/opt/** ixr,' "$brave_common"
          require_rule '${self.nixosConfigurations.laptop.pkgs.coreutils-full}/bin/** ixr,' "$brave_common"

          for app_name in ${
            pkgs-unstable.lib.concatMapStringsSep " " pkgs-unstable.lib.escapeShellArg applicationNames
          }; do
            app_profile="$profile_directory/local-$app_name"
            app_common="$(common_rules "$app_profile")"
            require_rule '${self.nixosConfigurations.laptop.pkgs.coreutils-full}/bin/** ixr,' "$app_common"
            require_rule '${self.nixosConfigurations.laptop.pkgs.glibc.bin}/bin/** ixr,' "$app_common"
          done

          for app_name in ${
            pkgs-unstable.lib.concatMapStringsSep " " pkgs-unstable.lib.escapeShellArg desktopApplicationNames
          }; do
            app_profile="$profile_directory/local-$app_name"
            app_common="$(common_rules "$app_profile")"
            require_rule '/ r,' "$app_common"
            require_rule '/etc/ r,' "$app_common"
            require_rule 'deny /etc/opt/{,**} w,' "$app_common"
            require_rule '/proc/[0-9]*/{cgroup,stat} r,' "$app_common"
            require_rule 'owner /proc/[0-9]*/{cmdline,mountinfo,statm,smaps,smaps_rollup} r,' "$app_common"
            require_rule 'owner /proc/[0-9]*/task/[0-9]*/{stat,status} r,' "$app_common"
            require_rule 'owner /proc/[0-9]*/task/[0-9]*/comm rw,' "$app_common"
            require_rule '/proc/pressure/{cpu,io,memory} r,' "$app_common"
            require_rule '/sys/fs/cgroup/**/{cpu.max,memory.high,memory.max} r,' "$app_common"
            require_rule 'deny owner /proc/[0-9]*/clear_refs w,' "$app_common"
            require_rule '/sys/devices/system/cpu/{kernel_max,present} r,' "$app_common"
            require_rule '/sys/devices/pci[0-9a-fA-F]*/**/class r,' "$app_common"
            require_rule '/sys/devices/virtual/dmi/id/{product_name,product_sku,sys_vendor} r,' "$app_common"
            require_rule '/sys/devices/system/cpu/cpu[0-9]*/topology/{core_cpus,core_cpus_list} r,' "$app_common"
            require_rule 'owner /run/user/[0-9]*/wayland-proxy-* rw,' "$app_common"
            require_rule '${self.nixosConfigurations.laptop.pkgs.xdg-utils}/bin/** ixr,' "$app_common"
            require_rule '${self.nixosConfigurations.laptop.pkgs.gawk}/bin/** ixr,' "$app_common"
            require_rule '${self.nixosConfigurations.laptop.pkgs.gnugrep}/bin/** ixr,' "$app_common"
            require_rule '${self.nixosConfigurations.laptop.pkgs.dbus}/bin/** ixr,' "$app_common"
            require_rule '${self.nixosConfigurations.laptop.pkgs.glib.out}/libexec/gio-launch-desktop ixr,' "$app_common"
            test -x '${self.nixosConfigurations.laptop.pkgs.glib.out}/libexec/gio-launch-desktop'
          done

          for app_name in ${
            pkgs-unstable.lib.concatMapStringsSep " " pkgs-unstable.lib.escapeShellArg networkApplicationNames
          }; do
            app_profile="$profile_directory/local-$app_name"
            app_common="$(common_rules "$app_profile")"
            require_rule 'network netlink dgram,' "$app_common"
            require_rule '/proc/sys/net/core/somaxconn r,' "$app_common"
            require_rule '/proc/sys/net/ipv4/ip_local_port_range r,' "$app_common"
          done

          for app_name in ${
            pkgs-unstable.lib.concatMapStringsSep " " pkgs-unstable.lib.escapeShellArg gpuApplicationNames
          }; do
            app_profile="$profile_directory/local-$app_name"
            app_common="$(common_rules "$app_profile")"
            require_rule '/dev/ r,' "$app_common"
            require_rule '/sys/devices/pci[0-9a-fA-F]*:[0-9a-fA-F]*/ r,' "$app_common"
            require_rule '/sys/devices/pci[0-9a-fA-F]*:[0-9a-fA-F]*/**/ r,' "$app_common"
            require_rule '/sys/devices/**/drm/ r,' "$app_common"
            require_rule '/sys/devices/**/drm/{card[0-9]*,renderD[0-9]*}/ r,' "$app_common"
          done

          for app_name in ${
            pkgs-unstable.lib.concatMapStringsSep " " pkgs-unstable.lib.escapeShellArg
              deviceDiscoveryApplicationNames
          }; do
            app_profile="$profile_directory/local-$app_name"
            app_common="$(common_rules "$app_profile")"
            require_rule '/dev/ r,' "$app_common"
            require_rule '/dev/disk/by-uuid/ r,' "$app_common"
            require_rule '/sys/class/ r,' "$app_common"
            require_rule '/sys/class/*/ r,' "$app_common"
            require_rule '/run/udev/data/{+hid:*,+usb:*,c10:*,c13:*,c189:*} r,' "$app_common"
            require_rule '/sys/devices/**/{0003,0005,0018}:*:*.*/report_descriptor r,' "$app_common"
            require_rule '/sys/devices/**/usb[0-9]*/**/{bConfigurationValue,busnum,devnum,interface,serial} r,' "$app_common"
            require_rule '/sys/devices/virtual/tty/tty0/active r,' "$app_common"
          done

          for app_name in ${
            pkgs-unstable.lib.concatMapStringsSep " " pkgs-unstable.lib.escapeShellArg
              bubblewrapApplicationNames
          }; do
            app_profile="$profile_directory/local-$app_name"
            app_common="$(common_rules "$app_profile")"
            bwrap_target=bwrap
            if [ "$app_name" = claude-code ]; then
              bwrap_target=local-claude-code-bwrap
            fi
            require_rule "priority=100 ${self.nixosConfigurations.laptop.pkgs.stable.bubblewrap}/bin/bwrap Px -> $bwrap_target," "$app_profile"
            if grep -F 'allow mount,' "$app_common" \
              || grep -F 'allow pivot_root,' "$app_common" \
              || grep -F 'capability sys_admin,' "$app_common"; then
              echo "Bubblewrap setup privileges leaked into local-$app_name" >&2
              exit 1
            fi
          done

          for app_name in ${
            pkgs-unstable.lib.concatMapStringsSep " " pkgs-unstable.lib.escapeShellArg usernsApplicationNames
          }; do
            app_profile="$profile_directory/local-$app_name"
            app_common="$(common_rules "$app_profile")"
            require_rule 'capability setpcap,' "$app_common"
            require_rule 'capability sys_admin,' "$app_common"
            require_rule 'capability sys_chroot,' "$app_common"
            require_rule 'capability sys_ptrace,' "$app_common"
            require_rule '/proc/[0-9]*/task/[0-9]*/status r,' "$app_common"
            require_rule 'owner /proc/[0-9]*/{gid_map,setgroups,uid_map} rw,' "$app_common"
            if grep -Fq 'profile namespace-bootstrap' "$app_profile"; then
              echo "user namespace rules escaped into a child profile" >&2
              exit 1
            fi
          done

          for app_name in ${
            pkgs-unstable.lib.concatMapStringsSep " " pkgs-unstable.lib.escapeShellArg developerApplicationNames
          }; do
            app_profile="$profile_directory/local-$app_name"
            app_common="$(common_rules "$app_profile")"
            require_rule '/nix/store/** mr,' "$app_common"
            require_rule '/nix/store/** ixr,' "$app_common"
            require_rule '/nix/store/ r,' "$app_common"
            require_rule '/nix/var/log/nix/ r,' "$app_common"
            require_rule '/nix/var/log/nix/drvs/{,**} r,' "$app_common"
            require_rule 'owner @{HOME}/.agents/skills/{,**} r,' "$app_common"
            require_rule 'owner @{HOME}/.cache/nix/{,**} rwkl,' "$app_common"
            require_rule 'owner @{HOME}/.cache/matplotlib/{,**} rwkl,' "$app_common"
            require_rule 'owner @{HOME}/.cache/uv/{,**} rwkl,' "$app_common"
            require_rule 'owner @{HOME}/.cache/go-build/{,**} rwkl,' "$app_common"
            require_rule 'owner @{HOME}/.cache/ort.pyke.io/{,**} rwkl,' "$app_common"
            require_rule 'owner @{HOME}/.cargo/.global-cache rwk,' "$app_common"
            require_rule 'owner @{HOME}/.cargo/.package-cache{,-mutate} rwk,' "$app_common"
            require_rule 'owner @{HOME}/.cargo/registry/{,**} rwkl,' "$app_common"
            require_rule 'owner @{HOME}/.config/go/telemetry/{,**} rwkl,' "$app_common"
            require_rule 'owner @{HOME}/.config/jj/repos/{,**} r,' "$app_common"
            require_rule 'owner @{HOME}/.config/git/ignore r,' "$app_common"
            require_rule 'owner @{HOME}/.keras/keras.json r,' "$app_common"
            require_rule 'owner @{HOME}/.local/share/*-skills/{,**} r,' "$app_common"
            require_rule 'owner @{HOME}/.local/share/uv/{,**} rwkl,' "$app_common"
            require_rule '/nix/store/*-man-cache/index.db rk,' "$app_common"
            require_rule '/var/cache/man/nixos-mandb/index.db rk,' "$app_common"
            require_rule 'owner @{HOME}/** m,' "$app_common"
            require_rule 'owner /tmp/** m,' "$app_common"
            require_rule 'owner /var/tmp/** m,' "$app_common"
            require_rule 'owner /dev/shm/{,**} rwkl,' "$app_common"
            require_rule 'owner /proc/[0-9]*/fd/ r,' "$app_common"
            require_rule 'ptrace (read, trace) peer=@{profile_name},' "$app_common"
            require_rule 'priority=50 /nix/store/** Pix,' "$app_common"
            if grep -F 'apparmor-closure-rules-local-' "$app_common"; then
              echo "developer profile unexpectedly includes a redundant closure" >&2
              exit 1
            fi
          done

          for app_name in ${
            pkgs-unstable.lib.concatMapStringsSep " " pkgs-unstable.lib.escapeShellArg
              hostDiagnosticApplicationNames
          }; do
            app_profile="$profile_directory/local-$app_name"
            app_common="$(common_rules "$app_profile")"
            require_rule '/etc/machine-id r,' "$app_common"
            require_rule '/proc/[0-9]*/{cgroup,cmdline,mountinfo,mounts,stat,status} r,' "$app_common"
            require_rule 'owner /proc/[0-9]*/{gid_map,uid_map} r,' "$app_common"
            require_rule 'owner /proc/[0-9]*/attr/current r,' "$app_common"
            ! grep -F '/proc/[0-9]*/{cgroup,cmdline,mountinfo,mounts,stat,statm,status} r,' "$app_common"
            require_rule '/proc/[0-9]*/task/[0-9]*/{comm,stat,status} r,' "$app_common"
            require_rule '/proc/bus/pci/devices r,' "$app_common"
            require_rule '/proc/modules r,' "$app_common"
            require_rule '/proc/sys/kernel/{osrelease,ostype,pid_max,unprivileged_userns_clone} r,' "$app_common"
            require_rule '/proc/sys/vm/{mmap_min_addr,nr_hugepages} r,' "$app_common"
            require_rule '/run/log/journal/{,**} r,' "$app_common"
            require_rule '/sys/class/{accel,drm}/ r,' "$app_common"
            require_rule '/sys/devices/pci[0-9a-fA-F]*/**/device r,' "$app_common"
            require_rule '/sys/devices/pci[0-9a-fA-F]*/**/vendor r,' "$app_common"
            require_rule '/sys/kernel/security/apparmor/features/{,**} r,' "$app_common"
            require_rule '/sys/kernel/security/apparmor/profiles r,' "$app_common"
            require_rule '/var/log/journal/{,**} r,' "$app_common"
            require_rule 'owner "/home/${username}/.local/state/apparmor-reports/{,**}" r,' "$app_common"
          done

          for app_name in ${
            pkgs-unstable.lib.concatMapStringsSep " " pkgs-unstable.lib.escapeShellArg userFilesApplicationNames
          }; do
            app_profile="$profile_directory/local-$app_name"
            app_common="$(common_rules "$app_profile")"
            grep -Eq '^[[:space:]]*@\{HOME\}/\[\^\.n\]\*/\{,\*\*\} r,$' "$app_common"
            grep -Eq '^[[:space:]]*owner @\{HOME\}/\[\^\.n\]\*/\{,\*\*\} rwkl,$' "$app_common"
          done

          for app_name in ${
            pkgs-unstable.lib.concatMapStringsSep " " pkgs-unstable.lib.escapeShellArg
              nonTerminalApplicationNames
          }; do
            app_profile="$profile_directory/local-$app_name"
            app_common="$(common_rules "$app_profile")"
            require_rule 'deny /dev/tty rw,' "$app_common"
            require_rule 'deny owner /dev/pts/[0-9]* rw,' "$app_common"
          done

          file_roller_common="$(common_rules "$profile_directory/local-file-roller")"
          require_rule '${pkgs-unstable.unzip}/bin/** ixr,' "$file_roller_common"

          require_rule 'owner @{HOME}/.config/BraveSoftware/Brave-Browser/WidevineCdm/*/_platform_specific/linux_x64/libwidevinecdm.so mr,' "$brave_common"
          require_rule '/dev/hidraw[0-9]* rw,' "$brave_common"
          require_rule '/run/udev/data/+hid:0003:1050:0407.* r,' "$brave_common"
          require_rule '/sys/devices/**/0003:1050:0407.*/report_descriptor r,' "$brave_common"
          require_rule 'owner "@{HOME}/.pki/nssdb/{,**}" rwkl,' "$brave_common"

          evince_common="$(common_rules "$profile_directory/local-evince")"
          require_rule 'owner @{HOME}/.local/share/gvfs-metadata/{,**} r,' "$evince_common"

          motrix_common="$(common_rules "$profile_directory/local-motrix")"
          require_rule '${self.nixosConfigurations.laptop.pkgs.webkitgtk_4_1}/libexec/** ixr,' "$motrix_common"
          require_rule 'owner "@{HOME}/.local/share/com.motrix.next/{,**}" rwkl,' "$motrix_common"

          logseq_common="$(common_rules "$profile_directory/local-logseq")"
          require_rule '${self.nixosConfigurations.laptop.pkgs.logseq-appimage.appimageContents}/AppRun ixr,' "$logseq_common"
          require_rule '${self.nixosConfigurations.laptop.pkgs.logseq-appimage.appimageContents}/logseq ixr,' "$logseq_common"
          require_rule 'owner "@{HOME}/.logseq/{,**}" rwkl,' "$logseq_common"
          if grep -F '${self.nixosConfigurations.laptop.pkgs.bubblewrap}' "$logseq_common" \
            || grep -F 'mount,' "$logseq_common" \
            || grep -F 'pivot_root' "$logseq_common" \
            || grep -F '/newroot' "$logseq_common" \
            || grep -F 'Px -> local-logseq' "$profile_directory/local-logseq"; then
            echo "Logseq unexpectedly retains its FHS bubblewrap sandbox rules" >&2
            exit 1
          fi

          inkscape_common="$(common_rules "$profile_directory/local-inkscape")"
          require_rule 'owner "@{HOME}/.config/enchant/{,**}" rwkl,' "$inkscape_common"

          proton_pass_common="$(common_rules "$profile_directory/local-proton-pass")"
          require_rule '${self.nixosConfigurations.laptop.pkgs.electron.unwrapped}/libexec/** ixr,' "$proton_pass_common"

          protonmail_bridge_common="$(common_rules "$profile_directory/local-protonmail-bridge")"
          require_rule 'owner "@{HOME}/.local/share/protonmail/{,**}" rwkl,' "$protonmail_bridge_common"

          thunderbird_common="$(common_rules "$profile_directory/local-thunderbird")"
          require_rule '${self.nixosConfigurations.laptop.pkgs.thunderbird.unwrapped}/lib/thunderbird/glxtest ixr,' "$thunderbird_common"
          require_rule '${self.nixosConfigurations.laptop.pkgs.thunderbird.unwrapped}/lib/thunderbird/pingsender ixr,' "$thunderbird_common"
          require_rule '${self.nixosConfigurations.laptop.pkgs.thunderbird.unwrapped}/lib/thunderbird/vaapitest ixr,' "$thunderbird_common"
          require_rule 'priority=100 ${self.nixosConfigurations.laptop.pkgs.brave}/bin/brave Px -> local-brave,' "$thunderbird_common"

          for app_name in textmaker planmaker presentations; do
            softmaker_common="$(common_rules "$profile_directory/local-$app_name")"
            require_rule '${self.nixosConfigurations.laptop.pkgs.util-linux}/bin/whereis ixr,' "$softmaker_common"
          done

          claude_common="$(common_rules "$profile_directory/local-claude-code")"
          require_rule 'owner @{run}/user/[0-9]*/cc-socks/{,**} rwkl,' "$claude_common"
          require_rule '/etc/claude-code/managed-settings.d/{,**} r,' "$claude_common"
          require_rule 'owner @{HOME}/.claude.json rwkl,' "$claude_common"
          require_rule 'owner @{HOME}/.claude.json.tmp.* rwkl,' "$claude_common"
          require_rule 'owner @{HOME}/.claude.json.lock/{,**} rwkl,' "$claude_common"
          require_rule 'owner @{HOME}/.cache/claude-cli-nodejs/{,**} rwkl,' "$claude_common"
          require_rule 'owner "@{HOME}/.claude.lock/{,**}" rwkl,' "$claude_common"
          require_rule 'owner "@{HOME}/.config/anthropic/{,**}" rwkl,' "$claude_common"
          require_rule 'owner @{HOME}/.config/user-dirs.dirs r,' "$claude_common"
          require_rule 'owner @{HOME}/.local/share/mime/{globs,magic} r,' "$claude_common"
          require_rule 'owner @{HOME}/.local/share/applications/claude-code-url-handler.desktop rw,' "$claude_common"
          require_rule 'deny owner @{HOME}/.config/BraveSoftware/Brave-Browser/{,**} rwklm,' "$claude_common"
          require_rule 'deny owner @{HOME}/.config/chromium/{,**} rwklm,' "$claude_common"
          require_rule 'deny owner @{HOME}/.config/google-chrome/{,**} rwklm,' "$claude_common"
          require_rule 'deny owner @{HOME}/.config/microsoft-edge/{,**} rwklm,' "$claude_common"
          require_rule 'deny owner @{HOME}/.config/vivaldi/{,**} rwklm,' "$claude_common"

          codex_common="$(common_rules "$profile_directory/local-codex-cli")"
          require_rule 'owner @{HOME}/.cache/codex-runtimes/{,**} rwkl,' "$codex_common"
          require_rule 'owner @{HOME}/.gnupg/.#lk* rwk,' "$codex_common"

          qbittorrent_common="$(common_rules "$profile_directory/local-qbittorrent")"
          require_rule 'deny ptrace read peer=unconfined,' "$qbittorrent_common"

          require_rule '/nix/store/*-etc-nsswitch.conf r,' "$profile_directory/local-apply-secret-dns"
          require_rule '"${
            toString self.nixosConfigurations.laptop.config.environment.etc."containers/registries.conf".source
          }" r,' "$profile_directory/local-codex-cli-container-engine"
          require_rule '"${
            toString self.nixosConfigurations.laptop.config.environment.etc."containers/registries.conf".source
          }" r,' "$profile_directory/local-claude-code-container-engine"
          require_rule '/run/secrets.d/[0-9]*/dns/' "$profile_directory/local-apply-secret-dns"
          require_rule 'include <abstractions/dbus-strict>' "$profile_directory/local-apply-secret-dns"
          require_rule 'dbus (send, receive) bus=system peer=(name=org.freedesktop.systemd1),' "$profile_directory/local-apply-secret-dns"
          require_rule 'owner /proc/[0-9]*/stat r,' "$profile_directory/local-apply-secret-dns"
          require_rule '/nix/store/*-etc-nsswitch.conf r,' "$profile_directory/local-syncthing"
          require_rule 'owner /proc/[0-9]*/{stat,statm} r,' "$profile_directory/local-syncthing"
          require_rule '/nix/store/*-etc-os-release r,' "$profile_directory/local-syncthing"
          require_rule '/sys/fs/cgroup/**/cpu.max r,' "$profile_directory/local-syncthing"
          require_rule 'network netlink dgram,' "$profile_directory/local-syncthing"
          require_rule '"/proc/bus/pci/devices" r,' "$profile_directory/local-syncthing"
          require_rule '"/proc/modules" r,' "$profile_directory/local-syncthing"

          pqiv_common="$(common_rules "$profile_directory/local-pqiv")"
          if grep -F 'owner @{HOME}/** rwkl,' "$pqiv_common" \
            || grep -F '/proc/{,**}' "$pqiv_common" \
            || grep -F '/run/user/[0-9]*/{,**}' "$pqiv_common" \
            || grep -F 'include <abstractions/nameservice>' "$pqiv_common" \
            || grep -F 'include <abstractions/audio>' "$pqiv_common" \
            || grep -F '/dev/video[0-9]* rw,' "$pqiv_common"; then
            echo "minimal desktop capability set leaked broad host access" >&2
            exit 1
          fi

          require_rule 'Px -> local-drawio,' "$profile_directory/local-drawio"
          if grep -F 'profile namespace-bootstrap' "$profile_directory/local-drawio"; then
            echo "drawio unexpectedly contains a namespace child profile" >&2
            exit 1
          fi

          proton_vpn_common="$(common_rules "$profile_directory/local-proton-vpn")"
          require_rule 'dbus (send, receive) bus=system peer=(name=org.freedesktop.NetworkManager),' "$proton_vpn_common"
          require_rule 'dbus (send, receive) bus=system peer=(name=org.freedesktop.login1),' "$proton_vpn_common"
          if grep -Fx 'dbus bus=system,' "$proton_vpn_common"; then
            echo "unscoped system D-Bus access remains" >&2
            exit 1
          fi

          for policy in "$profile_directory"/bwrap "$profile_directory"/local-*; do
            attachment="$(sed -n 's/^[[:space:]]*profile local-[^[:space:]]* \([^[:space:]]*\) flags=.*/\1/p' "$policy")"
            if [ -n "$attachment" ]; then
              test -x "$attachment"
            fi
            apparmor_parser --config-file /dev/null --quiet --skip-kernel-load --skip-cache \
              --Include "$profile_directory" ${includeArguments} "$policy"
          done
        done

        enforce_brave_common="$(common_rules ${pkgs-unstable.lib.escapeShellArg enforceProfileDirectory}/local-brave)"
        complain_brave_common="$(common_rules ${pkgs-unstable.lib.escapeShellArg complainProfileDirectory}/local-brave)"
        if grep -F 'owner @{HOME}/[^.]*/{,**} rwkl,' "$complain_brave_common" \
          || grep -F 'audit deny @{HOME}/nixos-config' "$complain_brave_common"; then
          echo "complain policy re-grants a reserved NixOS configuration tree" >&2
          exit 1
        fi
        require_rule 'audit deny @{HOME}/.ssh/id_* rwklm,' "$enforce_brave_common"
        require_rule 'audit deny @{HOME}/.ssh/config.secrets rwklm,' "$enforce_brave_common"
        require_rule 'audit deny @{HOME}/.ssh/known_hosts{,.old} rwklm,' "$enforce_brave_common"
        require_rule 'audit deny @{HOME}/.config/gh/{config.yml,hosts.yml} rwklm,' "$enforce_brave_common"
        require_rule 'audit deny @{HOME}/.config/glab-cli/{aliases.yml,config.yml} rwklm,' "$enforce_brave_common"
        require_rule 'audit deny @{HOME}/.ssh/{cm,sockets}/{,**} rwklm,' "$enforce_brave_common"
        require_rule 'audit deny /run/secrets.d/{,**} rwklm,' "$enforce_brave_common"
        require_rule 'audit deny @{HOME}/nixos-config/{,**} wklm,' "$enforce_brave_common"
        require_rule 'audit deny @{HOME}/nixos-config-writable/{,**} wklm,' "$enforce_brave_common"
        require_rule 'dbus send bus=session peer=(name=org.freedesktop.secrets),' "$enforce_brave_common"
        if grep -F 'audit deny dbus send bus=session peer=(name=org.freedesktop.secrets),' "$enforce_brave_common"; then
          echo "explicit Brave credential-broker access was overridden by a deny" >&2
          exit 1
        fi

        enforce_codex_common="$(common_rules ${pkgs-unstable.lib.escapeShellArg enforceProfileDirectory}/local-codex-cli)"
        require_rule 'owner @{HOME}/.ssh/id_* r,' "$enforce_codex_common"
        require_rule 'owner @{HOME}/.ssh/known_hosts{,.old} r,' "$enforce_codex_common"
        require_rule 'owner @{HOME}/.config/gh/{config.yml,hosts.yml} r,' "$enforce_codex_common"
        require_rule 'owner @{HOME}/.config/glab-cli/{aliases.yml,config.yml} r,' "$enforce_codex_common"
        require_rule 'owner @{HOME}/.gnupg/common.conf r,' "$enforce_codex_common"
        require_rule 'owner @{HOME}/.gnupg/trustdb.gpg rw,' "$enforce_codex_common"
        require_rule 'owner @{HOME}/.netrc r,' "$enforce_codex_common"
        require_rule 'owner @{HOME}/nixos-config-writable/{,**} rwkl,' "$enforce_codex_common"
        require_rule 'audit deny @{HOME}/.gnupg/private-keys-v1.d/{,**} rwklm,' "$enforce_codex_common"
        if grep -F 'audit deny @{HOME}/.ssh/id_* rwklm,' "$enforce_codex_common"; then
          echo "explicit Codex SSH identity access was overridden by a deny" >&2
          exit 1
        fi
        enforce_claude_common="$(common_rules ${pkgs-unstable.lib.escapeShellArg enforceProfileDirectory}/local-claude-code)"
        require_rule 'audit deny @{HOME}/.netrc rwklm,' "$enforce_claude_common"
        require_rule 'owner @{HOME}/.ssh/known_hosts{,.old} r,' "$enforce_claude_common"
        require_rule 'owner @{HOME}/.config/gh/{config.yml,hosts.yml} r,' "$enforce_claude_common"
        require_rule 'owner @{HOME}/.config/glab-cli/{aliases.yml,config.yml} r,' "$enforce_claude_common"
        if grep -F 'audit deny @{HOME}/.config/gh/{config.yml,hosts.yml} rwklm,' "$enforce_codex_common" \
          || grep -F 'audit deny @{HOME}/.config/gh/{config.yml,hosts.yml} rwklm,' "$enforce_claude_common"; then
          echo "explicit agent forge authentication access was overridden by a deny" >&2
          exit 1
        fi
        touch "$out"
      '';

  apparmor-vm = import ./apparmor.nix {
    inherit home-manager;
    pkgs = pkgs-unstable.extend selfPkgs.overlay;
  };
  desktop-toplevel = self.nixosConfigurations.desktop.config.system.build.toplevel;
  laptop-toplevel = self.nixosConfigurations.laptop.config.system.build.toplevel;
}
