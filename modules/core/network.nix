{
  config,
  lib,
  pkgs,
  host,
  hostFacts ? { },
  ...
}:
let
  dnsSecretName = "dns/${host}";
  nameservers = hostFacts.network.nameservers or [ ];
in
{
  networking = {
    hostName = "${host}";
    networkmanager.enable = true;
    tempAddresses = "default";
    inherit nameservers;
    nftables.enable = true;
    firewall = {
      enable = true;
      backend = "nftables";
      allowedTCPPorts = [ ];
      allowedUDPPorts = [ ];
      # NixOS adds loopback itself, but force this list so services cannot
      # silently turn another interface into a trusted firewall bypass.
      trustedInterfaces = lib.mkForce [ "lo" ];

      # Loose RPF is required by Tailscale/Mullvad exit-node and policy-routing
      # paths. It is not equivalent to trusting the Tailscale interface.
      checkReversePath = "loose";
      autoLoadConntrackHelpers = false;
      connectionTrackingModules = [ ];
      logRefusedConnections = false;
    };
  };

  # These systems are network endpoints, not routers.
  boot.kernel.sysctl = {
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

  environment.systemPackages = with pkgs; [ networkmanagerapplet ];

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

  sops.secrets.${dnsSecretName}.restartUnits = [ "apply-secret-dns.service" ];

  systemd.services.apply-secret-dns = lib.mkIf (builtins.hasAttr dnsSecretName config.sops.secrets) {
    description = "Apply sops-managed DNS settings to systemd-resolved";
    after = [
      "sops-nix.service"
      "systemd-resolved.service"
    ];
    wants = [ "systemd-resolved.service" ];
    wantedBy = [ "multi-user.target" ];
    path = with pkgs; [
      coreutils
      gnused
      systemd
    ];
    serviceConfig.Type = "oneshot";
    script = ''
      secret_file=${lib.escapeShellArg config.sops.secrets.${dnsSecretName}.path}
      if [ ! -s "$secret_file" ]; then
        exit 0
      fi

      dns="$(tr '\n' ' ' < "$secret_file" | sed 's/[[:space:]]*$//')"
      if [ -z "$dns" ]; then
        exit 0
      fi

      install -d -m 0755 /run/systemd/resolved.conf.d
      cat > /run/systemd/resolved.conf.d/90-sops-dns.conf <<EOF
      [Resolve]
      DNS=$dns
      Domains=~.
      DNSOverTLS=true
      EOF

      systemctl reload-or-restart systemd-resolved.service
    '';
  };
}
