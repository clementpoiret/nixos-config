# Bootstrap

This repo manages two NixOS hosts from one flake: `desktop` and `laptop`.
Home Manager is integrated into each NixOS system build, so bootstrap and
updates go through NixOS commands rather than standalone `home-manager switch`.

## New Machine

1. Boot a NixOS installer.
2. Partition and mount the target system under `/mnt`.
3. Generate initial hardware configuration:

   ```bash
   sudo nixos-generate-config --root /mnt
   ```

4. Review `/mnt/etc/nixos/hardware-configuration.nix` and move the relevant
   generated content into `hosts/<host>/hardware-configuration.nix`.
5. Ensure the host has an age key available for `sops-nix`:

   ```bash
   sudo install -d -m 0700 /mnt/root/.config/sops/age
   sudo install -m 0600 keys.txt /mnt/root/.config/sops/age/keys.txt
   install -d -m 0700 ~/.config/sops/age
   install -m 0600 keys.txt ~/.config/sops/age/keys.txt
   ```

6. Build and install the selected host:

   ```bash
   sudo nixos-install --flake .#laptop
   ```

Use `.#desktop` for the desktop host.

## Existing Machine

For a machine that already boots this configuration:

```bash
nix flake check --no-build --no-update-lock-file
nix build .#nixosConfigurations.$(hostname).config.system.build.toplevel
nh os test
nh os switch
```

## Secrets

System secrets decrypt from `/root/.config/sops/age/keys.txt`.
Home Manager secrets decrypt from `~/.config/sops/age/keys.txt`.

Do not read decrypted secret values during Nix evaluation. Services and user
activation scripts should consume paths from `config.sops.secrets.*.path`.

