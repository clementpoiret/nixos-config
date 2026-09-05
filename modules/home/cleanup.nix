{ pkgs, ... }:
{
  systemd.user.services.cleanup-downloads = {
    Unit = {
      Description = "Delete files in %h/Downloads older than 30 days";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.findutils}/bin/find %h/Downloads -mindepth 1 -type f -mtime +30 -delete";

      NoNewPrivileges = true;
      PrivateTmp = true;
      ReadWritePaths = [ "%h/Downloads" ];
      LockPersonality = true;
      RestrictSUIDSGID = true;
      PrivateDevices = true;
    };
  };

  systemd.user.timers.cleanup-downloads = {
    Unit = {
      Description = "Run cleanup for %h/Downloads daily";
    };
    Timer = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "10m";
      AccuracySec = "1h";
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
