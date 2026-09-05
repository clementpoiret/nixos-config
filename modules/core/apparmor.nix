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
  inherit (import ../../lib/apparmor.nix { inherit lib; }) sensitiveGroups inventoryType;

  stateType = types.enum [
    "disable"
    "complain"
    "enforce"
  ];

  serviceCapabilityType = types.enum [
    "network"
    "runtime-introspection"
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
        systemBusPeers = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Well-known system D-Bus peer names available for sending and receiving.";
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
  configuredDebugPath = cfg.debug.path;
  untrimmedDebugPath =
    if lib.hasPrefix "~/" configuredDebugPath then
      "${
        if homeDirectory == null then "/var/empty" else homeDirectory
      }/${lib.removePrefix "~/" configuredDebugPath}"
    else
      configuredDebugPath;
  debugPath =
    if untrimmedDebugPath == "/" then untrimmedDebugPath else lib.removeSuffix "/" untrimmedDebugPath;
  debugUser = if username == null then "root" else username;
  debugGroup =
    if username != null && lib.hasAttrByPath [ "users" "users" username "group" ] config then
      config.users.users.${username}.group
    else
      "root";

  applicationRegistry =
    if homeConfig == null then
      { }
    else
      lib.filterAttrs (_: app: app.enable) homeConfig.localAppArmor.applications;
  containerApplications = lib.filterAttrs (
    _: app: lib.elem "containers" app.capabilities
  ) applicationRegistry;
  configuredSessionReadPackages =
    if homeConfig == null then [ ] else homeConfig.localAppArmor.sessionReadPackages;
  homeInventory = if homeConfig == null then { } else homeConfig.localAppArmor.inventory;
  serviceRegistry = lib.filterAttrs (_: service: service.enable) cfg.services;

  profileNameFor = name: "local-${name}";
  containerEngineProfileNameFor = name: "${profileNameFor name}-container-engine";
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

  attrPackage =
    path:
    let
      evaluated = builtins.tryEval (lib.attrByPath path null config);
    in
    if evaluated.success then evaluated.value else null;
  homeAttrPackage =
    path:
    if homeConfig == null then
      null
    else
      let
        evaluated = builtins.tryEval (lib.attrByPath path null homeConfig);
      in
      if evaluated.success then evaluated.value else null;
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
  containerRegistriesConfig = lib.attrByPath [
    "environment"
    "etc"
    "containers/registries.conf"
    "source"
  ] null config;
  userEnvironmentReadRoots = lib.optional (
    username != null
    && lib.hasAttrByPath [
      "environment"
      "etc"
      "profiles/per-user/${username}"
      "source"
    ] config
  ) config.environment.etc."profiles/per-user/${username}".source;

  readOnlyClosureBaseRules = [
    "$path r"
    "$path/etc/** r"
    "$path/share/** mr"
    "$path/**.node mr"
    "$path/lib/**.so* mr"
    "$path/lib64/**.so* mr"
    "$path/lib/** r"
    "$path/lib64/** r"
  ];
  sourceReadRules = path: ''
    ${path}{,/**} r,
  '';
  profileDataReadRules = path: ''
    ${path}/share/{hunspell,mime}/{,**} r,
  '';
  sessionClosureRules = pkgs.apparmorRulesFromClosure {
    name = "local-session-read-only";
    baseRules = readOnlyClosureBaseRules;
  } sessionPackageReadRoots;
  sessionReadRules = pkgs.writeText "apparmor-local-session-read-only" ''
    include "${sessionClosureRules}"
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
      baseRules = readOnlyClosureBaseRules;
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
  bubblewrapApplications = lib.filterAttrs (
    _: app: hasCapability app "bubblewrap"
  ) applicationRegistry;
  bubblewrapPackages = lib.unique (
    builtins.filter (package: package != null) (
      map (app: app.bubblewrapPackage) (builtins.attrValues bubblewrapApplications)
    )
  );
  bubblewrapPackage =
    if builtins.length bubblewrapPackages == 1 then builtins.head bubblewrapPackages else null;
  bubblewrapProfile =
    if bubblewrapPackage == null then
      null
    else
      pkgs.runCommand "apparmor-bwrap-userns-restrict" { } ''
        substitute \
          ${pkgs.apparmor-profiles}/share/apparmor/extra-profiles/bwrap-userns-restrict \
          "$out" \
          --replace-fail /usr/bin/bwrap ${bubblewrapPackage}/bin/bwrap
      '';
  claudeSandboxEnabled =
    applicationRegistry ? claude-code && hasCapability applicationRegistry.claude-code "bubblewrap";
  claudeBubblewrapProfile =
    if !claudeSandboxEnabled || bubblewrapProfile == null then
      null
    else
      pkgs.runCommand "apparmor-claude-code-bwrap" { } ''
        substitute \
          ${bubblewrapProfile} \
          "$out" \
          --replace-fail \
            'profile bwrap ${bubblewrapPackage}/bin/bwrap flags=' \
            'profile local-claude-code-bwrap flags=' \
          --replace-fail \
            '&bwrap//&unpriv_bwrap' \
            '&local-claude-code-bwrap//&local-claude-code-bwrap-payload' \
          --replace-fail \
            'profile unpriv_bwrap flags=' \
            'profile local-claude-code-bwrap-payload flags=' \
          --replace-fail \
            'allow pix /** -> &unpriv_bwrap,' \
            'allow pix /** -> &local-claude-code-bwrap-payload,' \
          --replace-fail \
            'audit deny capability,' \
            'allow capability sys_admin,'
      '';
  needsRuntimeIntrospection =
    app:
    hasCapability app "desktop"
    || hasCapability app "developer-exec"
    || hasCapability app "runtime-introspection";
  sensitiveAccess = app: group: lib.elem group app.sensitiveAccess;
  quotePath = path: ''"${lib.replaceStrings [ "\\" "\"" ] [ "\\\\" "\\\"" ] path}"'';
  systemBusRulesFor =
    peers:
    lib.optionalString (peers != [ ]) ''
      include <abstractions/dbus-strict>
      ${lib.concatMapStringsSep "\n" (peer: "dbus (send, receive) bus=system peer=(name=${peer}),") peers}
    '';

  runtimeIntrospectionRules = ''
    /proc/ r,
    /proc/[0-9]*/{cgroup,stat} r,
    owner /proc/[0-9]*/{cmdline,mountinfo,statm,smaps,smaps_rollup} r,
    owner /proc/[0-9]*/task/ r,
    owner /proc/[0-9]*/task/[0-9]*/{stat,status} r,
    owner /proc/[0-9]*/task/[0-9]*/comm rw,
    /proc/stat r,
    /proc/version r,
    /proc/pressure/{cpu,io,memory} r,
    /proc/sys/fs/inotify/max_user_watches r,
    /proc/sys/kernel/{arch,yama/ptrace_scope} r,
    /sys/block/ r,
    /sys/bus/ r,
    /sys/bus/*/devices/ r,
    /sys/devices/**/uevent r,
    /sys/devices/**/{descriptors,manufacturer,product} r,
    /sys/devices/pci[0-9a-fA-F]*/**/class r,
    /sys/devices/system/node/ r,
    /sys/devices/system/cpu/{kernel_max,present} r,
    /sys/devices/system/cpu/cpu[0-9]*/cache/index[0-9]*/size r,
    /sys/devices/system/cpu/cpu[0-9]*/cpufreq/cpuinfo_max_freq r,
    /sys/devices/system/cpu/cpu[0-9]*/microcode/version r,
    /sys/devices/system/cpu/cpu[0-9]*/topology/{core_cpus,core_cpus_list} r,
    /sys/devices/system/cpu/cpufreq/policy[0-9]*/{cpuinfo_max_freq,scaling_cur_freq} r,
    /sys/devices/virtual/dmi/id/{product_name,product_sku,sys_vendor} r,
    /sys/fs/cgroup/**/{cpu.max,memory.high,memory.max} r,
    deny owner /proc/[0-9]*/clear_refs w,
    deny owner /proc/[0-9]*/oom_score_adj w,
  '';

  hostDiagnosticsRules = ''
    /etc/machine-id r,
    /proc/[0-9]*/ r,
    /proc/[0-9]*/{cgroup,cmdline,mountinfo,mounts,stat,status} r,
    owner /proc/[0-9]*/{gid_map,uid_map} r,
    owner /proc/[0-9]*/attr/current r,
    /proc/[0-9]*/task/ r,
    /proc/[0-9]*/task/[0-9]*/ r,
    /proc/[0-9]*/task/[0-9]*/{comm,stat,status} r,
    /proc/bus/pci/ r,
    /proc/bus/pci/devices r,
    /proc/modules r,
    /proc/tty/drivers r,
    /proc/sys/kernel/{osrelease,ostype,pid_max,unprivileged_userns_clone} r,
    /proc/sys/user/max_user_namespaces r,
    /proc/sys/vm/{mmap_min_addr,nr_hugepages} r,
    /run/log/journal/{,**} r,
    /sys/class/{accel,drm}/ r,
    /sys/devices/pci[0-9a-fA-F]*/**/device r,
    /sys/devices/pci[0-9a-fA-F]*/**/vendor r,
    /sys/kernel/security/apparmor/ r,
    /sys/kernel/security/apparmor/features/{,**} r,
    /sys/kernel/security/apparmor/profiles r,
    /var/log/journal/{,**} r,
    ${lib.optionalString cfg.debug.enable ''
      owner ${quotePath "${debugPath}/{,**}"} r,
    ''}
  '';

  deviceDiscoveryRules = ''
    /dev/ r,
    /dev/disk/by-uuid/ r,
    /sys/class/ r,
    /sys/class/*/ r,
    /run/udev/data/{+hid:*,+usb:*,c10:*,c13:*,c189:*} r,
    /sys/devices/**/{0003,0005,0018}:*:*.*/report_descriptor r,
    /sys/devices/**/usb[0-9]*/**/{bConfigurationValue,busnum,devnum,interface,serial} r,
    /sys/devices/virtual/tty/tty0/active r,
  '';

  userNamespaceRules = ''
    userns,
    capability setpcap,
    capability sys_admin,
    capability sys_chroot,
    capability sys_ptrace,
    /proc/sys/kernel/{overflowgid,overflowuid} r,
    /proc/sys/kernel/seccomp/actions_avail r,
    /proc/sys/user/max_user_namespaces r,
    /proc/[0-9]*/task/[0-9]*/status r,
    owner /proc/[0-9]*/fd/{,**} rw,
    owner /proc/[0-9]*/{gid_map,setgroups,uid_map} rw,
  '';

  serviceRuntimeIntrospectionRules = ''
    /proc/[0-9]*/{cgroup,mountinfo} r,
    owner /proc/[0-9]*/{stat,statm} r,
    /proc/sys/net/core/somaxconn r,
    /nix/store/*-etc-os-release r,
    /sys/fs/cgroup/**/cpu.max r,
  '';

  sensitiveRulesFor =
    state: app:
    lib.optionalString (state == "enforce") (
      lib.concatMapStrings (
        group: lib.optionalString (!(sensitiveAccess app group)) sensitiveGroups.${group}.denyRules
      ) (builtins.attrNames sensitiveGroups)
    );

  sensitiveAllowsFor =
    app:
    lib.concatMapStrings (
      group: lib.optionalString (sensitiveAccess app group) sensitiveGroups.${group}.allowRules
    ) (builtins.attrNames sensitiveGroups);

  pathsOverlap =
    left: right: left == right || lib.hasPrefix "${left}/" right || lib.hasPrefix "${right}/" left;
  homePathHasUndeclaredSensitiveAccess =
    app: path:
    lib.any (
      group:
      !(sensitiveAccess app group)
      && lib.any (root: pathsOverlap path root) sensitiveGroups.${group}.homeRoots
    ) (builtins.attrNames sensitiveGroups);
  allowedHomePathsFor =
    app:
    lib.filter (
      path: !(lib.hasPrefix "nixos-config" path) && !(homePathHasUndeclaredSensitiveAccess app path)
    ) app.homePaths;

  reservedUserFilesPrefix = "nixos";
  reservedUserFilesCharacters = lib.stringToCharacters reservedUserFilesPrefix;
  escapeCharacterClass = character: if character == "-" then "\\-" else character;
  userFilesRulesFor =
    qualifier: permissions:
    lib.concatStrings (
      lib.imap0 (
        index: excludedCharacter:
        let
          prefix = lib.concatStrings (lib.take index reservedUserFilesCharacters);
          excludedCharacters = lib.optionalString (index == 0) "." + escapeCharacterClass excludedCharacter;
        in
        lib.optionalString (prefix != "") ''
          ${qualifier}@{HOME}/${prefix}/{,**} ${permissions},
        ''
        + ''
          ${qualifier}@{HOME}/${prefix}[^${excludedCharacters}]*/{,**} ${permissions},
        ''
      ) reservedUserFilesCharacters
    );
  userFilesRules = userFilesRulesFor "" "r" + userFilesRulesFor "owner " "rwkl";

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
      deny /etc/opt/{,**} w,
      owner /run/user/[0-9]*/wayland-proxy-* rw,
      ${pkgs.glib.out}/libexec/gio-launch-desktop ixr,
    ''}
    ${lib.optionalString (hasCapability app "portal") ''
      include <abstractions/xdg-desktop>
      dbus send bus=session peer=(name=org.freedesktop.portal.Desktop),
      dbus receive bus=session peer=(name=org.freedesktop.portal.Desktop),
    ''}
    ${lib.optionalString (hasCapability app "session-bus") ''
      include <abstractions/dbus-session>
    ''}
    ${systemBusRulesFor app.systemBusPeers}
    ${lib.optionalString (hasCapability app "network") ''
      include <abstractions/nameservice>
      include <abstractions/ssl_certs>
      network netlink dgram,
      /proc/sys/net/core/somaxconn r,
      /proc/sys/net/ipv4/ip_local_port_range r,
    ''}
    ${lib.optionalString (hasCapability app "audio") ''
      include <abstractions/audio>
    ''}
    ${lib.optionalString (hasCapability app "camera") ''
      /dev/video[0-9]* rw,
    ''}
    ${lib.optionalString (hasCapability app "gpu") ''
      include <abstractions/opengl>
      /dev/ r,
      /dev/dri/{,**} rw,
      /sys/class/drm/ r,
      /sys/devices/pci[0-9a-fA-F]*:[0-9a-fA-F]*/ r,
      /sys/devices/pci[0-9a-fA-F]*:[0-9a-fA-F]*/**/ r,
      /sys/devices/**/drm/ r,
      /sys/devices/**/drm/{card[0-9]*,renderD[0-9]*}/ r,
      /sys/devices/pci[0-9a-fA-F]*/**/device r,
    ''}
    ${lib.optionalString (hasCapability app "device-discovery") deviceDiscoveryRules}
    ${lib.optionalString (hasCapability app "shared-memory" || hasCapability app "developer-exec") ''
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
    ${lib.optionalString (hasCapability app "host-diagnostics") hostDiagnosticsRules}
    ${lib.optionalString (hasCapability app "credential-broker") ''
      include <abstractions/dbus-session-strict>
      dbus send bus=session peer=(name=org.freedesktop.secrets),
      dbus receive bus=session peer=(name=org.freedesktop.secrets),
    ''}
  '';

  applicationHomeRules = app: ''
    owner @{HOME}/ r,
    include <abstractions/user-write>
    include <abstractions/user-download>
    ${lib.concatMapStrings (path: ''
      owner ${quotePath "@{HOME}/${path}/{,**}"} rwkl,
    '') (allowedHomePathsFor app)}
    ${lib.optionalString (hasCapability app "user-files") userFilesRules}
    ${lib.optionalString (hasCapability app "developer-exec") ''
      ptrace (read, trace) peer=@{profile_name},
      /nix/store/ r,
      /nix/store/** mr,
      /nix/store/** ixr,
      /nix/var/log/nix/ r,
      /nix/var/log/nix/drvs/{,**} r,
      owner @{HOME}/.agents/skills/{,**} r,
      owner @{HOME}/.cache/nix/{,**} rwkl,
      owner @{HOME}/.cache/matplotlib/{,**} rwkl,
      owner @{HOME}/.cache/uv/{,**} rwkl,
      owner @{HOME}/.cache/go-build/{,**} rwkl,
      owner @{HOME}/.cache/ort.pyke.io/{,**} rwkl,
      owner @{HOME}/.cargo/.global-cache rwk,
      owner @{HOME}/.cargo/.package-cache{,-mutate} rwk,
      owner @{HOME}/.cargo/registry/{,**} rwkl,
      owner @{HOME}/.config/git/ignore r,
      owner @{HOME}/.config/go/telemetry/{,**} rwkl,
      owner @{HOME}/.config/jj/repos/{,**} r,
      owner @{HOME}/.keras/keras.json r,
      owner @{HOME}/.local/share/*-skills/{,**} r,
      owner @{HOME}/.local/share/uv/{,**} rwkl,
      /nix/store/*-man-cache/index.db rk,
      /var/cache/man/nixos-mandb/index.db rk,
      owner @{HOME}/** m,
      owner @{HOME}/** ix,
      owner /proc/[0-9]*/fd/ r,
      owner /tmp/** m,
      owner /tmp/** ix,
      owner /var/tmp/** m,
      owner /var/tmp/** ix,
    ''}
  '';

  baseWrapperExecutionPackages = [
    pkgs.bash
    pkgs.coreutils
    pkgs.glibc.bin
  ];
  applicationWrapperExecutionPackages = baseWrapperExecutionPackages ++ [ pkgs.coreutils-full ];
  desktopExecutionPackages = [
    pkgs.dbus
    pkgs.gawk
    pkgs.gnugrep
    pkgs.xdg-utils
  ];

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
        ++ lib.optionals (hasCapability app "desktop") desktopExecutionPackages
      );
      closureRoots = lib.unique (
        [ app.package ]
        ++ app.extraClosureRoots
        ++ executionPackages
        ++ lib.optional (app.bubblewrapPackage != null) app.bubblewrapPackage
      );
      closureRules = lib.optionalString (!(hasCapability app "developer-exec")) (
        closureReadRules profileName closureRoots
      );
      protectedConfigurationRules = lib.optionalString (state == "enforce") ''
        audit deny @{HOME}/nixos-config/{,**} wklm,
      '';
      commonRules = pkgs.writeText "apparmor-${profileName}-common" ''
        include <abstractions/base>
        include <abstractions/nameservice-strict>

        owner /tmp/{,**} rwkl,
        owner /var/tmp/{,**} rwkl,

        include "${sessionReadRules}"
        ${lib.optionalString (closureRules != "") ''include "${closureRules}"''}

        ${lib.concatMapStrings directExecutionRules executionPackages}
        ${lib.concatMapStringsSep "\n" (path: "${path} ixr,") app.extraExecutables}
        ${applicationCapabilityRules app}
        ${applicationHomeRules app}
        ${sensitiveAllowsFor app}
        ${protectedConfigurationRules}
        ${sensitiveRulesFor state app}
        ${app.extraRules}
        ${lib.optionalString (hasCapability app "userns") userNamespaceRules}
        ${app.userNamespaceRules}
        ${lib.optionalString (hasCapability app "containers") ''
          # Stack the enforced rejection target, also preserving no-new-privs callers.
          priority=200 /nix/store/*-podman-*/bin/{podman,podmansh,.podman-wrapped} Px -> ${profileName}//&local-agent-container-denied,
          priority=200 /nix/store/*-buildah-*/bin/{buildah,.buildah-wrapped} Px -> ${profileName}//&local-agent-container-denied,
        ''}
        ${lib.optionalString (hasCapability app "developer-exec") "priority=50 /nix/store/** Pix,"}
      '';
      profileReentryTransitions = lib.concatMapStringsSep "\n" (
        path: "priority=100 ${path} Px -> ${profileName},"
      ) app.profileReentryExecutables;
      bubblewrapTransition =
        lib.optionalString (hasCapability app "bubblewrap" && app.bubblewrapPackage != null)
          "priority=100 ${app.bubblewrapPackage}/bin/bwrap Px -> ${
            if name == "claude-code" then "local-claude-code-bwrap" else "bwrap"
          },";
      containerTransitions =
        lib.optionalString (hasCapability app "containers" && app.containerToolsPackage != null)
          ''
            priority=110 ${app.containerToolsPackage}/bin/podman Px -> ${containerEngineProfileNameFor name},
            priority=110 ${app.containerToolsPackage}/bin/buildah Px -> ${containerEngineProfileNameFor name},
          '';
    in
    {
      inherit state;
      profile = ''
        abi <abi/4.0>,
        include <tunables/global>

        profile ${profileName} ${attachment} flags=(attach_disconnected,mediate_deleted) {
          include "${commonRules}"
          ${profileReentryTransitions}
          ${bubblewrapTransition}
          ${containerTransitions}
        }
      '';
    };

  containerEnginePolicy =
    name: app:
    let
      profileName = containerEngineProfileNameFor name;
      agentId =
        if name == "codex-cli" then
          "codex"
        else if name == "claude-code" then
          "claude"
        else
          name;
      containerTools = app.containerToolsPackage;
      enginePackages = lib.unique ([ containerTools ] ++ containerTools.enginePackages);
      closureRules = closureReadRules profileName enginePackages;
      engineExecutionRules = path: ''
        priority=100 ${path}/bin/** ixr,
        priority=100 ${path}/lib/** ixr,
        priority=100 ${path}/lib64/** ixr,
        priority=100 ${path}/libexec/** ixr,
        priority=100 ${path}/opt/** ixr,
        priority=100 ${path}/share/** ixr,
      '';
    in
    {
      state = "enforce";
      profile = ''
        abi <abi/4.0>,
        include <tunables/global>

        profile ${profileName} flags=(attach_disconnected.path=/apparmor-disconnected/agent-container-engine/,mediate_deleted) {
          include <abstractions/base>
          include <abstractions/nameservice>
          include <abstractions/ssl_certs>
          include "${closureRules}"

          ${lib.concatMapStrings engineExecutionRules enginePackages}
          ${containerTools}/libexec/{,**} r,
          ${containerTools.composeProvider}/bin/ r,
          priority=100 /run/wrappers/bin/{newgidmap,newuidmap} ixr,
          priority=100 /run/wrappers/wrappers.*/{newgidmap,newuidmap} ixr,

          network,
          unix,
          userns,
          capability,
          mount,
          remount,
          umount,
          pivot_root,
          ptrace (read, trace) peer=@{profile_name},
          ptrace (read) peer=local-agent-container-payload,
          signal (send, receive) peer=@{profile_name},
          signal (send) peer=local-agent-container-payload,

          priority=50 /** px -> local-agent-container-payload,

          /apparmor-disconnected/agent-container-engine/{,**} rwklm,

          / r,
          priority=100 / ix,
          /etc/{,group,hosts,host.conf,login.defs,nsswitch.conf,passwd,resolv.conf,subgid,subuid} r,
          /etc/containers/{,**} r,
          ${lib.optionalString (containerRegistriesConfig != null) ''
            ${quotePath (toString containerRegistriesConfig)} r,
          ''}
          /nix/store/*-etc-os-release r,
          /nix/store/*-login.defs r,
          /nix/store/*-policy/{,**} r,
          /proc/ r,
          /proc/filesystems r,
          /proc/mounts r,
          /proc/uptime r,
          /proc/self/{,**} rw,
          /proc/sys/kernel/{overflowgid,overflowuid,unprivileged_userns_clone} r,
          /proc/sys/net/ipv4/ip_forward rw,
          /proc/sys/net/ipv4/conf/*/{arp_notify,forwarding,route_localnet,rp_filter} rw,
          /proc/sys/net/ipv4/{ip_local_port_range,ping_group_range,tcp_rto_max_ms,tcp_syn_linear_timeouts,tcp_syn_retries} r,
          /proc/sys/net/ipv6/conf/*/{accept_dad,accept_ra,autoconf,forwarding} rw,
          /proc/sys/net/netfilter/{nf_conntrack_udp_timeout,nf_conntrack_udp_timeout_stream} r,
          /proc/sys/user/max_user_namespaces r,
          deny /proc/sys/fs/pipe-max-size r,
          owner /proc/[0-9]*/ r,
          owner /proc/[0-9]*/fd/{,**} rw,
          /proc/[0-9]*/net/{tcp,tcp6,udp,udp6} r,
          /proc/[0-9]*/stat r,
          owner /proc/[0-9]*/mounts r,
          owner /proc/[0-9]*/{attr/current,cgroup,cmdline,gid_map,loginuid,mountinfo,oom_score_adj,setgroups,stat,status,uid_map} rw,
          owner /proc/[0-9]*/task/[0-9]*/mountinfo r,
          /sys/{,**} r,
          /sys/fs/cgroup/{,**} rw,
          /dev/ r,
          /dev/{full,fuse,null,ptmx,random,tty,urandom,zero} rw,
          /dev/net/ r,
          /dev/net/tun rw,
          owner /dev/pts/[0-9]* rw,

          owner @{HOME}/ r,
          owner @{HOME}/[^.]*/{,**} rwklm,
          owner @{HOME}/nixos-config-writable/{,**} rwklm,
          owner @{HOME}/.local/ rw,
          owner @{HOME}/.local/share/ rw,
          owner @{HOME}/.local/share/containers/ rw,
          owner @{HOME}/.local/share/containers/agents/ rw,
          @{HOME}/.local/share/containers/agents/${agentId}/{,**} rwklm,
          owner @{run}/user/[0-9]*/agent-containers/ rw,
          @{run}/user/[0-9]*/agent-containers/${agentId}/{,**} rwklm,
          deny /run/log/journal/{,**} r,
          owner /tmp/{,**} rwklm,
          deny /var/log/journal/{,**} r,
          /var/tmp/ r,
          owner /var/tmp/{,**} rwklm,

          audit deny @{HOME}/.netrc rwklm,
          audit deny @{HOME}/.config/aerc/accounts.conf{,.d/**} rwklm,
          audit deny @{HOME}/.config/sops/{,**} rwklm,
          audit deny @{HOME}/.config/sops-nix/{,**} rwklm,
          audit deny @{HOME}/.gnupg/{,**} rwklm,
          audit deny @{HOME}/.password-store/{,**} rwklm,
          audit deny @{HOME}/.local/share/password-store/{,**} rwklm,
          audit deny @{HOME}/.ssh/{,**} rwklm,
          audit deny @{run}/user/[0-9]*/keyring/{,**} rwklm,
          audit deny /run/secrets{,.d}/{,**} rwklm,
          audit deny /run/user/[0-9]*/secrets.d/{,**} rwklm,
        }
      '';
    };

  containerPayloadPolicy = {
    state = "enforce";
    profile = ''
      abi <abi/4.0>,
      include <tunables/global>

      profile local-agent-container-payload flags=(attach_disconnected.path=/apparmor-disconnected/agent-container-payload/,mediate_deleted) {
        network,
        unix,
        userns,
        capability,
        mount,
        remount,
        umount,
        pivot_root,
        ptrace,
        signal,

        / r,
        /** rwkl,
        /** mr,
        /** ix,
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
    ${systemBusRulesFor service.systemBusPeers}
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
  containerEnginePolicies = lib.mapAttrs' (
    name: app: lib.nameValuePair (containerEngineProfileNameFor name) (containerEnginePolicy name app)
  ) containerApplications;
  containerInfrastructurePolicies = lib.optionalAttrs (containerApplications != { }) {
    local-agent-container-payload = containerPayloadPolicy;
    local-agent-container-denied = {
      state = "enforce";
      profile = ''
        abi <abi/4.0>,

        profile local-agent-container-denied flags=(attach_disconnected,mediate_deleted) {
          audit deny /** rwklmx,
        }
      '';
    };
  };
  servicePolicies = lib.mapAttrs' (
    name: service: lib.nameValuePair (profileNameFor name) (servicePolicy name service)
  ) serviceRegistry;
  bubblewrapPolicies =
    lib.optionalAttrs (bubblewrapProfile != null) {
      bwrap = {
        state = "enforce";
        profile = ''
          include "${bubblewrapProfile}"
        '';
      };
    }
    // lib.optionalAttrs (claudeBubblewrapProfile != null) {
      local-claude-code-bwrap = {
        state = "enforce";
        profile = ''
          include "${claudeBubblewrapProfile}"
        '';
      };
    };

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
  validHomePath =
    path:
    validRelativePath path
    && lib.all (metacharacter: !(lib.hasInfix metacharacter path)) [
      "*"
      "?"
      "["
      "]"
      "{"
      "}"
    ];
  validSystemBusPeer =
    peer:
    builtins.stringLength peer <= 255
    && builtins.match "[A-Za-z_][A-Za-z0-9_-]*(\\.[A-Za-z_][A-Za-z0-9_-]*)+" peer != null;
  appAssertions = lib.mapAttrsToList (name: app: {
    assertion =
      validRelativePath app.executable
      && lib.all validHomePath app.homePaths
      && lib.all (path: lib.hasPrefix "${builtins.storeDir}/" path) app.extraExecutables
      && lib.all (path: lib.hasPrefix "${builtins.storeDir}/" path) app.profileReentryExecutables
      && lib.all validSystemBusPeer app.systemBusPeers
      && (hasCapability app "credential-broker" == sensitiveAccess app "credential-broker")
      && (hasCapability app "bubblewrap" == (app.bubblewrapPackage != null))
      && (hasCapability app "containers" == (app.containerToolsPackage != null))
      && (!hasCapability app "host-diagnostics" || hasCapability app "developer-exec")
      && (app.profileReentryExecutables == [ ] || hasCapability app "userns")
      && (app.userNamespaceRules == "" || app.userNamespaceRulesRationale != "")
      && (
        (!(hasCapability app "developer-exec") && app.sensitiveAccess == [ ])
        || app.elevatedAccessRationale != ""
      )
      && (app.extraRules == "" || app.extraRulesRationale != "");
    message = "Invalid or unexplained AppArmor application descriptor: ${name}";
  }) applicationRegistry;
  serviceAssertions = lib.mapAttrsToList (name: service: {
    assertion =
      lib.all validSystemBusPeer service.systemBusPeers
      && (service.extraRules == "" || service.extraRulesRationale != "");
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
  apparmorDebugReportWriter = pkgs.writeShellApplication {
    name = "apparmor-debug-report-writer";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      if [[ $# -ne 2 ]]; then
        echo "usage: apparmor-debug-report-writer OUTPUT_DIRECTORY BOOT_ID" >&2
        exit 2
      fi

      output_directory="$1"
      boot_id="$2"
      archive_directory="$output_directory/boots"
      install -d -m 0700 "$output_directory" "$archive_directory"
      archive_temporary="$(mktemp "$archive_directory/.report-$boot_id.XXXXXX")"
      latest_temporary="$(mktemp "$output_directory/.logs.json.XXXXXX")"
      cleanup() {
        rm -f "$archive_temporary" "$latest_temporary"
      }
      trap cleanup EXIT

      tee "$archive_temporary" > "$latest_temporary"

      mv -fT "$archive_temporary" "$archive_directory/$boot_id.json"
      archive_temporary=""
      mv -fT "$latest_temporary" "$output_directory/logs.json"
      latest_temporary=""
    '';
  };
  apparmorDebugReport = pkgs.writeShellApplication {
    name = "apparmor-debug-report";
    runtimeInputs = [
      apparmorReport
      pkgs.coreutils
      pkgs.systemd
      pkgs.util-linux
    ];
    text = ''
      output_directory=${lib.escapeShellArg debugPath}
      report_user="${debugUser}"
      report_group="${debugGroup}"
      boot_id="$(< /proc/sys/kernel/random/boot_id)"

      if [[ ! "$boot_id" =~ ^[0-9a-f-]{36}$ ]]; then
        echo "apparmor-debug-report: invalid boot ID: $boot_id" >&2
        exit 1
      fi

      report_temporary="$(mktemp /run/apparmor-debug-report/report.XXXXXX)"
      trap 'rm -f "$report_temporary"' EXIT

      systemd-tmpfiles --create --prefix="$output_directory"
      apparmor-report --profile '*' --json > "$report_temporary"
      setpriv --reuid "$report_user" --regid "$report_group" --init-groups -- \
        ${apparmorDebugReportWriter}/bin/apparmor-debug-report-writer \
        "$output_directory" "$boot_id" < "$report_temporary"
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

    debug = {
      enable = lib.mkEnableOption "periodic AppArmor debug report collection";

      path = mkOption {
        type = types.str;
        default = "~/.local/state/apparmor-reports";
        example = "~/.local/state/apparmor-reports";
        description = ''
          Directory receiving the latest AppArmor report and per-boot archives.
          Absolute paths and paths beginning with ~/ are supported.
        '';
      };
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
        assertion = builtins.length bubblewrapPackages <= 1;
        message = "All local AppArmor Bubblewrap consumers must use the same exact Bubblewrap package.";
      }
      {
        assertion = !cfg.debug.enable || (username != null && homeDirectory != null);
        message = "Local AppArmor debug reporting requires a configured primary user and home directory.";
      }
      {
        assertion =
          !cfg.debug.enable
          || (
            lib.hasPrefix "/" debugPath
            && debugPath != "/"
            && debugPath != builtins.storeDir
            && !(lib.hasPrefix "${builtins.storeDir}/" debugPath)
          );
        message = ''
          security.localAppArmor.debug.path must be an absolute path or begin with ~/;
          the filesystem root and Nix store are not valid report directories.
        '';
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
      policies =
        applicationPolicies
        // servicePolicies
        // bubblewrapPolicies
        // containerEnginePolicies
        // containerInfrastructurePolicies;
    };

    environment.etc = lib.optionalAttrs claudeSandboxEnabled {
      "claude-code/managed-settings.d/20-sandbox.json".text = builtins.toJSON {
        sandbox = {
          enabled = true;
          failIfUnavailable = true;
          allowUnsandboxedCommands = false;
          excludedCommands = [
            "podman *"
            "buildah *"
          ];
        };
      };
    };

    environment.systemPackages = [ apparmorReport ];
    systemd.services =
      serviceAttachments
      // lib.optionalAttrs cfg.debug.enable {
        apparmor-debug-report = {
          description = "Generate the periodic AppArmor debug report";
          after = [
            "apparmor.service"
            "systemd-journald.service"
          ];
          wants = [ "apparmor.service" ];
          unitConfig.RequiresMountsFor = [ debugPath ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${apparmorDebugReport}/bin/apparmor-debug-report";
            UMask = "0077";
            RuntimeDirectory = "apparmor-debug-report";
            RuntimeDirectoryMode = "0700";
            NoNewPrivileges = true;
            PrivateDevices = true;
            PrivateNetwork = true;
            PrivateTmp = true;
            ProtectControlGroups = true;
            ProtectHome = "read-only";
            ProtectHostname = true;
            ProtectKernelModules = true;
            ProtectKernelTunables = true;
            ProtectSystem = "strict";
            ReadWritePaths = [ debugPath ];
            RestrictAddressFamilies = [ "AF_UNIX" ];
            RestrictNamespaces = true;
            RestrictRealtime = true;
            RestrictSUIDSGID = true;
            SystemCallArchitectures = "native";
          };
        };
      };

    systemd.timers.apparmor-debug-report = lib.mkIf cfg.debug.enable {
      description = "Generate an AppArmor debug report every 30 minutes";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:0/30";
        Persistent = true;
      };
    };

    systemd.tmpfiles.settings."10-apparmor-debug-report" = lib.mkIf cfg.debug.enable (
      lib.optionalAttrs
        (homeDirectory != null && lib.hasPrefix "${homeDirectory}/.local/state/" debugPath)
        {
          "${homeDirectory}/.local".d = {
            mode = "0700";
            user = debugUser;
            group = debugGroup;
          };
          "${homeDirectory}/.local/state".d = {
            mode = "0700";
            user = debugUser;
            group = debugGroup;
          };
        }
      // {
        ${debugPath}.d = {
          mode = "0700";
          user = debugUser;
          group = debugGroup;
        };
        "${debugPath}/boots".d = {
          mode = "0700";
          user = debugUser;
          group = debugGroup;
        };
      }
    );
  };
}
