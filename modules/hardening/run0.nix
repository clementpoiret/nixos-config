# Staged module: migrate to run0 only after testing local and remote recovery.
# The sudo shim is intentionally retained for the first phase.

{ ... }:

{
  security.run0 = {
    enable = true;
    wheelNeedsPassword = true;
    persistentAuth.enable = false;
    persistentAuth.enableRemote = false;
    sudo-shim.enable = true;
  };

  security.sudo.enable = false;
  security.sudo-rs.enable = false;
  security.polkit.enable = true;
  security.polkit.enablePkexecWrapper = false;

  # run0 authorization goes through Polkit. Preserve the repository's U2F
  # authentication path for that PAM service.
  security.pam.services."polkit-1".u2fAuth = true;
}
