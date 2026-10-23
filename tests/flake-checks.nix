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
  nixpkgs-inputs =
    let
      inherit (self) inputs;
      sharedInputs = builtins.attrValues (builtins.removeAttrs inputs [ "nix-cachyos-kernel" ]);
      packageSources = map (input: input.outPath) [
        inputs.nixpkgs
        inputs.nixpkgs-stable
        inputs.nixpkgs-master
      ];
    in
    assert builtins.all (
      input: !(input ? inputs.nixpkgs) || builtins.elem input.inputs.nixpkgs.outPath packageSources
    ) sharedInputs;
    assert builtins.elem inputs.niri.inputs.nixpkgs-stable.outPath packageSources;
    pkgs-unstable.runCommand "nixpkgs-inputs" { } ''
      touch "$out"
    '';

  collabora-font-cache =
    let
      collabora = self.packages.${pkgs-unstable.stdenv.hostPlatform.system}.collabora-desktop-bin;
    in
    pkgs-unstable.runCommand "collabora-font-cache"
      {
        nativeBuildInputs = [
          pkgs-unstable.fontconfig
          pkgs-unstable.gnused
        ];
      }
      ''
        export HOME="$TMPDIR/home"
        export XDG_CONFIG_HOME="$HOME/.config"
        export XDG_DATA_HOME="$HOME/.local/share"
        mkdir -p "$XDG_DATA_HOME/fonts"
        cp ${pkgs-unstable.dejavu_fonts}/share/fonts/truetype/DejaVuSans.ttf "$XDG_DATA_HOME/fonts/"
        cat > fonts.conf <<EOF
        <?xml version="1.0"?>
        <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
        <fontconfig>
          <dir>$XDG_DATA_HOME/fonts</dir>
          <cachedir prefix="xdg">fontconfig</cachedir>
        </fontconfig>
        EOF
        # The Nix build sandbox has no sysfs; font matching does not need it.
        sed -e 's|-- /app/bin/coda-qt|-- /usr/bin/fc-match|' \
          -e '\|--ro-bind /sys /sys|d' ${collabora.launcher} > font-probe

        for cache in "$HOME/.cache" "$TMPDIR/custom-cache"; do
          export XDG_CACHE_HOME="$cache"
          FONTCONFIG_FILE="$PWD/fonts.conf" fc-cache --force
          find "$cache/fontconfig" -name '*cache-*' -exec sha256sum {} + | sort > host-cache-before
          if [ "$cache" = "$HOME/.cache" ]; then
            unset XDG_CACHE_HOME
          fi
          bash font-probe -f '%{family}\n%{file}\n%{charset}\n' 'DejaVu Sans' > match
          grep -Fx 'DejaVu Sans' match
          grep -qE '^20-7e( |$)' match
          test -s "$cache/collabora-desktop-bin/fontconfig/CACHEDIR.TAG"
          find "$cache/fontconfig" -name '*cache-*' -exec sha256sum {} + | sort > host-cache-after
          cmp host-cache-before host-cache-after
        done
        touch "$out"
      '';

  binary-release-signatures =
    pkgs-unstable.runCommand "binary-release-signatures"
      {
        nativeBuildInputs = [
          pkgs-unstable.python3
          pkgs-unstable.gnupg
        ];
        PYTHONPATH = ../pkgs;
        BRAVE_UPDATER_SOURCE = ../pkgs/update-brave.py;
        PROTON_UPDATER_SOURCE = ../pkgs/update-proton.py;
        BRAVE_RELEASE_KEY = ../pkgs/brave/release-key.asc;
        BRIDGE_RELEASE_KEY = ../pkgs/protonmail-bridge/release-key.asc;
        RELEASE_SIGNATURE_FIXTURES = ./fixtures/release-signatures;
      }
      ''
        python ${./test_release_signatures.py}
        touch "$out"
      '';

  proton-package-updates =
    pkgs-unstable.runCommand "proton-package-updates"
      {
        nativeBuildInputs = [ pkgs-unstable.python3 ];
        PYTHONPATH = ../pkgs;
      }
      ''
        PROTON_UPDATER_SOURCE=${../pkgs/update-proton.py} \
          python ${./test_update_proton.py}
        touch "$out"
      '';

  measured-boot-retention =
    let
      excessiveRetentionHost = self.nixosConfigurations.laptop.extendModules {
        modules = [
          {
            specialisation.extra-kernel.configuration = { };
          }
        ];
      };
      retentionAssertions = builtins.filter (
        assertion:
        !assertion.assertion && pkgs-unstable.lib.hasInfix "Measured boot with PCR 4" assertion.message
      ) excessiveRetentionHost.config.assertions;
    in
    assert builtins.length retentionAssertions == 1;
    assert !(builtins.tryEval excessiveRetentionHost.config.system.build.toplevel.drvPath).success;
    pkgs-unstable.runCommand "measured-boot-retention" { } ''
      touch "$out"
    '';

  lanzaboote-historical-retention =
    let
      host = self.nixosConfigurations.laptop;
    in
    pkgs-unstable.runCommand "lanzaboote-historical-retention"
      {
        nativeBuildInputs = [ pkgs-unstable.python3 ];
      }
      ''
        export PATH=${host.config.systemd.package}/lib/systemd:$PATH
        python ${./lanzaboote-retention.py} \
          ${pkgs-unstable.lib.getExe host.config.boot.lanzaboote.package} \
          ${host.config.systemd.package} \
          ${host.config.boot.lanzaboote.package.src}/systemd/tests/fixtures/uefi-keys
        touch "$out"
      '';

  niri-mesa-runtime =
    let
      checkHost =
        hostName:
        let
          pkgs = self.nixosConfigurations.${hostName}.pkgs;
        in
        ''
          for binary in ${pkgs.niri-host}/bin/niri ${pkgs.niri-baseline}/bin/niri; do
            loader=$(patchelf --print-interpreter "$binary")
            library_path=$(patchelf --print-rpath "$binary")
            "$loader" --library-path "$library_path" ./mesa-load \
              ${pkgs.mesa}/lib/libgallium-${pkgs.mesa.version}.so
          done
        '';
    in
    pkgs-unstable.runCommandCC "niri-mesa-runtime"
      {
        nativeBuildInputs = [ pkgs-unstable.patchelf ];
      }
      ''
        # Niri already has libm loaded when it opens the graphics driver.
        $CC -Wall -Wextra -Werror ${./niri-mesa-load.c} \
          -Wl,--no-as-needed -lm -ldl -o mesa-load
        ${checkHost "desktop"}
        ${checkHost "laptop"}
        touch "$out"
      '';

  dms-application-theming =
    let
      checkHost =
        hostName:
        let
          host = self.nixosConfigurations.${hostName}.config;
          home = host.home-manager.users.${username};
        in
        assert !home.stylix.targets.gtk.colors.enable;
        assert !(home.xdg.configFile ? "gtk-3.0/gtk.css");
        assert !(home.xdg.configFile ? "gtk-4.0/gtk.css");
        assert !home.stylix.targets.qt.enable;
        assert !(home.xdg.configFile ? "qt5ct/qt5ct.conf");
        assert !(home.xdg.configFile ? "qt6ct/qt6ct.conf");
        assert !(home.xdg.configFile ? "Kvantum/kvantum.kvconfig");
        assert home.qt.platformTheme.name == "qtct";
        assert home.qt.style.name == null;
        assert host.environment.variables.QT_QPA_PLATFORMTHEME == "qt5ct";
        assert host.environment.variables.QT_QPA_PLATFORMTHEME_QT6 == "qt6ct";
        ''
          export HOME="$TMPDIR/${hostName}"
          export XDG_CONFIG_HOME="$HOME/.config"
          export XDG_DATA_HOME="$HOME/.local/share"
          export XDG_DATA_DIRS=${home.gtk.theme.package}/share
          mkdir -p "$XDG_CONFIG_HOME"/gtk-{3,4}.0
          cp ${home.xdg.configFile."gtk-3.0/settings.ini".source} "$XDG_CONFIG_HOME/gtk-3.0/settings.ini"
          cp ${home.xdg.configFile."gtk-4.0/settings.ini".source} "$XDG_CONFIG_HOME/gtk-4.0/settings.ini"
          for version in 3 4; do
            cat > "$XDG_CONFIG_HOME/gtk-$version.0/dank-colors.css" <<'EOF'
          /* BEGIN DMS OVERRIDE */
          @define-color accent_color #123456;
          /* END DMS OVERRIDE */
          EOF
          done
          mkdir -p "$XDG_DATA_HOME/color-schemes"
          printf '[Colors:Window]\nBackgroundNormal=18,52,86\n' \
            > "$XDG_DATA_HOME/color-schemes/DankMatugen.colors"
          for qtct in qt5ct qt6ct; do
            mkdir -p "$XDG_CONFIG_HOME/$qtct"
            cat > "$XDG_CONFIG_HOME/$qtct/$qtct.conf" <<'EOF'
          [Appearance]
          style=Fusion
          custom_palette=false
          EOF
          done

          for mode in true false true; do
            bash ${self.inputs.dms}/quickshell/scripts/gtk.sh "$XDG_CONFIG_HOME" apply "$mode"
            test ! -L "$XDG_CONFIG_HOME/gtk-4.0/gtk.css"
            grep -Fx '@import url("dank-colors.css");' "$XDG_CONFIG_HOME/gtk-4.0/gtk.css"
            bash ${self.inputs.dms}/quickshell/scripts/gtk.sh "$XDG_CONFIG_HOME" patch "$mode"
            variant=""
            [ "$mode" = true ] || variant="-dark"
            grep -Fx '@define-color accent_color #123456;' \
              "$XDG_DATA_HOME/themes/adw-gtk3$variant/gtk-3.0/gtk.css"
            bash ${self.inputs.dms}/quickshell/scripts/qt.sh "$XDG_CONFIG_HOME"
            for qtct in qt5ct qt6ct; do
              qt_config="$XDG_CONFIG_HOME/$qtct/$qtct.conf"
              grep -Fx "color_scheme_path=$XDG_DATA_HOME/color-schemes/DankMatugen.colors" "$qt_config"
              grep -Fx 'custom_palette=true' "$qt_config"
              grep -Fx 'style=Fusion' "$qt_config"
              test "$(grep -c '^color_scheme_path=' "$qt_config")" -eq 1
            done
          done
          cmp ${home.xdg.configFile."gtk-3.0/settings.ini".source} "$XDG_CONFIG_HOME/gtk-3.0/settings.ini"
          cmp ${home.xdg.configFile."gtk-4.0/settings.ini".source} "$XDG_CONFIG_HOME/gtk-4.0/settings.ini"
        '';
    in
    pkgs-unstable.runCommand "dms-application-theming"
      {
        nativeBuildInputs = with pkgs-unstable; [
          libsForQt5.qt5ct
          qt6Packages.qt6ct
        ];
      }
      ''
        ${checkHost "desktop"}
        ${checkHost "laptop"}
        touch "$out"
      '';

  manage-dns-portal =
    pkgs-unstable.runCommand "manage-dns-portal-test"
      {
        nativeBuildInputs = with pkgs-unstable; [
          bash
          coreutils
          gawk
          gnugrep
          gnused
          jq
        ];
      }
      ''
        bash ${./manage-dns.sh} ${../modules/core/manage-dns-portal.sh} ${../modules/core/manage-dns-connection-change.sh}
        touch "$out"
      '';

  sonoff-serial-access =
    let
      ruleDirectories =
        map (host: self.nixosConfigurations.${host}.config.environment.etc."udev/rules.d".source)
          [
            "desktop"
            "laptop"
          ];
    in
    pkgs-unstable.runCommand "sonoff-serial-access"
      {
        nativeBuildInputs = with pkgs-unstable; [
          jq
          systemd
          umockdev
        ];
      }
      ''
        export SYSTEMD_LOG_LEVEL=err
        sed 's/A: product=Sonoff Zigbee 3.0 USB Dongle Plus/A: product=CP2102 USB to UART Bridge Controller/' \
          ${./sonoff-serial.umockdev} > generic-serial.umockdev

        for rules in ${pkgs-unstable.lib.escapeShellArgs ruleDirectories}; do
          umockdev-run --device=${./sonoff-serial.umockdev} -- \
            udevadm test --json=short --action=add --resolve-names=never \
              --extra-rules-dir="$rules" /sys/devices/usb1/1-1/ttyUSB0 > sonoff.json
          jq -e '(.currentTags | index("uaccess") != null) and
            any(.queuedCommands[]; .type == "builtin" and .command == "uaccess")' sonoff.json

          umockdev-run --device=generic-serial.umockdev -- \
            udevadm test --json=short --action=add --resolve-names=never \
              --extra-rules-dir="$rules" /sys/devices/usb1/1-1/ttyUSB0 > generic.json
          jq -e '(.currentTags | index("uaccess") == null) and
            all(.queuedCommands[]?; .command != "uaccess")' generic.json
        done
        touch "$out"
      '';

  host-cpu-optimizations =
    let
      desktopPkgs = self.nixosConfigurations.desktop.pkgs;
      laptopPkgs = self.nixosConfigurations.laptop.pkgs;
      desktopKernel = self.nixosConfigurations.desktop.config.boot.kernelPackages.kernel;
      laptopKernel = self.nixosConfigurations.laptop.config.boot.kernelPackages.kernel;
      cachedKernel =
        self.inputs.nix-cachyos-kernel.packages.${pkgs-unstable.stdenv.hostPlatform.system}.linux-cachyos-latest-lto-zen4;
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
        assert check (kernel.drvPath == cachedKernel.drvPath);
        true;
    in
    assert checkHost "desktop" "znver5";
    assert checkHost "laptop" "znver4";
    assert desktopPkgs.flake.herdr.drvPath != laptopPkgs.flake.herdr.drvPath;
    assert desktopPkgs.niri-baseline.drvPath == laptopPkgs.niri-baseline.drvPath;
    assert desktopKernel.drvPath == laptopKernel.drvPath;
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
      desktopSecretWriter = builtins.head desktopHome.systemd.user.services.write-ssh-secret-config.Service.ExecStart;
      laptopSecretWriter = builtins.head laptopHome.systemd.user.services.write-ssh-secret-config.Service.ExecStart;
      laptopAgentLoader = laptopHome.systemd.user.services.ssh-agent.Service.ExecStartPost;
      desktopAgentEnvironment = desktopHome.systemd.user.services.ssh-agent.Service.Environment;
      laptopAgentEnvironment = laptopHome.systemd.user.services.ssh-agent.Service.Environment;
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
      caAgentIsOnDemand =
        home:
        let
          service = home.systemd.user.services.proton-pass-ca-agent;
        in
        (service.Install.WantedBy or [ ]) == [ ]
        && (service.Install.RequiredBy or [ ]) == [ ]
        && service.Unit.PartOf == [ "graphical-session.target" ]
        && service.Service.RuntimeMaxSec == "5min"
        && service.Service.RuntimeDirectoryMode == "0700"
        && service.Service.UMask == "0077"
        && home.services.gnome-keyring.components == [ "secrets" ];
    in
    assert desktopSsh."github.com".data.IdentityAgent == "SSH_AUTH_SOCK";
    assert desktopSsh."github.com".data.IdentityFile == "none";
    assert desktopSsh."gitlab.com".data.IdentityAgent == "SSH_AUTH_SOCK";
    assert desktopSsh."gitlab.com".data.IdentityFile == "none";
    assert serverForwardingIsRestricted desktopConfig;
    assert serverForwardingIsRestricted laptopConfig;
    assert caAgentIsOnDemand desktopHome;
    assert caAgentIsOnDemand laptopHome;
    assert desktopHome.services.gpg-agent.enableExtraSocket;
    assert laptopHome.services.gpg-agent.enableExtraSocket;
    assert builtins.elem "SSH_ASKPASS_REQUIRE=force" desktopAgentEnvironment;
    assert builtins.elem "SSH_ASKPASS_REQUIRE=force" laptopAgentEnvironment;
    assert gpgSyncIsSessionOneShot desktopHome desktopGpgSync;
    assert gpgSyncIsSessionOneShot laptopHome laptopGpgSync;
    pkgs-unstable.runCommand "credential-forwarding"
      {
        nativeBuildInputs = [
          pkgs-unstable.gnugrep
          pkgs-unstable.gnused
        ];
      }
      ''
        grep -F 'Host laptop-forwarded' ${desktopSecretWriter}
        grep -F 'Host desktop-forwarded' ${laptopSecretWriter}
        grep -F 'ForwardAgent \''${SSH_AUTH_SOCK}' ${desktopSecretWriter}
        grep -F 'RemoteForward $forwarded_gpg_socket $local_gpg_extra_socket' ${desktopSecretWriter}
        grep -F 'ControlMaster no' ${desktopSecretWriter}
        grep -F 'Host * !github.com !gitlab.com' ${desktopSecretWriter}
        grep -F 'Refusing to forward a GPG key file that is not a smartcard stub' ${desktopGpgSyncScript}

        cat > fake-ssh-add <<'EOF'
        #!/bin/sh
        if [ "$1" = -l ]; then
          probes=$(cat "$TEST_DIR/probes")
          probes=$((probes + 1))
          printf '%s\n' "$probes" > "$TEST_DIR/probes"
          [ "$probes" -gt "$READY_AFTER" ] && exit 1
          exit 2
        fi
        touch "$TEST_DIR/loaded"
        EOF
        chmod +x fake-ssh-add
        sed -E "s@/nix/store/[^[:space:]]+/bin/ssh-add@$PWD/fake-ssh-add@g" \
          ${laptopAgentLoader} > test-loader
        chmod +x test-loader

        export TEST_DIR="$PWD/agent-test"
        mkdir "$TEST_DIR"
        printf '0\n' > "$TEST_DIR/probes"
        export READY_AFTER=2
        XDG_RUNTIME_DIR="$TEST_DIR" ./test-loader
        test "$(cat "$TEST_DIR/probes")" = 3
        test -e "$TEST_DIR/loaded"

        rm "$TEST_DIR/loaded"
        printf '0\n' > "$TEST_DIR/probes"
        READY_AFTER=50 XDG_RUNTIME_DIR="$TEST_DIR" ./test-loader > "$TEST_DIR/output" 2>&1 \
          && exit 1
        test "$(cat "$TEST_DIR/probes")" = 50
        test ! -e "$TEST_DIR/loaded"
        grep -F 'SSH agent did not become available' "$TEST_DIR/output"
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
      disabledSyncthingService = appArmorTestHosts.disable.config.systemd.services.syncthing;
      overrideSyncthingService = appArmorTestHosts.override.config.systemd.services.syncthing;
      laptopConfig = self.nixosConfigurations.laptop.config;
      claudeManagedSettings =
        builtins.fromJSON
          laptopConfig.environment.etc."claude-code/managed-settings.d/20-sandbox.json".text;
      laptopServiceRegistry = laptopConfig.security.localAppArmor.services;
      dnsService = self.nixosConfigurations.laptop.config.systemd.services.apply-secret-dns;
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
    assert
      !(builtins.tryEval invalidAppArmorTestHosts.globHomePath.config.system.build.toplevel.drvPath)
      .success;
    assert
      !(builtins.tryEval invalidAppArmorTestHosts.missingRationale.config.system.build.toplevel.drvPath)
      .success;
    assert
      !(builtins.tryEval invalidAppArmorTestHosts.hostDiagnosticsWithoutDeveloper.config.system.build.toplevel.drvPath)
      .success;
    assert builtins.all (
      host:
      let
        home = host.config.home-manager.users.${username};
        installed = home.home.packages ++ host.config.environment.systemPackages;
      in
      builtins.all (
        app: !app.enable || builtins.any (package: package.drvPath == app.package.drvPath) installed
      ) (builtins.attrValues home.localAppArmor.applications)
    ) (builtins.attrValues self.nixosConfigurations);
    assert laptopServiceRegistry.syncthing.packageRoots == [ laptopConfig.services.syncthing.package ];
    assert builtins.elem "runtime-introspection" laptopServiceRegistry.syncthing.capabilities;
    assert builtins.elem "/proc/bus/pci/devices" laptopServiceRegistry.syncthing.readOnlyPaths;
    assert builtins.elem "/proc/modules" laptopServiceRegistry.syncthing.readOnlyPaths;
    assert builtins.elem "/proc/sys/kernel/osrelease" laptopServiceRegistry.syncthing.readOnlyPaths;
    assert !laptopConfig.systemd.services.syncthing.serviceConfig.RestrictSUIDSGID;
    assert laptopConfig.systemd.services.syncthing.serviceConfig.NoNewPrivileges;
    assert
      self.nixosConfigurations.desktop.config.systemd.services.syncthing.serviceConfig.RestrictSUIDSGID;
    assert laptopServiceRegistry.apply-secret-dns.stagedState == "enforce";
    assert builtins.all (
      host:
      let
        service = host.config.security.localAppArmor.services.apply-secret-dns;
      in
      builtins.elem host.config.systemd.package service.packageRoots
      && builtins.elem host.config.systemd.package service.executionPackages
    ) (builtins.attrValues self.nixosConfigurations);
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
        grep -F '"${laptopPkgs.bubblewrap}/bin/bwrap"' "$TMPDIR/codex-execve.log"

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
      bubblewrapApplicationNames = applicationNamesWith "bubblewrap";
      restrictedApplicationNames = applicationNamesWithout "developer-exec";
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
          if ! grep -Fq -- "$1" "$2"; then
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
          require_rule 'profile bwrap ${self.nixosConfigurations.laptop.pkgs.bubblewrap}/bin/bwrap flags=(attach_disconnected,mediate_deleted)' "$bwrap_profile"
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
            || grep -F 'profile local-claude-code-bwrap ${self.nixosConfigurations.laptop.pkgs.bubblewrap}/bin/bwrap' "$claude_bwrap_profile"; then
            echo "Claude Bubblewrap compatibility profile is not narrowly named" >&2
            exit 1
          fi

          brave_common="$(common_rules "$profile_directory/local-brave")"
          test -r "$brave_common"
          require_rule '/dev/ttyUSB[0-9]* rw,' "$brave_common"
          require_rule '/run/udev/data/c188:[0-9]* r,' "$brave_common"
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

          for app_name in ${
            pkgs-unstable.lib.concatMapStringsSep " " pkgs-unstable.lib.escapeShellArg
              restrictedApplicationNames
          }; do
            app_common="$(common_rules "$profile_directory/local-$app_name")"
            if grep -E '^[[:space:]]*/nix/store/\*\* [^,]*[wmxkl]' "$app_common"; then
              echo "ordinary application received broad store permissions: $app_name" >&2
              exit 1
            fi
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
            require_rule "priority=100 ${self.nixosConfigurations.laptop.pkgs.bubblewrap}/bin/bwrap Px -> $bwrap_target," "$app_profile"
            if grep -F 'allow mount,' "$app_common" \
              || grep -F 'allow pivot_root,' "$app_common" \
              || grep -F 'capability sys_admin,' "$app_common"; then
              echo "Bubblewrap setup privileges leaked into local-$app_name" >&2
              exit 1
            fi
          done

          claude_common="$(common_rules "$profile_directory/local-claude-code")"
          require_rule 'deny owner @{HOME}/.config/BraveSoftware/Brave-Browser/{,**} rwklm,' "$claude_common"
          require_rule 'deny owner @{HOME}/.config/chromium/{,**} rwklm,' "$claude_common"
          require_rule 'deny owner @{HOME}/.config/google-chrome/{,**} rwklm,' "$claude_common"
          require_rule 'deny owner @{HOME}/.config/microsoft-edge/{,**} rwklm,' "$claude_common"
          require_rule 'deny owner @{HOME}/.config/vivaldi/{,**} rwklm,' "$claude_common"

          codex_common="$(common_rules "$profile_directory/local-codex-cli")"
          if grep -F 'owner @{HOME}/.cache/BraveSoftware/{,**} rwkl,' "$codex_common" \
            || grep -F 'owner @{HOME}/.cache/BraveSoftware/{,**} rwkl,' "$claude_common"; then
            echo "agent cache exceptions leaked into another profile or browser cache" >&2
            exit 1
          fi

          proton_pass_common="$(common_rules "$profile_directory/local-proton-pass")"
          if grep -F 'owner "@{HOME}/.config/BraveSoftware/{,**}" rwkl,' "$proton_pass_common"; then
            echo "Proton Pass received broad browser profile access" >&2
            exit 1
          fi

          require_rule '"${
            toString self.nixosConfigurations.laptop.config.environment.etc."containers/registries.conf".source
          }" r,' "$profile_directory/local-codex-cli-container-engine"
          require_rule '"${
            toString self.nixosConfigurations.laptop.config.environment.etc."containers/registries.conf".source
          }" r,' "$profile_directory/local-claude-code-container-engine"

          pqiv_common="$(common_rules "$profile_directory/local-pqiv")"
          if grep -F 'owner @{HOME}/** rwkl,' "$pqiv_common" \
            || grep -F '/proc/{,**}' "$pqiv_common" \
            || grep -F '/run/user/[0-9]*/{,**}' "$pqiv_common" \
            || grep -F 'include <abstractions/nameservice>' "$pqiv_common" \
            || grep -F 'include <abstractions/audio>' "$pqiv_common" \
            || grep -F '/dev/ttyUSB[0-9]* rw,' "$pqiv_common" \
            || grep -F '/dev/video[0-9]* rw,' "$pqiv_common"; then
            echo "minimal desktop capability set leaked broad host access" >&2
            exit 1
          fi

          proton_vpn_common="$(common_rules "$profile_directory/local-proton-vpn")"
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
