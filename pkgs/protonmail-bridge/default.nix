{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  patchelf,
  libsecret,
  libfido2,
  versionCheckHook,
  gnupg,
  python3,
}:

let
  signatureHash = "sha256-euM3BpMhLA3eaTdzIsE/D+ilK09Ooq7JhOj9+FPLtD4=";
  # Patchelf 0.19.2 corrupts this vendor Go executable; keep the working ELF rewriter.
  bridgePatchelf = patchelf.overrideAttrs {
    version = "0.15.2";
    src = fetchurl {
      url = "https://github.com/NixOS/patchelf/releases/download/0.15.2/patchelf-0.15.2.tar.bz2";
      hash = "sha256-F3RfVkFZyOIo/EEtplogSLhGxLa0Igt3y/IkFuAvLXw=";
    };
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "protonmail-bridge";
  version = "3.27.1";

  src = fetchurl {
    url = "https://proton.me/download/bridge/protonmail-bridge_${finalAttrs.version}-1_amd64.deb";
    hash = "sha512-xOKcs3r07Y7LUxHzDbOsXaVbdMOVpAjzHjI8FOcNT50pbJWFl4XN47KlyhdZeSKZZBIypbGp5uYBTP1PLmA1Wg==";
  };

  nativeBuildInputs = [
    dpkg
    bridgePatchelf
    autoPatchelfHook
    gnupg
    python3
  ];
  buildInputs = [
    libsecret
    libfido2
  ];
  dontConfigure = true;
  dontBuild = true;

  preUnpack = ''
    python ${../verify_signature.py} ${./release-key.asc} ${finalAttrs.passthru.signature} "$src"
  '';

  # Keep the CLI backend used by Thunderbird; the launcher installs mutable updates.
  installPhase = ''
    runHook preInstall
    install -Dm755 usr/lib/protonmail/bridge/bridge $out/bin/protonmail-bridge
    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.signature = fetchurl {
    url = "https://proton.me/download/bridge/protonmail-bridge_${finalAttrs.version}-1_amd64.deb.sig";
    hash = signatureHash;
  };

  meta = {
    description = "Use Proton Mail with a local IMAP and SMTP email client";
    homepage = "https://proton.me/mail/bridge";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "protonmail-bridge";
  };
})
