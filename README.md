# Clement's NixOS Configuration

Single flake-based NixOS configuration for the `desktop` and `laptop` hosts,
with Home Manager integrated into each NixOS build.

## Important Defaults

- The managed username is currently fixed to `clementpoiret` in `flake.nix`.
  Create or keep that user on the stock system before switching.
- A flake host name is also used as `networking.hostName` and as the name of
  the host directory under `hosts/`.
- The shared configuration currently assumes an AMD CPU because `ucodenix` is
  enabled globally. A non-AMD host needs a small module change before it can be
  added.
- `system.stateVersion` and Home Manager's `home.stateVersion` are both
  currently `26.05`. Do not change them as part of a migration unless the
  machine was originally installed with a different state version and the
  implications have been reviewed.
- Home Manager is part of the NixOS configuration. Do not run a separate
  `home-manager switch`.

## Layout

- `flake.nix`: flake inputs, overlays, and host outputs.
- `lib/mkHost.nix`: shared host constructor.
- `hosts/<host>/`: host entrypoint, hardware config, and host facts.
- `modules/core/`: shared NixOS modules.
- `modules/home/`: Home Manager modules.
- `pkgs/`: local packages exposed through the default overlay.
- `secrets/`: sops-nix encrypted secrets.
- `docs/`: bootstrap, operations, architecture decisions, and host notes.
- `nixos-guide.md`: architecture and operations guide used for the current refactor.

## Hosts

- `desktop`: X870E/9950X3D workstation using its AMD iGPU for the graphical
  session and its RTX 4080 for compute.
- `laptop`: Framework laptop configuration with laptop-specific power,
  hibernation, Framework, and AMD GPU quirks.

## Add or Migrate a Device

This procedure starts from an already installed, bootable stock NixOS system.
It keeps the stock system as a bootloader rollback generation while preparing
and activating this repository.

Examples below use `desktop`. Replace it with the lowercase host name being
added:

```bash
export NEW_HOST=desktop
export REPO_DIR="$HOME/nixos-config"
```

If the machine is replacing an existing `desktop` or `laptop`, reuse that
output. Only create a new output when the device is meant to have a distinct
configuration.

### 1. Back Up the Stock Configuration

Keep a copy of the working stock configuration and record the installed state
version:

```bash
sudo cp -a /etc/nixos /etc/nixos.stock
grep 'system\.stateVersion' /etc/nixos/configuration.nix
hostname
lsblk --fs
findmnt
```

The current stock hostname should already equal `$NEW_HOST`. If it does not,
set `networking.hostName = "<new-host>";` in the stock configuration, rebuild
it, and reboot before enrolling U2F credentials.

Also retain a separate backup of important user data. At minimum, account for:

- the SOPS age private key;
- SSH identities, FIDO SSH key handles, `authorized_keys`, `known_hosts`, and
  `allowed_signers`;
- GPG public keys, owner trust, and any software-backed private keys;
- locally installed fonts;
- `~/Sync`, Syncthing state, and other data not stored in this repository;
- browser profiles or other application data that is not synchronized.

Use an encrypted removable device or another authenticated encrypted channel
for private keys. Never place them in this repository.

### 2. Obtain the Repository

The stock system only needs Git for the initial clone:

```bash
nix-shell -p git
git clone https://github.com/clementpoiret/nixos-config.git "$REPO_DIR"
cd "$REPO_DIR"
```

If the repository is not accessible over HTTPS, copy an existing checkout over
an encrypted channel. Restore the SSH remote after the SSH identities have been
installed:

```bash
git remote set-url origin git@github.com:clementpoiret/nixos-config.git
```

### 3. Install the SOPS Age Key

This repository currently encrypts secrets to the age recipient listed in
`.sops.yaml`. Copy the matching existing private key from a trusted machine;
generating an unrelated key will not decrypt the existing secrets.

Install the same key for the user-side Home Manager module and the system-side
NixOS module:

```bash
install -d -m 0700 "$HOME/.config/sops/age"
install -m 0600 /path/to/keys.txt \
  "$HOME/.config/sops/age/keys.txt"

sudo install -d -o root -g root -m 0700 /root/.config/sops/age
sudo install -o root -g root -m 0600 /path/to/keys.txt \
  /root/.config/sops/age/keys.txt
```

Verify that the private key produces the recipient from `.sops.yaml`, then
test decryption without printing plaintext:

