# Hardening

The active hardening policy is colocated with the subsystem it protects:
boot-chain settings live in `modules/core/bootloader.nix`, kernel policy in
`modules/core/hardware.nix`, local security controls in
`modules/core/security.nix`, and network policy in the network and Tailscale
modules. Host-only exceptions stay in `hosts/desktop` or `hosts/laptop`.

## Active baseline

Both hosts use:

- Lanzaboote Secure Boot with owner-only ESP mount masks and a PKI under
  `/var/lib/sbctl`;
- the cached CachyOS EEVDF/ThinLTO Zen 4 kernel from the personal kernel flake;
  this preset does not enable KCFI (see [kernel configuration](KERNEL.md));
- kernel information, BPF, userfaultfd, TTY, filesystem-link, ASLR, and
  end-host network sysctl restrictions;
- AppArmor with locally managed application and service profiles, user
  namespaces for application and Nix sandboxing, and coredump handlers
  configured to retain no payload;
- nftables with no globally open TCP port, no trusted Tailscale interface, and
  only Tailscale transport globally plus SSH/Syncthing on `tailscale0`;
- key-only SSH with root login and forwarding disabled;
- strict DNS-over-TLS/DNSSEC without fallback DNS, plus Chrony NTS;
- sandboxed, signature-requiring Nix with only `root` in `trusted-users`;
- run0/Polkit elevation without sudo, sudo-rs, a sudo shim, persistent
  authorization, or a global pkexec wrapper.

