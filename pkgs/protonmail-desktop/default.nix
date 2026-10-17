{
  lib,
  stdenvNoCC,
  fetchurl,
  dpkg,
  asar,
  makeWrapper,
  electron,
  channel ? "stable",
}:

let
  release = (builtins.fromJSON (builtins.readFile ./releases.json)).${channel};
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "protonmail-desktop";
  inherit (release) version;

  src = fetchurl {
    url = "https://proton.me/download/mail/linux/${finalAttrs.version}/ProtonMail-desktop-beta.deb";
    inherit (release) hash;
  };

  nativeBuildInputs = [
    dpkg
    asar
    makeWrapper
  ];
  dontConfigure = true;
  dontBuild = true;

  # Electron's resources directory belongs to its runtime, not this application.
  preInstall = ''
    asar extract usr/lib/proton-mail/resources/app.asar tmp
    substituteInPlace tmp/.webpack/main/index.js \
      --replace-fail "process.resourcesPath" "'$out/share/proton-mail'"
    asar pack tmp usr/lib/proton-mail/resources/app.asar
    rm -r tmp
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/proton-mail
    cp -r usr/share/. $out/share/
    cp -r usr/lib/proton-mail/resources/. $out/share/proton-mail/
    runHook postInstall
  '';

  preFixup = ''
    makeWrapper ${lib.getExe electron} $out/bin/proton-mail \
      --add-flags $out/share/proton-mail/app.asar \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}" \
      --set-default ELECTRON_FORCE_IS_PACKAGED 1 \
      --set-default ELECTRON_IS_DEV 0 \
      --inherit-argv0
  '';

  passthru = { inherit channel; };

  meta = {
    description = "Desktop application for Proton Mail and Calendar";
    homepage = "https://proton.me/mail";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "proton-mail";
  };
})
