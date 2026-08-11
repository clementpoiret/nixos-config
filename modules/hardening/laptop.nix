# Laptop-only policy: preserve encrypted hibernation and optimize idle behavior.

{ lib, ... }:

{
  # protectKernelImage adds nohibernate, so it must remain disabled here.
  security.protectKernelImage = false;

  # Permanently disable kexec for the current boot without disabling hibernation.
  boot.kernel.sysctl."kernel.kexec_load_disabled" = 1;

  # Preserve the existing battery-oriented choice.
  boot.kernel.sysctl."kernel.nmi_watchdog" = lib.mkForce 0;

  networking.networkmanager.wifi = {
    powersave = true;
    scanRandMacAddress = true;
    macAddress = "stable-ssid";
  };
}
