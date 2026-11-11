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
- `lib/apparmor.nix`: shared sensitive-resource rules and inventory schema.
- `hosts/<host>/`: host entrypoint, hardware config, and host facts.
- `modules/core/`: shared NixOS modules.
- `modules/home/`: Home Manager modules.
- `pkgs/`: local packages exposed through the default overlay.
- `tests/flake-checks.nix`: flake checks and AppArmor test host variants.
- `secrets/`: sops-nix encrypted secrets.
- `docs/`: bootstrap, operations, architecture decisions, and host notes.
- `docs/HARDENING.md`: active security posture, strict-control trials, and
  runtime verification.
- `docs/USBGUARD.md`: staged laptop USBGuard tutorial and recovery procedure.
- `docs/MEASURED-BOOT.md`: laptop Secure Boot, measured boot, TPM enrollment,
  and hardware-replacement recovery.
- [Manual upstream workarounds](#manual-upstream-workarounds): local patches,
  compatibility overrides, replacement packages, and their removal criteria.

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

The stock system needs Git for the initial clone and later flake evaluation.
Some pinned package sources, including Niri's Rust dependencies, are fetched
with Git while Nix evaluates the system. `nix-shell -p git` only provides Git
inside the temporary shell, so either keep that shell open through the
migration or enter it again in step 9:

```bash
nix-shell -p git
# Run the remaining commands from the nix-shell prompt.
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

Create `hosts/<new-host>/facts.nix` with the returned value and the device's
CPU target and kernel tuning. The tuning below matches the desktop; the
Framework laptop uses `znver4`, `"300"`, and `lazyRcu = true`:

```nix
{
  hardware = {
    cpuModelId = "REPLACE_WITH_CPUID";
    cpuTarget = "znver5";
    kernel = {
      hzTicks = "500";
      lazyRcu = false;
    };
  };

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

Register the host in `flake.nix`. For a host named `workstation`, add:

```nix
nixosConfigurations = {
  workstation = mkHost { host = "workstation"; };
};
```

Add its build check to the attribute set returned by `tests/flake-checks.nix`:

```nix
workstation-toplevel =
  self.nixosConfigurations.workstation.config.system.build.toplevel;
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

On captive-portal Wi-Fi, run `manage-dns disable` before opening the portal's
HTTP login page, then `manage-dns enable` after signing in. `manage-dns status`
shows the active mode and resolver configuration. Portal mode temporarily uses
the Wi-Fi connection's DNS without DNSSEC or DNS-over-TLS and disconnects
Tailscale if it was running. The normal DNS settings and prior Tailscale state
return when portal mode ends; switching to a different NetworkManager
connection also ends it. The temporary settings live under `/run` and disappear
on reboot.

New files in a Git worktree are invisible to flake evaluation until they are
tracked. Use one of these workflows before building:

```bash
# Colocated Jujutsu checkout
jj status

# Plain Git checkout
git add "hosts/$NEW_HOST" flake.nix tests/flake-checks.nix secrets/user-secrets.yaml
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

#### Sign or Renew SSH Certificates with Proton Pass

Keep the issuing SSH CA private key as an SSH key item in the Proton Pass
vault `SSH CA`. Store its matching public key as `~/.ssh/ssh_ca.pub` on each
host; copy it from the item's public-key field. YubiKey handles, public keys,
and issued certificates stay in `~/.ssh`. The YubiKey private keys remain on
the hardware.

On a new host, authenticate interactively with `pass-cli login`. The CLI uses
the desktop Secret Service keyring. Unlock it before starting the service;
if you configured a CLI session lock, also run `pass-cli session unlock` when
that session is locked.

Start the separate CA signing agent manually:

```bash
systemctl --user start proton-pass-ca-agent.service
systemctl --user status proton-pass-ca-agent.service
env SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/proton-pass-ca/agent.sock" ssh-add -l
ssh-keygen -lf ~/.ssh/ssh_ca.pub
```

Wait until `ssh-add -l` lists the CA and confirm its fingerprint matches the
local CA public key. Starting the systemd service does not wait for the CLI
to fetch the key. For startup errors, inspect
`journalctl --user -u proton-pass-ca-agent.service -n 50`.

The same command signs previously uncertified public keys or replaces their
existing certificates. This example preserves the `clementpoiret` principal
and issues certificates valid for one year, starting five minutes ago to
allow for clock skew:

```bash
env SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/proton-pass-ca/agent.sock" \
  ssh-keygen -U -s ~/.ssh/ssh_ca.pub \
    -I 'clementpoiret@pers' \
    -n clementpoiret \
    -V '-5m:+365d' \
    ~/.ssh/id_ed25519_sk_yk1.pub \
    ~/.ssh/id_ed25519_sk_yk2.pub

ssh-keygen -L -f ~/.ssh/id_ed25519_sk_yk1-cert.pub
ssh-keygen -L -f ~/.ssh/id_ed25519_sk_yk2-cert.pub
systemctl --user stop proton-pass-ca-agent.service
```

`-U` asks the agent to sign with the CA selected by its public key. The
resulting `*-cert.pub` files are public certificates; the CA private key is
not exported to `~/.ssh`. For other identities, change the input public-key
paths and use principals permitted by the destination server. A certificate
principal need not equal the SSH login username when the server explicitly
maps it.

Stop the CA agent after use, including when signing fails. It also stops
after five minutes or when the graphical session ends. It does not start
automatically, change `SSH_AUTH_SOCK`, or participate in agent forwarding.
The ordinary OpenSSH agent retains the destination-constrained YubiKey
identities and host-specific ordering.

After renewal, ordinary SSH connections read the updated certificates from
disk. Refresh the certificates held by the OpenSSH agent with:

```bash
systemctl --user restart ssh-agent.service
```

#### Restore GPG Material

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

Configure both YubiKeys to require a touch for every OpenPGP signature. Insert
one key at a time and repeat this command for each key (it prompts for the
OpenPGP admin PIN):

```bash
ykman openpgp keys set-touch sig on
```

The `on` policy is reversible. The NixOS configuration deliberately does not
change token-resident policy automatically.

After switching, use `ssh desktop-forwarded` from the laptop or
`ssh laptop-forwarded` from the desktop when the remote session needs to sign
commits or access GitHub/GitLab. These opt-in aliases forward the local SSH
agent and the restricted GPG extra socket; ordinary SSH aliases do not. The
forwarded SSH keys are destination-constrained to GitHub and GitLab, so restore
the peer and forge host keys in `~/.ssh/known_hosts` before the first switch.
The user-session `sync-forwarded-gpg-home.service` populates the isolated
`~/.gnupg-forwarded` home. If the smartcard signing stub does not exist when it
runs, insert the card, run `gpg --card-status`, then run
`systemctl --user restart sync-forwarded-gpg-home.service`.

Treat the exported files as sensitive metadata and remove the transfer copies
after verifying the import. A revocation certificate can revoke its
corresponding key, so keep the `openpgp-revocs.d` backup offline and tightly
protected.

### 8. Enroll FIDO/U2F Before the First Switch

The repository enables PAM U2F for login, greetd, and run0's Polkit path.
Enroll at least one device while the stock generation and password-based sudo
still work.

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

This preserves the current user-owned enrollment, so U2F is an authentication
alternative rather than a hardened privilege boundary. Before relying on it
to protect run0, migrate the mapping to a root-owned authfile as described in
[`docs/HARDENING.md`](docs/HARDENING.md#known-audit-gaps).

### 9. Evaluate and Build

Make Git available before evaluating. This is required even after the
repository has been cloned because some package sources are fetched with Git
during evaluation:

```bash
nix-shell -p git
# Run the remaining commands from the nix-shell prompt.

cd "$REPO_DIR"

nix --extra-experimental-features 'nix-command flakes' \
  flake check --no-build --no-update-lock-file

nix --extra-experimental-features 'nix-command flakes' \
  build ".#checks.x86_64-linux.${NEW_HOST}-toplevel"

sudo env "PATH=$PATH" nixos-rebuild build \
  --flake "$REPO_DIR#$NEW_HOST" \
  --option experimental-features "nix-command flakes"
```

The explicit `PATH` preserves the temporary Git package when `sudo` starts
`nixos-rebuild`. Without it, evaluation can fail with `executing "git": No such
file or directory` while fetching a Git dependency.

Inspect every failure rather than bypassing it. For storage, bootloader,
initrd, kernel, microcode, or GPU changes, install the new configuration for
the next boot instead of switching the running system immediately:

```bash
sudo env "PATH=$PATH" nixos-rebuild boot \
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
run0 -- dmesg | grep -E 'microcode|firmware|amdgpu|nvidia'
```

Then validate the authentication paths:

```bash
# Keep the existing root or local console session open while testing.
run0 -- id
ssh -T git@github.com
gpg --card-status
fc-match "TX02 Nerd Font Ret"
```

Verify Ethernet, Wi-Fi, Bluetooth, audio, displays, suspend, and any
host-specific GPU or hibernation behavior. For the Desktop, connect monitors
to the motherboard outputs and confirm `nvidia-smi` does not list Niri or
ordinary desktop applications.

### 11. Post-Install Checklist

- Run `run0 -- tailscale up` and authorize the new Tailscale node.
- Open Syncthing, add the new device to the existing cluster, and verify
  `~/Sync` before accepting large synchronization changes. Preserve the old
  Syncthing configuration only when intentionally preserving the same device
  identity.
- Confirm the SOPS-managed DNS service and generated SSH/mail configuration
  are healthy.
- Restore any remaining application data that is not declarative or
  synchronized.
- Run `run0 -- fwupdmgr refresh` and `fwupdmgr get-updates`.
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
nixos-rebuild switch --rollback --elevate=run0
```

From a live installer, mount the filesystems under `/mnt`, enter the system,
and reactivate a known-good generation:

```bash
sudo nixos-enter
NIXOS_INSTALL_BOOTLOADER=1 \
  /run/current-system/bin/switch-to-configuration boot
```

## Rhizome VPS management

Only the laptop enrolls in `wg-rhizome`; the existing Opercord `wg0` and personal Tailscale connections are independent. The laptop's VPS tunnel is off at boot and is never started automatically by SSH:

```sh
run0 -- systemctl start wg-quick-wg-rhizome.service
run0 -- wg show wg-rhizome
ssh internalvps
run0 -- systemctl stop wg-quick-wg-rhizome.service
```

`hosts/laptop/internal-vps.nix` routes only `10.78.0.1/32` to the VPS and pins its SSH host identity. The SSH alias binds to the tunnel and disables connection multiplexing, so it cannot connect when the tunnel is stopped. DNS/default routes are unchanged. Do not enable the tunnel unit.

The root-owned private key must exist at `/etc/wireguard/wg-rhizome.key` with mode `0600` before starting the service. Generate it on this device, back it up directly in your password manager, and enroll only its public key. Never reuse the Opercord key. Follow the server repository's `README.md` for enrollment/revocation and `docs/operations.md` for deployment, timed network rollback, and recovery. The VPS has no Tailscale management path.

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

# Test or switch the local machine through run0
nixos-rebuild test --flake ".#$NEW_HOST" --elevate=run0
nixos-rebuild switch --flake ".#$NEW_HOST" --elevate=run0

# Update flake inputs
nix flake update
```

The shell aliases `nix-test`, `nix-switch`, `nix-update`, and
`nix-flake-update` wrap the same workflow.

## Manual Upstream Workarounds

This is the cleanup inventory for local fixes layered over upstream software,
Nixpkgs, and flake modules. It includes source patches, dependency overrides,
test exceptions, runtime adapters, and replacement packages—not just the fixes
that most recently failed CI. Add or update an entry whenever introducing,
changing, or removing one of these adaptations.

The implementation links are the source of truth. Upstream issue/PR links are
included where recorded in the code; an unlinked entry does **not** mean an
upstream report exists. This inventory records what is carried locally, not a
claim that upstream's latest branch still lacks every fix. Compare the
**locked** versions with the upstream change before removing anything. Native
dependencies remain necessary after a packaging fix; remove our override only
when the upstream package declares them itself.

### Package and build compatibility fixes

| Fix and implementation | What is carried locally | Removal criteria and verification |
| --- | --- | --- |
| Hylki SQLite — [flake.nix](flake.nix), `pkgs-flake.hylki` | Adds system SQLite because the Rust build hooks select it instead of the bundled library. | Drop the dependency override when the Hylki flake supplies SQLite. Build Hylki with its tests; evaluation alone cannot prove native linking. |
| Lumen native libraries — [flake.nix](flake.nix), `pkgs-flake.lumen` | Adds libgit2 and zlib alongside upstream's OpenSSL. `libgit2-sys` 0.18 needs libgit2 ≥1.9.2 and <1.10 when vendoring is disabled. | Drop the override when Lumen's flake declares compatible native libraries. Check the crate's version range with `pkg-config`, then build Lumen. Do not bypass `LIBGIT2_NO_VENDOR` instead. |
| Rayburst SQLite — [flake.nix](flake.nix), `customOverlays` | Adds SQLite to Nixpkgs' Rayburst package; otherwise the final Rust link fails with `cannot find -lsqlite3`. | Remove when the selected Nixpkgs package declares SQLite. Verify the native link and build Rayburst, including its launcher/fixup phases. |
| Khal structured attributes — [flake.nix](flake.nix), `customOverlays` | Changes `sphinxBuilders` from an array to the scalar `"html man"` expected by `sphinxHook`. | Remove when Nixpkgs' Khal/Sphinx integration supports the supplied value under structured attributes. Build Khal's documentation and tests. |
| Niri host-library rebuild — [host-cpu-packages.nix](modules/core/host-cpu-packages.nix) | Builds the pinned source through the host's `niri-unstable` overlay rather than using the input flake's independently built package. This avoids a glibc mismatch with Mesa loaded from `/run/opengl-driver`. | Retire the package-set adapter only when the replacement uses a compatible host runtime. Run `niri-mesa-runtime`; a successful host build is insufficient. CPU optimization itself is intentional policy. |
| Niri libdisplay-info 0.2 — [flake.nix](flake.nix), [local ABI package](pkgs/libdisplay-info_0_2/default.nix) | Restores the 0.2 ABI required by pinned Niri after Nixpkgs removed that package attribute, using the host toolchain. | Remove the overlay and local package together when the selected Niri source supports an available ABI. Build both Niri variants and run `niri-mesa-runtime`. |
| Host-optimized build executables — [host-cpu-packages.nix](modules/core/host-cpu-packages.nix), [Niri config validation](modules/home/niri.nix) | Disables build/install tests for optimized Rust Niri/Herdr and adapts Ghostty's `-Dcpu` flag. Niri completions and config validation use upstream's generic cached binary with its original locked package set, not a locally compiled baseline. Generic runners may not execute host-specific instructions. | Remove generator/test accommodations only when upstream builders separate build-machine tools from host binaries, or checks run on capable machines. Run `niri-build-tools` to verify matching source/patches/features, config validation, and all completion generators. Keep the chosen CPU targets; Ghostty's install check is **not** disabled. |
| Bridge ELF rewriting — [protonmail-bridge/default.nix](pkgs/protonmail-bridge/default.nix) | Pins package-local patchelf 0.15.2 because 0.19.2 corrupts the vendor Go executable and causes a startup segfault. | Remove the pin only after rewriting the same vendor binary with the replacement patchelf and passing Bridge's runtime version install check. |
| Zotero's end-of-life Gecko runtime — [system.nix](modules/core/system.nix), [security rationale](docs/HARDENING.md#intentional-compatibility-choices) | Permits exactly `firefox-esr-140-bin-unwrapped-140.17.0esr`, required by Zotero 10's Nixpkgs runtime. This is an explicit security exception, not a general insecure-package allowance. | Remove when Zotero supports a maintained runtime. Match `GECKO_VERSION_LINUX` in Zotero's source, then build Zotero, both host toplevels, and `apparmor-policy-parser`. |

### Herdr source, runtime, and test adaptations

The local [Herdr App](pkgs/herdr-app/default.nix) and
[Herdr Core](pkgs/herdr-core/default.nix) packages are adapted from
[Nixpkgs PR #581031](https://github.com/NixOS/nixpkgs/pull/581031).
The older `herdr` flake input is a separate package: updating it does not remove
the App/Core workarounds. Replacing the local packages requires checking every
row below, not just matching their version numbers.

| Fix and implementation | What is carried locally | Removal criteria and verification |
| --- | --- | --- |
| Zig/Rust unwinding — [App](pkgs/herdr-app/default.nix), [Core](pkgs/herdr-core/default.nix) | Disables Ghostty VT's bundled compiler and UBSan runtimes to avoid overlapping unwind frames when linking with Rust. | Remove both substitutions when the bundled Ghostty build handles Rust linking correctly. Build and run App and Core, not just their Zig dependency fetches. |
| Core restart-lock lifetime — [source patch](pkgs/herdr-core/restart-lock-lifetime.patch), [regression fixture](pkgs/herdr-core/test-restart.py) | Moves ownership of the startup lock inside the server future so it is released before runtime teardown closes clients and triggers a replacement process. | Remove the patch when upstream releases the lock in the same safe order. Keep running the deterministic delayed-close restart install check against the replacement. |
| Core build identity — [Core](pkgs/herdr-core/default.nix), `env` | Requests a GNU build ID and strips debug sections that otherwise contain per-build Zig cache paths. | Remove only when upstream packaging preserves a stable identity for byte-identical builds without these flags. Verify reproducibility and the core's restart/update identity behavior. |
| Core helper lookup — [Core](pkgs/herdr-core/default.nix), `postPatch` | Replaces assumed `curl`, `sha256sum`, and archive-extractor commands with declared store executables; uses `bsdtar`. | Remove substitutions when upstream packaging resolves these tools reliably on NixOS. Exercise release download, checksum verification, and extraction. |
| Core remote installation — [Core](pkgs/herdr-core/default.nix), `machines.rs` substitution | Prevents copying the locally linked Nix executable to a same-platform remote machine that lacks its `/nix/store` dependencies; chooses the portable release build instead. | Remove when upstream can distinguish and deploy a portable binary or its complete runtime closure. Test a clean remote without the local store paths. |
| App desktop openers — [App](pkgs/herdr-app/default.nix), `src/links.rs` and vendored Linux platform substitutions | Uses the declared `xdg-open` for links and platform open requests. | Remove when upstream's Nix package supplies a reliable opener path. Test opening a file and a URL from the graphical application. |
| App Core discovery — [App](pkgs/herdr-app/default.nix), `src/core_bin.rs` | Adds the packaged Core's `bin` directory after the system profile in the discovery search. | Remove when upstream packaging reliably locates its compatible Core. Test startup without an unrelated `hc` on `PATH`. |
| App update instructions — [App](pkgs/herdr-app/default.nix), [upstream issue #136](https://github.com/herdrdev/herdr-app/issues/136) | Replaces the source-build instruction to update with Git with a Nix-managed update message. | Remove when the upstream package identifies Nix-managed installations and shows correct instructions. Check the Settings UI. |
| Sandboxed fixtures — [App](pkgs/herdr-app/default.nix), [Core](pkgs/herdr-core/default.nix) | Rewrites `/var/tmp` to `$TMPDIR`; supplies real fixture tools instead of `/bin` and `/usr/bin` assumptions. App's remote-shell fixtures get local Bash/printf/sh paths without leaking them into generated remote commands; App's `/bin/test` is replaced; Core's installer fixtures get their own tool path and its manifest shebang is patched. | Remove each substitution when upstream tests honor the sandbox's temp directory and declared tools. Run both suites; retain the distinction between local fixture executables and portable remote command strings. |
| App render-test environment — [App](pkgs/herdr-app/default.nix), `checkType` / `preCheck` | Uses debug test builds for GPUI bounds assertions, explicit Fontconfig fonts, Mesa software Vulkan, and test-time dynamic-library paths while keeping the installed binary in release mode. | Remove accommodations only when upstream's tests configure these requirements themselves. Verify actual render/pixel tests and the installed release binary. |
| App runtime library loading — [App](pkgs/herdr-app/default.nix), `postFixup` | Adds RUNPATH entries for dlopened OpenGL, Vulkan, and Wayland libraries after fixup would otherwise discard them. Avoids exporting `LD_LIBRARY_PATH` into every terminal. | Remove when upstream packaging retains the needed runtime search paths. Test the real Wayland/Vulkan application without a development shell. |
| App test exceptions — [App](pkgs/herdr-app/default.nix), `checkFlags` | Skips `mods::lifecycle_tests::close_starts_native_work_before_releasing_the_copy` (scheduler race) and `third_party_notices_are_current_and_complete` (source substitutions invalidate its fingerprint). | Remove the first skip when the fixture is reliable; remove the second when notices validation accounts for packaged source changes or those changes disappear. Re-enable and run each test before deleting its exception. |
| Core network-dependent tests — [Core](pkgs/herdr-core/default.nix), `checkFlags` / `preCheck` | Skips `a_box_without_hc_gets_this_one_when_you_say_yes` and `a_machine_reached_through_any_command_works_like_one_over_ssh` because the portable-release installation path needs network access; uses upstream's slow-runner timeout settings. | Remove skips when tests can supply an offline release fixture or no longer download a core. Re-enable in the Nix sandbox. Review timeout settings separately; they are not source fixes. |

Normal package mechanics such as locked Cargo/Zig dependencies, desktop files,
licenses, and installing only the intended agent skill are not bugs to delete
in isolation. They must be preserved by an upstream package replacing these
local derivations.

### Desktop and service integration

| Fix and implementation | What is carried locally | Removal criteria and verification |
| --- | --- | --- |
| Niri session environment — [niri.nix](modules/home/niri.nix), `importEnvironmentCommand` / `niriPackage` | Filters environment-variable names before importing them into the systemd user manager; patches `niri-session` and uses the same command at startup. | Remove the wrapper and redundant startup import when upstream session startup safely imports the needed environment. Verify UWSM login and D-Bus/systemd-activated desktop applications. |
| DMS GTK ownership — [stylix.nix](modules/home/stylix.nix), [gtk.nix](modules/home/gtk.nix) | Disables Stylix's GTK colors and Home Manager's GTK4 theme generation so DMS can replace writable `gtk.css` files instead of refusing store-backed symlinks. | Remove ownership overrides only when DMS/Stylix/Home Manager support the same file lifecycle without clobbering each other. Run `dms-application-theming` and a Home Manager activation/theme switch. |
| DMS Qt palette application — [gtk.nix](modules/home/gtk.nix), `configureQtTheme` / packaged `qt.sh` | Replaces DMS's Qt action with writable qt5ct/qt6ct updates, Fusion, and native `colors/matugen.conf` palettes; makes legacy read-only files writable. Disables Stylix Qt ownership rather than installing conflicting symlinks. | Remove the replacement script and activation hook when DMS produces standard Qt5/Qt6 palettes and handles existing files safely. Test both probes in `dms-application-theming`; a KDE-only palette is not sufficient. |
| DMS Home Assistant plugin imports — [gtk.nix](modules/home/gtk.nix), `extraQtPackages` | Adds QtWebSockets to the DMS package's launcher/import closure, not merely `home.packages`. | Remove when the selected DMS/plugin packaging exports that QML dependency itself. Load the Home Assistant plugin through the packaged DMS launcher. |
| Global shortcuts outside GNOME — [wayland.nix](modules/core/wayland.nix), [local portal](pkgs/niri-shortcuts-portal/default.nix), [Niri bindings](modules/home/niri.nix) | Implements a local GlobalShortcuts backend and presses application-bound IDs from Niri; GNOME's provider requires GNOME Shell. | Retire the backend and activation bindings when an upstream portal supports the same applications under Niri. Verify Ghostty's Alt+T toggle, D-Bus activation, and session lifetime. Keep GNOME screen sharing and the Secret portal. |
| Ghostty portal reconnection — [ghostty.nix](modules/home/ghostty/ghostty.nix), `ghostty-global-shortcuts.conf` | Reloads Ghostty after the portal frontend restarts because the old sessions are lost and Ghostty otherwise does not bind them again. | Remove when Ghostty/portal integration automatically rebinds after frontend restarts. Restart the frontend and verify the existing quick-terminal shortcut without restarting Ghostty. |
| AppArmor startup serialization — [apparmor.nix](modules/core/apparmor.nix), `apparmor.serviceConfig` | Replaces Nixpkgs' per-policy parser calls with batched calls per enforcement mode before `sysinit.target`, including reload cleanup. Complain-mode compilation cannot rely on the policy cache. | Remove the unit overrides when Nixpkgs batches equivalent loads/reloads efficiently. Verify boot timing, all profile modes, `apparmor-policy-parser`, and `apparmor-vm`; do not disable enforcement to improve timing. |
| Bubblewrap profile integration — [apparmor.nix](modules/core/apparmor.nix), `bubblewrapProfile` / `claudeBubblewrapProfile` | Rewrites upstream's `/usr/bin/bwrap` attachment to the exact Nix executable and derives named Claude-specific transitions/capability rules. | Replace only with upstream Nix-aware profiles offering the same confinement and working sandbox transitions. Run the AppArmor VM and real agent sandbox checks. This is security integration, not permission to drop the profiles. |
| Syncthing and directory setgid — [laptop/default.nix](hosts/laptop/default.nix), `RestrictSUIDSGID` | Disables only this service restriction because Syncthing preserves setgid directory bits during chmod and systemd otherwise rejects it with `EPERM`. | Remove when Syncthing/systemd can preserve existing directory permissions with the restriction enabled. Test real synchronization of a setgid directory; retain AppArmor, writable-path restrictions, and `NoNewPrivileges`. |
| Markdown formatter packaging — [helix.nix](modules/home/helix.nix), Markdown `formatter` | Uses `uvx` with GFM, footnote, and MyST plugins instead of the broken `mdformat.withPlugins` route. The downloads are not pinned. | Replace with a working Nix-packaged formatter plus the same plugins. Test stdin formatting and all three syntaxes; then remove the network-backed `uvx` invocation. |
| zk notebook symlinks — [zk.nix](modules/home/zk/zk.nix), `configuredDir` / `ZK_NOTEBOOK_DIR` | Keeps a host-selectable notebook directory while the recorded upstream symlink issue is unresolved; the comment records no PR number. | Review the directory indirection when the pinned zk handles the symlinked notebook correctly. Test indexing, links, and the language server before simplifying it. |
| ROCm dynamic libraries — [laptop/rocm.nix](hosts/laptop/rocm.nix), [ml-rocm shell](flake.nix), [ML runbook](docs/ML-ROCM.md) | Wraps `rocm-smi` with a libdrm search path and supplies an explicit native/ROCm library path for the Python wheel environment; provides `/opt/rocm` for tools expecting that layout. | Replace adapters when upstream Nix packages/wheels locate the same runtime libraries correctly. Verify `rocm-smi` and actual PyTorch/JAX GPU operations. Python-wheel support and the ROCm prefix are integration choices, not necessarily upstream bugs. |

### Boot, hardware, and manual operating procedures

| Fix and implementation | What is carried locally | Removal criteria and verification |
| --- | --- | --- |
| Lanzaboote protected-boot retention pin — [flake.nix](flake.nix), [flake.lock](flake.lock) | Pins upstream `4b983330` because v1.2.0 predates protected-system support and retention of the booted bootloader's measurements. | Replace with a tagged release containing [protected-system support](https://github.com/nix-community/lanzaboote/commit/c57a9234747eea6fe498d0eb601583f7ba378f06) and [booted-measurement protection](https://github.com/nix-community/lanzaboote/commit/d6c805ed883dfa23a5e4c032101913d9bcb41467). Run `lanzaboote-historical-retention` and follow the measured-boot runbook for live validation. The version string alone still reports 1.2.0. |
| Retired Lanzaboote specialisation — [bootloader.nix](modules/core/bootloader.nix), [source patch](modules/core/lanzaboote-drop-latest-nixos.patch) | Skips `latest-nixos` still embedded in retained generations' `boot.json`, allowing its obsolete boot entries and PCR measurements to be collected. | Remove after no retained/bootable generation contains that specialisation, or upstream provides equivalent safe filtering. Run `lanzaboote-historical-retention` and verify a real bootloader install. Keep the separate PCR 4 alternative-budget assertion. |
| TPM enrollment limitations — [measured-boot runbook](docs/MEASURED-BOOT.md#configure-measured-boot-and-tpm-unlock) | Manually enrolls both laptop LUKS volumes with TPM plus PIN rather than enabling Lanzaboote's single-device, no-PIN automatic enrollment. | Replace the manual procedure only when upstream supports both volumes and the required PIN/recovery semantics. Host builds cannot verify live TPM policy updates or recovery. |
| Framework panel self-refresh — [laptop/default.nix](hosts/laptop/default.nix), `options.boot.kernelParams.apply`; [host notes](docs/HOSTS.md) | Filters nixos-hardware's `amdgpu.dcdebugmask=0x10` parameter while preserving the other inherited parameters. | Remove the filter if upstream stops adding the parameter and the desired command line is unchanged. Verify AC/battery display behavior and suspend/resume; restore the upstream workaround if hangs return. |
| Shutdown timeout — [system.nix](modules/core/system.nix), `DefaultTimeoutStopSec` | Caps the system manager's default service stop timeout at 10 seconds to avoid getting stuck at shutdown. No particular upstream defect is recorded. | Treat as a local compatibility policy, not a confirmed upstream patch. Identify the blocking service and test clean shutdown/data persistence before reverting to the upstream timeout. |

The `latest-nixos` filter is still required while retained desktop generations
contain that specialisation. The `lanzaboote-historical-retention` fixture uses
a temporary ESP to verify removal of its images and PCR predictions while
keeping an older protected generation within the four-generation limit. This
does not exercise a live TPM policy update; see the
[measured-boot runbook](docs/MEASURED-BOOT.md#configure-measured-boot-and-tpm-unlock).

### Local replacement packages, release pins, and external forks

These are tracked alongside bug fixes because they also carry maintenance
burden. Their existence alone does not establish an upstream bug. Replace them
only when an upstream package provides the required behavior; do not remove
normal Nix packaging just because a vendor release is newer.

| Package / implementation | Locally maintained behavior | Retirement gate |
| --- | --- | --- |
| Herdr App and Core — [App](pkgs/herdr-app/default.nix), [Core](pkgs/herdr-core/default.nix), [PR #581031](https://github.com/NixOS/nixpkgs/pull/581031) | Separate source packages, locked Rust/Zig dependencies, runtime integration, and the adaptations listed above. | Adopt maintained upstream Nixpkgs packages or upstream flakes that preserve those fixes and checks, then remove the corresponding local package directories/update plumbing. |
| Hylki flake — [input and override](flake.nix), [external packaging repository](https://github.com/clementpoiret/hylki-flake) | Uses separately maintained Nix packaging for Hylki, plus the SQLite adaptation in this inventory. | Replace when maintained upstream packaging is equivalent. Removing the input must also update its package consumers, CI targets, and cache roots. |
| CachyOS kernel fork — [flake input](flake.nix), [kernel module](modules/core/hardware.nix), [external release branch](https://github.com/clementpoiret/nix-cachyos-kernel/tree/release), [kernel notes](docs/KERNEL.md) | Carries LLVM module build fixes and post-strip external-module signing with `.ko.cer` output; uses the fork's independent pinned Nixpkgs and published cache. | Change inputs only when the replacement preserves module build flags, signing/certificates, and cache compatibility. Do not drop `kernelModuleSignOverride` merely because a kernel builds. |
| Brave builder and signed release pins — [builder selection](pkgs/default.nix), [exported package](flake.nix), [package](pkgs/brave/default.nix), [updater](pkgs/update-brave.py) | Reuses the builder restored in `nixpkgs-master` with host libraries, overrides the vendor version/source, verifies signed checksums, and replaces Nixpkgs' update script with local pin management. | Drop the master-builder detour when root Nixpkgs supplies a suitable builder. Retire the local package/updater only if upstream also preserves the required release tracking, signature verification, runtime libraries, and install check. |
| Proton Mail and Pass desktop — [Mail](pkgs/protonmail-desktop/default.nix), [Pass](pkgs/proton-pass/default.nix), [updater](pkgs/update-proton.py) | Maintains stable/beta vendor pins; rewrites Electron resource lookup for Nixpkgs' Electron. Pass unpacks `.node` modules and patches libxkbcommon/libgcc dependencies. Matching the system Electron also keeps AppArmor execution rules applicable. | Replace with upstream packages preserving channels, resource paths, native modules, and confinement. Run Pass's ASAR-resolved native-module install check and launch both applications. |
| Proton Bridge vendor backend — [package](pkgs/protonmail-bridge/default.nix), [updater/signature verification](pkgs/update-proton.py) | Installs only the authenticated vendor CLI backend, avoiding the launcher's mutable updater; retains the package-local patchelf fix listed above. | Replace only with an equivalently verified, Nix-managed backend. Keep the correct signing feed/key handling and runtime version check; do not restore mutable self-updates accidentally. |
| Proton Pass CLI — [package](pkgs/proton-pass-cli/default.nix) | Packages the official binary with keyutils/libgcc and disables its update check with `PROTON_PASS_NO_UPDATE_CHECK`. | Replace when upstream packages the required CLI version/runtime dependencies and Nix-managed update behavior. Agent socket separation remains an independent security decision. |
| Logseq AppImage and CLI — [package](pkgs/logseq-appimage/default.nix), [consumer](modules/home/packages.nix) | Uses the vendor payload because plugins are broken in the Nixpkgs build; patches the interpreter, launches directly against an immutable FHS library tree without runtime Bubblewrap mounts/ldconfig, fixes desktop/URI handling, and extracts CLI/worker/skill files into a working relative layout. | Replace when upstream supports plugins, GUI, `logseq://` links, CLI/skill commands, and confinement without the custom launcher. Run `apparmor-application-smoke` and real GUI/CLI checks. |
| Collabora binary runtime — [package](pkgs/collabora-desktop-bin/default.nix), [package notes](pkgs/collabora-desktop-bin/AGENTS.md) | Repackages compatible pinned Flathub app/KDE/Mesa file trees, explicitly configures OSTree's TLS CA path, and supplies a Bubblewrap FHS runtime, host fonts/sockets, graphics paths, and corrected desktop entry without a Flatpak runtime service. | Replace with maintained upstream packaging that renders real documents on Wayland and preserves these integrations. A `--version` check or Qt `offscreen` launch is insufficient. |
| Collabora font-cache isolation — [package](pkgs/collabora-desktop-bin/default.nix), `XDG_CACHE_HOME` | Scopes its cache like Flatpak: the bundled Fontconfig misreads newer host caches and otherwise renders blank UI text. | Remove the local implementation only if the replacement safely isolates caches or demonstrably reads the host format correctly. Run `collabora-font-cache` for default and custom cache roots, then verify document rendering. |
| SoftMaker Office release override — [packages.nix](modules/home/packages.nix), `softmakerOffice` | Pins `officeVersion` to version `1504`, the selected edition, and a local source hash. This is a release selection, not a recorded upstream defect. | Drop the override when the desired Nixpkgs version/edition matches. Verify startup and document handling before replacing the selected binary. |

### Dormant, command-scoped, and already-resolved items

- **AMD microcode SHA bypass:** `microcode.amd_sha_check=off` is commented out
  in both [desktop](hosts/desktop/default.nix) and
  [laptop](hosts/laptop/default.nix). It is **not an active workaround**.
  Remove the stale workaround notes when the locked ucodenix blob/kernel
  combination passes validation and the loaded revision is confirmed; see
  [hardening choices](docs/HARDENING.md#intentional-compatibility-choices).
- **AMD S/G display bypass:** `amdgpu.sg_display=0` is commented out in
  [laptop/default.nix](hosts/laptop/default.nix), not applied. Retire the
  rollback hint only after sustained display/suspend validation on the
  replacement kernel/firmware stack.
- **JAX gfx identity:** the [ROCm runbook](docs/ML-ROCM.md#jax) uses
  `HSA_OVERRIDE_GFX_VERSION=11.0.0` for the JAX validation command because the
  recorded stack rejects `gfx1102`. It is **not** a global shell setting.
  Remove that command override when the selected JAX/ROCm stack supports the
  native GPU; retest real computation without changing PyTorch's detection.
- **Linkctl zstd:** the local dependency override has already been removed.
  [Linkctl commit `35c3d970`](https://github.com/clementpoiret/linkctl/commit/35c3d9709e9cbe11d23a6240fed019f2aa681924)
  fixes its flake and devenv upstream, and [flake.lock](flake.lock) pins that
  fix. [program.nix](modules/core/program.nix) now consumes the unmodified
  package; do not recreate the workaround when updating the pin.

### What is not an upstream-removal candidate

CPU targets, [scheduler/X3D tuning](hosts/desktop/performance.nix), GPU routing,
[sensor/module selections and webcam defaults](hosts/laptop/default.nix),
[device access rules](modules/features/development-hardware.nix),
[EasyEffects startup policy](modules/home/easyeffects/easyeffects.nix),
[OAuth-enabled isync](modules/home/aerc.nix), firmware certificate retention,
the PCR alternative budget, hibernation compatibility, and matching the CachyOS
binary cache are intentional system choices. They are not temporary bug fixes
just because they override a module default.

Likewise, the [agent container guards](pkgs/agent-container-tools/default.nix),
local AppArmor policy/closure rules, exact helper-package paths, host-specific
Bridge certificate pins in [Thunderbird](modules/home/thunderbird.nix),
secrets-only [GNOME Keyring](modules/home/niri.nix), and separate constrained
[SSH/Proton CA agents](modules/home/ssh.nix) are security design. The
`wrapAgent` PATH/`HERDR_AGENT` additions in [flake.nix](flake.nix) integrate those
tools rather than patching a vendor defect. Do not delete these wholesale in
response to an unrelated upstream update. CI job sequencing, curated cache
roots, signature-verifying updaters, and regression checks are repository
infrastructure, not vendor bugs.
The `batdiff is broken` comment in [bat.nix](modules/home/bat.nix) does not
disable `batdiff`; it is not an implemented workaround to remove.

### Retiring a workaround safely

1. Identify the upstream change and the first locked version containing it.
   Verify the implementation, not just the release number; record a real issue
   or PR link when available.
2. Remove the specific patch, dependency override, test skip, or adapter. Keep
   unrelated package policy, confinement, and runtime dependencies intact.
3. Run the row's targeted build/runtime test. `nix flake check --no-build`
   proves evaluation only; it did not catch the SQLite/libgit2 linker failures.
4. Build the affected applications and both host toplevels in CI, plus the
   relevant shared/runtime checks. Boot/TPM/display changes additionally need
   the documented boot-first and live hardware validation.
5. Update this inventory and `AGENTS.md` in the same change. Delete obsolete
   local package/update plumbing only when no consumers remain; keep useful
   behavioral regression tests rather than removing them with the workaround.

## Documentation

- `docs/BOOTSTRAP.md`: provisioning, recovery, and secret key setup.
- `docs/OPERATIONS.md`: build, test, switch, boot, rollback, and update flows.
- `docs/DECISIONS.md`: input, Home Manager, hardware, and secrets policy.
- `docs/HOSTS.md`: host inventory and machine-specific notes.
- `docs/HARDENING.md`: hardening invariants, strict trials, verification, and
  recovery.
- `docs/APPARMOR.md`: AppArmor modes, profile testing, policy changes, and
  rollout.
- `docs/USBGUARD.md`: disabled-by-default laptop USBGuard rollout.
- `docs/MEASURED-BOOT.md`: laptop measured-boot deployment, TPM enrollment,
  and recovery lifecycle.

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

Active app and tool flakes follow the root `nixos-unstable` input. CachyOS keeps
its own pinned nixpkgs input to match its published kernel cache.

`pkgs.stable` and `pkgs.master` remain available through the overlay as explicit
per-package escape hatches. Brave borrows its builder from master but is built
with the root package set's runtime libraries; it is not a whole-package-set
fallback. See `docs/DECISIONS.md` for flake-input fallbacks and the AppArmor
helper-path requirement.
