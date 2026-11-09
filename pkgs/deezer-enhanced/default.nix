{
  lib,
  stdenvNoCC,
  fetchurl,
  dpkg,
  asar,
  makeWrapper,
  electron,
  dbus,
  makeFontsConf,
  dejavu_fonts,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "deezer-enhanced";
  version = "1.5.1";

  src = fetchurl {
    url = "https://github.com/duzda/deezer-enhanced/releases/download/v${finalAttrs.version}/deezer-enhanced_${finalAttrs.version}_amd64.deb";
    hash = "sha256-iMqQ6mqP5/1nKjqH58kfiQERUeOF54gHvAOiI8narKI=";
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
    asar extract usr/lib/deezer-enhanced/resources/app.asar tmp
    substituteInPlace tmp/.vite/build/main.js \
      --replace-fail "process.resourcesPath" "'$out/share/deezer-enhanced'"
    asar pack tmp usr/lib/deezer-enhanced/resources/app.asar
    rm -r tmp
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/deezer-enhanced
    cp -r usr/share/. $out/share/
    cp -r usr/lib/deezer-enhanced/resources/. $out/share/deezer-enhanced/
    runHook postInstall
  '';

  preFixup = ''
    makeWrapper ${lib.getExe electron} $out/bin/deezer-enhanced \
      --add-flags $out/share/deezer-enhanced/app.asar \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}" \
      --set-default ELECTRON_FORCE_IS_PACKAGED 1 \
      --set-default ELECTRON_IS_DEV 0 \
      --inherit-argv0
  '';

  nativeInstallCheckInputs = [ dbus ];
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME="$TMPDIR/home"
    export XDG_CONFIG_HOME="$HOME/.config"
    export XDG_CACHE_HOME="$HOME/.cache"
    export XDG_RUNTIME_DIR="$TMPDIR/runtime"
    mkdir -m 0700 -p "$XDG_RUNTIME_DIR"
    unset DISPLAY WAYLAND_DISPLAY NIXOS_OZONE_WL
    export FONTCONFIG_FILE=${makeFontsConf { fontDirectories = [ dejavu_fonts ]; }}
    export GIO_USE_VFS=local ELECTRON_FORCE_IS_PACKAGED=1 ELECTRON_IS_DEV=0
    export DEEZER_ARCHIVE="$out/share/deezer-enhanced/app.asar"
    dbus-run-session --config-file=${./dbus.conf} -- \
      ${lib.getExe electron} --no-sandbox --disable-gpu --ozone-platform=headless ${./check-startup.cjs}
    runHook postInstallCheck
  '';

  meta = {
    description = "Unofficial application for Deezer with enhanced features";
    homepage = "https://github.com/duzda/deezer-enhanced";
    changelog = "https://github.com/duzda/deezer-enhanced/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "deezer-enhanced";
  };
})
