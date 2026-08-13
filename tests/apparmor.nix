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
        profileOverrides = {
          local-apply-secret-dns = "enforce";
          local-syncthing = "complain";
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
      ];

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
        machine.succeed("test -e /etc/apparmor.d/local-syncthing")
        machine.fail("test -e /etc/apparmor.d/local-brave")

    with subtest("the DNS profile enforces its home-directory boundary"):
        machine.succeed("install -o test -g users -m 0600 /dev/null /home/test/private")
        machine.fail(
            "aa-exec -p local-apply-secret-dns -- ${pkgs.coreutils}/bin/cat /home/test/private"
        )

    with subtest("the DNS writer produces an atomic private resolved drop-in"):
        machine.succeed("install -d -m 0755 /run/secrets/dns")
        machine.succeed("printf '1.1.1.1\\n' > /run/secrets/dns/test")
        machine.succeed("systemctl start apply-secret-dns.service")
        machine.succeed(
            "test $(stat -c %a /run/systemd/resolved.conf.d/90-sops-dns.conf) = 600"
        )
        machine.succeed(
            "test $(stat -c %U:%G /run/systemd/resolved.conf.d/90-sops-dns.conf) = systemd-resolve:systemd-resolve"
        )

    with subtest("Syncthing runs under the named complain-mode profile"):
        machine.wait_for_unit("syncthing.service")
        machine.wait_until_succeeds("systemctl is-active --quiet syncthing.service")
        machine.succeed(
            "pid=$(systemctl show --property MainPID --value syncthing.service); "
            "grep -Fx 'local-syncthing (complain)' /proc/$pid/attr/current"
        )
        machine.succeed("test -d /home/test/Sync/.config/syncthing")
  '';
}
