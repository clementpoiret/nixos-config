# Dependency updates

- The local Proton binary updater was verified with `python3 pkgs/update-proton.py`;
  it pins Proton's published checksums, which Nix verifies during builds. Mail and
  Pass keep stable/beta pins in `releases.json`; beta includes stable releases to
  avoid downgrades and accepts only Mail's `EarlyAccess` or Pass's `Beta`, not Alpha.
  Bridge and Pass CLI remain stable-only. Bridge uses
  `bridge/linux/x86/v1/version.json`; the old
  `bridge/version_linux.json` feed is stale. Its feed and DEB signatures are verified
  against the pinned Bridge public key; Mail, Pass and Pass CLI currently publish
  checksums without Linux binary signatures. Keep Mail and Pass on nixpkgs' Electron
  runtime so their existing AppArmor execution rules continue to apply.
- Bridge's vendor Go executable segfaults after patching with patchelf 0.19.2;
  its package-local 0.15.2 pin was verified with the runtime version install check.
  Keep that check and the DEB signature verification enabled when changing the pin.
- Khal's Sphinx hook reads `sphinxBuilders` as a scalar even with structured
  attributes. Keep `"html man"` rather than a list so its declared man output is
  produced; both the package and man output builds were verified.
- Pass's native `.node` modules must be unpacked from the ASAR and patched against
  `libxkbcommon` and `libgcc`. Its install check loads the module through Electron's
  ASAR resolver; a successful resource-only build does not exercise this boundary.
- Brave's local updater is `python3 pkgs/update-brave.py` (verified); both binary
  updaters require GnuPG on PATH. Brave's signed checksum is verified in the updater
  and build. Public keys are pinned from the vendors' official signing-key pages;
  key rotations require review and are outside CI's dependency-update allowlist.
- Zotero's Gecko major must match `app/config.sh` (`GECKO_VERSION_LINUX`) from
  `pkgs.zotero.src`. Nixpkgs now supplies a private `firefox-esr-140-bin.nix`
  runtime; the old `firefox-esr-153-unwrapped` override is no longer accepted.
  That runtime is end-of-life: keep its approved insecure-package exception in
  `modules/core/system.nix` version-specific. Flake evaluation does not catch
  runtime/source mismatches. The verified package check from the repository root
  is `nix build --no-link --no-update-lock-file .#nixosConfigurations.laptop.pkgs.zotero`;
  also rebuild both host toplevels and the AppArmor parser after changing it.
- Rayburst's Tauri state uses `dev.aninsomniacy.rayburst`; its native browser host
  is `dev.aninsomniacy.rayburst.browser`. Registration atomically replaces JSON
  manifests through `.tmp*` files in the browser directories. Its native Linux
  tray uses D-Bus, not Motrix's runtime tray-icon PNG files (verified in package source).
- For measured-boot changes, preserve the PCR 4 alternative budget enforced in
  `modules/core/bootloader.nix`: bootloader versions multiply retained generations
  and their specialisations. See `docs/MEASURED-BOOT.md` for the verified NH error
  diagnostic; successful host builds do not exercise the live TPM policy update.
- Nixpkgs removed `boot.initrd.systemd.enable` with scripted initrd; omit it even
  when setting it to true. Keep `boot.initrd.systemd.tpm2.enable` for TPM unlocking.
  Both host toplevels and initrds were evaluated with nixpkgs `3ec636362e18`;
  removing the flag also leaves their derivations unchanged on the existing pin.
- Build Niri's pinned source through the host overlay (`prev.niri-unstable`), not
  the input flake's independently built package. Mesa loads from `/run/opengl-driver`
  and can require a newer glibc. The `niri-mesa-runtime` flake check exercises this
  dynamic loading boundary without a GPU; a successful host build alone misses it.
  Unstable removed `libdisplay-info_0_2`; its local ABI compatibility override was
  verified with `nix build --no-link --no-update-lock-file .#nixosConfigurations.laptop.pkgs.libdisplay-info_0_2`.
- Keep CachyOS on the personal flake's `release` branch, own nixpkgs input, and
  `overlays.pinned`. Its `linuxPackages-cachyos-latest-lto-zen4` already supplies
  LLVM/VirtualBox module fixes; `host-cpu-optimizations` verifies both hosts use
  the exact cached kernel derivation. Cache output signatures were verified with
  `nix store verify --store https://nixos-cachyos-kernels.cachix.org --no-contents`
  and the configured key. See `docs/KERNEL.md` for the preserved custom recipe
  and the verified stale `kcfi` helper-symbol pitfall.
  GitHub runners do not inherit NixOS `nix.settings`: keep the kernel cache in
  `cachix-action.extraPullNames` in both build jobs, which installs its URL and key.
  The kernel flake's `kernelModuleSignOverride` signs external modules after
  stripping and supplies `.ko.cer` certificates for Nixpkgs' module-tree aggregator.
  Keep that helper when constructing custom kernel package sets; do not add
  duplicate local signing overrides.
- OpenCode's CLI build imports root-level `script/native-arch.ts`, which its
  upstream Nix source filter omits. Keep the full-source override until that filter
  includes the build scripts. Verified with
  `nix build --no-link --no-update-lock-file .#nixosConfigurations.laptop.pkgs.flake.opencode`.
