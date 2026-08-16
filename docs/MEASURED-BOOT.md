# Secure Boot, Measured Boot, and TPM Unlock

This runbook covers the laptop's migration to Lanzaboote measured boot with
TPM2-and-PIN unlocking for both LUKS2 containers. It also covers normal
operation, firmware changes, TPM clearing, motherboard replacement, and
recovery.

The intended steady state is:

```text
Daily unlock:       laptop TPM + PIN + accepted PCR 0/4/7 policy
Emergency unlock:   a unique offline recovery key for each LUKS volume
Removed afterward:  the old shared LUKS passphrase
```

LUKS keyslots are alternatives. A recovery key remains an `OR` path around the
TPM policy, which is intentional: it is high entropy, unique per volume, and
kept away from the laptop. TPM plus PIN is an `AND` policy inside the TPM
enrollment.

Measured boot and `systemd-pcrlock` are still experimental. Never rely on the
TPM slot as the only unlock method.

## Repository state and ownership

The shared bootloader module already:

- imports Lanzaboote and disables the normal systemd-boot installer;
- keeps Secure Boot signing keys in `/var/lib/sbctl`;
- automatically prepares owner keys for firmware enrollment while retaining
  Microsoft keys; and
- installs `sbctl`.

The laptop additionally retains the Framework firmware's built-in
certificates. Keep
`boot.lanzaboote.autoEnrollKeys.includeFirmwareBuiltinKeys = true`; removing
those certificates can break firmware-provided functionality.

Measured boot and TPM LUKS unlock are laptop policy. Put their settings in
`hosts/laptop/default.nix`, not the shared bootloader module or generated
`hosts/laptop/hardware-configuration.nix`.

The outer LUKS2 devices are:

```bash
ROOT_LUKS=/dev/disk/by-uuid/4b1c13e3-af35-4286-b534-674ca54de75a
HOME_LUKS=/dev/disk/by-uuid/5ee5fadf-22f0-4a53-a33d-63e22931255f
```

Do not enroll the inner Btrfs UUIDs `caf8fdb0-...` or `7556b3b1-...`.

## Security roles

- Secure Boot makes the firmware accept only trusted signed boot code. It
  protects the writable, unencrypted ESP from arbitrary boot-code replacement.
- PCR 0 measures firmware code, PCR 4 covers the bootloader and Lanzaboote
  stub, and PCR 7 measures Secure Boot policy and authorities. Lanzaboote's
  stub verifies the embedded kernel, initrd, and command-line hashes.
- `systemd-pcrlock` maintains an allow-list policy for retained NixOS boot
  generations, avoiding manual TPM re-enrollment after ordinary rebuilds.
- The TPM releases each random LUKS unlock key only for an accepted policy and
  the correct PIN.
- The recovery key bypasses TPM, PIN, and PCR policy. Its off-machine storage
  is therefore part of the security boundary.

This protects a powered-off laptop. It does not make normal suspend equivalent
to power-off: mounted LUKS volume keys remain available to the running kernel.
Hibernation remains protected because this host's swapfile is on encrypted
root storage.

## Phase 1: prepare recovery material

Do not change a keyslot until a current NixOS installer and encrypted offline
storage are available.

Set the device variables in each new shell:

```bash
ROOT_LUKS=/dev/disk/by-uuid/4b1c13e3-af35-4286-b534-674ca54de75a
HOME_LUKS=/dev/disk/by-uuid/5ee5fadf-22f0-4a53-a33d-63e22931255f
```

### Verify LUKS2 and TPM support

```bash
for device in "$ROOT_LUKS" "$HOME_LUKS"; do
  run0 -- cryptsetup luksDump "$device" | sed -n -E '/^(Version|UUID):/p'
done

run0 -- systemd-cryptenroll --tpm2-device=list
/run/current-system/systemd/lib/systemd/systemd-pcrlock is-supported
```

Both volumes must report `Version: 2`, the TPM listing must show a usable
device such as `/dev/tpmrm0`, and the support check must print `yes`. Stop if
any check fails. Converting LUKS1 is an offline metadata migration and is not
part of this runbook.

### Back up both LUKS headers

A header backup protects LUKS metadata and keyslots, not filesystem data.

```bash
run0 -- install -d -m 0700 /root/luks-header-backups

run0 -- cryptsetup luksHeaderBackup "$ROOT_LUKS" \
  --header-backup-file /root/luks-header-backups/root.pre-tpm.img
run0 -- cryptsetup luksHeaderBackup "$HOME_LUKS" \
  --header-backup-file /root/luks-header-backups/home.pre-tpm.img
run0 -- chmod 0600 \
  /root/luks-header-backups/root.pre-tpm.img \
  /root/luks-header-backups/home.pre-tpm.img
```