```bash
nix --extra-experimental-features 'nix-command flakes' \
  shell nixpkgs#age -c \
  age-keygen -y "$HOME/.config/sops/age/keys.txt"

SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt" \
  nix --extra-experimental-features 'nix-command flakes' \
  shell nixpkgs#sops -c \
  sops --decrypt secrets/user-secrets.yaml > /dev/null
```

Never commit `keys.txt`, copy it to the Nix store, or leave it on an
unencrypted transfer device.

To introduce a per-device age key instead, generate it on the new device, add
its public recipient to `.sops.yaml`, and run `sops updatekeys
secrets/user-secrets.yaml` using an already authorized private key. Do not
remove the old recipient until decryption has been tested with the new key.

### 4. Capture and Review the Hardware Configuration

Copy the hardware configuration from the booting stock system:

```bash
mkdir -p "hosts/$NEW_HOST"
cp /etc/nixos/hardware-configuration.nix \
  "hosts/$NEW_HOST/hardware-configuration.nix"
```

Review it instead of copying `configuration.nix` wholesale. In particular,
verify:

- every filesystem, LUKS mapping, UUID, subvolume, and `/boot` entry;
- the generated initrd and kernel modules;
- Btrfs mount options, swapfile size, and zram policy;
- GPU drivers and any early KMS requirement;
- hibernation device and Btrfs swapfile offset, if hibernation is enabled;
- that no mount or UUID from the previous physical machine remains.

For a replacement `desktop` or `laptop`, compare the generated file with the
existing host file and preserve intentional repository policy such as mount
options, zram, swap, GPU selection, and laptop hibernation settings.

### 5. Create the Host Files

Skip this section when reusing an existing host output. A new host needs an
entrypoint, hardware configuration, and facts file.

Start with a minimal `hosts/<new-host>/default.nix`:

```nix
{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/core
  ];

  boot.kernelParams = [
    "microcode.amd_sha_check=off"
  ];
}
```

Add only settings required by that device. Use the existing Desktop and Laptop
files as examples for GPU routing, hibernation, power management, or
machine-specific udev rules.

Retrieve the AMD CPUID used by `ucodenix`:

```bash
nix-shell -p cpuid --run \
  "cpuid -1 -l 1 -r | sed -n 's/.*eax=0x\([0-9a-f]*\).*/\U\1/p'"
```

Create `hosts/<new-host>/facts.nix` with the returned value:

```nix
{
  hardware.cpuModelId = "REPLACE_WITH_CPUID";

  home = {
    easyeffects = {
      enable = false;
      framework16Presets = false;
    };

    zk.notebookDir = null;
  };

  network.nameservers = [ ];
}
```

Register the host and its build check in `flake.nix`. For a host named
`workstation`, the two entries are:

```nix
nixosConfigurations = {
  workstation = mkHost { host = "workstation"; };
};

checks.${system} = {
  workstation-toplevel =
    self.nixosConfigurations.workstation.config.system.build.toplevel;
};
```

Keep the existing hosts in both attribute sets. Add an appropriate
`nixos-hardware` module through `extraModules` when one exists for the device.

Every registered host also requires a `dns/<host>` value in
`secrets/user-secrets.yaml`. Edit the file through SOPS and add the new key
under `dns`. An encrypted empty string is valid when the host should not
override DNS:

```bash
SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt" \
  nix --extra-experimental-features 'nix-command flakes' \
  shell nixpkgs#sops -c sops secrets/user-secrets.yaml
```

Do not put decrypted values on a command line or in a Nix expression.

New files in a Git worktree are invisible to flake evaluation until they are
tracked. Use one of these workflows before building:

```bash
# Colocated Jujutsu checkout
jj status

# Plain Git checkout
git add "hosts/$NEW_HOST" flake.nix secrets/user-secrets.yaml
```

Committing is not required for a local build, but the files must be tracked.

### 6. Restore Local Fonts

Nix installs the open fonts declared by Home Manager. The proprietary/local
fonts under `~/.local/share/fonts` are deliberately not committed. In
particular, Stylix and Ghostty expect `TX02 Nerd Font Ret`.

Copy the local font directory from the old machine or encrypted backup:

```bash
nix-shell -p rsync
mkdir -p "$HOME/.local/share/fonts"
rsync -a old-host:"$HOME/.local/share/fonts/" \
  "$HOME/.local/share/fonts/"
fc-cache -f
fc-match "TX02 Nerd Font Ret"
```

