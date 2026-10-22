{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  keyutils,
  libgcc,
  makeBinaryWrapper,
  versionCheckHook,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "proton-pass-cli";
  version = "2.5.1";
  strictDeps = true;

  src = fetchurl {
    url = "https://proton.me/download/pass-cli/${finalAttrs.version}/pass-cli-linux-x86_64";
    hash = "sha256-QOJ2ReBIX18NuSi4FGnRxafIlooWKVbpQAaUdiRMArE=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeBinaryWrapper
  ];
  buildInputs = [
    keyutils
    libgcc
  ];
  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/pass-cli
    runHook postInstall
  '';

  postFixup = ''
    wrapProgram $out/bin/pass-cli --set PROTON_PASS_NO_UPDATE_CHECK 1
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  meta = {
    description = "Command-line interface for Proton Pass";
    homepage = "https://github.com/protonpass/pass-cli";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "pass-cli";
  };
})