Copy the images to separately encrypted offline storage and verify the copy.
An old header backup plus a passphrase valid when it was created can restore
that removed passphrase, so retire these pre-migration images after verified
post-migration backups exist.

### Add and test unique recovery keys

Enroll a different generated recovery key into each volume. Label and record
each key before continuing; do not keep the only copy on this laptop.

```bash
run0 -- systemd-cryptenroll --recovery-key "$ROOT_LUKS"
run0 -- systemd-cryptenroll --recovery-key "$HOME_LUKS"
```

Test each key without opening another mapping:

```bash
run0 -- cryptsetup open \
  --test-passphrase \
  --disable-external-tokens \
  --tries 1 \
  "$ROOT_LUKS"

run0 -- cryptsetup open \
  --test-passphrase \
  --disable-external-tokens \
  --tries 1 \
  "$HOME_LUKS"
```

Enter the corresponding recovery key at each prompt. Keep the old shared
passphrase until the entire TPM path has survived a real reboot.

### Back up the Secure Boot PKI

`/var/lib/sbctl` contains private platform signing keys. Copy the directory to
encrypted offline storage without putting it in the Nix store or this
repository. Verify restrictive permissions on both the live and backup copy.

Losing the PKI does not immediately make an already signed generation
unbootable while its public key remains enrolled in firmware, but it prevents
signing future generations and complicates firmware or motherboard recovery.

## Phase 2: establish Secure Boot

If Secure Boot is already enabled and healthy, verify it and continue to phase
3:

```bash
bootctl status
run0 -- sbctl status
run0 -- sbctl verify
```

Confirm that `bootctl` reports `Secure Boot: enabled` and TPM2 support, and
that `sbctl verify` accepts the installed EFI artifacts.

For first-time enrollment:

1. Back up `/var/lib/sbctl` and keep a bootable installer ready.
2. Put the firmware into Secure Boot Setup Mode using the Framework firmware
   UI. Do not clear the TPM.
3. Build the signed boot generation:

   ```bash
   nix flake check --no-build --no-update-lock-file
   nix build .#checks.x86_64-linux.laptop-toplevel
   nixos-rebuild boot --flake .#laptop --elevate=run0
   ```

4. Check the automatic preparation service and signed artifacts:

   ```bash
   systemctl status prepare-sb-auto-enroll.service
   run0 -- sbctl verify
   ```

   If this unit is not available because the new configuration has not run
   yet, reboot once with Secure Boot still in Setup Mode, wait for the service
   to succeed, and then perform the enrollment reboot below.

5. Reboot. Lanzaboote/systemd-boot enrolls the prepared keys from the ESP.
   `autoReboot` is deliberately disabled, so this enrollment reboot is manual.
6. Re-run `bootctl status`, `sbctl status`, and `sbctl verify`.
7. Set a firmware administrator password so a thief cannot simply disable
   Secure Boot or replace its key database.

The laptop configuration deliberately includes Microsoft and Framework
firmware certificates alongside the owner keys. Do not switch to an
owner-key-only policy without auditing every Option ROM and the firmware update
path.

## Phase 3: configure measured boot and TPM unlock

### Add laptop policy

Merge the following settings into the existing `boot` attribute set in
`hosts/laptop/default.nix`:

```nix
boot = {
  initrd = {
    systemd = {
      enable = true;
      tpm2.enable = true;
    };

    luks.devices = {
      "luks-4b1c13e3-af35-4286-b534-674ca54de75a".crypttabExtraOpts = [
        "tpm2-device=auto"
      ];
      "luks-5ee5fadf-22f0-4a53-a33d-63e22931255f".crypttabExtraOpts = [
        "tpm2-device=auto"
      ];
    };
  };

  lanzaboote = {
    configurationLimit = 8;
    measuredBoot = {
      enable = true;
      pcrs = [
        0
        4
        7
      ];
    };
  };
};
```

The existing device paths remain in
`hosts/laptop/hardware-configuration.nix`; Nix merges these token options into
those definitions. `configurationLimit` must be at most eight because that is
the maximum policy size currently supported by `systemd-pcrlock`.

Do not put `tpm2-pin=yes` or PCR selections in `crypttabExtraOpts`. The LUKS2
systemd token written during enrollment records the PIN requirement and PCR
policy metadata. The initrd only needs token discovery via
`tpm2-device=auto`.

Do not enable `boot.lanzaboote.measuredBoot.autoCryptenroll` for this setup.
The pinned module accepts only one device and its automatic enrollment command
does not request a PIN; this laptop has two volumes and requires TPM plus PIN.

