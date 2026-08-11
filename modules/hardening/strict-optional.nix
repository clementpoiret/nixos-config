# Optional high-breakage controls.
#
# This file is valid Nix but enables nothing until a local boolean is changed.
# Activate one control at a time and retain both cached-CachyOS and stock-NixOS
# recovery specialisations.

{
  host,
  lib,
  ...
}:

let
  enableInitOnFree = false;
  enableDebugfsOff = false;
  enableStrictPtrace = false;
  enableIoUringRestriction = false;
  enableForcedPTI = false;
  enableNoSMT = false;
  enableModuleSignatureEnforcement = false;
  enableModuleLock = false;
  enableDesktopLockdown = false;
  enableHardenedMallocLight = false;

  enforceModuleSignatures = enableModuleSignatureEnforcement || enableDesktopLockdown;
in
lib.mkMerge [
  {
    boot.kernelParams =
      lib.optionals enableInitOnFree [ "init_on_free=1" ]
      ++ lib.optionals enableDebugfsOff [ "debugfs=off" ]
      ++ lib.optionals enforceModuleSignatures [ "module.sig_enforce=1" ]
      ++ lib.optionals (enableDesktopLockdown && host == "desktop") [
        "lockdown=integrity"
      ];

    assertions = [
      {
        assertion = !(enableDesktopLockdown && host != "desktop");
        message = ''
          Linux Lockdown denies hibernation in the current kernel. The laptop's
          hibernation requirement and Lockdown are therefore mutually exclusive.
          Secure Boot and module-signature enforcement may be staged separately.
        '';
      }
    ];
  }

  (lib.mkIf enableStrictPtrace {
    boot.kernel.sysctl."kernel.yama.ptrace_scope" = lib.mkForce 2;
  })

  (lib.mkIf enableIoUringRestriction {
    # Use 1 first. It blocks unprivileged use while retaining an administrative
    # escape path; use 2 only after testing every storage/database workload.
    boot.kernel.sysctl."kernel.io_uring_disabled" = lib.mkForce 1;
  })

  (lib.mkIf enableForcedPTI {
    security.forcePageTableIsolation = lib.mkForce true;
  })

  (lib.mkIf enableNoSMT {
    security.allowSimultaneousMultithreading = lib.mkForce false;
  })

  (lib.mkIf enableModuleLock {
    security.lockKernelModules = true;
  })

  (lib.mkIf enableHardenedMallocLight {
    environment.memoryAllocator.provider = lib.mkForce "graphene-hardened-light";
  })
]
