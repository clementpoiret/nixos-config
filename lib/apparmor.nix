{ lib }:
let
  inherit (lib) mkOption types;
in
{
  sensitiveGroups = {
    credential-broker = {
      allowRules = ''
        owner @{run}/user/[0-9]*/keyring/{,**} rwkl,
      '';
      denyRules = ''
        audit deny @{run}/user/[0-9]*/keyring/{,**} rwklm,
        audit deny dbus send bus=session peer=(name=org.freedesktop.secrets),
        audit deny dbus receive bus=session peer=(name=org.freedesktop.secrets),
      '';
      homeRoots = [ ];
    };
    forge-auth = {
      allowRules = ''
        owner @{HOME}/.config/gh/{config.yml,hosts.yml} r,
        owner @{HOME}/.config/glab-cli/{aliases.yml,config.yml} r,
      '';
      denyRules = ''
        audit deny @{HOME}/.config/gh/{config.yml,hosts.yml} rwklm,
        audit deny @{HOME}/.config/glab-cli/{aliases.yml,config.yml} rwklm,
      '';
      homeRoots = [
        ".config/gh"
        ".config/glab-cli"
      ];
    };
    gpg-agent = {
      allowRules = ''
        owner @{HOME}/.gnupg/S.gpg-agent{,.*} rw,
        owner @{HOME}/.gnupg/common.conf r,
        owner @{HOME}/.gnupg/trustdb.gpg rw,
      '';
      denyRules = ''
        audit deny @{HOME}/.gnupg/S.gpg-agent{,.*} rwklm,
      '';
      homeRoots = [ ".gnupg" ];
    };
    gpg-private = {
      allowRules = ''
        owner @{HOME}/.gnupg/private-keys-v1.d/{,**} r,
        owner @{HOME}/.gnupg/secring.gpg r,
      '';
      denyRules = ''
        audit deny @{HOME}/.gnupg/private-keys-v1.d/{,**} rwklm,
        audit deny @{HOME}/.gnupg/secring.gpg rwklm,
      '';
      homeRoots = [ ".gnupg" ];
    };
    hardware-credentials = {
      allowRules = ''
        owner @{HOME}/.config/Yubico/u2f_keys r,
      '';
      denyRules = ''
        audit deny @{HOME}/.config/Yubico/u2f_keys rwklm,
      '';
      homeRoots = [ ".config/Yubico" ];
    };
    mail-auth = {
      allowRules = ''
        owner @{HOME}/.config/aerc/accounts.conf{,.d/**} r,
      '';
      denyRules = ''
        audit deny @{HOME}/.config/aerc/accounts.conf{,.d/**} rwklm,
      '';
      homeRoots = [ ".config/aerc" ];
    };
    netrc = {
      allowRules = ''
        owner @{HOME}/.netrc r,
      '';
      denyRules = ''
        audit deny @{HOME}/.netrc rwklm,
      '';
      homeRoots = [ ".netrc" ];
    };
    nixos-config-writable = {
      allowRules = ''
        owner @{HOME}/nixos-config-writable/{,**} rwkl,
      '';
      denyRules = ''
        audit deny @{HOME}/nixos-config-writable/{,**} wklm,
      '';
      homeRoots = [ "nixos-config-writable" ];
    };
    password-store = {
      allowRules = ''
        owner @{HOME}/.password-store/{,**} rwkl,
        owner @{HOME}/.local/share/password-store/{,**} rwkl,
      '';
      denyRules = ''
        audit deny @{HOME}/.password-store/{,**} rwklm,
        audit deny @{HOME}/.local/share/password-store/{,**} rwklm,
      '';
      homeRoots = [
        ".password-store"
        ".local/share/password-store"
      ];
    };
    sops = {
      allowRules = ''
        owner @{HOME}/.config/sops/age/keys.txt r,
        owner @{HOME}/.config/sops-nix/secrets{,/**} r,
        owner /run/user/[0-9]*/secrets.d/{,/**} r,
        /run/secrets/{,/**} r,
        /run/secrets.d/[0-9]*/{,**} r,
      '';
      denyRules = ''
        audit deny @{HOME}/.config/sops/age/keys.txt rwklm,
        audit deny @{HOME}/.config/sops-nix/secrets{,/**} rwklm,
        audit deny /run/user/[0-9]*/secrets.d/{,/**} rwklm,
        audit deny /run/secrets/{,/**} rwklm,
        audit deny /run/secrets.d/{,**} rwklm,
      '';
      homeRoots = [
        ".config/sops"
        ".config/sops-nix"
      ];
    };
    ssh-config = {
      allowRules = ''
        owner @{HOME}/.ssh/config.secrets r,
        owner @{HOME}/.ssh/known_hosts{,.old} r,
      '';
      denyRules = ''
        audit deny @{HOME}/.ssh/config.secrets rwklm,
        audit deny @{HOME}/.ssh/known_hosts{,.old} rwklm,
      '';
      homeRoots = [ ".ssh" ];
    };
    ssh-control = {
      allowRules = ''
        owner @{HOME}/.ssh/{cm,sockets}/{,**} rwk,
      '';
      denyRules = ''
        audit deny @{HOME}/.ssh/{cm,sockets}/{,**} rwklm,
      '';
      homeRoots = [ ".ssh" ];
    };
    ssh-identities = {
      allowRules = ''
        owner @{HOME}/.ssh/id_* r,
        owner @{HOME}/.ssh/*.{key,p12,pem,pfx} r,
      '';
      denyRules = ''
        audit deny @{HOME}/.ssh/id_* rwklm,
        audit deny @{HOME}/.ssh/*.{key,p12,pem,pfx} rwklm,
      '';
      homeRoots = [ ".ssh" ];
    };
  };

  inventoryType = types.submodule {
    options = {
      kind = mkOption {
        type = types.enum [
          "application"
          "service"
        ];
      };
      status = mkOption {
        type = types.enum [
          "candidate"
          "exempt"
        ];
      };
      target = mkOption {
        type = types.str;
        description = "Package, launcher class, or service represented by this entry.";
      };
      rationale = mkOption {
        type = types.str;
        description = "Why the workload is not currently attached to a local profile.";
      };
    };
  };
}