### Build and boot the policy generation

```bash
nix flake check --no-build --no-update-lock-file
nix build .#checks.x86_64-linux.laptop-toplevel
nixos-rebuild boot --flake .#laptop --elevate=run0
run0 -- reboot
```

Unlock with the old passphrase or recovery keys during this transitional boot.
Enrollment must happen after booting the measured generation so the policy
contains the real firmware, Secure Boot, bootloader, kernel, initrd, and command
line measurements.

Verify that the policy was generated:

```bash
test -s /var/lib/systemd/pcrlock.json
systemctl --failed
systemctl status systemd-pcrlock-make-policy.service
/run/current-system/systemd/lib/systemd/systemd-pcrlock log
```

Resolve any failed PCR-lock service before enrollment.

### Enroll both volumes with TPM plus PIN

Keep both recovery keys physically available. Enroll one device at a time:

```bash
ROOT_LUKS=/dev/disk/by-uuid/4b1c13e3-af35-4286-b534-674ca54de75a
HOME_LUKS=/dev/disk/by-uuid/5ee5fadf-22f0-4a53-a33d-63e22931255f

run0 -- systemd-cryptenroll \
  --tpm2-device=auto \
  --tpm2-with-pin=yes \
  --tpm2-pcrlock=/var/lib/systemd/pcrlock.json \
  "$ROOT_LUKS"

run0 -- systemd-cryptenroll \
  --tpm2-device=auto \
  --tpm2-with-pin=yes \
  --tpm2-pcrlock=/var/lib/systemd/pcrlock.json \
  "$HOME_LUKS"
```

Use an ASCII PIN or short passphrase that is stronger than a phone-style
four-digit PIN. Wrong attempts advance the TPM-wide dictionary-attack counter
and can cause a prolonged lockout.

Using the same TPM PIN for root and home permits systemd's credential cache to
avoid a second prompt. The TPM-sealed LUKS unlock keys and offline recovery
keys remain unique per volume. Use different PINs only when the additional
compartmentalization is worth two early-boot prompts.

Inspect the LUKS2 token and keyslot metadata without printing credentials:

```bash
run0 -- cryptsetup luksDump "$ROOT_LUKS"
run0 -- cryptsetup luksDump "$HOME_LUKS"
```

### Reboot-test before removing anything

```bash
run0 -- reboot
```

Verify all of the following after entering the TPM PIN:

```bash
findmnt /
findmnt /home
findmnt /boot
bootctl status
run0 -- sbctl verify
systemctl --failed
journalctl -b -u 'systemd-cryptsetup@*'
```

Do not remove the shared passphrase unless both volumes unlocked, Secure Boot
is enabled, both recovery keys were tested, and a recovery installer is ready.

### Remove the old shared passphrase

`luksRemoveKey` removes the slot matching the credential entered at its prompt.
Enter the old shared passphrase, not the TPM PIN or recovery key:

```bash
run0 -- cryptsetup luksRemoveKey "$ROOT_LUKS"
run0 -- cryptsetup luksRemoveKey "$HOME_LUKS"
```

Confirm the old passphrase fails by repeating the `cryptsetup open
--test-passphrase --disable-external-tokens --tries 1` tests from phase 1, then
retest both recovery keys and inspect both `luksDump` outputs.

Create new header backups:

```bash
run0 -- cryptsetup luksHeaderBackup "$ROOT_LUKS" \
  --header-backup-file /root/luks-header-backups/root.post-tpm.img
run0 -- cryptsetup luksHeaderBackup "$HOME_LUKS" \
  --header-backup-file /root/luks-header-backups/home.post-tpm.img
run0 -- chmod 0600 \
  /root/luks-header-backups/root.post-tpm.img \
  /root/luks-header-backups/home.post-tpm.img
```

Copy and verify the new backups offline. Then securely retire the pre-TPM
header backups, which still contain a slot for the removed shared passphrase.

## Routine operation

### NixOS rebuilds and rollbacks

Lanzaboote predicts measurements for retained generations and updates the
managed policy during bootloader installation and boot. Ordinary
`nixos-rebuild boot` operations do not require LUKS re-enrollment.

Continue using the boot-first deployment workflow for bootloader, initrd,
kernel, or measured-boot changes:

```bash
nix flake check --no-build --no-update-lock-file
nix build .#checks.x86_64-linux.laptop-toplevel
nixos-rebuild boot --flake .#laptop --elevate=run0
run0 -- reboot
```

Keep the recovery keys available when booting an older generation. A token
created by a newer systemd is not guaranteed to work in an older initrd, while
a recovery key remains a normal LUKS credential.

