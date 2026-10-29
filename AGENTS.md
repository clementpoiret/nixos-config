# Checks

- Follow the verification policy in `docs/DECISIONS.md`: checks run real binaries,
  parsers, or fixtures, or assert properties derived across the configuration. Do not
  restate option values a module sets; record here why a setting must stay instead.

# Dependency updates

- Binary updaters: `python3 pkgs/update-proton.py` and `python3 pkgs/update-brave.py`
  (both verified; GnuPG must be on PATH). They pin vendor checksums, which Nix verifies.
  Brave's checksum file and Bridge's feed and DEB are verified against public keys
  pinned from the vendors' signing-key pages; key rotations need review and stay
  outside CI's update allowlist. Mail, Pass and Pass CLI publish no Linux signatures.
- Mail and Pass keep stable/beta pins in `releases.json`. Beta also considers stable
  releases to avoid downgrades and accepts only Mail's `EarlyAccess` or Pass's `Beta`,
  never Alpha. Bridge and Pass CLI are stable-only. Bridge's feed is
  `bridge/linux/x86/v1/version.json`; `bridge/version_linux.json` is stale.
- Keep Mail and Pass on nixpkgs' Electron so their AppArmor execution rules apply.
  Pass's native `.node` modules must be unpacked from the ASAR and patched against
  `libxkbcommon` and `libgcc`; only its install check, which loads them through
  Electron's ASAR resolver, exercises this.
- Bridge's Go executable segfaults after patchelf 0.19.2. Keep the package-local 0.15.2
  pin, its runtime version install check, and DEB signature verification.
- Khal's Sphinx hook reads `sphinxBuilders` as a scalar even with structured attributes:
  keep `"html man"`, not a list, so the declared man output is produced.
- Zotero's Gecko major must match `GECKO_VERSION_LINUX` in `app/config.sh` of
  `pkgs.zotero.src`; flake evaluation does not catch a mismatch. Its runtime is
  nixpkgs' private, end-of-life `firefox-esr-140-bin.nix` (the old
  `firefox-esr-153-unwrapped` override is rejected): keep the insecure-package
  exception in `modules/core/system.nix` version-specific. After changing it, build
  `nix build --no-link --no-update-lock-file .#nixosConfigurations.laptop.pkgs.zotero`
  (verified), both host toplevels, and `apparmor-policy-parser`.
- Rayburst's Tauri state is `dev.aninsomniacy.rayburst` and its native browser host
  `dev.aninsomniacy.rayburst.browser`. Registration atomically replaces JSON manifests
  through `.tmp*` files in the browser directories; its tray uses D-Bus, not runtime
  PNG files.
- Measured boot: preserve the PCR 4 alternative budget in `modules/core/bootloader.nix`
  (bootloader versions × retained generations × specialisations). Host builds do not
  exercise the live TPM policy update; see `docs/MEASURED-BOOT.md` for the NH error.
- Nixpkgs removed `boot.initrd.systemd.enable`; omit it even as `true`. Keep
  `boot.initrd.systemd.tpm2.enable` for TPM unlocking.
- Build Niri's pinned source through the host overlay (`prev.niri-unstable`), not the
  input flake's package: Mesa loads from `/run/opengl-driver` and can require a newer
  glibc. Only `niri-mesa-runtime` exercises this; host builds miss it. The local
  `libdisplay-info_0_2` ABI override replaces the version unstable removed.
- Keep CachyOS on the personal flake's `release` branch with its own nixpkgs input and
  `overlays.pinned`; `linuxPackages-cachyos-latest-lto-zen4` already carries the
  LLVM/VirtualBox module fixes, and `cached-kernel` checks both hosts use that exact
  derivation. GitHub runners ignore NixOS `nix.settings`, so both build jobs need the
  kernel cache in `cachix-action.extraPullNames`. Reuse the kernel flake's
  `kernelModuleSignOverride` for custom kernel package sets: it signs external modules
  after stripping and supplies the `.ko.cer` files the modules-tree aggregator needs.
  See `docs/KERNEL.md` for the custom recipe and its stale `kcfi` symbol pitfall.
- OpenCode's CLI build imports `script/native-arch.ts`, which upstream's Nix source
  filter omits; keep the full-source override until the filter includes it. Its
  `bun.lock` can change before upstream's hash bot catches up, so keep the source pinned
  and use upstream `nix/hashes.json`, never auto-accepted hashes. The shared repository
  also publishes v1 releases, so `releases/latest` can be older than the installed v2;
  `pkgs/update-opencode.py` only advances to newer stable releases.

