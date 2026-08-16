{ pkgs, ... }:
{
  boot = {
    kernelParams = [
      "page_alloc.shuffle=1"
      "slab_nomerge"
      "vsyscall=none"

      # Optional strict trials. Uncomment only one control per boot generation
      # and follow docs/HARDENING.md before retaining it.
      # "init_on_free=1"
      # "debugfs=off"
    ];

    kernel.sysctl = {
      "kernel.kptr_restrict" = 2;
      "kernel.dmesg_restrict" = 1;
      # Strict trial: change to 2 only when debuggers/profilers are expendable.
      "kernel.yama.ptrace_scope" = 1;
      "kernel.unprivileged_bpf_disabled" = 1;
      "net.core.bpf_jit_harden" = 1;
      "kernel.perf_event_paranoid" = 2;
      "vm.unprivileged_userfaultfd" = 0;
      "dev.tty.ldisc_autoload" = 0;

      "fs.protected_fifos" = 2;
      "fs.protected_regular" = 2;
      "fs.protected_hardlinks" = 1;
      "fs.protected_symlinks" = 1;
      "fs.suid_dumpable" = 0;
      "kernel.randomize_va_space" = 2;
      "vm.mmap_min_addr" = 65536;

      # Optional strict trial: blocks unprivileged io_uring while retaining a
      # privileged escape path. Test storage, databases, runtimes, and games.
      # "kernel.io_uring_disabled" = 1;
    };
  };

  security = {
    localAppArmor = {
      mode = "staged";
    };
    rtkit.enable = true;

    # Preserve the isolation primitives required by Nix, browsers, Flatpak,
    # Bubblewrap, and rootless Podman.
    allowUserNamespaces = true;
    allowSimultaneousMultithreading = true; # Strict trial: set false.
    forcePageTableIsolation = false; # Strict trial: set true.

    run0 = {
      enable = true;
      wheelNeedsPassword = true;
      persistentAuth.enable = false;
      persistentAuth.enableRemote = false;
      sudo-shim.enable = false;
    };

    sudo.enable = false;
    sudo-rs.enable = false;
    polkit = {
      enable = true;
      enablePkexecWrapper = false;
    };

    pam = {
      services = {
        login = {
          u2f.enable = true;
          enableGnomeKeyring = true;
        };
        greetd = {
          fprintAuth = true;
          u2f.enable = true;
        };
        # run0 authorization is mediated by Polkit.
        "polkit-1".u2f.enable = true;
      };
      u2f = {
        enable = true;
        settings = {
          interactive = true;
          cue = true;
        };
      };
      loginLimits = [
        {
          domain = "*";
          type = "soft";
          item = "core";
          value = "0";
        }
        {
          domain = "*";
          type = "hard";
          item = "core";
          value = "0";
        }
      ];
    };
  };

  system.tools.nixos-rebuild.enableRun0Elevation = true;

  # Keep systemd-coredump as the handler so crashes cannot leave ordinary core
  # files in arbitrary working directories, but retain no payload.
  systemd = {
    coredump = {
      enable = true;
      settings.Coredump = {
        Storage = "none";
        ProcessSizeMax = 0;
      };
    };
    settings.Manager.DefaultLimitCORE = "0";
    user.settings.Manager.DefaultLimitCORE = "0";
  };

  environment.systemPackages = with pkgs; [
    libsecret
    gnome-keyring
    seahorse
  ];

  programs.seahorse.enable = true;

  services.udev.extraRules = ''
    ACTION=="remove",\
     ENV{ID_BUS}=="usb",\
     ENV{ID_MODEL_ID}=="0407",\
     ENV{ID_VENDOR_ID}=="1050",\
     ENV{ID_VENDOR}=="Yubico",\
     RUN+="${pkgs.systemd}/bin/loginctl lock-sessions"
  '';
}
