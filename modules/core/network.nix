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
    inherit nameservers;
    firewall = {
      enable = true;
      allowedTCPPorts = [
        22
        80
        443
        59010
        59011
      ];
      allowedUDPPorts = [
        51820
        59010
        59011
      ];
    };
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };

  environment.systemPackages = with pkgs; [ networkmanagerapplet ];

  services.resolved = {
    enable = true;
    settings = {
      Resolve = {
        DNSoverTLS = "true";
      };
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
