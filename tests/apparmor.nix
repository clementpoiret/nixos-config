{ pkgs }:
pkgs.testers.runNixOSTest {
  name = "local-apparmor";

  nodes.machine =
    { ... }:
    {
      imports = [ ../modules/core/apparmor.nix ];

      _module.args = {
        host = "laptop";
        username = "test";
      };

      system.stateVersion = "26.05";

      users.users.test = {
        isNormalUser = true;
        home = "/home/test";
        createHome = true;
      };

      security.localAppArmor = {
        mode = "disable";
        debug = {
          enable = true;
          path = "~/.apparmor_reports";
        };
        profileOverrides = {
          local-apply-secret-dns = "enforce";
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
            ];
            executionPackages = with pkgs; [
              bash
              coreutils
            ];
            readOnlyPaths = [ "/run/secrets/dns/test" ];
            readWritePaths = [ "/run/systemd/resolved.conf.d/{,**}" ];
            extraRules = ''
              capability chown,
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
            readOnlyPaths = [ "/home/test/" ];
            readWritePaths = [
              "/home/test/Sync/"
              "/home/test/Sync/**"
              "/run/syncthing/"
              "/run/syncthing/**"
            ];
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
        '';
      };
    };

  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("apparmor.service")

    with subtest("only the selected profiles are loaded"):
        machine.succeed("test -e /etc/apparmor.d/local-apply-secret-dns")
        machine.succeed("test -e /etc/apparmor.d/local-policy-fixture")
        machine.succeed("test -e /etc/apparmor.d/local-syncthing")
        machine.fail("test -e /etc/apparmor.d/local-brave")

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

    with subtest("the automated debug report is private, valid, and archived by boot"):
        machine.succeed("systemctl start apparmor-debug-report.service")
        machine.succeed("systemctl is-active --quiet apparmor-debug-report.timer")
        machine.succeed(
            "${pkgs.jq}/bin/jq -e '(.profile_patterns == [\"*\"]) and (.summary.denied >= 1)' "
            "/home/test/.apparmor_reports/logs.json"
        )
        machine.succeed(
            "boot_id=$(cat /proc/sys/kernel/random/boot_id); "
            "cmp /home/test/.apparmor_reports/logs.json "
            "/home/test/.apparmor_reports/boots/$boot_id.json"
        )
        machine.succeed(
            "test $(stat -c %a:%U:%G /home/test/.apparmor_reports) = 700:test:users"
        )
        machine.succeed(
            "test $(stat -c %a:%U:%G /home/test/.apparmor_reports/logs.json) = 600:test:users"
        )

    with subtest("the DNS profile enforces exact secret and home boundaries"):
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