Copy only fonts whose licenses permit installation on the new device.

### 7. Restore SSH and GPG Material

Home Manager generates `~/.ssh/config` and `~/.ssh/config.secrets`; do not copy
those generated files. Securely restore the identities that the configuration
references:

- `id_ed25519_sk_yk1`, `id_ed25519_sk_yk1.pub`, and any certificate;
- `id_ed25519_sk_yk2`, `id_ed25519_sk_yk2.pub`, and any certificate;
- `id_ed25519_initramfs` and its public key;
- any other intentionally used identity such as `id_ed25519_pwd`;
- `allowed_signers`, `known_hosts`, and `authorized_keys` where applicable.

The `*_sk_*` private files are key handles for the corresponding FIDO device.
Copy non-resident key handles or recover resident credentials with
`ssh-keygen -K`, then update the configured filenames if necessary.

Restore safe permissions:

```bash
install -d -m 0700 "$HOME/.ssh"
find "$HOME/.ssh" -type f ! -name '*.pub' -exec chmod 0600 {} +
find "$HOME/.ssh" -type f -name '*.pub' -exec chmod 0644 {} +
```

The system SSH server disables password and keyboard-interactive
authentication. Install a working `~/.ssh/authorized_keys` before the first
boot if remote recovery is required. Do not copy `/etc/ssh/ssh_host_*` from a
different machine; the new device must keep its own host identity.

For GPG:

- export public keys in backup mode and import them in restore mode so that
  GnuPG-specific metadata and local signatures are retained;
- export and restore owner trust;
- transfer software-backed private keys only through encrypted media;
- for smartcard/YubiKey-backed keys, import the public keys but leave private
  key material on the token;
- preserve `~/.gnupg/openpgp-revocs.d/` separately in secure offline storage;
- preserve any local GnuPG configuration that is not declared in
  `modules/home/gpg.nix`, such as a custom `dirmngr.conf`.

Home Manager regenerates `gpg.conf`, `gpg-agent.conf`, and `scdaemon.conf` from
`modules/home/gpg.nix`. Card-resident settings remain on the token. After the
switch, import the public keys, insert the token, and run `gpg --card-status`;
GnuPG should recreate the local smartcard key stubs automatically.

Example public-key migration:

```bash
# On the old machine
umask 077
gpg --export-options backup --export > public-keys.gpg
gpg --export-ownertrust > ownertrust.txt

# On the new machine
gpg --import-options restore --import public-keys.gpg
gpg --import-ownertrust ownertrust.txt
gpg --card-status
gpg --list-secret-keys
```

Treat the exported files as sensitive metadata and remove the transfer copies
after verifying the import. A revocation certificate can revoke its
corresponding key, so keep the `openpgp-revocs.d` backup offline and tightly
protected.

### 8. Enroll FIDO/U2F Before the First Switch

The repository enables PAM U2F for login, greetd, and sudo. Enroll at least one
device while the stock generation and password-based sudo still work.

The credential origin must use the final hostname:

```bash
install -d -m 0700 "$HOME/.config/Yubico"

nix --extra-experimental-features 'nix-command flakes' \
  shell nixpkgs#pam_u2f -c \
  pamu2fcfg -u "$USER" \
    -o "pam://$NEW_HOST" -i "pam://$NEW_HOST" \
  > "$HOME/.config/Yubico/u2f_keys"

chmod 0600 "$HOME/.config/Yubico/u2f_keys"
```

Touch the authenticator when prompted. Add a backup authenticator to the same
line with:

```bash
nix --extra-experimental-features 'nix-command flakes' \
  shell nixpkgs#pam_u2f -c \
  pamu2fcfg -n -u "$USER" \
    -o "pam://$NEW_HOST" -i "pam://$NEW_HOST" \
  >> "$HOME/.config/Yubico/u2f_keys"
```

Repeat enrollment for each hostname; a PAM credential enrolled for one
hostname is not automatically valid for another.

### 9. Evaluate and Build

Run evaluation and the host-specific check without updating `flake.lock`:

```bash
cd "$REPO_DIR"

nix --extra-experimental-features 'nix-command flakes' \
  flake check --no-build --no-update-lock-file

nix --extra-experimental-features 'nix-command flakes' \
  build ".#checks.x86_64-linux.${NEW_HOST}-toplevel"

sudo nixos-rebuild build \
  --flake "$REPO_DIR#$NEW_HOST" \
  --option experimental-features "nix-command flakes"
```

