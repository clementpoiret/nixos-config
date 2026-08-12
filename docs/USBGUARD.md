# Laptop USBGuard rollout

USBGuard is intentionally disabled. A generic deny-by-default policy can block
the built-in keyboard, YubiKeys, webcam, expansion cards, dock, storage, audio,
or the only recovery input device. Deploy it as a separate, boot-first change.

## 1. Inventory and generate the policy

Connect every trusted device, including:

- all Framework expansion cards and built-in input devices;
- both enrolled YubiKeys;
- webcam, dock components, storage, headset, and audio adapters;
- a separate recovery keyboard;
- charging-only devices that expose a USB interface.

Generate a policy with the packaged tool and store it beside the example
feature module:

```bash
nix shell nixpkgs#usbguard -c sh -c \
  'run0 -- "$(command -v usbguard)" generate-policy' \
  > modules/features/usbguard-laptop.rules
```

Review every rule. Prefer stable device/interface attributes and remove rules
for devices that were connected accidentally. USBGuard controls USB device
authorization; it does not replace IOMMU or Thunderbolt DMA protection.

## 2. Prepare the laptop-only module

Copy `modules/features/usbguard-laptop.nix.example` to
`modules/features/usbguard-laptop.nix`, review it, and import the new module
only from `hosts/laptop/default.nix`. The example enforces the reviewed policy
for present and newly inserted devices, limits IPC to root, and disables its
D-Bus interface.

Do not import the example directly and do not enable USBGuard on the desktop as
part of this rollout.

## 3. Build and cold-boot test

```bash
nix flake check --no-build --no-update-lock-file
nix build .#checks.x86_64-linux.laptop-toplevel
nixos-rebuild boot --flake .#laptop --elevate=run0
run0 -- reboot
```

Keep the previous generation available. After the cold boot, test every
trusted device, login and run0 with both FIDO keys, docked and undocked use,
suspend/resume, and hibernation. Inspect USBGuard state with:

```bash
run0 -- usbguard list-devices
journalctl -u usbguard -b
```

If an essential device is blocked, boot the previous generation and revise the
policy. Re-run the complete device test after firmware updates or hardware
replacement because identifiers and exposed interfaces can change.
