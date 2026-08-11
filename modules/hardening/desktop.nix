# Desktop-only policy: no hibernation and stronger running-kernel immutability.

{ config, lib, ... }:

{
  # NixOS implements this by disabling kexec and adding nohibernate. That is
  # appropriate on this desktop because hibernation is not part of its design.
  security.protectKernelImage = true;

  # The NMI watchdog is a reliability/debugging facility, not a security
  # mitigation. Keep it disabled for lower interrupt/performance overhead; turn
  # it on temporarily when diagnosing hard lockups. rasdaemon remains useful.
  boot.kernel.sysctl."kernel.nmi_watchdog" = lib.mkForce 0;

  # The common firewall no longer trusts whole interfaces. A default libvirt
  # NAT network therefore needs only its host-side DNS and DHCP listeners. If
  # the bridge has another name, replace virbr0 after inspecting `ip link`.
  networking.firewall.interfaces."virbr0" = lib.mkIf config.virtualisation.libvirtd.enable {
    allowedTCPPorts = [ 53 ];
    allowedUDPPorts = [
      53
      67
    ];
  };
}
