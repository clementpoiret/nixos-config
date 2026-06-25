{
  inputs,
  hostFacts,
  pkgs,
  ...
}:
{
  imports = [ inputs.ucodenix.nixosModules.default ];

  # performance tweaks
  boot.kernel.sysctl = {
    "vm.swappiness" = 10;
    "vm.vfs_cache_pressure" = 50;
    "vm.dirty_background_ratio" = 5;
    "vm.dirty_ratio" = 10;
    "kernel.nmi_watchdog" = 0;

    # TCP Fast Open
    "net.ipv4.tcp_fastopen" = 3;
    # Increase network performance
    "net.core.netdev_max_backlog" = 16384;
    "net.ipv4.tcp_max_syn_backlog" = 8192;
    "net.core.somaxconn" = 8192;
    # BBR TCP congestion control
    "net.core.default_qdisc" = "cake";
    "net.ipv4.tcp_congestion_control" = "bbr";
  };

  services.udev.extraRules = ''
    # Set scheduler for NVMe
    ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}="none"
    # Set scheduler for SATA SSD
    ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="bfq"
    # Set scheduler for HDD
    ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"

    # This is for picotool
    SUBSYSTEM=="usb", \
      ATTRS{idVendor}=="2e8a", \
      ATTRS{idProduct}=="0003", \
      TAG+="uaccess" \
      MODE="660", \
      GROUP="plugdev"
    SUBSYSTEM=="usb", \
      ATTRS{idVendor}=="2e8a", \
      ATTRS{idProduct}=="0009", \
      TAG+="uaccess" \
      MODE="660", \
      GROUP="plugdev"
    SUBSYSTEM=="usb", \
      ATTRS{idVendor}=="2e8a", \
      ATTRS{idProduct}=="000a", \
      TAG+="uaccess" \
      MODE="660", \
      GROUP="plugdev"
    SUBSYSTEM=="usb", \
      ATTRS{idVendor}=="2e8a", \
      ATTRS{idProduct}=="000f", \
      TAG+="uaccess" \
      MODE="660", \
      GROUP="plugdev"

    # Jolt
    SUBSYSTEM=="powercap", ACTION=="add", RUN+="${pkgs.coreutils}/bin/chmod o+r /sys/class/powercap/intel-rapl/intel-rapl:0/energy_uj /sys/class/powercap/intel-rapl/intel-rapl:0/*/energy_uj"
  '';

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  hardware.enableRedistributableFirmware = true;

  # bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Experimental = true;
      };
    };
  };
  services.blueman.enable = true;

  # Firmware updates
  services.fwupd = {
    enable = true;
    extraRemotes = [ "lvfs-testing" ];
  };

  # ucode updates
  services.ucodenix = {
    enable = true;
    cpuModelId = hostFacts.hardware.cpuModelId;
  };

  # /tmp as tmpfs
  boot.tmp = {
    useTmpfs = true;
    # tmpfsSize = "50%";
  };

  hardware.flipperzero.enable = true;
}
