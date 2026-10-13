# Dependency updates

- The local Proton binary updater was verified with `python3 pkgs/update-proton.py`;
  it selects stable releases and pins Proton's published checksums, which Nix
  verifies during builds. Bridge uses `bridge/linux/x86/v1/version.json`; the old
  `bridge/version_linux.json` feed is stale. Its feed and DEB signatures are verified
  against the pinned Bridge public key; Mail, Pass and Pass CLI currently publish
  checksums without Linux binary signatures. Keep Mail and Pass on nixpkgs' Electron
  runtime so their existing AppArmor execution rules continue to apply.
- Pass's native `.node` modules must be unpacked from the ASAR and patched against
  `libxkbcommon` and `libgcc`. Its install check loads the module through Electron's
  ASAR resolver; a successful resource-only build does not exercise this boundary.
- Brave's local updater is `python3 pkgs/update-brave.py` (verified); both binary
  updaters require GnuPG on PATH. Brave's signed checksum is verified in the updater
  and build. Public keys are pinned from the vendors' official signing-key pages;
  key rotations require review and are outside CI's dependency-update allowlist.
- When changing Zotero's Firefox override in `flake.nix`, match the Gecko major in
  `app/config.sh` (`GECKO_VERSION_LINUX`) from `pkgs.zotero.src`. Nixpkgs can move
  to a newer ESR while Zotero's actor-patching scripts still require the older one.
  Flake evaluation does not catch this mismatch. From the repository root, the
  verified package check is `nix build --no-link --no-update-lock-file .#nixosConfigurations.laptop.pkgs.zotero`;
  also rebuild both host toplevels and the AppArmor parser after changing it.
- For measured-boot changes, preserve the PCR 4 alternative budget enforced in
  `modules/core/bootloader.nix`: bootloader versions multiply retained generations
  and their specialisations. See `docs/MEASURED-BOOT.md` for the verified NH error
  diagnostic; successful host builds do not exercise the live TPM policy update.
- Build Niri's pinned source through the host overlay (`prev.niri-unstable`), not
  the input flake's independently built package. Mesa loads from `/run/opengl-driver`
  and can require a newer glibc. The `niri-mesa-runtime` flake check exercises this
  dynamic loading boundary without a GPU; a successful host build alone misses it.

# SSH agents

- Keep the Proton Pass CA signing socket separate from the forwarded OpenSSH
  agent. Proton Pass CLI 2.4.2 cannot sign FIDO identities or enforce OpenSSH
  destination constraints; the YubiKey forwarding restrictions depend on OpenSSH.

# Jujutsu synchronization

- Fetching a rewritten imported `agent-base` can automatically rebase the writable
  working change. Keep working-copy updates enabled for these fetches and use the
  current `@` for the subsequent rebase; the pre-fetch commit ID can be obsolete.
  The agent integration tests reproduce this with a tracked, imported baseline.