- OpenCode's rolling source can change `bun.lock` before its Nix hash bot catches
  up. Keep its source pinned and use upstream `nix/hashes.json`, not automatic
  acceptance of reported hashes. `pkgs/update-opencode.py` advances only to newer
  stable release versions: the shared repository also publishes v1 releases, so
  GitHub's `releases/latest` can point below the installed v2 version. The verified
  source pin is treated as 2.2.0 until a newer stable release is available.

# CI caching

- Add explicitly cached applications to `mkHostEntries` in `flake.nix`, not only
  the workflow's build targets: the per-host Cachix pins retain those roots.
  Hylki's membership in both host roots was verified by Nix evaluation.
- Cachix pushes recursive closures: keep kernel outputs and aggregate modules
  trees out of host roots, caching `boot.extraModulePackages` individually instead.
  Push roots explicitly rather than watching build dependencies. Both host roots
  were built and their runtime closures verified kernel-free; CI checks all kernel
  outputs before uploading or pinning.

# Application theming

- DMS's GTK apply script refuses Home Manager-managed `gtk.css` symlinks.
  Keep `stylix.targets.gtk.colors.enable = false` and `gtk.gtk4.theme = null`
  so DMS owns the stylesheets while Stylix keeps fonts and cursors. A GTK4
  theme makes Home Manager generate `gtk.css` even without `extraCss`.
  Verified both hosts with
  `nix build --no-link --no-update-lock-file .#checks.x86_64-linux.dms-application-theming`,
  which runs upstream apply/patch against writable copies of packaged adw-gtk3.
- Keep `stylix.targets.qt.enable = false` and qtct/Kvantum files free of Home
  Manager symlinks: DMS replaces qtct files, which would block later activation.
  The activation hook and packaged DMS Qt action select Fusion and each qtct's
  native `colors/matugen.conf`; standard qtct cannot load KDE-only palettes such
  as `DankMatugen.colors`. Legacy qtct files can still be read-only regular files,
  so the updater makes them writable before merging settings. Keep qt5ct/qt6ct
  platform themes and leave `QT_STYLE_OVERRIDE` unset. The theming check above
  verifies both Qt palettes in light/dark modes; keep its probes in separate
  derivations because Nix's Qt hooks reject mixed major versions.

# AppArmor

- Confined systemd services must allow `config.systemd.package`, not just
  `pkgs.systemd`: NixOS customizes the package used by unit PATHs. The DNS writer
  VM test exercises the actual service command, and the mode-matrix check covers
  both host registries without granting wildcard store execution.
- Container-engine policies must read the enabled `environment.etc` sources with
  targets under `containers/`: `/etc` permissions do not cover their store-backed
  symlink targets. Podman 6 uses drop-ins and omits empty registry settings.
  Full flake evaluation was verified on the pinned nixpkgs and `31ecbaca1bde`;
  both container-engine profiles were also parsed against the latter.

# USB serial devices

- Sonoff's CP210x USB IDs are shared with generic adapters: match its manufacturer
  and product too. Keep its `uaccess` tag before `73-seat-late.rules`; NixOS writes
  `services.udev.extraRules` to `99-local.rules`, too late to queue session ACLs.
  Verified both hosts with `nix build --no-link --no-update-lock-file .#checks.x86_64-linux.sonoff-serial-access`,
  using simulated Sonoff and generic CP210x devices without accessing real hardware.

# Syncthing

- Keep the laptop-only `RestrictSUIDSGID` exception: Syncthing preserves existing
  directory setgid bits during chmod, which systemd otherwise rejects with EPERM.
  Leave `NoNewPrivileges`, AppArmor, and writable-path restrictions enabled.

# SSH agents

- Keep the Proton Pass CA signing socket separate from the forwarded OpenSSH
  agent. Proton Pass CLI 2.4.2 cannot sign FIDO identities or enforce OpenSSH
  destination constraints; the YubiKey forwarding restrictions depend on OpenSSH.
- Niri's Home Manager GNOME Keyring service must stay secrets-only. The NixOS
  GNOME Keyring module supplies D-Bus, portal, PAM, and IPC-locking integration;
  it does not replace the Home Manager session service. Verified with
  `nix build --no-link --no-update-lock-file .#checks.x86_64-linux.credential-forwarding`.

# VPS management

- Keep `hosts/laptop/internal-vps.nix` laptop-only and `wg-rhizome` manual-only,
  separate from Opercord's `wg0` and personal Tailscale. The VPS peer registry
  lives in `nixos-server-config/nixos/wireguard-peers.nix`; private keys stay out
  of Nix. Verified with `nix build --no-link --no-update-lock-file .#checks.x86_64-linux.internal-vps-access`.

# Jujutsu synchronization

- Promotion accepts a linear stack rooted at the exact protected baseline, with
  every promoted revision checked for conflicts and a Conventional Commit subject.
  An empty writable tip is excluded; `fetch` rebases the whole pending stack while
  preserving its change IDs. The agent integration tests verify both paths.
- Fetching a rewritten imported `agent-base` can automatically rebase the writable
  working change. Keep working-copy updates enabled for these fetches and use the
  current `@` for the subsequent rebase; the pre-fetch commit ID can be obsolete.
  The agent integration tests reproduce this with a tracked, imported baseline.
