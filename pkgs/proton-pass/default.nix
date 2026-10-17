{
  lib,
  stdenvNoCC,
  fetchurl,
  dpkg,
  asar,
  makeWrapper,
  electron,
  autoPatchelfHook,
  libgcc,
  libxkbcommon,
  channel ? "stable",
}:

let
  release = (builtins.fromJSON (builtins.readFile ./releases.json)).${channel};
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "proton-pass";
  inherit (release) version;

  src = fetchurl {
    url = "https://proton.me/download/pass/linux/proton-pass_${finalAttrs.version}_amd64.deb";
    inherit (release) hash;
  };

  nativeBuildInputs = [
    dpkg
    asar
    makeWrapper
    autoPatchelfHook
  ];
  buildInputs = [
    libgcc
    libxkbcommon
  ];
  dontConfigure = true;
  dontBuild = true;

  # Match nixpkgs' Electron integration so the existing AppArmor policy applies.
  preInstall = ''
    asar extract usr/lib/proton-pass/resources/app.asar tmp
    substituteInPlace tmp/.webpack/main/index.js \
      --replace-fail "process.resourcesPath" "'$out/share/proton-pass'"
    # Native modules must remain outside the ASAR so Nix can patch their libraries.
    asar pack tmp usr/lib/proton-pass/resources/app.asar --unpack '*.node'
    rm -r tmp
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/proton-pass
    cp -r usr/share/. $out/share/
    cp -r usr/lib/proton-pass/resources/. $out/share/proton-pass/
    runHook postInstall
  '';

  preFixup = ''
    makeWrapper ${lib.getExe electron} $out/bin/proton-pass \
      --add-flags $out/share/proton-pass/app.asar \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}" \
      --set-default ELECTRON_FORCE_IS_PACKAGED 1 \
      --set-default ELECTRON_IS_DEV 0 \
      --inherit-argv0
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    ELECTRON_RUN_AS_NODE=1 ${lib.getExe electron} -e \
      'console.log(Object.keys(require(process.argv[1])).join("\n"))' \
      "$out/share/proton-pass/app.asar/.webpack/main/native_modules/native.linux-x64-gnu.node"
    runHook postInstallCheck
  '';

  passthru = { inherit channel; };

  meta = {
    description = "Desktop application for Proton Pass";
    homepage = "https://proton.me/pass";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "proton-pass";
  };
})
