# Dependency updates

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