Inspect every failure rather than bypassing it. For storage, bootloader,
initrd, kernel, microcode, or GPU changes, install the new configuration for
the next boot instead of switching the running system immediately:

```bash
sudo nixos-rebuild boot \
  --flake "$REPO_DIR#$NEW_HOST" \
  --option experimental-features "nix-command flakes"

sudo reboot
```

Keep the stock generation in the bootloader until the new configuration has
completed several successful boots.

### 10. First-Boot Validation

Before closing the first local session, check:

```bash
hostname
findmnt
swapon --show
systemctl --failed
systemctl status sops-install-secrets.service
systemctl --user status sops-nix.service
systemctl --user status write-ssh-secret-config.service
sudo dmesg | grep -E 'microcode|firmware|amdgpu|nvidia'
```

Then validate the authentication paths:

```bash
# Keep the existing root or local console session open while testing.
sudo -k
sudo true
ssh -T git@github.com
gpg --card-status
fc-match "TX02 Nerd Font Ret"
```

Verify Ethernet, Wi-Fi, Bluetooth, audio, displays, suspend, and any
host-specific GPU or hibernation behavior. For the Desktop, connect monitors
to the motherboard outputs and confirm `nvidia-smi` does not list Niri or
ordinary desktop applications.

### 11. Post-Install Checklist

- Run `sudo tailscale up` and authorize the new Tailscale node.
- Open Syncthing, add the new device to the existing cluster, and verify
  `~/Sync` before accepting large synchronization changes. Preserve the old
  Syncthing configuration only when intentionally preserving the same device
  identity.
- Confirm the SOPS-managed DNS service and generated SSH/mail configuration
  are healthy.
- Restore any remaining application data that is not declarative or
  synchronized.
- Run `sudo fwupdmgr refresh` and `fwupdmgr get-updates`.
- Verify SSH access from another machine before relying on remote-only access.
- Change the repository remote back to SSH if it was cloned over HTTPS.
- Optionally initialize a colocated Jujutsu workspace with
  `jj git init --colocate`.
- Keep the stock `/etc/nixos.stock` backup and old boot generation until the
  migration is proven stable.

### Recovery

If the new generation does not boot, select the previous stock generation in
the bootloader. From a working generation:

```bash
sudo nixos-rebuild switch --rollback
```

From a live installer, mount the filesystems under `/mnt`, enter the system,
and reactivate a known-good generation:

```bash
sudo nixos-enter
NIXOS_INSTALL_BOOTLOADER=1 \
  /run/current-system/bin/switch-to-configuration boot
```

## Common Commands

```bash
# Enter a shell with Nix tooling
nix develop

# Format Nix files
nix fmt

# Evaluate without changing the system
nix flake check --no-update-lock-file

# Build host toplevels
nix build .#checks.x86_64-linux.laptop-toplevel
nix build .#checks.x86_64-linux.desktop-toplevel

# Test or switch the local machine
nh os test
nh os switch

# Update flake inputs
nix flake update
```

The shell aliases `nix-test`, `nix-switch`, `nix-update`, and
`nix-flake-update` wrap the same workflow.

## Documentation

- `docs/BOOTSTRAP.md`: provisioning, recovery, and secret key setup.
- `docs/OPERATIONS.md`: build, test, switch, boot, rollback, and update flows.
- `docs/DECISIONS.md`: input, Home Manager, hardware, and secrets policy.
- `docs/HOSTS.md`: host inventory and machine-specific notes.

## Secrets

Secrets are managed with `sops-nix`. Decrypted values are consumed at runtime
through `/run/secrets` for system services and Home Manager's
`~/.config/sops-nix/secrets` symlinks for user services.

System secrets decrypt with `/root/.config/sops/age/keys.txt`; Home Manager
secrets decrypt with `~/.config/sops/age/keys.txt`.

Do not read decrypted secret files during Nix evaluation. Runtime writer
services generate user files such as SSH and mail configs after `sops-nix`
has decrypted the relevant values.

## Notes

Active app and tool flakes should follow the root `nixpkgs` input when that is
compatible with the upstream flake. Boot-critical or upstream-sensitive flakes
may keep their own `nixpkgs` pin to reduce upgrade risk.

`pkgs.master` is intentionally exposed through the overlay as an emergency
escape hatch when a fix is available on `nixpkgs/master` but has not reached
`nixpkgs-unstable` yet.