# CI caching

- Add explicitly cached applications to `mkHostEntries` in `flake.nix`, not only to the
  workflow's build targets: the per-host Cachix pins retain those roots.
- Cachix pushes recursive closures: keep kernel outputs and aggregate modules trees out
  of host roots and cache `boot.extraModulePackages` individually. Push roots explicitly
  rather than watching build dependencies; CI rejects roots containing kernel outputs.

# Application theming

- DMS's GTK apply script refuses Home Manager-managed `gtk.css` symlinks. Keep
  `stylix.targets.gtk.colors.enable = false` and `gtk.gtk4.theme = null`, since any GTK4
  theme makes Home Manager generate `gtk.css`; DMS owns the stylesheets while Stylix
  keeps fonts and cursors.
- Keep `stylix.targets.qt.enable = false` and qtct/Kvantum files free of Home Manager
  symlinks: DMS replaces qtct files, which would block later activations. The
  activation hook and packaged DMS Qt action select Fusion and each qtct's native
  `colors/matugen.conf`, because standard qtct cannot load KDE-only palettes such as
  `DankMatugen.colors`. Legacy qtct files can be read-only, so the updater makes them
  writable before merging. Keep qt5ct/qt6ct platform themes and `QT_STYLE_OVERRIDE`
  unset.
- `dms-application-theming` runs upstream's scripts against writable copies of the
  packaged themes and probes both Qt palettes. Keep the Qt5 and Qt6 probes in separate
  derivations: Nix's Qt hooks reject mixed major versions.

# Niri desktop

- GNOME Control Center provides the D-Bus GlobalShortcutsProvider, which Ghostty's
  global keybindings can activate even outside GNOME. Keep Niri's GlobalShortcuts
  portal set to `none` without disabling Online Accounts or the keyring; GNOME still
  provides screen sharing.
- The reusable terminal needs its own Ghostty `--class` so GTK single-instance mode does
  not share the normal terminal's identity. Its helper addresses workspaces by ID
  through Niri's JSON IPC, because CLI workspace numbers are per-monitor, and parks on a
  dynamic empty workspace, because a named one would change the login workspace.

# AppArmor

- Confined systemd services must allow `config.systemd.package`, not `pkgs.systemd`:
  NixOS customizes the package used in unit PATHs. `apparmor-mode-matrix` checks both
  host registries.
- Container-engine policies must read the enabled `environment.etc` sources targeting
  `containers/`: `/etc` rules do not cover their store-backed symlink targets. Podman 6
  uses drop-ins and omits empty registry settings; `apparmor-policy-parser` checks
  every such source.

# USB serial devices

- Sonoff's CP210x USB IDs are shared with generic adapters, so also match its
  manufacturer and product. Its `uaccess` tag must precede `73-seat-late.rules`;
  `services.udev.extraRules` lands in `99-local.rules`, too late to queue session ACLs.

# Syncthing

- Keep the laptop-only `RestrictSUIDSGID` exception: Syncthing preserves existing
  directory setgid bits during chmod, which systemd otherwise rejects with EPERM.
  Leave `NoNewPrivileges`, AppArmor, and writable-path restrictions enabled.

# SSH agents

- Keep the Proton Pass CA signing socket separate from the forwarded OpenSSH agent:
  Proton Pass CLI 2.4.2 cannot sign FIDO identities or enforce OpenSSH destination
  constraints, which the YubiKey forwarding restrictions rely on.
- Niri's Home Manager GNOME Keyring service must stay secrets-only. The NixOS GNOME
  Keyring module supplies D-Bus, portal, PAM, and IPC-locking integration but does not
  replace the Home Manager session service.

# VPS management

- Keep `hosts/laptop/internal-vps.nix` laptop-only and `wg-rhizome` manual-only,
  separate from Opercord's `wg0` and personal Tailscale. The VPS peer registry lives in
  `nixos-server-config/nixos/wireguard-peers.nix`; private keys stay out of Nix.

# Jujutsu synchronization

- Promotion accepts a linear stack rooted at the exact protected baseline, with every
  revision conflict-free and carrying a Conventional Commit subject. An empty writable
  tip is excluded; `fetch` rebases the whole pending stack, preserving change IDs.
- Fetching a rewritten imported `agent-base` can rebase the writable working change.
  Keep working-copy updates enabled for these fetches and use the current `@` for the
  following rebase: the pre-fetch commit ID can be obsolete.
