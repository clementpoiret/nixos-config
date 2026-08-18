{
  config,
  lib,
  pkgs,
  username ? null,
  ...
}:
let
  cfg = config.security.localAppArmor;
  inherit (lib) mkOption types;

  stateType = types.enum [
    "disable"
    "complain"
    "enforce"
  ];

  serviceCapabilityType = types.enum [
    "network"
    "runtime-introspection"
    "system-bus"
    "terminal"
  ];

  serviceType = types.submodule (
    { name, ... }:
    {
      options = {
        enable = lib.mkEnableOption "the local-${name} AppArmor service profile" // {
          default = true;
        };
        unit = mkOption {
          type = types.str;
          default = name;
          description = "systemd service receiving the generated AppArmor attachment.";
        };
        stagedState = mkOption {
          type = stateType;
          default = "complain";
          description = "State used for this service while the global mode is staged.";
        };
        packageRoots = mkOption {
          type = types.listOf types.package;
          default = [ ];
          description = "Package closures granted read and mmap access.";
        };
        executionPackages = mkOption {
          type = types.listOf types.package;
          default = [ ];
          description = "Direct package outputs whose commands the service may execute.";
        };
        capabilities = mkOption {
          type = types.listOf serviceCapabilityType;
          default = [ ];
          description = "Composable host capabilities granted to the service.";
        };
        readOnlyPaths = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Exact AppArmor path expressions granted read access.";
        };
        readWritePaths = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Exact AppArmor path expressions granted read/write/lock access.";
        };
        extraRules = mkOption {
          type = types.lines;
          default = "";
          description = "Audited service rules not represented by typed fields.";
        };
        extraRulesRationale = mkOption {
          type = types.str;
          default = "";
          description = "Required rationale when extraRules is non-empty.";
        };
      };
    }
  );

  inventoryType = types.submodule {
    options = {
      kind = mkOption {
        type = types.enum [
          "application"
          "service"
        ];
      };
      status = mkOption {
        type = types.enum [
          "candidate"
          "exempt"
        ];
      };
      target = mkOption { type = types.str; };
      rationale = mkOption { type = types.str; };
    };
  };

  hasHomeManagerUser =
    username != null
    && lib.hasAttrByPath [
      "home-manager"
      "users"
      username
    ] config;
  homeConfig = if hasHomeManagerUser then config.home-manager.users.${username} else null;
  homeDirectory =
    if homeConfig != null then
      homeConfig.home.homeDirectory
    else if username != null && lib.hasAttrByPath [ "users" "users" username "home" ] config then
      config.users.users.${username}.home
    else
      null;

  applicationRegistry =
    if homeConfig == null then
      { }
    else
      lib.filterAttrs (_: app: app.enable) homeConfig.localAppArmor.applications;
  developerPackages = if homeConfig == null then [ ] else homeConfig.localAppArmor.developerPackages;
  configuredSessionReadPackages =
    if homeConfig == null then [ ] else homeConfig.localAppArmor.sessionReadPackages;
  homeInventory = if homeConfig == null then { } else homeConfig.localAppArmor.inventory;
  serviceRegistry = lib.filterAttrs (_: service: service.enable) cfg.services;

  profileNameFor = name: "local-${name}";
  appProfileNames = map profileNameFor (builtins.attrNames applicationRegistry);
  serviceProfileNames = map profileNameFor (builtins.attrNames serviceRegistry);
  managedProfileNames = serviceProfileNames ++ appProfileNames;
  applicationAttachments = lib.mapAttrsToList (
    _: app: "${app.package}/${app.executable}"
  ) applicationRegistry;
  serviceUnits = map (service: service.unit) (builtins.attrValues serviceRegistry);

  stateFor =
    name: stagedState:
    cfg.profileOverrides.${name} or (if cfg.mode == "staged" then stagedState else cfg.mode);

  attrPackage = path: lib.attrByPath path null config;
  homeAttrPackage = path: if homeConfig == null then null else lib.attrByPath path null homeConfig;
  optionalPackage = package: lib.optional (package != null && lib.isDerivation package) package;
  packagesAt = paths: builtins.concatMap (path: optionalPackage (attrPackage path)) paths;
  homePackagesAt = paths: builtins.concatMap (path: optionalPackage (homeAttrPackage path)) paths;

  dconfReadRoots =
    if lib.hasAttrByPath [ "programs" "dconf" "packages" ] config then
      config.programs.dconf.packages
    else
      [ ];
  sessionPackageReadRoots = lib.unique (
    configuredSessionReadPackages
    ++ config.fonts.packages
    ++ dconfReadRoots
    ++ packagesAt [
      [
        "hardware"
        "graphics"
        "package"
      ]
      [
        "hardware"
        "graphics"
        "package32"
      ]
    ]
    ++ lib.attrByPath [ "hardware" "graphics" "extraPackages" ] [ ] config
    ++ lib.attrByPath [ "hardware" "graphics" "extraPackages32" ] [ ] config
    ++ lib.attrByPath [ "xdg" "portal" "configPackages" ] [ ] config
    ++ lib.attrByPath [ "xdg" "portal" "extraPortals" ] [ ] config
    ++ packagesAt [
      [
        "services"
        "gvfs"
        "package"
      ]
    ]
    ++ homePackagesAt [
      [
        "gtk"
        "theme"
        "package"
      ]
      [
        "gtk"
        "iconTheme"
        "package"
      ]
      [
        "gtk"
        "cursorTheme"
        "package"
      ]
      [
        "home"
        "pointerCursor"
        "package"
      ]
      [
        "stylix"
        "cursor"
        "package"
      ]
      [
        "stylix"
        "icons"
        "package"
      ]
      [
        "stylix"
        "fonts"
        "serif"
        "package"
      ]
      [
        "stylix"
        "fonts"
        "sansSerif"
        "package"
      ]
      [
        "stylix"
        "fonts"
        "monospace"
        "package"
      ]
      [
        "stylix"
        "fonts"
        "emoji"
        "package"
      ]
    ]
    ++ [
      pkgs.gtk4
      pkgs.libXxf86vm
      pkgs.libsForQt5.qt5ct
      pkgs.libsForQt5.qtstyleplugin-kvantum
      pkgs.qt6Packages.qt6ct
      pkgs.qt6Packages.qtstyleplugin-kvantum
    ]
  );

  etcReadRoots = map (name: config.environment.etc.${name}.source) (
    builtins.filter (name: lib.hasAttrByPath [ "environment" "etc" name "source" ] config) [
      "lsb-release"
      "os-release"
    ]
  );
  userEnvironmentReadRoots = lib.optional (
    username != null
    && lib.hasAttrByPath [
      "environment"
      "etc"
      "profiles/per-user/${username}"
      "source"
    ] config
  ) config.environment.etc."profiles/per-user/${username}".source;

  standardReadRules = path: ''
    ${path} r,
    ${path}/etc/** r,
    ${path}/share/** mr,
    ${path}/lib/**.so* mr,
    ${path}/lib64/**.so* mr,
    ${path}/lib/** r,
    ${path}/lib64/** r,
  '';
  sourceReadRules = path: ''
    ${path}{,/**} r,
  '';
  profileDataReadRules = path: ''
    ${path}/share/{hunspell,mime}/{,**} r,
  '';
  sessionReadRules = pkgs.writeText "apparmor-local-session-read-only" ''
    ${lib.concatMapStrings standardReadRules sessionPackageReadRoots}
    ${lib.concatMapStrings sourceReadRules etcReadRoots}
    ${lib.concatMapStrings profileDataReadRules ([ config.system.path ] ++ userEnvironmentReadRoots)}

    /nix/store/*-dconf-db r,
    /nix/store/*-fc-cache/** r,
    /nix/store/*-fontconfig-conf/etc/fonts/{,**} r,
    /nix/store/** r,
  '';

  closureReadRules =
    name: roots:
    pkgs.apparmorRulesFromClosure {
      inherit name;
      baseRules = [
        "$path r"
        "$path/etc/** r"
        "$path/share/** mr"
        "$path/lib/**.so* mr"
        "$path/lib64/**.so* mr"
        "$path/lib/** r"
        "$path/lib64/** r"
      ];
    } roots;

  directExecutionRules = path: ''
    ${path}/bin/** ixr,
    ${path}/lib/** ixr,
    ${path}/lib64/** ixr,
    ${path}/libexec/** ixr,
    ${path}/opt/** ixr,
    ${path}/share/** ixr,
  '';

  hasCapability = app: capability: lib.elem capability app.capabilities;
  needsRuntimeIntrospection =
    app: hasCapability app "desktop" || hasCapability app "runtime-introspection";
  sensitiveAccess = app: group: lib.elem group app.sensitiveAccess;
  quotePath = path: ''"${lib.replaceStrings [ "\\" "\"" ] [ "\\\\" "\\\"" ] path}"'';

  runtimeIntrospectionRules = ''
    /proc/ r,
    owner /proc/[0-9]*/{cgroup,cmdline,mountinfo,stat,statm,smaps} r,
    owner /proc/[0-9]*/task/[0-9]*/stat r,
    /proc/stat r,
    /proc/version r,
    /proc/sys/fs/inotify/max_user_watches r,
    /sys/block/ r,
    /sys/bus/pci/devices/ r,
    /sys/devices/system/node/ r,
    /sys/devices/system/cpu/{kernel_max,present} r,
    /sys/devices/system/cpu/cpu[0-9]*/cache/index[0-9]*/size r,
    /sys/devices/system/cpu/cpu[0-9]*/cpufreq/cpuinfo_max_freq r,
    /sys/devices/system/cpu/cpu[0-9]*/topology/core_cpus_list r,
    /sys/devices/system/cpu/cpufreq/policy[0-9]*/cpuinfo_max_freq r,
    /sys/devices/virtual/dmi/id/product_name r,
    owner /sys/fs/cgroup/**/cpu.max r,
    deny owner /proc/[0-9]*/oom_score_adj w,
  '';

  userNamespaceRules = ''
    userns,
    capability setpcap,
    capability sys_admin,
    capability sys_ptrace,
    /proc/sys/kernel/{overflowgid,overflowuid} r,
    /proc/sys/kernel/seccomp/actions_avail r,
    /proc/sys/user/max_user_namespaces r,
    owner /proc/[0-9]*/fd/{,**} rw,
    owner /proc/[0-9]*/{gid_map,setgroups,uid_map} rw,
  '';

  serviceRuntimeIntrospectionRules = ''
    /proc/[0-9]*/{cgroup,mountinfo} r,
    /proc/sys/net/core/somaxconn r,
    /sys/fs/cgroup/**/cpu.max r,
  '';

  sensitiveGroups = {
    sops = ''
      audit deny owner @{HOME}/.config/sops/age/keys.txt rwklm,
      audit deny owner @{HOME}/.config/sops-nix/secrets{,/**} rwklm,
      audit deny owner /run/user/[0-9]*/secrets.d/{,/**} rwklm,
      audit deny /run/secrets/{,/**} rwklm,
    '';
    gpg-private = ''
      audit deny owner @{HOME}/.gnupg/private-keys-v1.d/{,**} rwklm,
      audit deny owner @{HOME}/.gnupg/secring.gpg rwklm,
    '';
    gpg-agent = ''
      audit deny owner @{HOME}/.gnupg/S.gpg-agent{,.*} rwklm,
    '';
    password-store = ''
      audit deny owner @{HOME}/.password-store/{,**} rwklm,
      audit deny owner @{HOME}/.local/share/password-store/{,**} rwklm,
    '';
    ssh-identities = ''
      audit deny owner @{HOME}/.ssh/id_* rwklm,
      audit deny owner @{HOME}/.ssh/*.{key,p12,pem,pfx} rwklm,
    '';
    ssh-config = ''
      audit deny owner @{HOME}/.ssh/config.secrets rwklm,
    '';
    ssh-control = ''
      audit deny owner @{HOME}/.ssh/{cm,sockets}/{,**} rwklm,
    '';
    mail-auth = ''
      audit deny owner @{HOME}/.config/aerc/accounts.conf{,.d/**} rwklm,
    '';
    credential-broker = ''
      audit deny owner @{run}/user/[0-9]*/keyring/{,**} rwklm,
      audit deny dbus send bus=session peer=(name=org.freedesktop.secrets),
      audit deny dbus receive bus=session peer=(name=org.freedesktop.secrets),
    '';
    hardware-credentials = ''
      audit deny owner @{HOME}/.config/Yubico/u2f_keys rwklm,
    '';
  };
  secretDenialsFor =
    app:
    lib.concatMapStrings
      (group: lib.optionalString (!(sensitiveAccess app group)) sensitiveGroups.${group})
      [
        "sops"
        "gpg-private"
        "gpg-agent"
        "password-store"
        "ssh-identities"
        "ssh-config"
        "ssh-control"
        "mail-auth"
        "credential-broker"
        "hardware-credentials"
      ];

  sensitiveAllowsFor = app: ''
    ${lib.optionalString (sensitiveAccess app "sops") ''
      owner @{HOME}/.config/sops/age/keys.txt r,
      owner @{HOME}/.config/sops-nix/secrets{,/**} r,
      owner /run/user/[0-9]*/secrets.d/{,/**} r,
      /run/secrets/{,/**} r,
    ''}
    ${lib.optionalString (sensitiveAccess app "gpg-private") ''
      owner @{HOME}/.gnupg/private-keys-v1.d/{,**} r,
      owner @{HOME}/.gnupg/secring.gpg r,
    ''}
    ${lib.optionalString (sensitiveAccess app "ssh-identities") ''
      owner @{HOME}/.ssh/id_* r,
      owner @{HOME}/.ssh/*.{key,p12,pem,pfx} r,
    ''}
    ${lib.optionalString (sensitiveAccess app "ssh-config") ''
      owner @{HOME}/.ssh/config.secrets r,
    ''}
    ${lib.optionalString (sensitiveAccess app "ssh-control") ''
      owner @{HOME}/.ssh/{cm,sockets}/{,**} rwk,
    ''}
    ${lib.optionalString (sensitiveAccess app "gpg-agent") ''
      owner @{HOME}/.gnupg/S.gpg-agent{,.*} rw,
    ''}
    ${lib.optionalString (sensitiveAccess app "password-store") ''
      owner @{HOME}/.password-store/{,**} rwkl,
      owner @{HOME}/.local/share/password-store/{,**} rwkl,
    ''}
    ${lib.optionalString (sensitiveAccess app "mail-auth") ''
      owner @{HOME}/.config/aerc/accounts.conf{,.d/**} r,
    ''}
    ${lib.optionalString (sensitiveAccess app "credential-broker") ''
      owner @{run}/user/[0-9]*/keyring/{,**} rwkl,
    ''}
    ${lib.optionalString (sensitiveAccess app "hardware-credentials") ''
      owner @{HOME}/.config/Yubico/u2f_keys r,
    ''}
  '';

  applicationCapabilityRules = app: ''
    ${lib.optionalString (hasCapability app "desktop") ''
      include <abstractions/fonts>
      include <abstractions/X>
      include <abstractions/wayland>
      include <abstractions/dconf>
      include <abstractions/gtk>
      include <abstractions/gnome>
      include <abstractions/dbus-session-strict>
      / r,
      /etc/ r,
      owner /run/user/[0-9]*/wayland-proxy-* rw,
    ''}
    ${lib.optionalString (hasCapability app "portal") ''
      include <abstractions/xdg-desktop>
      dbus send bus=session peer=(name=org.freedesktop.portal.Desktop),
      dbus receive bus=session peer=(name=org.freedesktop.portal.Desktop),
    ''}
    ${lib.optionalString (hasCapability app "session-bus") ''
      include <abstractions/dbus-session>
    ''}
    ${lib.optionalString (hasCapability app "system-bus") ''
      /run/dbus/system_bus_socket rw,
      dbus bus=system,
    ''}
    ${lib.optionalString (hasCapability app "network") ''
      include <abstractions/nameservice>
      include <abstractions/ssl_certs>
      network netlink dgram,
    ''}
    ${lib.optionalString (hasCapability app "audio") ''
      include <abstractions/audio>
    ''}
    ${lib.optionalString (hasCapability app "camera") ''
      /dev/video[0-9]* rw,
    ''}
    ${lib.optionalString (hasCapability app "gpu") ''
      include <abstractions/opengl>
      /dev/dri/{,**} rw,
    ''}
    ${lib.optionalString (hasCapability app "shared-memory") ''
      owner /dev/shm/{,**} rwkl,
    ''}
    ${
      if hasCapability app "terminal" then
        ''
          /dev/tty rw,
          owner /dev/pts/[0-9]* rw,
        ''
      else
        ''
          deny /dev/tty rw,
          deny owner /dev/pts/[0-9]* rw,
        ''
    }
    ${lib.optionalString (needsRuntimeIntrospection app) runtimeIntrospectionRules}
    ${lib.optionalString (hasCapability app "credential-broker") ''
      include <abstractions/dbus-session-strict>
      dbus send bus=session peer=(name=org.freedesktop.secrets),
      dbus receive bus=session peer=(name=org.freedesktop.secrets),
    ''}
  '';

  applicationHomeRules = app: ''
    owner @{HOME}/ r,
    ${
      if hasCapability app "full-home" then
        ''
          owner @{HOME}/** rwkl,
        ''
      else
        ''
          include <abstractions/user-write>
          include <abstractions/user-download>
        ''
    }
    ${lib.concatMapStrings (path: ''
      owner ${quotePath "@{HOME}/${path}/{,**}"} rwkl,
    '') app.homePaths}
    ${lib.optionalString (hasCapability app "user-files") ''
      owner @{HOME}/[^.]*/{,**} rwkl,
    ''}
    ${lib.optionalString (hasCapability app "developer-exec") ''
      ptrace,
      owner @{HOME}/** ix,
      owner /tmp/** ix,
      owner /var/tmp/** ix,
    ''}
  '';

  baseWrapperExecutionPackages = [
    pkgs.bash
    pkgs.coreutils
  ];
  applicationWrapperExecutionPackages = baseWrapperExecutionPackages ++ [ pkgs.coreutils-full ];

  applicationPolicy =
    name: app:
    let
      profileName = profileNameFor name;
      state = stateFor profileName "complain";
      attachment = "${app.package}/${app.executable}";
      executionPackages = lib.unique (
        [ app.package ]
        ++ applicationWrapperExecutionPackages
        ++ app.executionPackages
        ++ lib.optionals (hasCapability app "developer-exec") developerPackages
      );
      closureRoots = lib.unique ([ app.package ] ++ app.extraClosureRoots ++ executionPackages);
      closureRules = closureReadRules profileName closureRoots;
      commonRules = pkgs.writeText "apparmor-${profileName}-common" ''
        include <abstractions/base>
        include <abstractions/nameservice-strict>

        owner /tmp/{,**} rwkl,
        owner /var/tmp/{,**} rwkl,

        include "${sessionReadRules}"
        include "${closureRules}"

        ${lib.concatMapStrings directExecutionRules executionPackages}
        ${lib.concatMapStringsSep "\n" (path: "${path} ixr,") app.extraExecutables}
        ${applicationCapabilityRules app}
        ${applicationHomeRules app}
        ${sensitiveAllowsFor app}
        ${app.extraRules}
        ${lib.optionalString (
          hasCapability app "userns" && app.namespaceExecutables == [ ]
        ) userNamespaceRules}
        ${lib.optionalString (state == "enforce") (secretDenialsFor app)}
      '';
      namespaceTransitions = lib.concatMapStringsSep "\n" (
        path: "priority=100 ${path} Cx -> namespace-bootstrap,"
      ) app.namespaceExecutables;
      namespaceProfile = lib.optionalString (app.namespaceExecutables != [ ]) ''
        profile namespace-bootstrap flags=(attach_disconnected,mediate_deleted) {
          include "${commonRules}"
          ${userNamespaceRules}
          ${app.namespaceRules}
        }
      '';
    in
    {
      inherit state;
      profile = ''
        abi <abi/4.0>,
        include <tunables/global>

        profile ${profileName} ${attachment} flags=(attach_disconnected,mediate_deleted) {
          include "${commonRules}"
          ${namespaceTransitions}
          ${namespaceProfile}
        }
      '';
    };

  serviceCapabilityRules = service: ''
    ${lib.optionalString (lib.elem "network" service.capabilities) ''
      include <abstractions/nameservice>
      include <abstractions/ssl_certs>
      network netlink dgram,
    ''}
    ${lib.optionalString (lib.elem "runtime-introspection" service.capabilities) serviceRuntimeIntrospectionRules}
    ${lib.optionalString (lib.elem "system-bus" service.capabilities) ''
      /run/dbus/system_bus_socket rw,
      dbus bus=system,
    ''}
    ${
      if lib.elem "terminal" service.capabilities then
        ''
          /dev/tty rw,
        ''
      else
        ''
          deny /dev/tty rw,
        ''
    }
  '';

  servicePolicy =
    name: service:
    let
      profileName = profileNameFor name;
      state = stateFor profileName service.stagedState;
      executionPackages = lib.unique (baseWrapperExecutionPackages ++ service.executionPackages);
      closureRoots = lib.unique (service.packageRoots ++ executionPackages);
      closureRules = closureReadRules profileName closureRoots;
    in
    {
      inherit state;
      profile = ''
        abi <abi/4.0>,
        include <tunables/global>

        profile ${profileName} flags=(attach_disconnected,mediate_deleted) {
          include <abstractions/base>
          include <abstractions/nameservice-strict>
          include "${closureRules}"

          /nix/store/*-etc-nsswitch.conf r,
          ${lib.concatMapStrings directExecutionRules executionPackages}
          ${serviceCapabilityRules service}
          ${lib.concatMapStringsSep "\n" (path: "${quotePath path} r,") service.readOnlyPaths}
          ${lib.concatMapStringsSep "\n" (path: "${quotePath path} rwkl,") service.readWritePaths}
          owner /tmp/{,**} rwkl,
          ${service.extraRules}
        }
      '';
    };

  applicationPolicies = lib.mapAttrs' (
    name: app: lib.nameValuePair (profileNameFor name) (applicationPolicy name app)
  ) applicationRegistry;
  servicePolicies = lib.mapAttrs' (
    name: service: lib.nameValuePair (profileNameFor name) (servicePolicy name service)
  ) serviceRegistry;

  serviceAttachments = lib.mapAttrs' (
    name: service:
    let
      profileName = profileNameFor name;
      enabled = stateFor profileName service.stagedState != "disable";
    in
    lib.nameValuePair service.unit {
      after = lib.optional enabled "apparmor.service";
      requires = lib.optional enabled "apparmor.service";
      serviceConfig.AppArmorProfile = lib.mkIf enabled profileName;
    }
  ) serviceRegistry;

  validRelativePath =
    path: path != "" && !(lib.hasPrefix "/" path) && !(lib.elem ".." (lib.splitString "/" path));
  appAssertions = lib.mapAttrsToList (name: app: {
    assertion =
      validRelativePath app.executable
      && lib.all validRelativePath app.homePaths
      && lib.all (path: lib.hasPrefix "${builtins.storeDir}/" path) app.extraExecutables
      && lib.all (path: lib.hasPrefix "${builtins.storeDir}/" path) app.namespaceExecutables
      && (hasCapability app "credential-broker" == sensitiveAccess app "credential-broker")
      && (app.namespaceExecutables == [ ] || hasCapability app "userns")
      && (app.namespaceRules == "" || app.namespaceRulesRationale != "")
      && (app.extraRules == "" || app.extraRulesRationale != "");
    message = "Invalid or unexplained AppArmor application descriptor: ${name}";
  }) applicationRegistry;
  serviceAssertions = lib.mapAttrsToList (name: service: {
    assertion = service.extraRules == "" || service.extraRulesRationale != "";
    message = "AppArmor service ${name} has extraRules without a rationale.";
  }) serviceRegistry;

  apparmorReport = pkgs.writeShellApplication {
    name = "apparmor-report";
    runtimeInputs = [
      pkgs.apparmor-bin-utils
      pkgs.python3
      pkgs.systemd
    ];
    text = ''
      exec python3 ${./apparmor_report.py} "$@"
    '';
  };
in
{
  options.security.localAppArmor = {
    mode = mkOption {
      type = types.enum [
        "staged"
        "disable"
        "complain"
        "enforce"
      ];
      default = "staged";
      description = ''
        Default state for locally managed AppArmor profiles. Staged mode uses
        each service descriptor's staged state and keeps applications in complain mode.
      '';
    };

    profileOverrides = mkOption {
      type = types.attrsOf stateType;
      default = { };
      description = "Per-profile state overrides for locally managed AppArmor policies.";
    };

    services = mkOption {
      type = types.attrsOf serviceType;
      default = { };
      description = "Services registered for locally generated AppArmor profiles.";
    };

    inventory = mkOption {
      type = types.attrsOf inventoryType;
      default = { };
      description = "Audited service candidates and explicit confinement exemptions.";
    };
  };

  config = {
    assertions = [
      {
        assertion = lib.all (name: lib.elem name managedProfileNames) (
          builtins.attrNames cfg.profileOverrides
        );
        message = ''
          security.localAppArmor.profileOverrides contains an unmanaged profile.
          Managed profiles: ${lib.concatStringsSep ", " managedProfileNames}
        '';
      }
      {
        assertion = applicationRegistry == { } || homeDirectory != null;
        message = "Local AppArmor applications require a concrete Home Manager home directory.";
      }
      {
        assertion =
          homeConfig == null
          || lib.all (app: lib.elem app.package homeConfig.home.packages) (
            builtins.attrValues applicationRegistry
          );
        message = "Every local AppArmor application package must be installed by Home Manager.";
      }
      {
        assertion =
          builtins.length applicationAttachments == builtins.length (lib.unique applicationAttachments);
        message = "Local AppArmor application attachments must be unique.";
      }
      {
        assertion = builtins.length serviceUnits == builtins.length (lib.unique serviceUnits);
        message = "Local AppArmor service unit attachments must be unique.";
      }
      {
        assertion =
          lib.intersectLists (builtins.attrNames applicationRegistry) (builtins.attrNames serviceRegistry)
          == [ ];
        message = "Local AppArmor application and service profile names must not overlap.";
      }
      {
        assertion =
          lib.intersectLists (builtins.attrNames applicationRegistry) (builtins.attrNames homeInventory)
          == [ ];
        message = "A local AppArmor workload cannot be both protected and inventoried as unconfined.";
      }
      {
        assertion =
          lib.intersectLists (builtins.attrNames serviceRegistry) (builtins.attrNames cfg.inventory) == [ ];
        message = "A local AppArmor service cannot be both protected and inventoried as unconfined.";
      }
    ]
    ++ appAssertions
    ++ serviceAssertions;

    security.apparmor = {
      enable = true;
      enableCache = false;
      killUnconfinedConfinables = false;
      policies = applicationPolicies // servicePolicies;
    };

    environment.systemPackages = [ apparmorReport ];
    systemd.services = serviceAttachments;
  };
}
