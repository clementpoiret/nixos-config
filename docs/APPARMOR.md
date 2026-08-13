# AppArmor policy operations

The local AppArmor policy lives in `modules/core/apparmor.nix`. It confines
selected applications plus the Syncthing and secret-DNS services without
turning broad interactive launchers into misleadingly permissive profiles.

The default is a staged rollout. Changes are declarative: edit the Nix
configuration, run the checks, and activate a test generation. Avoid using
`aa-enforce`, `aa-complain`, or `aa-disable` as permanent configuration because
the next NixOS activation will restore the state declared here.

## Modes

Set the default policy state with `security.localAppArmor.mode`:

| Mode | Loaded policy state | Intended use |
|---|---|---|
| `staged` | `local-apply-secret-dns` is enforced; every other managed profile is in complain mode | Default rollout and compatibility learning |
| `disable` | No locally managed profile is loaded and service attachments are omitted | Bounded recovery or comparison with an unconfined process |
| `complain` | Every managed profile is loaded in complain mode | Learn required accesses without enforcing ordinary allow rules |
| `enforce` | Every managed profile is enforced | Final state after every workload has been tested |

`disable` affects only the profiles managed by this repository. AppArmor itself
remains enabled, so profiles supplied by NixOS or packages continue to work.

AppArmor explicit `deny` rules still block access in complain mode. For that
reason, the credential-denial rules are generated only for enforced
non-development application profiles. Moving an application from `complain` to
`enforce` therefore activates both its allow-list and its credential boundary.

### Change the mode

The module defaults to `staged`. To select a mode for one host, add this to
`hosts/desktop/default.nix` or `hosts/laptop/default.nix`:

```nix
security.localAppArmor.mode = "complain";
```

Use a profile override when only one workload should change state:

```nix
security.localAppArmor = {
  mode = "staged";
  profileOverrides = {
    local-syncthing = "enforce";
    local-brave = "complain";
    local-motrix = "disable";
  };
};
```

Overrides accept `disable`, `complain`, or `enforce`; `staged` is only a global
mode. An override always wins over the global mode. Unknown profile names fail
Nix evaluation, which prevents a misspelling from silently leaving a program
unconfined.

To change the default for both hosts, change the `default` value of the
`security.localAppArmor.mode` option in `modules/core/apparmor.nix`. Prefer
host-specific settings while trialling a change.

## Managed profile names

The two service profiles are:

```text
local-apply-secret-dns
local-syncthing
```

The application profiles are:

```text
local-file-roller       local-evince             local-mpv
local-pqiv              local-inkscape            local-drawio
local-zotero            local-logseq              local-textmaker
local-planmaker         local-presentations       local-brave
local-glide             local-helium              local-mullvad-browser
local-orion             local-vivaldi             local-thunderbird
local-protonmail-bridge local-proton-pass          local-proton-pass-cli
local-proton-vpn        local-qbittorrent          local-motrix
local-deezer            local-codex-cli            local-claude-code
local-antigravity-cli   local-antigravity-ide      local-zed
local-codex-desktop
```

`local-codex-desktop` is generated only when the Codex Desktop package is in
the user's Home Manager package list. All other names are always managed.

Development profiles intentionally retain repository, home-directory,
authentication, compiler, interpreter, editor, Nix, and VCS access. They still
provide an explicit process label and a bounded Nix-store closure, but they are
not a credential-separation boundary.

## Test the configuration

Run the smallest relevant check first, then build the affected host. None of
these commands activates the configuration:

```bash
# Check mode semantics, override precedence, systemd attachments, and
# credential-denial generation for every mode.
nix build .#checks.x86_64-linux.apparmor-mode-matrix \
  --no-update-lock-file --no-link

# Parse every desktop, laptop, and all-enforced profile and verify that each
# executable attachment exists.
nix build .#checks.x86_64-linux.apparmor-policy-parser \
  --no-update-lock-file --no-link

# Boot the integration VM. It checks enforced denial, DNS file ownership and
# mode, and a running Syncthing process in complain mode under ~/Sync.
nix build .#checks.x86_64-linux.apparmor-vm \
  --no-update-lock-file --no-link

# Confirm both real host configurations still build.
nix build .#checks.x86_64-linux.desktop-toplevel \
  .#checks.x86_64-linux.laptop-toplevel \
  --no-update-lock-file --no-link
```

Run the complete check set before finishing a policy change:

```bash
nix flake check --no-update-lock-file
```

The parser may report that its kernel interface or cache is unavailable in the
Nix build sandbox. That warning is expected when the command exits successfully;
the check uses `--skip-kernel-load` and is validating policy syntax, includes,
and executable paths rather than changing the running kernel policy.

### Inspect the evaluated state

Show the configured mode and the effective state of every profile:

```bash
nix eval --raw \
  .#nixosConfigurations.desktop.config.security.localAppArmor.mode

nix eval --json \
  .#nixosConfigurations.desktop.config.security.apparmor.policies \
  --apply 'policies: builtins.mapAttrs (_: policy: policy.state) policies'
```

Replace `desktop` with `laptop` when checking that host. The second command
shows effective states after applying `staged` behavior and profile overrides.

### Test on the running host

Activate a temporary system generation first. `test` changes the running system
but does not make the generation the boot default:

```bash
nixos-rebuild test --flake .#desktop --elevate=run0
run0 -- aa-status
```