The local AppArmor policy defaults to a staged rollout: the narrow DNS helper
is enforced, while Syncthing and the application profiles are loaded in
complain mode. This makes their labels and audit evidence available without
pretending that desktop workloads have already been exhaustively learned.
See [AppArmor policy](#apparmor-policy) before promoting a profile.

The desktop additionally prevents replacement of the running kernel image and
does not support hibernation. The laptop keeps encrypted hibernation, disables
kexec through sysctl, and must not enable Linux Lockdown while hibernation is a
requirement.

The laptop's migration from Secure Boot alone to managed PCR 0/4/7 measured
boot with TPM-plus-PIN LUKS unlock is documented in
[MEASURED-BOOT.md](MEASURED-BOOT.md). That runbook owns enrollment order,
recovery-key requirements, firmware-update handling, and motherboard/TPM
replacement; do not improvise keyslot removal outside it.

## Known audit gaps

These security issues remain unresolved:

- PAM treats U2F as an alternative to the password, while the mapping file is
  enrolled under the user's writable `~/.config/Yubico/u2f_keys`. A compromised
  account can replace that mapping before requesting run0 authorization. Move
  it to a root-owned `security.pam.u2f.settings.authfile` before treating U2F
  as a privilege-boundary control; separately decide whether it should be a
  required second factor.
- Both hosts grant the primary user membership in `libvirtd`. Access to the
  system libvirt daemon and its root-running QEMU configuration is effectively
  administrative access outside run0. Remove that group, use a per-user daemon,
  or constrain system-daemon authorization if run0 is meant to be the only
  elevation path.

Lower-priority user-session issues include unsafe filename handling in the
archive extraction helper, unpinned `uvx` packages in Helix's Markdown formatter,
an unauthenticated Syncthing loopback GUI, unescaped page titles sent to the
qutebrowser command FIFO by qutepocket, and a predictable suspend-helper PID
file in `/tmp`.

## Intentional compatibility choices

- User namespaces, SMT, automatic PTI selection, SCX/LAVD, guarded agent rootless Podman/Buildah,
  libvirt, Xwayland, Bluetooth, QMK/RP2040, Flipper Zero, and host udev rules
  remain available for current workflows.
- AppArmor does not globally restrict unprivileged user namespaces. Browser,
  Electron, AppImage, Flatpak, Bubblewrap, Nix, and rootless-container
  compatibility remains controlled by their own profiles and existing kernel
  settings.
- Zotero 10 still requires end-of-life Firefox ESR 140. Both hosts explicitly
  permit only `firefox-esr-140-bin-unwrapped-140.17.0esr`; this accepts the lack
  of further security fixes. Remove the exception when Zotero supports a
  maintained runtime.
- `lvfs-testing` remains an explicit firmware-update source; selecting and
  applying an update is still an administrative action.
- USBGuard is not enabled. Follow [USBGUARD.md](USBGUARD.md) only after every
  trusted laptop device and a recovery keyboard are inventoried.
- The `microcode.amd_sha_check=off` workaround is commented out. Flake
  evaluation may therefore warn that ucodenix microcode could fail to load;
  verify the loaded revision and kernel log after every firmware, kernel, or
  ucodenix update.

## Optional strict trials

The trial settings are left commented beside their natural owners. Enable one
per boot generation, retain a working generation, and record the result
before trying the next control.

| Control | Location | Required validation |
|---|---|---|
| `init_on_free=1`, `debugfs=off` | `modules/core/security.nix` | Boot, graphics, perf/tracing, development tools, representative workloads |
| `kernel.yama.ptrace_scope=2` | `modules/core/security.nix` | IDE debuggers, profilers, crash handlers, anti-cheat |
| `kernel.io_uring_disabled=1` | `modules/core/security.nix` | Storage tools, databases, runtimes, game launchers |
| Forced PTI | `modules/core/security.nix` | Syscall-, VM-, and compile-heavy performance |
| SMT disabled | `modules/core/security.nix` | Parallel throughput and fixed-work energy |
| Hardened malloc light | `modules/core/system.nix` | Greeter, browsers, mail, Syncthing, databases, GPU userspace, every daemon |
| Module signature enforcement | both host files | All external modules report a trusted signer; especially NVIDIA and `acpi_call` |
| Integrity Lockdown | desktop host only | NVIDIA, GPU diagnostics, virtualization, recovery; never laptop hibernation |
| Kernel module loading lock | both host files | Preload every hotplug, VPN, VM, filesystem, and development-device module |

Do not apply a broad module blacklist without first inventorying `lsmod`,
`lspci -k`, `lsusb -t`, and mounted network or uncommon filesystems.

## AppArmor policy

`modules/core/apparmor.nix` owns the policy generator. Applications register
beside their Home Manager packages, while services register beside their NixOS
units. Workload profiles use a staged learning policy by default; the narrow
DNS helper is enforced. Required Bubblewrap and agent-container infrastructure
profiles remain enforced even when workload mode is `complain` or `disable`.

Enforced workloads deny undeclared access to credentials and protected
configuration trees. Developer profiles deliberately have broader execution
rights; staged or complain-mode profiles are not a complete malicious-agent
boundary. Systemd sandboxing and Unix permissions remain independent layers.

[APPARMOR.md](APPARMOR.md) is the authoritative reference for
[modes](APPARMOR.md#modes), capabilities and exceptions, guarded containers,
[verification](APPARMOR.md#verify-a-policy-change),
[debug reports](APPARMOR.md#automatic-debug-reports), and
[promotion and recovery](APPARMOR.md#promote-and-recover). Promote one workload
at a time after testing its complete intended workflow. Recover with a narrow
profile override, not by disabling AppArmor or adding broad execution grants.

## Deployment and recovery

Build both hosts before deployment. For kernel, bootloader, initrd,
filesystem, hibernation, or GPU changes, install for the next boot rather than
switching the running system:

```bash
nix flake check --no-build --no-update-lock-file
nix build .#checks.x86_64-linux.desktop-toplevel
nix build .#checks.x86_64-linux.laptop-toplevel
nixos-rebuild boot --flake .#desktop --elevate=run0
run0 -- reboot
```

Keep a working generation with a known-good kernel. Maintain
offline LUKS recovery material, two FIDO devices, SOPS recovery keys, per-host
Secure Boot key backups, and a NixOS installer.
Recompute the laptop Btrfs `resume_offset` whenever its swapfile is recreated,
moved, resized, or restored.

## Runtime verification

Static evaluation cannot prove firmware enrollment, the active kernel, loaded
microcode, encrypted resume storage, or runtime firewall state. After a boot,
check:

```bash
uname -r
cat /proc/cmdline
zgrep -E 'CONFIG_(CFI|MODULE_SIG_FORCE|LOCK_DOWN|PREEMPT|HZ_|NO_HZ|TRANSPARENT_HUGEPAGE)' /proc/config.gz
cat /sys/kernel/security/lsm
cat /sys/kernel/security/lockdown 2>/dev/null || true

sysctl kernel.kptr_restrict kernel.dmesg_restrict \
  kernel.yama.ptrace_scope kernel.unprivileged_bpf_disabled \
  net.core.bpf_jit_harden kernel.perf_event_paranoid \
  vm.unprivileged_userfaultfd dev.tty.ldisc_autoload \
  kernel.kexec_load_disabled
cat /proc/sys/kernel/modules_disabled

bootctl status
run0 -- sbctl status
run0 -- sbctl verify
run0 -- aa-status
run0 -- nft list ruleset
ss -lntup
resolvectl status
chronyc -N sources
chronyc authdata
nix show-config | grep -E \
  'sandbox|require-sigs|accept-flake-config|trusted-users|allowed-users'
find /run/wrappers/bin -maxdepth 1 -type f -printf '%M %u:%g %p\n'
systemctl --failed
```

Expected network exposure is no inbound TCP service on physical interfaces,
SSH and Syncthing only on Tailscale, and the Tailscale UDP transport port
globally. Verify this from another machine as well as from the local ruleset.

On the laptop, also test explicit hibernation and suspend-then-hibernate at
meaningful memory pressure, then inspect the previous boot:

```bash
run0 -- btrfs inspect-internal map-swapfile -r /var/lib/swapfile
run0 -- systemctl hibernate
journalctl -b -1 -u systemd-hibernate.service
journalctl -b -1 -k | grep -Ei 'hibernate|resume|lockdown|signature|KCFI'
```
