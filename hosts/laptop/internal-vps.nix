{ ... }:
{
  networking.wg-quick.interfaces.wg-rhizome = {
    autostart = false;
    address = [ "10.78.0.2/32" ];
    privateKeyFile = "/etc/wireguard/wg-rhizome.key";
    peers = [
      {
        publicKey = "XHNl08Ev48TVsB/gdgR7zX34zyLiuz+hxwkMkmwmhxY=";
        endpoint = "95.111.232.201:51820";
        allowedIPs = [ "10.78.0.1/32" ];
        persistentKeepalive = 25;
      }
    ];
  };

  programs.ssh.knownHosts.internalvps = {
    hostNames = [
      "internalvps"
      "10.78.0.1"
    ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGzsbrricThv/7voAy3tFL2qSSyQQiHx1bXWFUG1lJqZ";
  };

  home-manager.users.clementpoiret =
    { lib, ... }:
    {
      programs.ssh.settings.internalvps = lib.hm.dag.entryBefore [ "*" ] {
        HostName = "10.78.0.1";
        HostKeyAlias = "internalvps";
        User = "clementpoiret";
        BindInterface = "wg-rhizome";
        ConnectTimeout = 10;
        # Never reuse a connection established over the old management path.
        ControlMaster = "no";
        ControlPersist = "no";
        ControlPath = "none";
      };
    };
}
