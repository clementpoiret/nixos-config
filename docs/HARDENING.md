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
- a custom CachyOS EEVDF/ThinLTO/KCFI kernel with a cached CachyOS recovery
  specialisation;
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

These findings are documented but intentionally not changed by this refactor:

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
Lower-priority user-session issues also remain outside this refactor: the
archive extraction helper does not safely preserve arbitrary filenames, the
Helix Markdown formatter executes unpinned `uvx` packages, Syncthing's
loopback GUI has no explicit authentication, the qutepocket userscript writes
unescaped page titles to the qutebrowser command FIFO, and the suspend helper
uses a predictable PID file in `/tmp`.

## Intentional compatibility choices

- User namespaces, SMT, automatic PTI selection, SCX/LAVD, rootless Podman,
  libvirt, Xwayland, Bluetooth, QMK/RP2040, Flipper Zero, and host udev rules
  remain available for current workflows.
- AppArmor does not globally restrict unprivileged user namespaces. Browser,
  Electron, AppImage, Flatpak, Bubblewrap, Nix, and rootless-container
  compatibility remains controlled by their own profiles and existing kernel
  settings.
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
per boot generation, retain the recovery specialisation, and record the result
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

`modules/core/apparmor.nix` owns the local policy and exposes two settings. The
complete mode reference, testing commands, policy-editing recipes, and rollback
procedure are in [APPARMOR.md](APPARMOR.md).

A typical configuration is:

```nix
security.localAppArmor = {
  mode = "staged";
  profileOverrides.local-syncthing = "enforce";
};
```

The complete modes are active configuration, not commented examples:

| Mode | Result |
|---|---|
| `staged` | Enforce `local-apply-secret-dns`; load every other managed profile in complain mode |
| `disable` | Keep all policy definitions evaluable, but load none and omit systemd AppArmor attachments |
| `complain` | Load every managed profile in complain mode |
| `enforce` | Enforce every managed profile |

`profileOverrides` accepts `disable`, `complain`, or `enforce` for any managed
profile and always wins over the selected mode. Unknown names fail evaluation.
AppArmor remains enabled when the local mode is `disable`, so upstream or
future service profiles are not silently disabled with the local set.

The application inventory covers:

- untrusted files and documents: File Roller, Evince, mpv, pqiv, Inkscape,
  Draw.io, Zotero, Logseq, and the three SoftMaker applications;
- browsers and network clients: Brave, Glide, Helium, Mullvad Browser, Orion,
  Vivaldi, Thunderbird, Proton Mail Bridge, Proton Pass and its CLI, Proton
  VPN, qBittorrent, Motrix, and Deezer;
- development tools: Codex Desktop and CLI, Claude Code, Antigravity CLI and
  IDE, and Zed.

Application attachments use their exact Nix store executables, and inherited
children receive rules generated from the package closure. Development-agent
profiles additionally receive a bounded closure of installed compilers,
interpreters, editors, Nix/VCS, and shell tools so repository work remains
possible. Their home/repository execution and authentication access is an
intentional compatibility exception.

When a non-development application is enforced, explicit exclusions protect
SOPS/age keys and decrypted user secrets, SSH private-key patterns, GPG private
keys, the U2F mapping, and common password-store locations. Those explicit
`deny` rules are deliberately emitted only for enforced profiles: AppArmor
applies explicit denies even when a profile is otherwise in complain mode.
Therefore complain mode is for learning compatibility, and the credential
boundary becomes active at promotion.

Syncthing is always configured at `/home/clementpoiret/Sync`. On the desktop,
both that logical path and `/srv/syncthing` are authorized because `~/Sync` is
a symlink to the encrypted mount and AppArmor/systemd may mediate the canonical
target. Its systemd unit uses a read-only home and system image with only those
roots writable. The DNS helper has a narrow enforced profile, an explicit
`CAP_CHOWN` ceiling, and atomically installs a `0600` drop-in owned by
`systemd-resolve`.

Shells, terminal emulators, Nautilus, Neovim, Helix, GPG/SSH agents, Podman,
libvirt, sshd, and Tailscale are intentionally not attached to these local
profiles. Profiling broad interactive launchers would either transitively
confine unrelated work or require a policy so permissive that the label would
be misleading. Existing service sandboxing and subsystem controls still apply.

### Promotion workflow

Promote one profile at a time. Exercise its file-open/save/export paths,
desktop portals, audio/video, hardware acceleration, network behavior, and
child processes before enforcement:

```bash
run0 -- journalctl -b --grep 'apparmor="DENIED"'
run0 -- aa-status
nix build .#checks.x86_64-linux.apparmor-policy-parser
nix build .#checks.x86_64-linux.apparmor-vm
```

Set a single override to `enforce`, rebuild both hosts, and repeat the workload
and journal review. Use `complain` to continue learning or `disable` to unload a
problem profile; do not add broad `/nix/store/**` execution rules to silence
denials. Exact package closures keep store access bounded across upgrades.

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

Keep a working generation and the `cached-cachyos` specialisation. Maintain
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
zgrep -E 'CONFIG_(CFI_CLANG|MODULE_SIG_FORCE|LOCK_DOWN|PREEMPT|HZ_|NO_HZ|TRANSPARENT_HUGEPAGE)' /proc/config.gz
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
