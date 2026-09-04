{ home-manager, pkgs }:
let
  mkAgentFixture =
    name:
    pkgs.writeCBin name ''
      #include <errno.h>
      #include <stdio.h>
      #include <string.h>
      #include <unistd.h>

      int main(int argc, char **argv) {
        if (argc < 2) {
          fprintf(stderr, "${name}: missing command\n");
          return 64;
        }
        execv(argv[1], &argv[1]);
        fprintf(stderr, "${name}: execv: %s\n", strerror(errno));
        return 127;
      }
    '';
  claudeFixture = mkAgentFixture "claude-fixture";
  codexFixture = mkAgentFixture "codex-fixture";
  nestedUsernsProbe = pkgs.writeCBin "nested-userns-probe" ''
    #define _GNU_SOURCE
    #include <errno.h>
    #include <fcntl.h>
    #include <sched.h>
    #include <stdio.h>
    #include <string.h>
    #include <unistd.h>

    int main(void) {
      char label[512];
      int label_fd = open("/proc/self/attr/current", O_RDONLY | O_CLOEXEC);
      if (label_fd == -1) {
        fprintf(stderr, "nested-userns-probe: open label: %s\n", strerror(errno));
        return 1;
      }
      ssize_t label_length = read(label_fd, label, sizeof(label) - 1);
      close(label_fd);
      if (label_length == -1) {
        fprintf(stderr, "nested-userns-probe: read label: %s\n", strerror(errno));
        return 1;
      }
      label[label_length] = '\0';
      fputs(label, stdout);

      if (unshare(CLONE_NEWUSER) == -1) {
        fprintf(stderr, "nested-userns-probe: unshare: %s\n", strerror(errno));
        return 1;
      }

      int setgroups_fd = open("/proc/self/setgroups", O_WRONLY | O_CLOEXEC);
      if (setgroups_fd == -1) {
        fprintf(stderr, "nested-userns-probe: open setgroups: %s\n", strerror(errno));
        return 1;
      }
      if (write(setgroups_fd, "deny", 4) != 4) {
        fprintf(stderr, "nested-userns-probe: write setgroups: %s\n", strerror(errno));
        close(setgroups_fd);
        return 1;
      }
      close(setgroups_fd);
      return 0;
    }
  '';