### Firmware and Secure Boot database updates

Firmware updates can change PCR 0. Changes to Secure Boot enablement or the
PK, KEK, `db`, or `dbx` databases can change PCR 7. Before either operation:

1. Test both recovery keys.
2. Verify the offline `/var/lib/sbctl` backup and recovery installer.
3. Install the update while the current system is healthy.
4. Be prepared for the first boot to require recovery keys.
5. After boot, verify Secure Boot, inspect `systemctl --failed`, and run
   `nixos-rebuild boot --flake .#laptop --elevate=run0` to refresh predicted
   boot artifacts and policy.
6. Reboot and verify TPM-plus-PIN unlock again.

Do not clear the TPM merely because a firmware update changed measurements.

### Policy-generation failure

If `nixos-rebuild` reports a PCR policy error such as `Remote address
changed`, keep the current policy and TPM slots until recovery access has been
retested. Boot with recovery keys, preserve the failed policy for diagnosis,
and regenerate it:

```bash
run0 -- test ! -e /var/lib/systemd/pcrlock.json.failed
run0 -- mv \
  /var/lib/systemd/pcrlock.json \
  /var/lib/systemd/pcrlock.json.failed
nixos-rebuild boot --flake .#laptop --elevate=run0
run0 -- reboot
```

After booting with recovery keys, confirm a new policy exists and replace the
TPM enrollment on both volumes. Combining enrollment with `--wipe-slot=tpm2`
creates the new TPM slot before removing the old TPM slots:

```bash
run0 -- systemd-cryptenroll \
  --wipe-slot=tpm2 \
  --tpm2-device=auto \
  --tpm2-with-pin=yes \
  --tpm2-pcrlock=/var/lib/systemd/pcrlock.json \
  "$ROOT_LUKS"

run0 -- systemd-cryptenroll \
  --wipe-slot=tpm2 \
  --tpm2-device=auto \
  --tpm2-with-pin=yes \
  --tpm2-pcrlock=/var/lib/systemd/pcrlock.json \
  "$HOME_LUKS"
```

Reboot-test TPM unlocking before retiring the preserved failed policy.

## TPM clear or motherboard replacement

Clearing the TPM or replacing the motherboard destroys the TPM-bound unlock
path for both volumes. It does not invalidate either recovery key or the LUKS
data.

### Before a planned replacement

1. Test both recovery keys with external tokens disabled.
2. Verify encrypted offline backups of `/var/lib/sbctl`, both current LUKS
   headers, and important data.
3. Ensure a current NixOS installer boots on the machine.
4. Do not remove the recovery slots or erase the old drive.

### Recover after clearing only the TPM

Secure Boot keys live in UEFI variables and `/var/lib/sbctl`, not in the TPM.
If only the TPM was cleared, do not reset or re-enroll Secure Boot:

1. Boot the normal signed generation and unlock both volumes with their
   recovery keys.
2. Verify that Secure Boot remains healthy with `bootctl status`, `sbctl
   status`, and `sbctl verify`.
3. Preserve `/var/lib/systemd/pcrlock.json`, rebuild the policy against the
   cleared TPM, and reboot with recovery keys:

   ```bash
   run0 -- test ! -e /var/lib/systemd/pcrlock.json.pre-clear
   run0 -- mv \
     /var/lib/systemd/pcrlock.json \
     /var/lib/systemd/pcrlock.json.pre-clear
   nixos-rebuild boot --flake .#laptop --elevate=run0
   run0 -- reboot
   ```

4. Replace both TPM enrollments using the policy-failure commands above with
   `--wipe-slot=tpm2`, then reboot-test TPM-plus-PIN unlock.

### Recover on a replacement motherboard

A replacement motherboard changes both the TPM and the firmware Secure Boot
key database. Automatic enrollment material created on the old board may also
contain the old board's built-in certificates, so regenerate it on the new
board rather than reusing it blindly.

1. Enable the replacement TPM in firmware.
2. Temporarily disable Secure Boot, without clearing the replacement board's
   factory keys yet, so the existing NixOS generation or installer can start.
3. Boot and unlock root and home with their recovery keys. Old TPM slots cannot
   work with the replacement TPM.
4. Restore `/var/lib/sbctl` from its encrypted backup if the original disks no
   longer contain it. Preserve its ownership and permissions.
5. Preserve any automatic-enrollment bundle from the old board, then restart
   the preparation service so it reads the replacement board's built-in
   certificates. Skip the `mv` only if `/boot/loader/keys/auto` does not exist:

   ```bash
   run0 -- test ! -e /boot/loader/keys/auto.previous-board
   run0 -- mv \
     /boot/loader/keys/auto \
     /boot/loader/keys/auto.previous-board
   run0 -- systemctl restart prepare-sb-auto-enroll.service
   systemctl status prepare-sb-auto-enroll.service
   run0 -- sbctl verify
   ```

