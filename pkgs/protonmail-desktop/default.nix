{
  lib,
  stdenvNoCC,
  fetchurl,
  dpkg,
  asar,
  makeWrapper,
  electron,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "protonmail-desktop";
  version = "1.14.0";

  src = fetchurl {
    url = "https://proton.me/download/mail/linux/${finalAttrs.version}/ProtonMail-desktop-beta.deb";
    hash = "sha512-WQhjL+NOPUC2mMlFm7d0Qopbau3XyJ7Z/2g5S5AifGiaWgPucZ+bOk4gx8SmnOZ/5AqxLg80Q1npAFx76DnYGA==";
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

  meta = {
    description = "Desktop application for Proton Mail and Calendar";
    homepage = "https://proton.me/mail";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "proton-mail";
  };
})
