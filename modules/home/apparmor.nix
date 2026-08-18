{ lib, ... }:
let
  inherit (lib) mkOption types;

  capabilityType = types.enum [
    "audio"
    "camera"
    "credential-broker"
    "desktop"
    "developer-exec"
    "full-home"
    "gpu"
    "network"
    "portal"
    "runtime-introspection"
    "session-bus"
    "shared-memory"
    "system-bus"
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

        namespaceExecutables = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Executables transitioned into the restricted namespace child profile.";
        };

        namespaceRules = mkOption {
          type = types.lines;
          default = "";
          description = "Audited capability and process-map rules limited to the namespace child.";
        };

        namespaceRulesRationale = mkOption {
          type = types.str;
          default = "";
          description = "Required rationale when namespaceRules is non-empty.";
        };

        sensitiveAccess = mkOption {
          type = types.listOf sensitiveAccessType;
          default = [ ];
          description = "Sensitive resource groups explicitly available to this application.";
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

    developerPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Configured developer package outputs executable by developer-capable profiles.";
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