6. Put the replacement firmware into Secure Boot Setup Mode and reboot. The
   repository's newly prepared enrollment files retain Microsoft and the new
   Framework firmware certificates and are consumed by systemd-boot:

   ```bash
   run0 -- reboot
   ```

7. Verify `bootctl status`, `sbctl status`, and `sbctl verify` before relying on
   Secure Boot again.
8. Preserve the old PCR policy file for diagnosis, generate a policy against
   the new TPM and firmware, and boot it with recovery keys:

   ```bash
   run0 -- test ! -e /var/lib/systemd/pcrlock.json.old-tpm
   run0 -- mv \
     /var/lib/systemd/pcrlock.json \
     /var/lib/systemd/pcrlock.json.old-tpm
   nixos-rebuild boot --flake .#laptop --elevate=run0
   run0 -- reboot
   ```

9. Re-enroll both devices using the policy-failure commands above with
   `--wipe-slot=tpm2`. Enter the recovery key when asked for an existing LUKS
   credential and choose the desired new TPM PIN.
10. Reboot-test TPM-plus-PIN unlock, then create and export fresh LUKS header
   backups.

If the Secure Boot PKI is intentionally rotated rather than restored, treat it
as a new Secure Boot deployment: enroll the new public keys in firmware,
regenerate the PCR policy, and replace both TPM slots while recovery keys are
available.

## Emergency recovery from a NixOS installer

The stock NixOS installer is normally not signed by this repository's owner
key. Disable Secure Boot temporarily, boot the installer, and identify the
outer LUKS devices:

```bash
lsblk -o NAME,PATH,FSTYPE,UUID,MOUNTPOINTS
```

Open them with the separate recovery keys, mount the Btrfs subvolumes and ESP
under `/mnt`, then enter the system:

```bash
sudo cryptsetup open \
  /dev/disk/by-uuid/4b1c13e3-af35-4286-b534-674ca54de75a \
  luks-4b1c13e3-af35-4286-b534-674ca54de75a
sudo cryptsetup open \
  /dev/disk/by-uuid/5ee5fadf-22f0-4a53-a33d-63e22931255f \
  luks-5ee5fadf-22f0-4a53-a33d-63e22931255f
```

Mount commands depend on the current subvolume layout; confirm it with
`btrfs subvolume list` rather than copying stale commands. After mounting root,
home, and the ESP in their installed locations, run `sudo nixos-enter` and
install a known-good boot generation:

```bash
NIXOS_INSTALL_BOOTLOADER=1 \
  /run/current-system/bin/switch-to-configuration boot
```

Exit, unmount cleanly, reboot, and restore Secure Boot only after the installed
artifacts and firmware enrollment are healthy.

## Disabling measured boot

Keep measured boot enabled unless a deliberate rollback is required. To
disable it safely:

1. Test both recovery keys.
2. Remove TPM slots from both volumes while the current system still boots:

   ```bash
   run0 -- systemd-cryptenroll --wipe-slot=tpm2 "$ROOT_LUKS"
   run0 -- systemd-cryptenroll --wipe-slot=tpm2 "$HOME_LUKS"
   ```

3. Disable `boot.lanzaboote.measuredBoot`, remove the TPM token options if they
   are no longer needed, and build a boot generation.
4. Deallocate the managed policy only after the LUKS slots are gone:

   ```bash
   run0 -- \
     /run/current-system/systemd/lib/systemd/systemd-pcrlock remove-policy
   ```

5. Reboot and use the recovery key or a newly enrolled strong passphrase.

Secure Boot can remain enabled independently of measured boot and TPM unlock.

## References

- [Lanzaboote: enable measured boot](https://github.com/nix-community/lanzaboote/blob/4a773989235545c56f408d168cb63bc41d468832/docs/how-to-guides/enable-measured-boot.md)
- [Lanzaboote: measured boot explanation](https://github.com/nix-community/lanzaboote/blob/4a773989235545c56f408d168cb63bc41d468832/docs/explanation/measured-boot.md)
- [systemd-cryptenroll](https://www.freedesktop.org/software/systemd/man/latest/systemd-cryptenroll.html)
- [systemd-pcrlock](https://www.freedesktop.org/software/systemd/man/latest/systemd-pcrlock.html)
- [cryptsetup](https://gitlab.com/cryptsetup/cryptsetup/-/wikis/home)
