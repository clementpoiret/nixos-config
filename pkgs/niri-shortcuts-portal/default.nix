{
  lib,
  python3,
  stdenvNoCC,
  systemd,
}:
let
  python = python3.withPackages (ps: [ ps.dbus-fast ]);
  busName = "org.freedesktop.impl.portal.desktop.niri_shortcuts";
  portalPath = "/org/freedesktop/portal/desktop";
in
stdenvNoCC.mkDerivation {
  pname = "niri-shortcuts-portal";
  version = "1.0.0";
  src = ./niri-shortcuts-portal.py;
  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    install -Dm0444 "$src" "$out/libexec/niri-shortcuts-portal.py"
    substituteInPlace "$out/libexec/niri-shortcuts-portal.py" \
      --replace-fail '@bus_name@' '${busName}'
    exec="${python.interpreter} $out/libexec/niri-shortcuts-portal.py"

    install -Dm0444 /dev/stdin "$out/share/xdg-desktop-portal/portals/niri-shortcuts.portal" <<EOF
    [portal]
    DBusName=${busName}
    Interfaces=org.freedesktop.impl.portal.GlobalShortcuts;
    EOF

    install -Dm0444 /dev/stdin "$out/share/dbus-1/services/${busName}.service" <<EOF
    [D-BUS Service]
    Name=${busName}
    Exec=$exec
    SystemdService=niri-shortcuts-portal.service
    EOF

    install -Dm0444 /dev/stdin "$out/lib/systemd/user/niri-shortcuts-portal.service" <<EOF
    [Unit]
    Description=Portal service (shortcuts pressed by niri key bindings)
    PartOf=graphical-session.target
    After=graphical-session.target

    [Service]
    Type=dbus
    BusName=${busName}
    ExecStart=$exec
    Slice=session.slice
    EOF

    runHook postInstall
  '';

  passthru = {
    portalName = "niri-shortcuts";
    # The command a niri bind spawns to press a shortcut that an application bound.
    activateCommand = appId: shortcutId: [
      "${systemd}/bin/busctl"
      "--user"
      "call"
      busName
      portalPath
      busName
      "Activate"
      "ss"
      appId
      shortcutId
    ];
  };

  meta = {
    description = "GlobalShortcuts portal backend whose shortcuts niri key bindings press";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
