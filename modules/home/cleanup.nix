{ pkgs, lib, ... }:
let
  cleanupJobs = {
    downloads = {
      path = "%h/Downloads";
      age = 30;
      schedule = "daily";
    };
  };
in
{
  systemd.user.services = lib.mapAttrs' (name: job: {
    name = "cleanup-${name}";
    value = {
      Unit = {
        Description = "Delete files in ${job.path} older than ${toString job.age} days";
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.findutils}/bin/find ${job.path} -mindepth 1 -type f -mtime +${toString job.age} -delete";

        NoNewPrivileges = true;
        PrivateTmp = true;
        ReadWritePaths = [ job.path ];
        LockPersonality = true;
        RestrictSUIDSGID = true;
        PrivateDevices = true;
      };
    };
  }) cleanupJobs;

  systemd.user.timers = lib.mapAttrs' (name: job: {
    name = "cleanup-${name}";
    value = {
      Unit = {
        Description = "Run cleanup for ${job.path} ${job.schedule}";
      };
      Timer = {
        OnCalendar = job.schedule;
        Persistent = true;
        RandomizedDelaySec = "10m";
        AccuracySec = "1h";
      };
      Install = {
        WantedBy = [ "timers.target" ];
      };
    };
  }) cleanupJobs;
}
