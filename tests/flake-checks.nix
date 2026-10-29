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

  opencode-package-updates =
    pkgs-unstable.runCommand "opencode-package-updates"
      {
        nativeBuildInputs = [ pkgs-unstable.python3 ];
        OPENCODE_UPDATER_SOURCE = ../pkgs/update-opencode.py;
      }
      ''
        python ${./test_update_opencode.py}
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

  niri-scratch-terminal =
    pkgs-unstable.runCommand "niri-scratch-terminal"
      {
        nativeBuildInputs = [ pkgs-unstable.python3 ];
        NIRI_SCRATCH_TERMINAL_SOURCE = ../modules/home/niri-scratch-terminal.py;
      }
      ''
        python ${./test_niri_scratch_terminal.py}
        touch "$out"
      '';

  dms-application-theming =
    let
      qtThemeProbe =
        qtPackages:
        pkgs-unstable.runCommandCC "qt-theme-${qtPackages.qtbase.version}"
          {
            nativeBuildInputs = [ pkgs-unstable.pkg-config ];
            buildInputs = [ qtPackages.qtbase ];
          }
          ''
            mkdir -p "$out/bin"
            $CXX -Wall -Wextra -Werror -fPIC ${./qt-theme.cpp} \
              $(pkg-config --cflags --libs Qt${pkgs-unstable.lib.versions.major qtPackages.qtbase.version}Widgets) \
              -o "$out/bin/qt-theme"
          '';
      checkHost =
        hostName:
        let
          host = self.nixosConfigurations.${hostName}.config;
          hostPkgs = self.nixosConfigurations.${hostName}.pkgs;
          home = host.home-manager.users.${username};
        in
        assert !(home.xdg.configFile ? "gtk-3.0/gtk.css");
        assert !(home.xdg.configFile ? "gtk-4.0/gtk.css");
        assert !(home.xdg.configFile ? "qt5ct/qt5ct.conf");
        assert !(home.xdg.configFile ? "qt6ct/qt6ct.conf");
        assert !(home.xdg.configFile ? "Kvantum/kvantum.kvconfig");
        assert !(home.home.sessionVariables ? QT_STYLE_OVERRIDE);
        assert !(host.environment.variables ? QT_STYLE_OVERRIDE);
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
          qt_applier=${home.programs.dank-material-shell.package}/share/quickshell/dms/scripts/qt.sh
          bash "$qt_applier" "$XDG_CONFIG_HOME"
          for qtct in qt5ct qt6ct; do
            test ! -L "$XDG_CONFIG_HOME/$qtct/$qtct.conf"
            cat > "$XDG_CONFIG_HOME/$qtct/$qtct.conf" <<'EOF'
          [Appearance]
          style=kvantum
          custom_palette=false
          icon_theme=rose-pine

          [Fonts]
          general="Noto Sans,9"
          fixed="Noto Sans Mono,9"
          EOF
            chmod u-w "$XDG_CONFIG_HOME/$qtct/$qtct.conf"
          done

          cat > "$HOME/matugen.toml" <<EOF
          [config]
          [templates.qt5ct]
          input_path = '${self.inputs.dms}/quickshell/matugen/templates/qtct-colors.conf'
          output_path = '$XDG_CONFIG_HOME/qt5ct/colors/matugen.conf'
          [templates.qt6ct]
          input_path = '${self.inputs.dms}/quickshell/matugen/templates/qtct-colors.conf'
          output_path = '$XDG_CONFIG_HOME/qt6ct/colors/matugen.conf'
          EOF

          for mode in true false true; do
            bash ${self.inputs.dms}/quickshell/scripts/gtk.sh "$XDG_CONFIG_HOME" apply "$mode"
            test ! -L "$XDG_CONFIG_HOME/gtk-4.0/gtk.css"
            grep -Fx '@import url("dank-colors.css");' "$XDG_CONFIG_HOME/gtk-4.0/gtk.css"
            bash ${self.inputs.dms}/quickshell/scripts/gtk.sh "$XDG_CONFIG_HOME" patch "$mode"
            variant=""
            [ "$mode" = true ] || variant="-dark"
            grep -Fx '@define-color accent_color #123456;' \
              "$XDG_DATA_HOME/themes/adw-gtk3$variant/gtk-3.0/gtk.css"
            palette_mode=dark
            [ "$mode" = true ] || palette_mode=light
            matugen -c "$HOME/matugen.toml" -m "$palette_mode" color hex '#123456'
            bash "$qt_applier" "$XDG_CONFIG_HOME"
            for qtct in qt5ct qt6ct; do
              qt_config="$XDG_CONFIG_HOME/$qtct/$qtct.conf"
              test "$(crudini --get "$qt_config" Appearance color_scheme_path)" = "$XDG_CONFIG_HOME/$qtct/colors/matugen.conf"
              test "$(crudini --get "$qt_config" Appearance custom_palette)" = true
              test "$(crudini --get "$qt_config" Appearance style)" = Fusion
              test "$(crudini --get "$qt_config" Appearance icon_theme)" = rose-pine
              test "$(crudini --get "$qt_config" Fonts general)" = '"Noto Sans,9"'
              test ! -L "$qt_config"
              test -w "$qt_config"
              test "$(grep -c '^[[:space:]]*color_scheme_path[[:space:]]*=' "$qt_config")" -eq 1
            done
            QT_QPA_PLATFORMTHEME=qt5ct \
              QT_PLUGIN_PATH=${hostPkgs.libsForQt5.qt5ct}/${hostPkgs.libsForQt5.qtbase.qtPluginPrefix}:${hostPkgs.libsForQt5.qtbase}/${hostPkgs.libsForQt5.qtbase.qtPluginPrefix} \
              ${qtThemeProbe hostPkgs.libsForQt5}/bin/qt-theme qt5ct
            QT_QPA_PLATFORMTHEME=qt6ct \
              QT_PLUGIN_PATH=${hostPkgs.qt6Packages.qt6ct}/${hostPkgs.qt6Packages.qtbase.qtPluginPrefix}:${hostPkgs.qt6Packages.qtbase}/${hostPkgs.qt6Packages.qtbase.qtPluginPrefix} \
              ${qtThemeProbe hostPkgs.qt6Packages}/bin/qt-theme qt6ct
          done
          cmp ${home.xdg.configFile."gtk-3.0/settings.ini".source} "$XDG_CONFIG_HOME/gtk-3.0/settings.ini"
          cmp ${home.xdg.configFile."gtk-4.0/settings.ini".source} "$XDG_CONFIG_HOME/gtk-4.0/settings.ini"
        '';
    in
    pkgs-unstable.runCommand "dms-application-theming"
      {
        nativeBuildInputs = with pkgs-unstable; [
          crudini
          matugen
        ];
      }
      ''
        export QT_QPA_PLATFORM=offscreen
        export LC_ALL=C.UTF-8
        export FONTCONFIG_FILE=${pkgs-unstable.makeFontsConf { fontDirectories = [ ]; }}
        export XDG_RUNTIME_DIR="$TMPDIR/runtime"
        mkdir -m 0700 "$XDG_RUNTIME_DIR"
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

  cached-kernel =
    let
      cachedKernel =
        self.inputs.nix-cachyos-kernel.packages.${pkgs-unstable.stdenv.hostPlatform.system}.linux-cachyos-latest-lto-zen4;
      usesCachedKernel =
        hostName:
        pkgs-unstable.lib.assertMsg (
          self.nixosConfigurations.${hostName}.config.boot.kernelPackages.kernel.drvPath
          == cachedKernel.drvPath
        ) "${hostName} would build its kernel instead of using the cached CachyOS kernel";
    in
    assert usesCachedKernel "desktop";
    assert usesCachedKernel "laptop";
    pkgs-unstable.runCommand "cached-kernel" { } ''
      touch "$out"
    '';

  internal-vps-access =
    let
      laptop = self.nixosConfigurations.laptop.config;
      desktop = self.nixosConfigurations.desktop.config;
      service = laptop.systemd.services.wg-quick-wg-rhizome;
      sshConfig = laptop.home-manager.users.${username}.home.file.".ssh/config".source;
      noAutomaticDependency =
        unit: !(builtins.elem "wg-quick-wg-rhizome.service" (unit.wants ++ unit.requires));
    in
    assert !(desktop.networking.wg-quick.interfaces ? wg-rhizome);
    assert service.wantedBy == [ ] && service.requiredBy == [ ];
    assert pkgs-unstable.lib.all noAutomaticDependency (builtins.attrValues laptop.systemd.services);
    assert !(builtins.elem "wg-rhizome" laptop.networking.firewall.trustedInterfaces);
    pkgs-unstable.runCommand "internal-vps-access"
      {
        nativeBuildInputs = [
          pkgs-unstable.openssh_hpn
          pkgs-unstable.gnugrep
        ];
      }
      ''
        export HOME="$TMPDIR/home"
        mkdir -p "$HOME"
        ssh -G -F ${sshConfig} internalvps > effective-ssh-config
        grep -Fx 'hostname 10.78.0.1' effective-ssh-config
        grep -Fx 'hostkeyalias internalvps' effective-ssh-config
        grep -Fx 'bindinterface wg-rhizome' effective-ssh-config
        grep -Fx 'controlmaster false' effective-ssh-config
        grep -Fx 'controlpersist no' effective-ssh-config
        # OpenSSH omits ControlPath from -G output when it is set to none.
        if grep -q '^controlpath ' effective-ssh-config; then
          exit 1
        fi
        touch "$out"
      '';

  ssh-agent-key-loader =
    let
      laptopHome = self.nixosConfigurations.laptop.config.home-manager.users.${username};
      laptopAgentLoader = laptopHome.systemd.user.services.ssh-agent.Service.ExecStartPost;
    in
    pkgs-unstable.runCommand "ssh-agent-key-loader"
      {
        nativeBuildInputs = [
          pkgs-unstable.gnugrep
          pkgs-unstable.gnused
        ];
      }
      ''
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
    assert builtins.all (
      host:
      let
        service = host.config.security.localAppArmor.services.apply-secret-dns;
      in
      builtins.elem host.config.systemd.package service.packageRoots
      && builtins.elem host.config.systemd.package service.executionPackages
    ) (builtins.attrValues self.nixosConfigurations);
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
      containerConfigHost = appArmorTestHosts.enforce.extendModules {
        modules = [
          {
            virtualisation.containers.registries.settings.registry = [
              { location = "registry.example.test"; }
            ];
            environment.etc.container-storage-drop-in = {
              target = "containers/storage.conf.d/90-local.conf";
              text = ''
                [storage.options.overlay]
                mountopt = "nodev"
              '';
            };
          }
        ];
      };
      configurations = [
        self.nixosConfigurations.desktop
        self.nixosConfigurations.laptop
        containerConfigHost
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
      containerConfigChecks = pkgs-unstable.lib.concatMapStrings (
        configuration:
        let
          entries = pkgs-unstable.lib.filterAttrs (
            _: entry: entry.enable && pkgs-unstable.lib.hasPrefix "containers/" entry.target
          ) configuration.config.environment.etc;
          directory = configuration.config.environment.etc."apparmor.d".source;
        in
        pkgs-unstable.lib.concatMapStrings (entry: ''
          require_rule ${pkgs-unstable.lib.escapeShellArg ''"${toString entry.source}" r,''} \
            ${directory}/local-codex-cli-container-engine
          require_rule ${pkgs-unstable.lib.escapeShellArg ''"${toString entry.source}" r,''} \
            ${directory}/local-claude-code-container-engine
        '') (builtins.attrValues entries)
      ) configurations;
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
          brave_common="$(common_rules "$profile_directory/local-brave")"
          session_rules="$(sed -n 's/^[[:space:]]*include "\([^"]*apparmor-local-session-read-only\)"/\1/p' "$brave_common")"
          test -r "$session_rules"
          session_closure_rules="$(sed -n 's/^[[:space:]]*include "\([^"]*apparmor-closure-rules-local-session-read-only\)"/\1/p' "$session_rules")"
          test -r "$session_closure_rules"
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

          for policy in "$profile_directory"/bwrap "$profile_directory"/local-*; do
            attachment="$(sed -n 's/^[[:space:]]*profile local-[^[:space:]]* \([^[:space:]]*\) flags=.*/\1/p' "$policy")"
            if [ -n "$attachment" ]; then
              test -x "$attachment"
            fi
            apparmor_parser --config-file /dev/null --quiet --skip-kernel-load --skip-cache \
              --Include "$profile_directory" ${includeArguments} "$policy"
          done
        done

        ${containerConfigChecks}
        touch "$out"
      '';

  apparmor-vm = import ./apparmor.nix {
    inherit home-manager;
    pkgs = pkgs-unstable.extend selfPkgs.overlay;
  };
  desktop-toplevel = self.nixosConfigurations.desktop.config.system.build.toplevel;
  laptop-toplevel = self.nixosConfigurations.laptop.config.system.build.toplevel;
}