Restart the affected service or fully exit and relaunch the affected
application. Existing processes keep their previous AppArmor label. For a
systemd service, inspect its actual label with:

```bash
pid="$(systemctl show --property MainPID --value syncthing.service)"
run0 -- cat "/proc/$pid/attr/current"
```

The expected result is `local-syncthing (complain)` or
`local-syncthing (enforce)`, according to the effective state. For desktop
applications, find the relevant process with `ps` or `pgrep` and read the same
`/proc/<pid>/attr/current` file.

Exercise the application's real workflow, including:

- opening, creating, saving, renaming, exporting, and deleting files;
- desktop portals, drag-and-drop, clipboard, and notifications;
- audio, video, camera, GPU acceleration, and hardware devices where relevant;
- network access, downloads, helper processes, and external URL handling;
- logout/login, reboot, upgrade, and application restart paths.

Review both enforced denials and complain-mode observations:

```bash
run0 -- journalctl -k -b --grep 'apparmor="(DENIED|ALLOWED)"'
run0 -- journalctl -b -u apparmor.service
systemctl --failed
```

Filter by `profile="local-..."` when the log is busy. A complain-mode log is
evidence to review, not automatically a reason to add an allow rule: deny
optional telemetry, probing, or unrelated filesystem discovery when the
application works without it.

Once runtime testing succeeds, activate the persistent generation with the
normal deployment workflow:

```bash
nixos-rebuild switch --flake .#desktop --elevate=run0
```

## Modify an application profile

Application definitions are in the `appProfiles` list in
`modules/core/apparmor.nix`. A minimal entry is:

```nix
{
  name = "example";
  package = pkgs.example;
  executable = "example";
}
```

This creates `local-example` attached to
`${pkgs.example}/bin/example`. The generated package-closure rules allow the
program and its declared runtime closure without granting execution across all
of `/nix/store`.

Set `userns = true` only when the application requires user namespaces, such as
Chromium- or Electron-based software. Set `developer = true` only for a tool
that genuinely needs the broader developer-tool closure and home execution.
Both flags are security-relevant compatibility exceptions and default to
false.

To add rules for one application, add a field to its `appProfiles` entry:

```nix
additionalRules = ''
  owner @{HOME}/Documents/example/ r,
  owner @{HOME}/Documents/example/** rwkl,
'';
```

Then emit the optional field inside the generated profile in
`applicationPolicy`, near `sharedApplicationRules`:

```nix
${app.additionalRules or ""}
```

Use `sharedApplicationRules` only for access required by every managed GUI
application. A rule needed by one program belongs in that program's additional
rules; do not broaden every profile to fix one denial.

When changing paths:

- AppArmor does not expand `~`; use `@{HOME}` in application policies or an
  explicit Nix-generated home path in service policies.
- Authorize the directory itself and its descendants separately, for example
  `/data/example/ r,` and `/data/example/** rwkl,`.
- Prefer `owner` for user-owned data.
- Include canonical targets for symlinked data. Syncthing therefore authorizes
  both `/home/clementpoiret/Sync` and the desktop target `/srv/syncthing`.
- Keep executable access tied to package closures. Do not add a broad
  `/nix/store/** ix` rule.
- Never add credential paths to a non-development application merely to clear
  a denial. Reconsider whether the operation is required or should go through
  a portal or dedicated service.

Common permissions in this module are `r` for read, `w` for write, `k` for file
locking, `l` for hard links, and `ix` to execute while inheriting the current
profile. Grant only the operations demonstrated by a tested workflow.

After adding or changing an application, run the mode-matrix and parser checks,
then test it in `complain` before selecting `enforce`.

## Modify a service profile

The Syncthing and DNS policies are explicit `syncthingPolicy` and `dnsPolicy`
values. When adding another service:

1. Add its `local-...` name to `serviceProfileNames` so overrides validate.
2. Define a policy whose state comes from `stateFor "local-..."`.
3. Add the policy to `security.apparmor.policies`.
4. Add `After=apparmor.service`, `Requires=apparmor.service`, and
   `AppArmorProfile=local-...` only when its effective state is not `disable`.
5. Keep systemd filesystem, capability, address-family, and syscall controls
   aligned with the AppArmor rules.
6. Extend `tests/apparmor.nix` with a behavior check and a meaningful denied
   access.

AppArmor and systemd sandboxing are complementary. A path allowed by AppArmor
can still be hidden or read-only under `ProtectSystem`, `ProtectHome`, or
`ReadWritePaths`, so inspect both layers when diagnosing a denial.

## Promote, recover, or roll back

Promote one profile at a time:

1. Override it to `complain` and activate a test generation.
2. Exercise representative workloads and review the kernel journal.
3. Add only the narrow rules required for intended behavior.
4. Run the mode-matrix, parser, VM, and affected host builds.
5. Override it to `enforce`, activate another test generation, and repeat the
   workload and journal review.
6. Persist the generation only after the enforced profile works.

If a profile breaks a required workflow, set that profile to `complain` or
`disable` and rebuild. Prefer `complain` when collecting more evidence; use
`disable` when the attachment itself prevents recovery. To return the entire
local policy set to its compatibility baseline, select `staged`.

For a system-generation rollback:

```bash
nixos-rebuild switch --rollback --elevate=run0
```

Do not disable `security.apparmor.enable` to recover one local profile. That
would also remove unrelated package or system profiles and is broader than the
local mode and override controls.
