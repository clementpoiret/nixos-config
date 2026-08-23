{
  config,
  host,
  lib,
  pkgs,
  username,
  ...
}:
let
  homeDirectory = config.users.users.${username}.home;
  syncthingRoot = lib.removeSuffix "/" config.services.syncthing.dataDir;
  syncthingRoots = lib.unique (
    [ syncthingRoot ] ++ lib.optional (host == "desktop") "/srv/syncthing"
  );
in
{
  services = {
    gvfs.enable = true;
    dbus = {
      enable = true;
      implementation = "broker";
      packages = with pkgs; [
        gcr
        gnome-keyring
        libsecret
        seahorse
      ];
    };
    journald.extraConfig = ''
      Storage=persistent
      Compress=yes
      Seal=yes
      SystemMaxUse=1G
      MaxRetentionSec=30day
      RateLimitIntervalSec=30s
      RateLimitBurst=10000
    '';
    timesyncd.enable = false;
    chrony = {
      enable = true;
      enableNTS = true;
      servers = [
        "time.cloudflare.com"
        "nts.netnod.se"
        "ptbtime1.ptb.de"
      ];
    };
    #fstrim.enable = true;
  };

  services.syncthing = {
    enable = true;
    user = username;
    dataDir = "/home/${username}/Sync/";
    openDefaultPorts = false;
  };

  security.localAppArmor = {
    services.syncthing = {
      unit = "syncthing";
      packageRoots = [ config.services.syncthing.package ];
      executionPackages = [ config.services.syncthing.package ];
      capabilities = [
        "network"
        "runtime-introspection"
      ];
      readOnlyPaths = [
        "${homeDirectory}/"
        "/proc/bus/pci/devices"
        "/proc/modules"
      ];
      readWritePaths =
        builtins.concatMap (path: [
          "${path}/"
          "${path}/**"
        ]) syncthingRoots
        ++ [
          "/run/syncthing/"
          "/run/syncthing/**"
        ];
    };

    inventory = {
      network-control-plane = {
        kind = "service";
        status = "exempt";
        target = "NetworkManager, resolved, chrony, OpenSSH, and Tailscale";
        rationale = "Network control-plane daemons require individual protocol and privilege threat models.";
      };
      virtualization = {
        kind = "service";
        status = "exempt";
        target = "libvirt and Podman";
        rationale = "Container and VM launchers intentionally construct dynamic namespaces, devices, and child policies.";
      };
      desktop-session = {
        kind = "service";
        status = "exempt";
        target = "greetd, D-Bus, portals, keyrings, PipeWire, Bluetooth, and PCSC";
        rationale = "Session brokers mediate other applications and need dedicated peer-aware policies.";
      };
      host-management = {
        kind = "service";
        status = "exempt";
        target = "hardware, firmware, GPU, scheduler, and performance daemons";
        rationale = "Their privileged device and sysfs surfaces require host-specific enforced tests.";
      };
      apparmor-debug-report = {
        kind = "service";
        status = "exempt";
        target = "apparmor-debug-report.service";
        rationale = "The hardened root collector must read kernel audit records before dropping privileges for report writes.";
      };
    };
  };

  systemd.services.syncthing.serviceConfig = {
    ProtectHome = "read-only";
    ProtectSystem = "strict";
    ReadWritePaths = syncthingRoots;
    RestrictAddressFamilies = [
      "AF_UNIX"
      "AF_INET"
      "AF_INET6"
    ];
    SystemCallArchitectures = "native";
    UMask = "0077";
  };
}
