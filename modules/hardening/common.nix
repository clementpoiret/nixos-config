# Security controls that are appropriate for both the desktop and laptop.
#
# High-breakage controls are deliberately excluded. In particular, this module
# does not force PTI, disable SMT, globally disable user namespaces, lock kernel
# modules, enforce module signatures, enable a global hardened allocator, or
# activate USBGuard without a reviewed device policy.

{
  config,
  host,
  lib,
  username,
  ...
}:

let
  tailscaleEnabled = config.services.tailscale.enable;
  tailscalePort = config.services.tailscale.port;
in
{
  boot.kernelParams = [
    "page_alloc.shuffle=1"
    "slab_nomerge"
    "vsyscall=none"
  ];

  boot.kernel.sysctl = {
    # Kernel information and local attack-surface restrictions.
    "kernel.kptr_restrict" = 2;
    "kernel.dmesg_restrict" = 1;
    "kernel.yama.ptrace_scope" = 1;
    "kernel.unprivileged_bpf_disabled" = 1;

    # Unprivileged BPF is already disabled permanently above, so level 1 has
    # little active effect in the normal state. Retain it as defense-in-depth;
    # level 2 would also harden privileged BPF and should be benchmarked before
    # applying it to the deliberately retained sched-ext/SCX workload.
    "net.core.bpf_jit_harden" = 1;

    "kernel.perf_event_paranoid" = 2;
    "vm.unprivileged_userfaultfd" = 0;
    "dev.tty.ldisc_autoload" = 0;

    # Filesystem link/FIFO protections and core-dump policy.
    "fs.protected_fifos" = 2;
    "fs.protected_regular" = 2;
    "fs.protected_hardlinks" = 1;
    "fs.protected_symlinks" = 1;
    "fs.suid_dumpable" = 0;
    "kernel.randomize_va_space" = 2;
    "vm.mmap_min_addr" = 65536;

    # Host-network hardening. These machines are not routers.
    "net.ipv4.tcp_syncookies" = 1;
    "net.ipv4.tcp_rfc1337" = 1;
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
    "net.ipv4.icmp_ignore_bogus_error_responses" = 1;

    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.secure_redirects" = 0;
    "net.ipv4.conf.default.secure_redirects" = 0;
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv4.conf.default.accept_source_route" = 0;
    "net.ipv4.conf.all.log_martians" = 1;
    "net.ipv4.conf.default.log_martians" = 1;

    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv6.conf.default.accept_redirects" = 0;
    "net.ipv6.conf.all.accept_source_route" = 0;
    "net.ipv6.conf.default.accept_source_route" = 0;
  };

  # Use the NixOS network option so its generated per-interface and default
  # sysctls have a single authoritative definition.
  networking.tempAddresses = "default";

  # Keep the isolation primitives used by Nix, browsers, Flatpak, Bubblewrap,
  # rootless Podman, and other sandboxes. Restrict namespaces per service.
  security.allowUserNamespaces = true;
  security.allowSimultaneousMultithreading = true;
  security.forcePageTableIsolation = false;

  security.apparmor.enable = true;

  # Disabling the systemd-coredump handler can make the kernel write ordinary
  # core files. Keep the handler, but configure it to retain no crash payload.
  systemd.coredump.enable = true;
  systemd.coredump.settings.Coredump = {
    Storage = "none";
    ProcessSizeMax = 0;
  };

  security.pam.loginLimits = [
    {
      domain = "*";
      type = "soft";
      item = "core";
      value = "0";
    }
    {
      domain = "*";
      type = "hard";
      item = "core";
      value = "0";
    }
  ];
  systemd.settings.Manager.DefaultLimitCORE = "0";
  systemd.user.settings.Manager.DefaultLimitCORE = "0";

  services.journald.extraConfig = ''
    Storage=persistent
    Compress=yes
    Seal=yes
    SystemMaxUse=1G
    MaxRetentionSec=30day
    RateLimitIntervalSec=30s
    RateLimitBurst=10000
  '';

  # Do not trust all packets arriving through Tailscale. Permit only the
  # services intentionally exposed over the private interface.
  networking.nftables.enable = true;
  networking.firewall = {
    enable = true;
    backend = "nftables";

    allowedTCPPorts = lib.mkForce [ ];
    allowedUDPPorts = lib.mkForce (lib.optionals tailscaleEnabled [ tailscalePort ]);
    trustedInterfaces = lib.mkForce [ ];

    # Loose RPF is retained because the repository uses Tailscale/Mullvad and
    # may use exit-node or policy-routing paths.
    checkReversePath = "loose";
    autoLoadConntrackHelpers = false;
    connectionTrackingModules = [ ];
    logRefusedConnections = false;
  };

  networking.firewall.interfaces = lib.mkIf tailscaleEnabled {
    "tailscale0" = {
      # SSH administration and Syncthing transport over the authenticated mesh.
      allowedTCPPorts = [
        22
        22000
      ];
      allowedUDPPorts = [ 22000 ];
    };
  };

  services.syncthing.openDefaultPorts = false;

  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      PubkeyAuthentication = true;

      X11Forwarding = false;
      AllowAgentForwarding = false;
      AllowTcpForwarding = false;
      GatewayPorts = "no";
      PermitTunnel = false;
      PermitUserEnvironment = false;

      MaxAuthTries = 3;
      MaxSessions = 4;
      LoginGraceTime = 30;
      LogLevel = "VERBOSE";
      AllowGroups = [ "ssh-users" ];
    };
  };

  users.groups.ssh-users = { };
  users.users.${username}.extraGroups = [ "ssh-users" ];

  # Strict authenticated DNS. The existing sops-managed drop-in can continue to
  # supply the resolver addresses and SNI names.
  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNSOverTLS = "true";
      DNSSEC = "true";
      FallbackDNS = [ ];
      LLMNR = "false";
      MulticastDNS = "false";
    };
  };

  # Authenticated time. These public services currently support NTS.
  services.timesyncd.enable = false;
  services.chrony = {
    enable = true;
    enableNTS = true;
    servers = [
      "time.cloudflare.com"
      "nts.netnod.se"
      "ptbtime1.ptb.de"
    ];
  };

  # A trusted Nix user is effectively inside the root trust boundary. Keep the
  # interactive account allowed to build, but not trusted to change daemon trust
  # policy or import unsigned paths.
  nix.settings = {
    sandbox = true;
    require-sigs = true;
    accept-flake-config = false;
    trusted-users = lib.mkForce [ "root" ];
    allowed-users = lib.mkForce [
      "root"
      username
    ];
  };

  # The encrypted DNS value should not be world-readable after decryption.
  sops.secrets."dns/${host}".mode = lib.mkForce "0400";

  # Use only stable LVFS metadata by default.
  services.fwupd.extraRemotes = lib.mkForce [ ];

  # Prefer portal-mediated file/application opening in the Wayland session.
  xdg.portal.xdgOpenUsePortal = lib.mkForce true;

  # Keep the current upstream TCP timestamp policy. Do not set
  # net.ipv4.tcp_timestamps=0; mode 1 preserves PAWS/RTT behavior while Linux
  # uses per-connection random offsets.
}