in
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
        linger = true;
      };
      users.manageLingering = true;

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
          local-claude-code = "complain";
          local-codex-cli = "complain";
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
            packages = [
              pkgs.agent-container-tools
              claudeFixture
              codexFixture
              pkgs.coreutils
            ];
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
                "forge-auth"
                "gpg-agent"
                "nixos-config-writable"
                "ssh-config"
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
            claude-code = {
              package = claudeFixture;
              executable = "bin/claude-fixture";
              capabilities = [
                "bubblewrap"
                "containers"
              ];
              bubblewrapPackage = pkgs.bubblewrap;
              containerToolsPackage = pkgs.agent-container-tools;
            };
            codex-cli = {
              package = codexFixture;
              executable = "bin/codex-fixture";
              capabilities = [
                "bubblewrap"
                "containers"
              ];
              bubblewrapPackage = pkgs.bubblewrap;
              containerToolsPackage = pkgs.agent-container-tools;
            };
            enforce-fixture = {
              package = pkgs.coreutils;
              executable = "bin/mkdir";
              capabilities = [ "user-files" ];
              homePaths = [
                ".config/gh"
                ".config/sops/age"
                "Documents"
              ];
            };
          };
        };
      };

      services.resolved.enable = true;
      virtualisation.containers.enable = true;
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

    with subtest("the automated debug report accepts an empty journal"):
        machine.succeed("systemctl start apparmor-debug-report.service")
        machine.succeed(
            "${pkgs.jq}/bin/jq -e '.summary.events == 0' "
            "/home/test/.local/state/apparmor-reports/logs.json"
        )

    with subtest("only the selected profiles are loaded"):
        machine.succeed("test -e /etc/apparmor.d/local-agent-fixture")
        machine.succeed("test -e /etc/apparmor.d/local-apply-secret-dns")
        machine.succeed("test -e /etc/apparmor.d/local-audit-fixture")
        machine.succeed("test -e /etc/apparmor.d/bwrap")
        machine.succeed("test -e /etc/apparmor.d/local-claude-code-bwrap")
        machine.succeed("test -e /etc/apparmor.d/local-bwrap-fixture")
        machine.succeed("test -e /etc/apparmor.d/local-enforce-fixture")
        machine.succeed("test -e /etc/apparmor.d/local-policy-fixture")
        machine.succeed("test -e /etc/apparmor.d/local-syncthing")
        machine.fail("test -e /etc/apparmor.d/local-brave")

    with subtest("Claude only bypasses Bubblewrap for guarded container launchers"):
        machine.succeed(
            "${pkgs.jq}/bin/jq -e "
            "'.sandbox.enabled == true and "
            ".sandbox.failIfUnavailable == true and "
            ".sandbox.allowUnsandboxedCommands == false and "
            ".sandbox.excludedCommands == [\"podman *\", \"buildah *\"]' "
            "/etc/claude-code/managed-settings.d/20-sandbox.json"
        )

    with subtest("agent container brokers and payloads are always enforced"):
        machine.succeed(
            "aa-status --json | ${pkgs.jq}/bin/jq -e "
            "'.profiles[\"local-codex-cli\"] == \"complain\" and "
            ".profiles[\"local-claude-code\"] == \"complain\" and "
            ".profiles[\"local-codex-cli-container-engine\"] == \"enforce\" and "
            ".profiles[\"local-claude-code-container-engine\"] == \"enforce\" and "
            ".profiles[\"local-agent-container-payload\"] == \"enforce\"'"
        )

    with subtest("guarded rootless Buildah and Podman use isolated stores and the payload profile"):
        container_tools = "${pkgs.agent-container-tools}/bin"

        def guarded(profile, command, environment=""):
            launcher = (
                "${codexFixture}/bin/codex-fixture"
                if profile == "local-codex-cli"
                else "${claudeFixture}/bin/claude-fixture"
            )
            environment_prefix = f"{environment} " if environment else ""
            return (
                "su -s ${pkgs.bash}/bin/bash test -c "
                f"'cd /home/test/workspace && {environment_prefix}aa-exec -p {profile} "
                f"-- {launcher} {container_tools}/{command}'"
            )

        machine.succeed(
            "install -d -o test -g users -m 0700 /home/test/workspace/rootfs/bin"
        )
        machine.succeed(
            "install -o test -g users -m 0555 ${pkgs.pkgsStatic.busybox}/bin/busybox "
            "/home/test/workspace/rootfs/bin/busybox"
        )
        machine.succeed(
            "printf '%s\\n' 'FROM scratch' "
            "'COPY rootfs/bin/busybox /bin/busybox' "
            "'RUN [\"/bin/busybox\", \"true\"]' "
            "> /home/test/workspace/Containerfile && "
            "chown test:users /home/test/workspace/Containerfile"
        )
        machine.succeed(
            "printf '%s\\n' 'services:' '  agent-compose:' "
            "'    image: localhost/agent-network-build' "
            "'    environment:' "
            "'      REQUIRED: ''${OPERCORD_POSTGRES_PASSWORD:?required}' "
            "> /home/test/workspace/compose.yaml && "
            "chown test:users /home/test/workspace/compose.yaml"
        )
        machine.fail(
            "su -s ${pkgs.bash}/bin/bash test -c "
            f"'cd /home/test/workspace && {container_tools}/podman version'"
        )
        machine.fail(
            guarded("local-codex-cli", "podman run --privileged localhost/agent-test")
        )
        machine.succeed(guarded("local-codex-cli", "podman version"))
        machine.succeed(guarded("local-claude-code", "podman version"))
        machine.succeed(guarded("local-claude-code", "podman info --format json"))
        machine.succeed(
            guarded(
                "local-claude-code",
                "podman build --tag localhost/agent-network-build .",
            )
        )
        machine.succeed(
            guarded(
                "local-claude-code",
                "podman network create agent-test-network",
            )
        )
        machine.succeed(
            guarded(
                "local-claude-code",
                "podman network rm agent-test-network",
            )
        )
        machine.succeed(guarded("local-claude-code", "podman compose version"))
        machine.succeed(
            guarded(
                "local-claude-code",
                "podman compose --file compose.yaml --project-name agent-compose config --services",
                "OPERCORD_POSTGRES_PASSWORD=packaging-check",
            )
            + " | grep -Fx agent-compose"
        )
        machine.succeed(
            guarded(
                "local-claude-code",
                "podman image rm localhost/agent-network-build",
            )
        )
        machine.succeed(guarded("local-codex-cli", "buildah version"))
        machine.succeed(guarded("local-codex-cli", "buildah from --name agent-buildah scratch"))
        machine.succeed(
            guarded(
                "local-codex-cli",
                "buildah copy agent-buildah rootfs/bin/busybox /bin/busybox",
            )
        )
        machine.succeed(
            guarded(
                "local-codex-cli",
                "buildah commit agent-buildah localhost/agent-test",
            )
        )
        machine.succeed(guarded("local-codex-cli", "buildah rm agent-buildah"))
        machine.succeed(
            guarded(
                "local-codex-cli",
                "podman run --rm localhost/agent-test /bin/busybox cat /proc/self/attr/current",
            )
            + " | grep -Fx 'local-agent-container-payload (enforce)'"
        )
        machine.succeed(
            "test -d /home/test/.local/share/containers/agents/codex/storage"
        )
        machine.succeed(
            "test -d /home/test/.local/share/containers/agents/claude/storage"
        )

    with subtest("Bubblewrap is always enforced and brokers namespace setup"):
        machine.succeed(
            "aa-status --json | ${pkgs.jq}/bin/jq -e "
            "'.profiles[\"bwrap\"] == \"enforce\" and "
            ".profiles[\"unpriv_bwrap\"] == \"enforce\" and "
            ".profiles[\"local-claude-code-bwrap\"] == \"enforce\" and "
            ".profiles[\"local-claude-code-bwrap-payload\"] == \"enforce\" and "
            ".profiles[\"local-bwrap-fixture\"] == \"enforce\"'"
        )
        machine.succeed(
            "su -s ${pkgs.bash}/bin/bash test -c "
            "'aa-exec -p local-bwrap-fixture -- ${pkgs.bash}/bin/bash -c "
            "\"exec ${pkgs.bubblewrap}/bin/bwrap --ro-bind / / --dev /dev --proc /proc "
            "--unshare-user --unshare-pid --die-with-parent ${pkgs.coreutils}/bin/true\"'"
        )

        def agent_sandbox(profile, launcher, command):
            return (
                "su -s ${pkgs.bash}/bin/bash test -c "
                f"'aa-exec -p {profile} -- {launcher} ${pkgs.bubblewrap}/bin/bwrap "
                "--ro-bind / / --dev /dev --proc /proc --unshare-user --unshare-pid "
                f"--die-with-parent {command}'"
            )

        claude_nested_output = machine.succeed(
            agent_sandbox(
                "local-claude-code",
                "${claudeFixture}/bin/claude-fixture",
                "${nestedUsernsProbe}/bin/nested-userns-probe",
            )
        )
        assert "local-claude-code-bwrap" in claude_nested_output
        assert "local-claude-code-bwrap-payload" in claude_nested_output

        machine.fail(
            agent_sandbox(
                "local-codex-cli",
                "${codexFixture}/bin/codex-fixture",
                "${nestedUsernsProbe}/bin/nested-userns-probe",
            )
            + " >/tmp/codex-nested-userns.out 2>/tmp/codex-nested-userns.err"
        )
        machine.succeed(
            "grep -F 'bwrap' /tmp/codex-nested-userns.out "
            "| grep -F 'unpriv_bwrap'"
        )
        machine.succeed(
            "grep -F 'setgroups: Permission denied' /tmp/codex-nested-userns.err"
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
            "/home/test/.cargo /home/test/.config/gh /home/test/.config/glab-cli "
            "/home/test/.config/git /home/test/.config/go/telemetry /home/test/.ssh "
            "/home/test/.keras /home/test/.gnupg/private-keys-v1.d "
            "/home/test/.local/state/apparmor-reports /home/test/nixos-config "
            "/home/test/nixos-config-writable"
        )
        machine.succeed(
            "touch "
            "/home/test/.agents/skills/example/SKILL.md /home/test/.cargo/.global-cache "
            "/home/test/.config/git/ignore /home/test/.config/go/telemetry/count "
            "/home/test/.config/gh/config.yml /home/test/.config/gh/hosts.yml "
            "/home/test/.config/glab-cli/aliases.yml /home/test/.config/glab-cli/config.yml "
            "/home/test/.keras/keras.json /home/test/.gnupg/common.conf "
            "/home/test/.gnupg/trustdb.gpg /home/test/.gnupg/private-keys-v1.d/private.key "
            "/home/test/.local/state/apparmor-reports/logs.json /home/test/.ssh/known_hosts"
        )
        machine.succeed(
            "chown -R test:users /home/test/.agents /home/test/.cache /home/test/.cargo /home/test/.config "
            "/home/test/.keras /home/test/.gnupg /home/test/.local /home/test/.ssh /home/test/nixos-config "
            "/home/test/nixos-config-writable"
        )
        machine.succeed(
            "install -d -o root -g root -m 0755 /var/cache/man/nixos-mandb/cat1"
        )
        machine.succeed(
            "install -o root -g root -m 0444 /dev/null /var/cache/man/nixos-mandb/index.db"
        )
        machine.succeed(
            "install -o root -g root -m 0666 /dev/null /var/cache/man/nixos-mandb/cat1/cache"
        )
        machine.succeed(
            "chmod 0600 /home/test/.agents/skills/example/SKILL.md /home/test/.config/git/ignore "
            "/home/test/.keras/keras.json /home/test/.gnupg/common.conf "
            "/home/test/.gnupg/trustdb.gpg /home/test/.gnupg/private-keys-v1.d/private.key "
            "/home/test/.local/state/apparmor-reports/logs.json /home/test/.ssh/known_hosts "
            "/home/test/.config/gh/config.yml /home/test/.config/gh/hosts.yml "
            "/home/test/.config/glab-cli/aliases.yml /home/test/.config/glab-cli/config.yml"
        )
        machine.succeed(
            "su -s ${pkgs.bash}/bin/bash test -c "
            "'aa-exec -p local-agent-fixture -- ${pkgs.coreutils}/bin/cat "
            "/home/test/.agents/skills/example/SKILL.md /home/test/.config/git/ignore "
            "/home/test/.config/gh/config.yml /home/test/.config/gh/hosts.yml "
            "/home/test/.config/glab-cli/aliases.yml /home/test/.config/glab-cli/config.yml "
            "/home/test/.keras/keras.json /home/test/.gnupg/common.conf "
            "/home/test/.local/state/apparmor-reports/logs.json /home/test/.ssh/known_hosts'"
        )
        machine.succeed(
            "su -s ${pkgs.bash}/bin/bash test -c "
            "'aa-exec -p local-agent-fixture -- ${pkgs.coreutils}/bin/touch "
            "/home/test/.cache/nix/allowed /home/test/.cache/uv/allowed "
            "/home/test/.config/go/telemetry/allowed "
            "/home/test/nixos-config-writable/allowed'"
        )
        machine.succeed(
            "su -s ${pkgs.bash}/bin/bash test -c "
            "'aa-exec -p local-agent-fixture -- ${pkgs.util-linux}/bin/flock "
            "/home/test/.cargo/.global-cache ${pkgs.coreutils}/bin/true'"
        )
        machine.succeed(
            "su -s ${pkgs.bash}/bin/bash test -c "
            "'aa-exec -p local-agent-fixture -- ${pkgs.bash}/bin/bash -c "
            "\"exec 9</var/cache/man/nixos-mandb/index.db; "
            "${pkgs.util-linux}/bin/flock --shared 9\"'"
        )
        machine.fail(
            "su -s ${pkgs.bash}/bin/bash test -c "
            "'aa-exec -p local-agent-fixture -- ${pkgs.coreutils}/bin/truncate -s 1 "
            "/var/cache/man/nixos-mandb/cat1/cache'"
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
            "'aa-exec -p local-agent-fixture -- ${pkgs.coreutils}/bin/truncate -s 1 "
            "/home/test/.config/gh/hosts.yml'"
        )
        machine.fail(
            "su -s ${pkgs.bash}/bin/bash test -c "
            "'aa-exec -p local-agent-fixture -- ${pkgs.coreutils}/bin/truncate -s 1 "
            "/home/test/.config/glab-cli/config.yml'"
        )
        machine.fail(
            "su -s ${pkgs.bash}/bin/bash test -c "
            "'aa-exec -p local-agent-fixture -- ${pkgs.coreutils}/bin/truncate -s 1 "
            "/home/test/.ssh/known_hosts'"
        )
        machine.fail(
            "su -s ${pkgs.bash}/bin/bash test -c "
            "'aa-exec -p local-enforce-fixture -- ${pkgs.coreutils}/bin/cat "
            "/home/test/.config/gh/hosts.yml'"
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
            "install -o root -g root -m 0666 /dev/null /home/test/Documents/shared"
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
            "'aa-exec -p local-enforce-fixture -- ${pkgs.coreutils}/bin/cat "
            "/home/test/Documents/shared'"
        )
        machine.fail(
            "su -s ${pkgs.bash}/bin/bash test -c "
            "'aa-exec -p local-enforce-fixture -- ${pkgs.coreutils}/bin/truncate -s 1 "
            "/home/test/Documents/shared'"
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
        machine.wait_for_unit("syncthing.service")
        machine.wait_until_succeeds("systemctl is-active --quiet syncthing.service")
        machine.succeed(
            "pid=$(systemctl show --property MainPID --value syncthing.service); "
            "grep -Fx 'local-syncthing (enforce)' /proc/$pid/attr/current"
        )
        machine.succeed("test -d /home/test/Sync/.config/syncthing")
        machine.fail("journalctl -k --grep 'profile=\\\"local-syncthing\\\"'")
        machine.succeed(
            "aa-exec -p local-syncthing -- ${pkgs.coreutils}/bin/cat /proc/bus/pci/devices"
        )
        machine.succeed(
            "aa-exec -p local-syncthing -- ${pkgs.coreutils}/bin/cat /proc/modules"
        )
  '';
}
