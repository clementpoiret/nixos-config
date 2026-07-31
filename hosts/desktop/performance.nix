{
  config,
  lib,
  pkgs,
  ...
}:
{
  services = {
    power-profiles-daemon.enable = true;

    # Let LAVD adapt its scheduling policy to desktop load instead of pinning
    # it to the Balanced platform power profile selected below.
    scx.extraArgs = lib.mkForce [ "--autopilot" ];

    # Keep GPU limits mutable until each LACT profile has been validated on the
    # desktop. A non-empty settings value would make the GUI configuration
    # read-only.
    lact.enable = true;
  };

  hardware.rasdaemon.enable = true;

  environment.systemPackages = with pkgs; [
    ccache
    lm_sensors
    memtester
    mold
    sccache
    stress-ng
    config.boot.kernelPackages.turbostat
  ];

  systemd.services = {
    desktop-power-profile-balanced = {
      description = "Select the balanced desktop power profile";
      after = [ "power-profiles-daemon.service" ];
      requires = [ "power-profiles-daemon.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${config.services.power-profiles-daemon.package}/bin/powerprofilesctl set balanced";
      };
    };

    desktop-x3d-frequency = {
      description = "Prefer the frequency CCD on the Ryzen X3D CPU";
      after = [ "systemd-modules-load.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        for mode_file in \
          /sys/bus/platform/drivers/amd_x3d_vcache/*/amd_x3d_mode
        do
          if [ -e "$mode_file" ]; then
            printf '%s\n' frequency > "$mode_file"
            exit 0
          fi
        done

        echo "amd_x3d_mode was not exposed by the kernel" >&2
        exit 1
      '';
    };

    scx = {
      after = [
        "desktop-power-profile-balanced.service"
        "desktop-x3d-frequency.service"
      ];
      wants = [
        "desktop-power-profile-balanced.service"
        "desktop-x3d-frequency.service"
      ];
    };
  };
}
