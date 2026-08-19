{ lib, ... }:
let
  inherit (lib) mkOption types;

  capabilityType = types.enum [
    "audio"
    "bubblewrap"
    "camera"
    "credential-broker"
    "desktop"
    "developer-exec"
    "gpu"
    "host-diagnostics"
    "network"
    "portal"
    "runtime-introspection"
    "session-bus"
    "shared-memory"
    "terminal"
    "userns"
    "user-files"
  ];

  sensitiveAccessType = types.enum [
    "credential-broker"
    "gpg-agent"
    "gpg-private"
    "hardware-credentials"
    "mail-auth"
    "nixos-config-writable"
    "password-store"
    "sops"
    "ssh-config"
    "ssh-control"
    "ssh-identities"
  ];

  applicationType = types.submodule (
    { name, ... }:
    {
      options = {
        enable = lib.mkEnableOption "the local-${name} AppArmor profile" // {
          default = true;
        };

        package = mkOption {
          type = types.package;
          description = "The exact installed package protected by this profile.";
        };

        executable = mkOption {
          type = types.str;
          default = "bin/${name}";
          description = "Package-relative executable used as the profile attachment.";
        };

        capabilities = mkOption {
          type = types.listOf capabilityType;
          default = [ ];
          description = "Composable host capabilities granted to the application.";
        };

        bubblewrapPackage = mkOption {
          type = types.nullOr types.package;
          default = null;
          description = "Exact Bubblewrap package used by this application's command sandbox.";
        };

        homePaths = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Home-relative application state trees granted read/write access.";
        };

        extraClosureRoots = mkOption {
          type = types.listOf types.package;
          default = [ ];
          description = "Additional package closures granted read and mmap access.";
        };

        executionPackages = mkOption {
          type = types.listOf types.package;
          default = [ ];
          description = "Direct package outputs whose application/helper executables may run.";
        };

        extraExecutables = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Exact executable paths or AppArmor path patterns outside direct package outputs.";
        };

        profileReentryExecutables = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Executables that re-enter the same profile with a scrubbed environment.";
        };

        userNamespaceRules = mkOption {
          type = types.lines;
          default = "";
          description = "Audited namespace rules added to the application's main profile.";
        };

        userNamespaceRulesRationale = mkOption {
          type = types.str;
          default = "";
          description = "Required rationale when userNamespaceRules is non-empty.";
        };

        systemBusPeers = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Well-known system D-Bus peer names available for sending and receiving.";
        };

        sensitiveAccess = mkOption {
          type = types.listOf sensitiveAccessType;
          default = [ ];
          description = "Sensitive resource groups explicitly available to this application.";
        };

        elevatedAccessRationale = mkOption {
          type = types.str;
          default = "";
          description = "Required rationale for developer execution or sensitive resource access.";
        };

        extraRules = mkOption {
          type = types.lines;
          default = "";
          description = "Audited AppArmor rules not represented by a typed capability.";
        };

        extraRulesRationale = mkOption {
          type = types.str;
          default = "";
          description = "Required rationale when extraRules is non-empty.";
        };
      };
    }
  );

  inventoryType = types.submodule (
    { ... }:
    {
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
    }
  );
in
{
  options.localAppArmor = {
    applications = mkOption {
      type = types.attrsOf applicationType;
      default = { };
      description = "Applications registered for locally generated AppArmor profiles.";
    };

    sessionReadPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Session asset/plugin packages granted read and library-mmap access.";
    };

    inventory = mkOption {
      type = types.attrsOf inventoryType;
      default = { };
      description = "Audited candidates and explicit exemptions from local confinement.";
    };
  };
}
