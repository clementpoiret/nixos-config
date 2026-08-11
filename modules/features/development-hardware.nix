{ pkgs, ... }:
{
  services.udev = {
    packages = [ pkgs.qmk-udev-rules ];
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
