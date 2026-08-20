{ home-manager, pkgs }:
pkgs.testers.runNixOSTest {
  name = "local-apparmor";

  nodes.machine =
    { ... }:
    {
      imports = [
        ../modules/core/apparmor.nix
        home-manager.nixosModules.home-manager
      ];

      _module.args = {
        host = "laptop";
        username = "test";
      };

      system.stateVersion = "26.05";
      hardware.graphics = {
        package = pkgs.mesa;
        package32 = pkgs.pkgsi686Linux.mesa;
      };

      users.users.test = {
        isNormalUser = true;
        home = "/home/test";
        createHome = true;
      };

      security.localAppArmor = {
        mode = "disable";
        debug = {
          enable = true;
          path = "~/.local/state/apparmor-reports";
        };
        profileOverrides = {
          local-agent-fixture = "enforce";
          local-audit-fixture = "complain";
          local-apply-secret-dns = "enforce";
          local-bwrap-fixture = "enforce";
          local-enforce-fixture = "enforce";
          local-policy-fixture = "enforce";
          local-syncthing = "enforce";
        };
        services = {
          apply-secret-dns = {
            unit = "apply-secret-dns";
            stagedState = "enforce";
            packageRoots = with pkgs; [
              bash
              coreutils
              systemd
            ];
            executionPackages = with pkgs; [
              bash
              coreutils
              systemd
            ];
            systemBusPeers = [ "org.freedesktop.systemd1" ];
            readOnlyPaths = [ "/run/secrets/dns/test" ];
            readWritePaths = [
              "/run/systemd/private"
              "/run/systemd/resolved.conf.d/{,**}"
            ];
            extraRules = ''
              capability chown,
              owner /proc/[0-9]*/stat r,
              /nix/store/*-unit-script-apply-secret-dns-start/bin/apply-secret-dns-start rix,
            '';
            extraRulesRationale = "The test service changes ownership of an atomic resolved drop-in.";
          };
          policy-fixture = {
            unit = "apparmor-policy-fixture";
            packageRoots = [ pkgs.coreutils ];
            executionPackages = [ pkgs.coreutils ];
            capabilities = [ "runtime-introspection" ];
            readWritePaths = [ "/var/lib/apparmor-fixture/{,**}" ];
          };
          syncthing = {
            unit = "syncthing";
            packageRoots = [ pkgs.syncthing ];
            executionPackages = [ pkgs.syncthing ];
            capabilities = [
              "network"
              "runtime-introspection"
            ];
            readOnlyPaths = [
              "/home/test/"
              "/proc/bus/pci/devices"
              "/proc/modules"
            ];
            readWritePaths = [
              "/home/test/Sync/"
              "/home/test/Sync/**"
              "/run/syncthing/"
              "/run/syncthing/**"
            ];
          };
        };
      };

      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        users.test = {
          imports = [ ../modules/home/apparmor.nix ];
          home = {
            stateVersion = "26.05";
            packages = [ pkgs.coreutils ];
          };
          localAppArmor.applications = {
            agent-fixture = {
              package = pkgs.coreutils;
              executable = "bin/cat";
              capabilities = [
                "developer-exec"
                "host-diagnostics"
              ];
              sensitiveAccess = [
                "gpg-agent"
                "nixos-config-writable"
              ];
              elevatedAccessRationale = "The fixture verifies shared developer state and the intended credential boundaries.";
            };
            audit-fixture = {
              package = pkgs.coreutils;
              executable = "bin/touch";
              capabilities = [ "user-files" ];
              homePaths = [
                ".config/sops/age"
                "Documents"
              ];
            };
            bwrap-fixture = {
              package = pkgs.coreutils;
              executable = "bin/env";
              capabilities = [ "bubblewrap" ];
              bubblewrapPackage = pkgs.bubblewrap;
            };
            enforce-fixture = {
              package = pkgs.coreutils;
              executable = "bin/mkdir";
              capabilities = [ "user-files" ];
              homePaths = [
                ".config/sops/age"
                "Documents"
              ];
            };
          };
        };
      };

      services.resolved.enable = true;
      services.syncthing = {
        enable = true;
        user = "test";
        dataDir = "/home/test/Sync/";
        openDefaultPorts = false;
      };

      systemd.tmpfiles.rules = [
        "d /run/systemd/resolved.conf.d 0755 root root -"
        "d /home/test/Sync 0700 test users -"
        "d /var/lib/apparmor-fixture 0700 root root -"
      ];

      systemd.services.apparmor-policy-fixture = {
        description = "Load and exercise the generic local AppArmor service profile";
        serviceConfig.Type = "oneshot";
        script = "true";
      };

      systemd.services.apply-secret-dns = {
        description = "Exercise the confined DNS writer";
        path = with pkgs; [ coreutils ];
        serviceConfig = {
          Type = "oneshot";
          UMask = "0077";
          NoNewPrivileges = true;
          CapabilityBoundingSet = [ "CAP_CHOWN" ];
          AmbientCapabilities = [ ];
          PrivateDevices = true;
          PrivateTmp = true;
          ProtectHome = true;
          ProtectSystem = "strict";
          ReadWritePaths = [ "/run/systemd/resolved.conf.d" ];
          RestrictAddressFamilies = [ "AF_UNIX" ];
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          SystemCallArchitectures = "native";
        };
        script = ''
          input=/run/secrets/dns/test
          output=/run/systemd/resolved.conf.d/90-sops-dns.conf
          temporary="$(mktemp /run/systemd/resolved.conf.d/.90-sops-dns.conf.XXXXXX)"
          trap 'rm -f "$temporary"' EXIT
          printf '[Resolve]\nDNS=%s\n' "$(tr '\n' ' ' < "$input")" > "$temporary"
          chmod 0600 "$temporary"
          chown systemd-resolve:systemd-resolve "$temporary"
          mv -f "$temporary" "$output"
          trap - EXIT
          systemctl reload-or-restart systemd-resolved.service
        '';
      };
    };

  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("apparmor.service")
    machine.succeed("test $(systemctl show -P Result home-manager-test.service) = success")

    with subtest("only the selected profiles are loaded"):
        machine.succeed("test -e /etc/apparmor.d/local-agent-fixture")
        machine.succeed("test -e /etc/apparmor.d/local-apply-secret-dns")
        machine.succeed("test -e /etc/apparmor.d/local-audit-fixture")
        machine.succeed("test -e /etc/apparmor.d/bwrap")
        machine.succeed("test -e /etc/apparmor.d/local-bwrap-fixture")
        machine.succeed("test -e /etc/apparmor.d/local-enforce-fixture")
        machine.succeed("test -e /etc/apparmor.d/local-policy-fixture")
        machine.succeed("test -e /etc/apparmor.d/local-syncthing")
        machine.fail("test -e /etc/apparmor.d/local-brave")

    with subtest("Bubblewrap is always enforced and brokers namespace setup"):
        machine.succeed(
            "aa-status --json | ${pkgs.jq}/bin/jq -e "
            "'.profiles[\"bwrap\"] == \"enforce\" and "
            ".profiles[\"unpriv_bwrap\"] == \"enforce\" and "
            ".profiles[\"local-bwrap-fixture\"] == \"enforce\"'"
        )
        machine.succeed(
            "su -s ${pkgs.bash}/bin/bash test -c "
            "'aa-exec -p local-bwrap-fixture -- ${pkgs.bash}/bin/bash -c "
            "\"exec ${pkgs.bubblewrap}/bin/bwrap --ro-bind / / --dev /dev --proc /proc "
            "--unshare-user --unshare-pid --die-with-parent ${pkgs.coreutils}/bin/true\"'"
        )

    with subtest("the generic service profile permits only declared data and executables"):
        machine.succeed("install -o test -g users -m 0600 /dev/null /home/test/private")
        machine.succeed(
            "aa-exec -p local-policy-fixture -- ${pkgs.bash}/bin/bash -c "
            "'exec ${pkgs.coreutils}/bin/touch /var/lib/apparmor-fixture/allowed'"
        )
        machine.fail(
            "aa-exec -p local-policy-fixture -- ${pkgs.bash}/bin/bash -c "
            "'exec ${pkgs.coreutils}/bin/touch /home/test/forbidden'"
        )
        machine.fail(
            "aa-exec -p local-policy-fixture -- ${pkgs.bash}/bin/bash -c "
            "'exec ${pkgs.findutils}/bin/find /var/lib/apparmor-fixture'"
        )
        machine.succeed(
            "aa-exec -p local-policy-fixture -- ${pkgs.coreutils}/bin/stat /proc/self/stat"
        )

    with subtest("the developer profile permits shared tooling state without exposing private keys or the protected clone"):
        machine.succeed(
            "install -d -o test -g users -m 0700 "
            "/home/test/.agents/skills/example /home/test/.cache/nix /home/test/.cache/uv "
            "/home/test/.config/git /home/test/.keras /home/test/.gnupg/private-keys-v1.d "
            "/home/test/.local/state/apparmor-reports /home/test/nixos-config "
            "/home/test/nixos-config-writable"
        )
        machine.succeed(
            "touch "
            "/home/test/.agents/skills/example/SKILL.md /home/test/.config/git/ignore "
            "/home/test/.keras/keras.json /home/test/.gnupg/common.conf "
            "/home/test/.gnupg/trustdb.gpg /home/test/.gnupg/private-keys-v1.d/private.key "
            "/home/test/.local/state/apparmor-reports/logs.json"
        )
        machine.succeed(
            "chown -R test:users /home/test/.agents /home/test/.cache /home/test/.config "
            "/home/test/.keras /home/test/.gnupg /home/test/.local /home/test/nixos-config "
            "/home/test/nixos-config-writable"
        )
        machine.succeed(
            "chmod 0600 /home/test/.agents/skills/example/SKILL.md /home/test/.config/git/ignore "
            "/home/test/.keras/keras.json /home/test/.gnupg/common.conf "
            "/home/test/.gnupg/trustdb.gpg /home/test/.gnupg/private-keys-v1.d/private.key "
            "/home/test/.local/state/apparmor-reports/logs.json"
        )
        machine.succeed(
            "su -s ${pkgs.bash}/bin/bash test -c "
            "'aa-exec -p local-agent-fixture -- ${pkgs.coreutils}/bin/cat "
            "/home/test/.agents/skills/example/SKILL.md /home/test/.config/git/ignore "
            "/home/test/.keras/keras.json /home/test/.gnupg/common.conf "
            "/home/test/.local/state/apparmor-reports/logs.json'"
        )
        machine.succeed(
            "su -s ${pkgs.bash}/bin/bash test -c "
            "'aa-exec -p local-agent-fixture -- ${pkgs.coreutils}/bin/touch "
            "/home/test/.cache/nix/allowed /home/test/.cache/uv/allowed "
            "/home/test/nixos-config-writable/allowed'"
        )
        machine.succeed(
            "su -s ${pkgs.bash}/bin/bash test -c "
            "'aa-exec -p local-agent-fixture -- ${pkgs.coreutils}/bin/truncate -s 1 "
            "/home/test/.gnupg/trustdb.gpg'"
        )
        machine.succeed(
            "su -s ${pkgs.bash}/bin/bash test -c "
            "'aa-exec -p local-agent-fixture -- ${pkgs.coreutils}/bin/ls /proc/self/fd'"
        )
        machine.succeed(
            "su -s ${pkgs.bash}/bin/bash test -c "
            "'aa-exec -p local-agent-fixture -- ${pkgs.bash}/bin/bash -c "
            "\"printf agent-fixture > /proc/self/task/\\$\\$/comm\"'"
        )
        machine.fail(
            "su -s ${pkgs.bash}/bin/bash test -c "
            "'aa-exec -p local-agent-fixture -- ${pkgs.coreutils}/bin/cat "
            "/home/test/.gnupg/private-keys-v1.d/private.key'"
        )
        machine.fail(
            "su -s ${pkgs.bash}/bin/bash test -c "
            "'aa-exec -p local-agent-fixture -- ${pkgs.coreutils}/bin/touch "
            "/home/test/nixos-config/blocked'"
        )

    with subtest("the automated debug report is private, valid, and archived by boot"):
        machine.succeed("systemctl start apparmor-debug-report.service")
        machine.succeed("systemctl is-active --quiet apparmor-debug-report.timer")
        machine.succeed(
            "${pkgs.jq}/bin/jq -e '(.profile_patterns == [\"*\"]) and (.summary.denied >= 1)' "
            "/home/test/.local/state/apparmor-reports/logs.json"
        )
        machine.succeed(
            "boot_id=$(cat /proc/sys/kernel/random/boot_id); "
            "cmp /home/test/.local/state/apparmor-reports/logs.json "
            "/home/test/.local/state/apparmor-reports/boots/$boot_id.json"
        )
        machine.succeed(
            "test $(stat -c %a:%U:%G /home/test/.local/state/apparmor-reports) = 700:test:users"
        )
        machine.succeed(
            "test $(stat -c %a:%U:%G /home/test/.local/state/apparmor-reports/logs.json) = 600:test:users"
        )

    with subtest("complain mode permits while enforce mode blocks sensitive and protected writes"):
        machine.succeed(
            "aa-status --json | ${pkgs.jq}/bin/jq -e "
            "'.profiles[\"local-audit-fixture\"] == \"complain\" and "
            ".profiles[\"local-enforce-fixture\"] == \"enforce\"'"
        )
        machine.succeed(
            "install -d -o test -g users -m 0700 "
            "/home/test/.config/sops/age /home/test/Documents /home/test/nixos-config"
        )
        machine.succeed(
            "install -o test -g users -m 0600 /dev/null "
            "/home/test/.config/sops/age/keys.txt"
        )
        machine.succeed(
            "install -o test -g users -m 0600 /dev/null "
            "/home/test/nixos-config/complain-permitted"
        )
        machine.succeed(
            "install -o test -g users -m 0600 /dev/null "
            "/home/test/nixos-config/enforced"
        )
        machine.succeed(
            "su -s ${pkgs.bash}/bin/bash test -c "
            "'aa-exec -p local-audit-fixture -- ${pkgs.coreutils}/bin/truncate -s 1 "
            "/home/test/.config/sops/age/keys.txt'"
        )
        machine.fail(
            "su -s ${pkgs.bash}/bin/bash test -c "
            "'aa-exec -p local-enforce-fixture -- ${pkgs.coreutils}/bin/truncate -s 2 "
            "/home/test/.config/sops/age/keys.txt'"
        )
        machine.succeed(
            "su -s ${pkgs.bash}/bin/bash test -c "
            "'aa-exec -p local-audit-fixture -- ${pkgs.coreutils}/bin/truncate -s 1 "
            "/home/test/nixos-config/complain-permitted'"
        )
        machine.fail(
            "su -s ${pkgs.bash}/bin/bash test -c "
            "'aa-exec -p local-enforce-fixture -- ${pkgs.coreutils}/bin/truncate -s 1 "
            "/home/test/nixos-config/enforced'"
        )
        machine.succeed(
            "su -s ${pkgs.bash}/bin/bash test -c "
            "'aa-exec -p local-enforce-fixture -- ${pkgs.coreutils}/bin/touch "
            "/home/test/Documents/allowed'"
        )
    with subtest("the DNS profile enforces exact secret and home boundaries"):
        machine.succeed(
            "aa-exec -p local-apply-secret-dns -- ${pkgs.coreutils}/bin/cat /proc/self/stat"
        )
        machine.fail(
            "aa-exec -p local-apply-secret-dns -- ${pkgs.coreutils}/bin/cat /home/test/private"
        )
        machine.succeed("install -d -m 0755 /run/secrets/dns")
        machine.succeed("printf '9.9.9.9\\n' > /run/secrets/dns/sibling")
        machine.fail(
            "aa-exec -p local-apply-secret-dns -- ${pkgs.coreutils}/bin/cat /run/secrets/dns/sibling"
        )

    with subtest("the DNS writer produces an atomic private resolved drop-in"):
        machine.succeed("printf '1.1.1.1\\n' > /run/secrets/dns/test")
        machine.succeed("systemctl start apply-secret-dns.service")
        machine.succeed(
            "test $(stat -c %a /run/systemd/resolved.conf.d/90-sops-dns.conf) = 600"
        )
        machine.succeed(
            "test $(stat -c %U:%G /run/systemd/resolved.conf.d/90-sops-dns.conf) = systemd-resolve:systemd-resolve"
        )

    with subtest("Syncthing runs under its enforced profile"):
        machine.succeed(
            "aa-exec -p local-syncthing -- ${pkgs.coreutils}/bin/cat /proc/bus/pci/devices"
        )
        machine.succeed(
            "aa-exec -p local-syncthing -- ${pkgs.coreutils}/bin/cat /proc/modules"
        )
        machine.wait_for_unit("syncthing.service")
        machine.wait_until_succeeds("systemctl is-active --quiet syncthing.service")
        machine.succeed(
            "pid=$(systemctl show --property MainPID --value syncthing.service); "
            "grep -Fx 'local-syncthing (enforce)' /proc/$pid/attr/current"
        )
        machine.succeed("test -d /home/test/Sync/.config/syncthing")
        machine.fail("journalctl -k --grep 'profile=\\\"local-syncthing\\\"'")
  '';
}
