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
- Build Niri's pinned source through the host overlay (`prev.niri-unstable`), not
  the input flake's independently built package. Mesa loads from `/run/opengl-driver`
  and can require a newer glibc. The `niri-mesa-runtime` flake check exercises this
  dynamic loading boundary without a GPU; a successful host build alone misses it.
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

# Application theming

- DMS's GTK apply script refuses Home Manager-managed `gtk.css` symlinks.
  Keep `stylix.targets.gtk.colors.enable = false` and `gtk.gtk4.theme = null`
  so DMS owns the stylesheets while Stylix keeps fonts and cursors. A GTK4
  theme makes Home Manager generate `gtk.css` even without `extraCss`.
  Verified both hosts with
  `nix build --no-link --no-update-lock-file .#checks.x86_64-linux.dms-application-theming`,
  which runs upstream apply/patch against writable copies of packaged adw-gtk3.
- Keep `stylix.targets.qt.enable = false` and qtct/Kvantum settings unmanaged:
  DMS rewrites qtct files with `sed -i`, replacing Home Manager symlinks with
  regular files that block later activation. Keep the Qt platform themes on
  qt5ct/qt6ct rather than GTK passthrough; install Kvantum's plugins without
  forcing `QT_STYLE_OVERRIDE`, so existing selections remain available.

# AppArmor

- Confined systemd services must allow `config.systemd.package`, not just
  `pkgs.systemd`: NixOS customizes the package used by unit PATHs. The DNS writer
  VM test exercises the actual service command, and the mode-matrix check covers
  both host registries without granting wildcard store execution.

# Syncthing

- Keep the laptop-only `RestrictSUIDSGID` exception: Syncthing preserves existing
  directory setgid bits during chmod, which systemd otherwise rejects with EPERM.
  Leave `NoNewPrivileges`, AppArmor, and writable-path restrictions enabled.

# SSH agents

- Keep the Proton Pass CA signing socket separate from the forwarded OpenSSH
  agent. Proton Pass CLI 2.4.2 cannot sign FIDO identities or enforce OpenSSH
  destination constraints; the YubiKey forwarding restrictions depend on OpenSSH.

# Jujutsu synchronization

- Promotion accepts a linear stack rooted at the exact protected baseline, with
  every promoted revision checked for conflicts and a Conventional Commit subject.
  An empty writable tip is excluded; `fetch` rebases the whole pending stack while
  preserving its change IDs. The agent integration tests verify both paths.
- Fetching a rewritten imported `agent-base` can automatically rebase the writable
  working change. Keep working-copy updates enabled for these fetches and use the
  current `@` for the subsequent rebase; the pre-fetch commit ID can be obsolete.
  The agent integration tests reproduce this with a tracked, imported baseline.
