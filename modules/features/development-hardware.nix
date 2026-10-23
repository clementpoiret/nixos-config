{ pkgs, ... }:
{
  services.udev = {
    packages = [
      pkgs.qmk-udev-rules
      (pkgs.writeTextDir "lib/udev/rules.d/70-sonoff-uaccess.rules" ''
        # Assign active-session ACLs before 73-seat-late.rules processes uaccess.
        SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", ATTRS{manufacturer}=="ITead", ATTRS{product}=="Sonoff Zigbee 3.0 USB Dongle Plus", TAG+="uaccess"
      '')
    ];
    extraRules = ''
      # Raspberry Pi RP2040 devices used by picotool.
      SUBSYSTEM=="usb", ATTRS{idVendor}=="2e8a", ATTRS{idProduct}=="0003", TAG+="uaccess", MODE="0660"
      SUBSYSTEM=="usb", ATTRS{idVendor}=="2e8a", ATTRS{idProduct}=="0009", TAG+="uaccess", MODE="0660"
      SUBSYSTEM=="usb", ATTRS{idVendor}=="2e8a", ATTRS{idProduct}=="000a", TAG+="uaccess", MODE="0660"
      SUBSYSTEM=="usb", ATTRS{idVendor}=="2e8a", ATTRS{idProduct}=="000f", TAG+="uaccess", MODE="0660"
    '';
  };

  hardware.flipperzero.enable = true;
}
