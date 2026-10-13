{
  upstreamBrave,
  fetchurl,
  gnupg,
  python3,
  versionCheckHook,
}:

let
  release = builtins.fromJSON (builtins.readFile ./release.json);
  filename = "brave-browser_${release.version}_amd64.deb";
  url = "https://github.com/brave/brave-browser/releases/download/v${release.version}/${filename}";
  checksum = fetchurl {
    url = "${url}.sha256";
    sha256 = release.checksumSha256;
  };
  signature = fetchurl {
    url = "${url}.sha256.asc";
    sha256 = release.signatureSha256;
  };
in
upstreamBrave.overrideAttrs (oldAttrs: {
  inherit (release) version;
  src = fetchurl {
    inherit url;
    sha256 = release.sha256;
  };

  nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [
    gnupg
    python3
  ];
  nativeInstallCheckInputs = (oldAttrs.nativeInstallCheckInputs or [ ]) ++ [ versionCheckHook ];
  versionCheckProgram = "${placeholder "out"}/opt/brave.com/brave/brave";
  installCheckPhase = ''
    runHook preInstallCheck
    ${oldAttrs.installCheckPhase}
    runHook postInstallCheck
  '';

  preUnpack = (oldAttrs.preUnpack or "") + ''
    python ${../verify_signature.py} ${./release-key.asc} ${signature} ${checksum}
    test "$(cat ${checksum})" = '${release.sha256}  ${filename}'
    printf '%s  %s\n' '${release.sha256}' "$src" | sha256sum --check
  '';

  # CI owns the local release pin; nixpkgs' updater targets its own package files.
  passthru = builtins.removeAttrs (oldAttrs.passthru or { }) [ "updateScript" ];
  meta = oldAttrs.meta // {
    platforms = [ "x86_64-linux" ];
    changelog = "https://github.com/brave/brave-browser/releases/tag/v${release.version}";
  };
})
